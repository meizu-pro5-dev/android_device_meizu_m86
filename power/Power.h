/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <aidl/android/hardware/power/BnPower.h>

#include <array>
#include <chrono>
#include <condition_variable>
#include <thread>
#include <memory>
#include <mutex>
#include <vector>

namespace aidl::android::hardware::power::impl::m86 {

class Power : public BnPower {
 public:
  Power();
  ~Power() override;

  ndk::ScopedAStatus setMode(Mode type, bool enabled) override;
  ndk::ScopedAStatus isModeSupported(Mode type, bool* supported) override;
  ndk::ScopedAStatus setBoost(Boost type, int32_t duration_ms) override;
  ndk::ScopedAStatus isBoostSupported(Boost type, bool* supported) override;
  ndk::ScopedAStatus createHintSession(
      int32_t tgid, int32_t uid, const std::vector<int32_t>& thread_ids,
      int64_t duration_nanos,
      std::shared_ptr<IPowerHintSession>* session) override;
  ndk::ScopedAStatus getHintSessionPreferredRate(int64_t* rate_nanos) override;
  binder_status_t dump(int fd, const char** args, uint32_t num_args) override;

 private:
  void ApplyPowerProfileLocked(bool low_power);
  void ApplyGpuFloorLocked();
  void ApplyGpuCeilingLocked();
  void RequestBoostLocked(size_t source, int32_t duration_ms, int default_ms);
  void ApplyBoostLocked();
  void BoostWorker();
  using Clock = std::chrono::steady_clock;
  std::array<Clock::time_point, 3> boost_deadlines_{};
  std::condition_variable boost_cv_;
  std::thread boost_worker_;
  bool stop_boost_ = false;
  int applied_boost_ = -1;
  unsigned int boost_requests_ = 0;
  unsigned int boost_errors_ = 0;

  std::mutex lock_;
  bool interactive_ = true;
  bool display_inactive_ = false;
  bool low_power_ = false;
  bool profile_applied_ = false;
  bool sustained_performance_ = false;
  bool expensive_rendering_ = false;
  const char* applied_gpu_floor_ = nullptr;
  const char* applied_gpu_ceiling_ = nullptr;
};

}  // namespace aidl::android::hardware::power::impl::m86
