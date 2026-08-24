/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "m86-power-aidl"

#include "Power.h"

#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <log/log.h>

#include <cstdlib>
#include <memory>
#include <string>

using aidl::android::hardware::power::impl::m86::Power;

int main() {
  ABinderProcess_setThreadPoolMaxThreadCount(0);

  std::shared_ptr<Power> power = ndk::SharedRefBase::make<Power>();
  const std::string instance = std::string(Power::descriptor) + "/default";
  const binder_status_t status =
      AServiceManager_addService(power->asBinder().get(), instance.c_str());
  if (status != STATUS_OK) {
    ALOGE("Cannot register %s: %d", instance.c_str(), status);
    return EXIT_FAILURE;
  }

  ALOGI("Registered %s", instance.c_str());
  ABinderProcess_joinThreadPool();
  return EXIT_FAILURE;
}
