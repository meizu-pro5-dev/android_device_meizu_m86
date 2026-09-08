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

int main(int argc, char** argv) {
    const char* dataDirectory = kGatekeeperDataDirectory;
    if (argc == 2 && strcmp(argv[1], "/data/vendor/gatekeeper") == 0) {
        dataDirectory = argv[1];
    } else if (argc != 1) {
        ALOGE("Unsupported Gatekeeper data directory argument");
        return 1;
    }
    // Flyme's Exynos 7420 GateKeeperAdaptationLayer stores its retry records
    // as relative <secure_user_id>.rec paths. The generic HIDL service starts
    // in /, where its system uid cannot create them; verification then returns
    // ERROR and LockSettings cannot unwrap the synthetic password. Match the
    // legacy gatekeeperd environment before dlopen() loads gatekeeper.m86.so.
    if (chdir(dataDirectory) != 0) {
        ALOGE("Cannot enter %s: %s", dataDirectory, strerror(errno));
        return 1;
    }

    ALOGI("Using Gatekeeper data directory %s", dataDirectory);
    return defaultPassthroughServiceImplementation<IGatekeeper>();
}
