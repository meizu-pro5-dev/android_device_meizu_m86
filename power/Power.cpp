/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "m86-power-aidl"

#include "Power.h"

#include <log/log.h>

#include <algorithm>
#include <cstdio>
#include <string>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>

namespace aidl::android::hardware::power::impl::m86 {
namespace {

constexpr char kTopAppBoost[] = "/dev/stune/top-app/schedtune.boost";
constexpr char kForegroundBoost[] = "/dev/stune/foreground/schedtune.boost";
constexpr char kHotplugProfile[] =
    "/sys/module/exynos_march_cpu_hotplug/parameters/current_profile_no";
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
  LoadBoostConfigLocked();
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

void Power::LoadBoostConfigLocked() {
  FILE* fp = fopen("/vendor/etc/m86-schedtune.conf", "re");
  if (!fp) { ALOGW("No boost config; using B9 defaults"); return; }
  int fg, base, active, interaction, display, launch;
  char extra;
  const int count = fscanf(fp, "%d %d %d %d %d %d %c", &fg, &base, &active,
                           &interaction, &display, &launch, &extra);
  fclose(fp);
  if (count != 6 || fg < 0 || fg > 50 || base < 0 || base > 50 ||
      active < base || active > 50 || interaction < 40 || interaction > 2000 ||
      display < 40 || display > 2000 || launch < 40 || launch > 2000) {
    ALOGE("Invalid boost config; using B9 defaults"); return;
  }
  foreground_boost_ = fg; base_boost_ = base; active_boost_ = active;
  interaction_ms_ = interaction; display_ms_ = display; launch_ms_ = launch;
  config_valid_ = true;
}

void Power::ApplyBoostLocked() {
  if (applied_foreground_ != foreground_boost_) {
    if (WriteNode(kForegroundBoost, std::to_string(foreground_boost_).c_str()) == 0)
      applied_foreground_ = foreground_boost_;
    else ++boost_errors_;
  }
  const auto now = Clock::now();
  const bool allowed = interactive_ && !display_inactive_ && !low_power_ &&
                       !sustained_performance_ && !stop_boost_;
  if (!allowed) boost_deadlines_.fill(Clock::time_point{});
  bool active = false;
  for (auto& deadline : boost_deadlines_) {
    if (deadline > now) active = true;
    else deadline = Clock::time_point{};
  }
  const int value = active ? active_boost_ : base_boost_;
  if (value != applied_boost_) {
    const int error = WriteNode(kTopAppBoost, std::to_string(value).c_str());
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
    const int desired = next == Clock::time_point::max() ? base_boost_ : active_boost_;
    if (desired != applied_boost_ || applied_foreground_ != foreground_boost_)
      next = std::min(next, Clock::now() + std::chrono::milliseconds(100));
    if (next == Clock::time_point::max()) boost_cv_.wait(guard);
    else boost_cv_.wait_until(guard, next);
  }
}

void Power::ApplyPowerProfileLocked(bool low_power) {
  const int profile_error =
      WriteNode(kHotplugProfile, low_power ? kProfileEco : kProfileHigh);
  // The kernel online policy owns core targets. Eco mode temporarily uses
  // legacy targets; returning to normal restores the selected online policy.
  low_power_ = low_power;
  profile_applied_ = profile_error == 0;
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
      RequestBoostLocked(2, enabled ? launch_ms_ : -1, launch_ms_);
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
      RequestBoostLocked(0, duration_ms, interaction_ms_);
      break;
    case Boost::DISPLAY_UPDATE_IMMINENT:
      RequestBoostLocked(1, duration_ms, display_ms_);
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
          "core_targets=kernel_policy cpu_boost=schedtune-b11\n",
          interactive_, display_inactive_, low_power_, sustained_performance_,
          expensive_rendering_,
          applied_gpu_floor_ == nullptr ? "unknown" : applied_gpu_floor_,
          applied_gpu_ceiling_ == nullptr ? "unknown" : applied_gpu_ceiling_);
  dprintf(fd, "config_valid=%d foreground=%d applied_foreground=%d default_ms=%d/%d/%d\n",
          config_valid_, foreground_boost_, applied_foreground_, interaction_ms_, display_ms_, launch_ms_);
  dprintf(fd, "stune_base=%d stune_active=%d stune_applied=%d requests=%u errors=%u remaining_ms=",
          base_boost_, active_boost_, applied_boost_, boost_requests_, boost_errors_);
  for (auto deadline : boost_deadlines_) {
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(deadline - Clock::now()).count();
    dprintf(fd, "%lld ", static_cast<long long>(std::max<int64_t>(0, ms)));
  }
  dprintf(fd, "\n");
  return STATUS_OK;
}

}  // namespace aidl::android::hardware::power::impl::m86
