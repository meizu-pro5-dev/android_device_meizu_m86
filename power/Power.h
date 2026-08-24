/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <aidl/android/hardware/power/BnPower.h>

#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <thread>
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
  using TimePoint = std::chrono::steady_clock::time_point;

  void ApplyPowerProfileLocked(bool low_power);
  void ApplyGpuFloorLocked();
  void ApplyGpuCeilingLocked();
  void CancelInteractionBoostLocked();
  void CancelDisplayUpdateBoostLocked();
  void CancelGpuBoostsLocked();
  void SendInteractionBoostLocked(bool launch);
  void SendDisplayUpdateBoostLocked();
  void GpuBoostWorker();

  std::mutex lock_;
  std::condition_variable gpu_cond_;
  std::thread gpu_thread_;
  bool stop_worker_ = false;
  bool interactive_ = true;
  bool display_inactive_ = false;
  bool low_power_ = false;
  bool sustained_performance_ = false;
  bool expensive_rendering_ = false;
  bool interaction_boost_ = false;
  bool interaction_high_boost_ = false;
  bool display_update_boost_ = false;
  TimePoint interaction_deadline_{};
  TimePoint interaction_high_deadline_{};
  TimePoint display_update_deadline_{};
  const char* applied_gpu_floor_ = nullptr;
  const char* applied_gpu_ceiling_ = nullptr;
};

}  // namespace aidl::android::hardware::power::impl::m86
