/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "m86-power-aidl"

#include "Power.h"

#include <log/log.h>

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>

namespace aidl::android::hardware::power::impl::m86 {
namespace {

constexpr char kTopAppBoost[] = "/dev/stune/top-app/schedtune.boost";
constexpr int kBaseBoost = 15;
constexpr int kInteractionBoost = 30;
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

}  // namespace

Power::Power() {
  std::lock_guard<std::mutex> guard(lock_);
  ApplyBoostLocked();
  ApplyPowerProfileLocked(false);
  boost_worker_ = std::thread(&Power::BoostWorker, this);
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

Power::~Power() {
  {
    std::lock_guard<std::mutex> guard(lock_);
    stop_boost_ = true;
    boost_deadlines_.fill(Clock::time_point{});
    ApplyBoostLocked();
    boost_cv_.notify_all();
  }
  if (boost_worker_.joinable()) boost_worker_.join();
}

void Power::ApplyBoostLocked() {
  const auto now = Clock::now();
  const bool allowed = interactive_ && !display_inactive_ && !low_power_ &&
                       !sustained_performance_ && !stop_boost_;
  if (!allowed) boost_deadlines_.fill(Clock::time_point{});
  bool active = false;
  for (auto& deadline : boost_deadlines_) {
    if (deadline > now) active = true;
    else deadline = Clock::time_point{};
  }
  const int value = active ? kInteractionBoost : kBaseBoost;
  if (value != applied_boost_) {
    const int error = WriteNode(kTopAppBoost, value == kBaseBoost ? "15" : "30");
    if (!error) applied_boost_ = value;
    else {
      ++boost_errors_;
      if (boost_errors_ == 1 || boost_errors_ % 100 == 0)
        ALOGW("SchedTune boost write failed: %s", strerror(-error));
    }
  }
}

void Power::RequestBoostLocked(size_t source, int32_t duration_ms, int default_ms) {
  ++boost_requests_;
  if (duration_ms < 0) {
    boost_deadlines_[source] = Clock::time_point{};
  } else if (interactive_ && !display_inactive_ && !low_power_ &&
             !sustained_performance_) {
    const int duration = duration_ms == 0 ? default_ms :
                         std::min(duration_ms, 2000);
    boost_deadlines_[source] = std::max(boost_deadlines_[source],
        Clock::now() + std::chrono::milliseconds(duration));
  }
  ApplyBoostLocked();
  boost_cv_.notify_all();
}

void Power::BoostWorker() {
  std::unique_lock<std::mutex> guard(lock_);
  while (!stop_boost_) {
    ApplyBoostLocked();
    auto next = Clock::time_point::max();
    for (const auto deadline : boost_deadlines_)
      if (deadline != Clock::time_point{}) next = std::min(next, deadline);
    // Retry failed writes, including baseline restoration, without spinning.
    const int desired = next == Clock::time_point::max() ? kBaseBoost : kInteractionBoost;
    if (desired != applied_boost_)
      next = std::min(next, Clock::now() + std::chrono::milliseconds(100));
    if (next == Clock::time_point::max()) boost_cv_.wait(guard);
    else boost_cv_.wait_until(guard, next);
  }
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
      RequestBoostLocked(2, enabled ? 1000 : -1, 1000);
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

  ApplyBoostLocked();
  boost_cv_.notify_all();
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
      RequestBoostLocked(0, duration_ms, 500);
      break;
    case Boost::DISPLAY_UPDATE_IMMINENT:
      RequestBoostLocked(1, duration_ms, 120);
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
          "big_min_policy=0 cpu_boost=schedtune-b9\n",
          interactive_, display_inactive_, low_power_, sustained_performance_,
          expensive_rendering_,
          applied_gpu_floor_ == nullptr ? "unknown" : applied_gpu_floor_,
          applied_gpu_ceiling_ == nullptr ? "unknown" : applied_gpu_ceiling_);
  dprintf(fd, "stune_base=%d stune_active=%d stune_applied=%d requests=%u errors=%u remaining_ms=",
          kBaseBoost, kInteractionBoost, applied_boost_, boost_requests_, boost_errors_);
  for (auto deadline : boost_deadlines_) {
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(deadline - Clock::now()).count();
    dprintf(fd, "%lld ", static_cast<long long>(std::max<int64_t>(0, ms)));
  }
  dprintf(fd, "\n");
  return STATUS_OK;
}

}  // namespace aidl::android::hardware::power::impl::m86
