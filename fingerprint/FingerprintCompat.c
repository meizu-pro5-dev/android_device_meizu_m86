/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * Flyme's m86 fingerprint HAL was built with four Meizu callbacks inserted
 * into fingerprint_device_t before get_authenticator_id.  Android's standard
 * legacy-to-HIDL adapter therefore reads every callback from
 * get_authenticator_id through authenticate at the wrong offset.  In
 * particular, set_active_group calls get_authenticator_id and the Flyme HAL's
 * template database path remains empty.
 *
 * Load the unmodified Flyme HAL under a private name, open its device, and
 * rewrite only the public callback slots to Android's standard layout.  The
 * implementation, Trustonic session, template database, and authentication
 * tokens remain owned by the original Flyme HAL.
 */

#define LOG_TAG "m86-fingerprint-compat"

#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <hardware/fingerprint.h>
#include <hardware/hardware.h>
#include <log/log.h>

#ifdef __ANDROID_VENDOR__
#define FLYME_FINGERPRINT_HAL "/vendor/lib64/hw/fingerprint.m86.flyme.so"
#else
#define FLYME_FINGERPRINT_HAL "/system/lib64/hw/fingerprint.m86.flyme.so"
#endif

struct flyme_fingerprint_device {
  hw_device_t common;
  fingerprint_notify_t notify;
  int (*set_notify)(fingerprint_device_t *, fingerprint_notify_t);
  uint64_t (*pre_enroll)(fingerprint_device_t *);
  int (*enroll)(fingerprint_device_t *, const hw_auth_token_t *, uint32_t,
                uint32_t);
  int (*post_enroll)(fingerprint_device_t *);

  /* Flyme-private callbacks absent from AOSP's fingerprint_device_t. */
  int (*screen_off)(fingerprint_device_t *);
  int (*screen_on)(fingerprint_device_t *);
  int (*lockout)(fingerprint_device_t *);
  int (*lockout_reset)(fingerprint_device_t *);

  uint64_t (*get_authenticator_id)(fingerprint_device_t *);
  int (*cancel)(fingerprint_device_t *);
  int (*enumerate)(fingerprint_device_t *);
  int (*remove)(fingerprint_device_t *, uint32_t, uint32_t);
  int (*set_active_group)(fingerprint_device_t *, uint32_t, const char *);
  int (*authenticate)(fingerprint_device_t *, uint64_t, uint32_t);
  void *reserved[4];
};

_Static_assert(offsetof(fingerprint_device_t, get_authenticator_id) == 0xa0,
               "unexpected AOSP fingerprint ABI");
_Static_assert(offsetof(fingerprint_device_t, set_active_group) == 0xc0,
               "unexpected AOSP fingerprint ABI");
_Static_assert(offsetof(struct flyme_fingerprint_device,
                        get_authenticator_id) == 0xc0,
               "unexpected Flyme fingerprint ABI");
_Static_assert(offsetof(struct flyme_fingerprint_device, set_active_group) ==
                   0xe0,
               "unexpected Flyme fingerprint ABI");
_Static_assert(sizeof(struct flyme_fingerprint_device) == 0x110,
               "unexpected Flyme fingerprint device size");

static void *flyme_hal_handle;
static pthread_mutex_t notify_lock = PTHREAD_MUTEX_INITIALIZER;
static fingerprint_notify_t framework_notify;
static int (*flyme_set_notify)(fingerprint_device_t *, fingerprint_notify_t);
static int (*flyme_cancel)(fingerprint_device_t *);
static int cancel_in_progress;
static int cancel_notified;

static void fingerprint_compat_notify(const fingerprint_msg_t *message) {
  fingerprint_notify_t notify;

  pthread_mutex_lock(&notify_lock);
  if (cancel_in_progress && message != NULL &&
      message->type == FINGERPRINT_ERROR &&
      message->data.error == FINGERPRINT_ERROR_CANCELED) {
    cancel_notified = 1;
  }
  notify = framework_notify;
  pthread_mutex_unlock(&notify_lock);

  if (notify != NULL) {
    notify(message);
  }
}

static int fingerprint_compat_set_notify(fingerprint_device_t *device,
                                         fingerprint_notify_t notify) {
  int status;

  if (flyme_set_notify == NULL) {
    return -ENOSYS;
  }
  pthread_mutex_lock(&notify_lock);
  framework_notify = notify;
  pthread_mutex_unlock(&notify_lock);
  status = flyme_set_notify(device, fingerprint_compat_notify);
  if (status != 0) {
    pthread_mutex_lock(&notify_lock);
    framework_notify = NULL;
    pthread_mutex_unlock(&notify_lock);
  }
  return status;
}

static int fingerprint_compat_cancel(fingerprint_device_t *device) {
  fingerprint_notify_t notify;
  fingerprint_msg_t canceled_message;
  int synthesize_cancel;
  int status;

  if (flyme_cancel == NULL) {
    return -ENOSYS;
  }

  pthread_mutex_lock(&notify_lock);
  cancel_in_progress = 1;
  cancel_notified = 0;
  pthread_mutex_unlock(&notify_lock);

  /*
   * Flyme joins the active worker before returning from cancel(), but its
   * FPC_ERROR_CANCELLED path exits without the Android-required
   * FINGERPRINT_ERROR_CANCELED notification. Settings' FindSensor activity
   * waits for that notification before it starts the real enrollment client.
   */
  status = flyme_cancel(device);

  pthread_mutex_lock(&notify_lock);
  notify = framework_notify;
  synthesize_cancel = status == 0 && !cancel_notified && notify != NULL;
  cancel_in_progress = 0;
  pthread_mutex_unlock(&notify_lock);

  if (synthesize_cancel) {
    memset(&canceled_message, 0, sizeof(canceled_message));
    canceled_message.type = FINGERPRINT_ERROR;
    canceled_message.data.error = FINGERPRINT_ERROR_CANCELED;
    ALOGI("Synthesized missing FINGERPRINT_ERROR_CANCELED callback");
    notify(&canceled_message);
  }
  return status;
}

static int fingerprint_compat_open(const hw_module_t *module, const char *id,
                                   hw_device_t **hardware_device) {
  const fingerprint_module_t *flyme_module;
  struct flyme_fingerprint_device *flyme_device;
  fingerprint_device_t *aosp_device;
  uint64_t (*get_authenticator_id)(fingerprint_device_t *);
  int (*cancel)(fingerprint_device_t *);
  int (*enumerate)(fingerprint_device_t *);
  int (*remove)(fingerprint_device_t *, uint32_t, uint32_t);
  int (*set_active_group)(fingerprint_device_t *, uint32_t, const char *);
  int (*authenticate)(fingerprint_device_t *, uint64_t, uint32_t);
  void *handle;
  int status;

  (void)module;
  if (hardware_device == NULL) {
    return -EINVAL;
  }
  *hardware_device = NULL;

  handle = dlopen(FLYME_FINGERPRINT_HAL, RTLD_NOW | RTLD_LOCAL);
  if (handle == NULL) {
    ALOGE("Cannot load %s: %s", FLYME_FINGERPRINT_HAL, dlerror());
    return -ENOENT;
  }

  dlerror();
  flyme_module = (const fingerprint_module_t *)
      dlsym(handle, HAL_MODULE_INFO_SYM_AS_STR);
  if (flyme_module == NULL) {
    ALOGE("Cannot find %s in %s: %s", HAL_MODULE_INFO_SYM_AS_STR,
          FLYME_FINGERPRINT_HAL, dlerror());
    dlclose(handle);
    return -EINVAL;
  }
  if (flyme_module->common.methods == NULL ||
      flyme_module->common.methods->open == NULL) {
    ALOGE("Flyme fingerprint HAL has no open method");
    dlclose(handle);
    return -EINVAL;
  }

  status = flyme_module->common.methods->open(
      &flyme_module->common, id, hardware_device);
  if (status != 0 || *hardware_device == NULL) {
    ALOGE("Flyme fingerprint HAL open failed: %d", status);
    dlclose(handle);
    *hardware_device = NULL;
    return status != 0 ? status : -EIO;
  }

  flyme_device = (struct flyme_fingerprint_device *)*hardware_device;
  flyme_set_notify = flyme_device->set_notify;
  get_authenticator_id = flyme_device->get_authenticator_id;
  flyme_cancel = flyme_device->cancel;
  cancel = fingerprint_compat_cancel;
  enumerate = flyme_device->enumerate;
  remove = flyme_device->remove;
  set_active_group = flyme_device->set_active_group;
  authenticate = flyme_device->authenticate;
  if (flyme_set_notify == NULL || get_authenticator_id == NULL ||
      flyme_cancel == NULL || enumerate == NULL || remove == NULL ||
      set_active_group == NULL || authenticate == NULL) {
    ALOGE("Flyme fingerprint HAL has an incomplete callback table");
    (*hardware_device)->close(*hardware_device);
    *hardware_device = NULL;
    dlclose(handle);
    return -EINVAL;
  }

  /* Capture every source pointer before writing overlapping AOSP slots. */
  aosp_device = (fingerprint_device_t *)flyme_device;
  aosp_device->set_notify = fingerprint_compat_set_notify;
  aosp_device->get_authenticator_id = get_authenticator_id;
  aosp_device->cancel = cancel;
  aosp_device->enumerate = enumerate;
  aosp_device->remove = remove;
  aosp_device->set_active_group = set_active_group;
  aosp_device->authenticate = authenticate;

  /* Keep the provider loaded for the lifetime of its returned device. */
  flyme_hal_handle = handle;
  ALOGI("Remapped Flyme fingerprint callbacks to the AOSP 2.1 ABI");
  return 0;
}

static struct hw_module_methods_t fingerprint_compat_methods = {
    .open = fingerprint_compat_open,
};

fingerprint_module_t HAL_MODULE_INFO_SYM = {
    .common =
        {
            .tag = HARDWARE_MODULE_TAG,
            .module_api_version = FINGERPRINT_MODULE_API_VERSION_2_1,
            .hal_api_version = HARDWARE_HAL_API_VERSION,
            .id = FINGERPRINT_HARDWARE_MODULE_ID,
            .name = "Meizu PRO 5 Flyme fingerprint ABI compatibility HAL",
            .author = "The LineageOS Project",
            .methods = &fingerprint_compat_methods,
        },
};
