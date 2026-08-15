/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "android.hardware.gatekeeper@1.0-service.m86"

#include <android/hardware/gatekeeper/1.0/IGatekeeper.h>
#include <hidl/LegacySupport.h>
#include <log/log.h>

#include <cerrno>
#include <cstring>
#include <unistd.h>

using android::hardware::defaultPassthroughServiceImplementation;
using android::hardware::gatekeeper::V1_0::IGatekeeper;

namespace {

constexpr char kGatekeeperDataDirectory[] = "/data/misc/gatekeeper";

}  // namespace

int main() {
    // Flyme's Exynos 7420 GateKeeperAdaptationLayer stores its retry records
    // as relative <secure_user_id>.rec paths. The generic HIDL service starts
    // in /, where its system uid cannot create them; verification then returns
    // ERROR and LockSettings cannot unwrap the synthetic password. Match the
    // legacy gatekeeperd environment before dlopen() loads gatekeeper.m86.so.
    if (chdir(kGatekeeperDataDirectory) != 0) {
        ALOGE("Cannot enter %s: %s", kGatekeeperDataDirectory, strerror(errno));
        return 1;
    }

    ALOGI("Using legacy Gatekeeper data directory %s", kGatekeeperDataDirectory);
    return defaultPassthroughServiceImplementation<IGatekeeper>();
}
