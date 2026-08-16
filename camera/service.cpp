/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "android.hardware.camera.provider@2.4-service.m86"

#include <android/hardware/camera/provider/2.4/ICameraProvider.h>
#include <binder/ProcessState.h>
#include <hidl/LegacySupport.h>

using android::hardware::defaultPassthroughServiceImplementation;
using android::hardware::camera::provider::V2_4::ICameraProvider;

int main() {
    ALOGI("CameraProvider@2.4 m86 service is starting.");

    // The Flyme m86 camera HAL uses libsensor and resolves the framework
    // sensorservice through libbinder. Forcing this process onto /dev/vndbinder
    // makes that lookup block forever in the vendor service manager. HIDL
    // transport has its own /dev/hwbinder ProcessState, so keep libbinder on
    // the framework /dev/binder default for the legacy HAL.
    android::ProcessState::initWithDriver("/dev/binder");

    return defaultPassthroughServiceImplementation<ICameraProvider>(
            "legacy/0", /*maxThreads*/ 6);
}
