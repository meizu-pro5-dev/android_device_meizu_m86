/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "m86-power-aidl"

#include "Power.h"

#include <log/log.h>

#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>

namespace aidl::android::hardware::power::impl::m86 {
namespace {

constexpr char kCpu0BoostPulse[] =
    "/sys/devices/system/cpu/cpu0/cpufreq/interactive/boostpulse";
constexpr char kCpu0BoostDuration[] =
    "/sys/devices/system/cpu/cpu0/cpufreq/interactive/boostpulse_duration";
constexpr char kHmpBoostPulse[] = "/sys/kernel/hmp/boostpulse";
constexpr char kHmpBoostDuration[] = "/sys/kernel/hmp/boostpulse_duration";
constexpr char kHotplugProfile[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/current_profile_no";
constexpr char kHotplugBigCluster[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/cl1_booster";
constexpr char kHotplugBigMinimum[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/min_cpu_boosted";
constexpr char kGpuDvfsMinLock[] =
    "/sys/devices/14ac0000.mali/dvfs_min_lock";
constexpr char kGpuDvfsMaxLock[] =
    "/sys/devices/14ac0000.mali/dvfs_max_lock";

constexpr char kProfileHigh[] = "0";
constexpr char kProfileEco[] = "2";
constexpr char kLittleBoostDurationUs[] = "80000";
constexpr char kDisplayBoostDurationUs[] = "120000";
constexpr char kHmpInteractionDurationUs[] = "250000";
constexpr char kHmpLaunchDurationUs[] = "500000";
constexpr char kGpuUnlock[] = "0";
constexpr char kGpuFloorRendering[] = "420";
constexpr char kGpuCeilingLimited[] = "544";

int WriteNode(const char* path, const char* value) {
  int fd = TEMP_FAILURE_RETRY(open(path, O_WRONLY | O_CLOEXEC));
  if (fd < 0) {
    ALOGV("Cannot open %s: %s", path, strerror(errno));
    return -errno;
  }

  const ssize_t expected = static_cast<ssize_t>(strlen(value));
  const ssize_t written = TEMP_FAILURE_RETRY(write(fd, value, expected));
  if (written != expected) {
    const int error = written < 0 ? errno : EIO;
    ALOGW("Cannot write %s: %s", path, strerror(error));
    close(fd);
    return -error;
  }

  close(fd);
  return 0;
}

void SendBoostPulse(const char* duration_path, const char* pulse_path,
                    const char* duration_us) {
  if (WriteNode(duration_path, duration_us) == 0) {
    WriteNode(pulse_path, "1");
  }
}

}  // namespace

Power::Power() {
  std::lock_guard<std::mutex> guard(lock_);
  WriteNode(kCpu0BoostDuration, kLittleBoostDurationUs);
  ApplyPowerProfileLocked(false);
}

void Power::ApplyGpuFloorLocked() {
  const char* floor = interactive_ && !display_inactive_ && expensive_rendering_
                          ? kGpuFloorRendering
                          : kGpuUnlock;

  if (applied_gpu_floor_ == nullptr || strcmp(applied_gpu_floor_, floor) != 0) {
    if (WriteNode(kGpuDvfsMinLock, floor) == 0) {
      applied_gpu_floor_ = floor;
    }
  }
}

void Power::ApplyGpuCeilingLocked() {
  const char* ceiling =
      (low_power_ || sustained_performance_) ? kGpuCeilingLimited : kGpuUnlock;

  if (applied_gpu_ceiling_ == nullptr ||
      strcmp(applied_gpu_ceiling_, ceiling) != 0) {
    if (WriteNode(kGpuDvfsMaxLock, ceiling) == 0) {
      applied_gpu_ceiling_ = ceiling;
    }
  }
}

void Power::SendDisplayUpdateBoostLocked() {
  if (!interactive_ || display_inactive_) {
    return;
  }

  if (!low_power_) {
    SendBoostPulse(kHmpBoostDuration, kHmpBoostPulse,
                   kDisplayBoostDurationUs);
  }
}

void Power::SendInteractionBoostLocked(bool launch) {
  if (!launch && (!interactive_ || display_inactive_)) {
    return;
  }
  if (!low_power_) {
    SendBoostPulse(kHmpBoostDuration, kHmpBoostPulse,
                   launch ? kHmpLaunchDurationUs
                          : kHmpInteractionDurationUs);
  }
  WriteNode(kCpu0BoostPulse, "1");
}

void Power::ApplyPowerProfileLocked(bool low_power) {
  const int profile_error =
      WriteNode(kHotplugProfile, low_power ? kProfileEco : kProfileHigh);
  const int cluster_error = WriteNode(kHotplugBigCluster, low_power ? "0" : "1");
  // Let March choose the big-core count without a forced minimum.
  const int error = WriteNode(kHotplugBigMinimum, "0");
  if (error != 0) {
    ALOGW("Cannot reset %s to 0: %s", kHotplugBigMinimum, strerror(-error));
  }

  low_power_ = low_power;
  profile_applied_ = profile_error == 0 && cluster_error == 0 && error == 0;
  ApplyGpuCeilingLocked();
  ApplyGpuFloorLocked();
}

ndk::ScopedAStatus Power::setMode(Mode type, bool enabled) {
  std::lock_guard<std::mutex> guard(lock_);

  switch (type) {
    case Mode::LOW_POWER:
      if (low_power_ != enabled || !profile_applied_) {
        ApplyPowerProfileLocked(enabled);
      }
      break;
    case Mode::SUSTAINED_PERFORMANCE:
      sustained_performance_ = enabled;
      ApplyGpuCeilingLocked();
      break;
    case Mode::LAUNCH:
      if (enabled) {
        SendInteractionBoostLocked(true);
      }
      break;
    case Mode::EXPENSIVE_RENDERING:
      expensive_rendering_ = enabled;
      ApplyGpuFloorLocked();
      break;
    case Mode::INTERACTIVE:
      interactive_ = enabled;
      ApplyGpuFloorLocked();
      break;
    case Mode::DISPLAY_INACTIVE:
      display_inactive_ = enabled;
      ApplyGpuFloorLocked();
      break;
    default:
      break;
  }

  return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::isModeSupported(Mode type, bool* supported) {
  switch (type) {
    case Mode::LOW_POWER:
    case Mode::SUSTAINED_PERFORMANCE:
    case Mode::LAUNCH:
    case Mode::EXPENSIVE_RENDERING:
    case Mode::INTERACTIVE:
    case Mode::DISPLAY_INACTIVE:
      *supported = true;
      break;
    default:
      *supported = false;
      break;
  }
  return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::setBoost(Boost type, int32_t duration_ms) {
  std::lock_guard<std::mutex> guard(lock_);

  switch (type) {
    case Boost::INTERACTION:
      if (duration_ms >= 0) {
        SendInteractionBoostLocked(false);
      }
      break;
    case Boost::DISPLAY_UPDATE_IMMINENT:
      if (duration_ms >= 0) {
        SendDisplayUpdateBoostLocked();
      }
      break;
    default:
      break;
  }
  return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::isBoostSupported(Boost type, bool* supported) {
  *supported = type == Boost::INTERACTION ||
               type == Boost::DISPLAY_UPDATE_IMMINENT;
  return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus Power::createHintSession(
    int32_t tgid, int32_t uid, const std::vector<int32_t>& thread_ids,
    int64_t duration_nanos, std::shared_ptr<IPowerHintSession>* session) {
  (void)tgid;
  (void)uid;
  (void)thread_ids;
  (void)duration_nanos;
  *session = nullptr;
  return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
}

ndk::ScopedAStatus Power::getHintSessionPreferredRate(int64_t* rate_nanos) {
  *rate_nanos = 0;
  return ndk::ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
}

binder_status_t Power::dump(int fd, const char** args, uint32_t num_args) {
  (void)args;
  (void)num_args;
  std::lock_guard<std::mutex> guard(lock_);
  dprintf(fd,
          "m86 AIDL PowerHAL\n"
          "interactive=%d display_inactive=%d low_power=%d sustained=%d "
          "expensive_rendering=%d gpu_floor=%s gpu_ceiling=%s "
          "big_min_policy=0 hmp_us=120000/250000/500000\n",
          interactive_, display_inactive_, low_power_, sustained_performance_,
          expensive_rendering_,
          applied_gpu_floor_ == nullptr ? "unknown" : applied_gpu_floor_,
          applied_gpu_ceiling_ == nullptr ? "unknown" : applied_gpu_ceiling_);
  return STATUS_OK;
}

}  // namespace aidl::android::hardware::power::impl::m86
