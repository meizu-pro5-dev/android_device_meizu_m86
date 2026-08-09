/*
 * Copyright (C) 2017-2018 TeamNexus
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "libm86camera_shim"

#include <sys/types.h>

#include <cutils/threads.h>
#include <gui/GLConsumer.h>
#include <log/log.h>
#include <ui/GraphicBuffer.h>

namespace android {

/*
 * These two Samsung/Meizu CameraParameters constants are imported by the
 * hash-locked Flyme 8 libexynoscamera but are not part of Android 10's
 * generic CameraParameters class. A partial declaration is sufficient for
 * defining the exact legacy data symbols without replacing libcamera_client.
 */
class CameraParameters {
  public:
    static const char EFFECT_POINT_BLUE[];
    static const char PIXEL_FORMAT_YUV420SP_NV21[];
};

const char CameraParameters::EFFECT_POINT_BLUE[] = "point-blue";
const char CameraParameters::PIXEL_FORMAT_YUV420SP_NV21[] = "nv21";

}  // namespace android

extern "C" pid_t androidGetTid()
{
    return gettid();
}

/* The stock library references a vendor hook that has no external effect. */
extern "C" void set_value()
{
    ALOGV("ignored legacy set_value hook");
}

/*
 * Fence::~Fence stopped exporting an out-of-line D1 symbol in Android P.
 * The object is ref-counted by current libui; the universal7420 compatibility
 * implementation is intentionally an empty legacy entry point.
 */
extern "C" void* _ZN7android5FenceD1Ev(void* instance)
{
    return instance;
}

/*
 * GLConsumer::getCurrentBuffer gained an optional out-slot argument after
 * the Flyme camera stack was built. Preserve the old no-argument entry point
 * and forward it to Android 10's implementation.
 */
android::sp<android::GraphicBuffer> legacyGetCurrentBuffer(
        const android::GLConsumer* consumer)
        __asm__("_ZNK7android10GLConsumer16getCurrentBufferEv");

android::sp<android::GraphicBuffer> legacyGetCurrentBuffer(
        const android::GLConsumer* consumer)
{
    return consumer->getCurrentBuffer(nullptr);
}

/*
 * GraphicBuffer::lock gained optional bytes-per-pixel and bytes-per-stride
 * result arguments after the Flyme camera libraries were built. Keep the old
 * two-argument member ABI and forward it to Android 10's implementation.
 */
android::status_t legacyGraphicBufferLock(android::GraphicBuffer* buffer,
        uint32_t usage, void** vaddr)
        __asm__("_ZN7android13GraphicBuffer4lockEjPPv");

android::status_t legacyGraphicBufferLock(android::GraphicBuffer* buffer,
        uint32_t usage, void** vaddr)
{
    return buffer->lock(usage, vaddr, nullptr, nullptr);
}
