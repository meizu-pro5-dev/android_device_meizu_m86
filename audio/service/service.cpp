/*
 * Copyright (C) 2016 The Android Open Source Project
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "audiohalservice"

#include <signal.h>
#include <string>
#include <vector>

#include <binder/ProcessState.h>
#include <cutils/properties.h>
#include <hidl/HidlTransportSupport.h>
#include <hidl/LegacySupport.h>
#include <hwbinder/ProcessState.h>

using namespace android::hardware;
using android::OK;

using InterfacesList = std::vector<std::string>;

template <class Iter>
static bool registerPassthroughServiceImplementations(Iter first, Iter last) {
    for (; first != last; ++first) {
        if (registerPassthroughServiceImplementation(*first) == OK) {
            return true;
        }
    }
    return false;
}

int main(int /* argc */, char* /* argv */[]) {
    signal(SIGPIPE, SIG_IGN);

    // The legacy m86 audio stack still makes vendor binder calls. Android 13's
    // generic audio service starts this pool and then tries to shrink the same
    // libbinder ProcessState through libbinder_ndk, which aborts immediately.
    // Keep the proven HIDL-only service boundary used by Exynos7420 instead.
    ::android::ProcessState::initWithDriver("/dev/vndbinder");
    ::android::ProcessState::self()->startThreadPool();

    const int32_t defaultValue = -1;
    int32_t value =
            property_get_int32("persist.vendor.audio.service.hwbinder.size_kbyte", defaultValue);
    if (value != defaultValue) {
        ALOGD("Configuring hwbinder with mmap size %d KBytes", value);
        ProcessState::initWithMmapSize(static_cast<size_t>(value) * 1024);
    }
    configureRpcThreadpool(16, true /* callerWillJoin */);

    // Automatic formatting tries to compact these lists.
    // clang-format off
    const std::vector<InterfacesList> mandatoryInterfaces = {
        {
            "Audio Core API",
            "android.hardware.audio@7.1::IDevicesFactory",
            "android.hardware.audio@7.0::IDevicesFactory",
            "android.hardware.audio@6.0::IDevicesFactory",
            "android.hardware.audio@5.0::IDevicesFactory",
            "android.hardware.audio@4.0::IDevicesFactory",
        },
        {
            "Audio Effect API",
            "android.hardware.audio.effect@7.0::IEffectsFactory",
            "android.hardware.audio.effect@6.0::IEffectsFactory",
            "android.hardware.audio.effect@5.0::IEffectsFactory",
            "android.hardware.audio.effect@4.0::IEffectsFactory",
        },
        {
            "Bluetooth Audio API",
            "android.hardware.bluetooth.audio@2.0::IBluetoothAudioProvidersFactory",
        },
    };

    const std::vector<InterfacesList> optionalInterfaces = {
        {
            "Soundtrigger API",
            "android.hardware.soundtrigger@2.3::ISoundTriggerHw",
            "android.hardware.soundtrigger@2.2::ISoundTriggerHw",
            "android.hardware.soundtrigger@2.1::ISoundTriggerHw",
            "android.hardware.soundtrigger@2.0::ISoundTriggerHw",
        },
        {
            "Bluetooth Audio Offload API",
            "android.hardware.bluetooth.a2dp@1.0::IBluetoothAudioOffload",
        },
    };
    // clang-format on

    for (const auto& listIter : mandatoryInterfaces) {
        auto iter = listIter.begin();
        const std::string& interfaceFamilyName = *iter++;
        LOG_ALWAYS_FATAL_IF(!registerPassthroughServiceImplementations(iter, listIter.end()),
                            "Could not register %s", interfaceFamilyName.c_str());
    }

    for (const auto& listIter : optionalInterfaces) {
        auto iter = listIter.begin();
        const std::string& interfaceFamilyName = *iter++;
        ALOGW_IF(!registerPassthroughServiceImplementations(iter, listIter.end()),
                 "Could not register %s", interfaceFamilyName.c_str());
    }

    joinRpcThreadpool();
}
