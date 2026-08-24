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
constexpr char kCpu4BoostPulse[] =
    "/sys/devices/system/cpu/cpu4/cpufreq/interactive/boostpulse";
constexpr char kCpu0BoostDuration[] =
    "/sys/devices/system/cpu/cpu0/cpufreq/interactive/boostpulse_duration";
constexpr char kCpu4BoostDuration[] =
    "/sys/devices/system/cpu/cpu4/cpufreq/interactive/boostpulse_duration";
constexpr char kHmpBoostPulse[] = "/sys/kernel/hmp/boostpulse";
constexpr char kHmpBoostDuration[] = "/sys/kernel/hmp/boostpulse_duration";
constexpr char kHotplugProfile[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/current_profile_no";
constexpr char kHotplugBigCluster[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/cl1_booster";
constexpr char kHotplugBigMinimum[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/min_cpu_boosted";
constexpr char kHotplugInteraction[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/interaction_boost";
constexpr char kGpuDvfsMinLock[] =
    "/sys/devices/14ac0000.mali/dvfs_min_lock";
constexpr char kGpuDvfsMaxLock[] =
    "/sys/devices/14ac0000.mali/dvfs_max_lock";

constexpr char kProfileHigh[] = "0";
constexpr char kProfileEco[] = "2";
constexpr char kBigMinimumHigh[] = "2";
constexpr char kLittleBoostDurationUs[] = "80000";
constexpr char kBigBoostDurationUs[] = "400000";
constexpr char kBigLaunchBoostDurationUs[] = "600000";
constexpr char kDisplayBoostDurationUs[] = "120000";
constexpr char kHmpInteractionDurationUs[] = "250000";
constexpr char kHmpLaunchDurationUs[] = "500000";
constexpr char kGpuUnlock[] = "0";
constexpr char kGpuFloorRendering[] = "420";
constexpr char kGpuFloorDisplayUpdate[] = "544";
constexpr char kGpuFloorHigh[] = "700";
constexpr unsigned int kGpuDisplayUpdateMs = 100;
constexpr unsigned int kGpuInteractionHighMs = 300;
constexpr unsigned int kGpuInteractionMs = 800;
constexpr unsigned int kGpuLaunchMs = 1300;

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
  WriteNode(duration_path, duration_us);
  WriteNode(pulse_path, "1");
}

}  // namespace

Power::Power() {
  std::lock_guard<std::mutex> guard(lock_);
  WriteNode(kCpu0BoostDuration, kLittleBoostDurationUs);
  WriteNode(kGpuDvfsMinLock, kGpuUnlock);
  WriteNode(kGpuDvfsMaxLock, kGpuUnlock);
  ApplyPowerProfileLocked(false);
  applied_gpu_floor_ = kGpuUnlock;
  applied_gpu_ceiling_ = kGpuUnlock;
  gpu_thread_ = std::thread(&Power::GpuBoostWorker, this);
}

Power::~Power() {
  {
    std::lock_guard<std::mutex> guard(lock_);
    stop_worker_ = true;
    gpu_cond_.notify_all();
  }
  if (gpu_thread_.joinable()) {
    gpu_thread_.join();
  }
}

void Power::ApplyGpuFloorLocked() {
  const char* floor = kGpuUnlock;

  if (interactive_ && !display_inactive_) {
    if (interaction_high_boost_ || display_update_boost_) {
      floor = low_power_ ? kGpuFloorRendering : kGpuFloorHigh;
    } else if (interaction_boost_) {
      floor = low_power_ ? kGpuFloorRendering
                         : kGpuFloorDisplayUpdate;
    } else if (expensive_rendering_) {
      floor = kGpuFloorRendering;
    }
  }

  if (applied_gpu_floor_ == nullptr || strcmp(applied_gpu_floor_, floor) != 0) {
    if (WriteNode(kGpuDvfsMinLock, floor) == 0) {
      applied_gpu_floor_ = floor;
    }
  }
}

void Power::ApplyGpuCeilingLocked() {
  const char* ceiling =
      (low_power_ || sustained_performance_) ? kGpuFloorDisplayUpdate
                                             : kGpuUnlock;

  if (applied_gpu_ceiling_ == nullptr ||
      strcmp(applied_gpu_ceiling_, ceiling) != 0) {
    if (WriteNode(kGpuDvfsMaxLock, ceiling) == 0) {
      applied_gpu_ceiling_ = ceiling;
    }
  }
}

void Power::CancelInteractionBoostLocked() {
  interaction_boost_ = false;
  interaction_high_boost_ = false;
  interaction_deadline_ = TimePoint{};
  interaction_high_deadline_ = TimePoint{};
  ApplyGpuFloorLocked();
}

void Power::CancelDisplayUpdateBoostLocked() {
  display_update_boost_ = false;
  display_update_deadline_ = TimePoint{};
  ApplyGpuFloorLocked();
}

void Power::CancelGpuBoostsLocked() {
  interaction_boost_ = false;
  interaction_high_boost_ = false;
  display_update_boost_ = false;
  interaction_deadline_ = TimePoint{};
  interaction_high_deadline_ = TimePoint{};
  display_update_deadline_ = TimePoint{};
  ApplyGpuFloorLocked();
}

void Power::GpuBoostWorker() {
  std::unique_lock<std::mutex> lock(lock_);

  while (!stop_worker_) {
    gpu_cond_.wait(lock, [this] {
      return stop_worker_ || interaction_boost_ || display_update_boost_;
    });
    if (stop_worker_) {
      break;
    }

    TimePoint deadline = interaction_boost_ ? interaction_deadline_
                                            : display_update_deadline_;
    if (display_update_boost_ && display_update_deadline_ < deadline) {
      deadline = display_update_deadline_;
    }
    if (interaction_high_boost_ && interaction_high_deadline_ < deadline) {
      deadline = interaction_high_deadline_;
    }
    if (gpu_cond_.wait_until(lock, deadline) != std::cv_status::timeout) {
      continue;
    }

    const auto now = std::chrono::steady_clock::now();
    bool changed = false;
    if (interaction_boost_ && interaction_deadline_ <= now) {
      interaction_boost_ = false;
      interaction_high_boost_ = false;
      interaction_deadline_ = TimePoint{};
      interaction_high_deadline_ = TimePoint{};
      changed = true;
    } else if (interaction_high_boost_ &&
               interaction_high_deadline_ <= now) {
      interaction_high_boost_ = false;
      interaction_high_deadline_ = TimePoint{};
      changed = true;
    }
    if (display_update_boost_ && display_update_deadline_ <= now) {
      display_update_boost_ = false;
      display_update_deadline_ = TimePoint{};
      changed = true;
    }
    if (changed) {
      ApplyGpuFloorLocked();
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
    SendBoostPulse(kCpu4BoostDuration, kCpu4BoostPulse,
                   kDisplayBoostDurationUs);
  }

  const auto now = std::chrono::steady_clock::now();
  display_update_boost_ = true;
  display_update_deadline_ =
      now + std::chrono::milliseconds(kGpuDisplayUpdateMs);
  ApplyGpuFloorLocked();
  gpu_cond_.notify_all();
}

void Power::SendInteractionBoostLocked(bool launch) {
  if (!low_power_) {
    WriteNode(kHotplugInteraction, "1");
    SendBoostPulse(kHmpBoostDuration, kHmpBoostPulse,
                   launch ? kHmpLaunchDurationUs
                          : kHmpInteractionDurationUs);
    SendBoostPulse(kCpu4BoostDuration, kCpu4BoostPulse,
                   launch ? kBigLaunchBoostDurationUs
                          : kBigBoostDurationUs);
  }
  WriteNode(kCpu0BoostPulse, "1");

  if (!interactive_ || display_inactive_) {
    return;
  }

  const unsigned int gpu_ms = launch ? kGpuLaunchMs : kGpuInteractionMs;
  const auto now = std::chrono::steady_clock::now();
  interaction_boost_ = true;
  interaction_high_boost_ = true;
  interaction_high_deadline_ =
      now + std::chrono::milliseconds(kGpuInteractionHighMs);
  interaction_deadline_ = now + std::chrono::milliseconds(gpu_ms);
  ApplyGpuFloorLocked();
  gpu_cond_.notify_all();
}

void Power::ApplyPowerProfileLocked(bool low_power) {
  WriteNode(kHotplugProfile, low_power ? kProfileEco : kProfileHigh);
  WriteNode(kHotplugBigCluster, low_power ? "0" : "1");
  WriteNode(kHotplugBigMinimum, low_power ? "0" : kBigMinimumHigh);

  low_power_ = low_power;
  ApplyGpuCeilingLocked();
  ApplyGpuFloorLocked();
}

ndk::ScopedAStatus Power::setMode(Mode type, bool enabled) {
  std::lock_guard<std::mutex> guard(lock_);

  switch (type) {
    case Mode::LOW_POWER:
      if (low_power_ != enabled) {
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
      if (!enabled) {
        CancelGpuBoostsLocked();
      } else {
        ApplyGpuFloorLocked();
      }
      gpu_cond_.notify_all();
      break;
    case Mode::DISPLAY_INACTIVE:
      display_inactive_ = enabled;
      if (enabled) {
        CancelGpuBoostsLocked();
      } else {
        ApplyGpuFloorLocked();
      }
      gpu_cond_.notify_all();
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
      if (duration_ms < 0) {
        CancelInteractionBoostLocked();
        gpu_cond_.notify_all();
      } else {
        SendInteractionBoostLocked(false);
      }
      break;
    case Boost::DISPLAY_UPDATE_IMMINENT:
      if (duration_ms < 0) {
        CancelDisplayUpdateBoostLocked();
        gpu_cond_.notify_all();
      } else {
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
          "expensive_rendering=%d interaction_boost=%d "
          "interaction_high_boost=%d "
          "display_update_boost=%d "
          "gpu_floor=%s gpu_ceiling=%s "
          "big_min=%s hmp_us=120000/250000/500000\n",
          interactive_, display_inactive_, low_power_, sustained_performance_,
          expensive_rendering_, interaction_boost_, interaction_high_boost_,
          display_update_boost_,
          applied_gpu_floor_ == nullptr ? "unknown" : applied_gpu_floor_,
          applied_gpu_ceiling_ == nullptr ? "unknown" : applied_gpu_ceiling_,
          low_power_ ? "0" : kBigMinimumHigh);
  return STATUS_OK;
}

}  // namespace aidl::android::hardware::power::impl::m86
