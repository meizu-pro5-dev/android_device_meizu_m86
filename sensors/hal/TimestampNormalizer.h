// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <cstdint>
#include <ctime>

namespace m86 {
constexpr int64_t kSecond = 1000000000LL;
struct Clocks { int64_t boot = 0; int64_t real = 0; bool valid = false; };
inline Clocks sampleClocks() {
    for (int i = 0; i < 3; ++i) {
        timespec b0{}, r{}, b1{};
        if (clock_gettime(CLOCK_BOOTTIME, &b0) || clock_gettime(CLOCK_REALTIME, &r) ||
            clock_gettime(CLOCK_BOOTTIME, &b1)) return {};
        const int64_t start = b0.tv_sec * kSecond + b0.tv_nsec;
        const int64_t end = b1.tv_sec * kSecond + b1.tv_nsec;
        if (end >= start && end - start <= 1000000)
            return {start + (end - start) / 2, r.tv_sec * kSecond + r.tv_nsec, true};
    }
    return {};
}
inline bool isLegacyInputSensor(int handle, int type) {
    // Fixed handles verified against the locked Flyme sensors.m86.so.
    return (type == 5 && handle == 4) || (type == 8 && (handle == 3 || handle == 27));
}
inline bool normalizeTimestamp(int64_t timestamp, const Clocks &before,
                               const Clocks &after, int64_t *result) {
    if (!before.valid || !after.valid || timestamp <= 0) return false;
    const int64_t offset = after.real - after.boot;
    const int64_t change = offset - (before.real - before.boot);
    // A wall-clock step across poll makes queued input times ambiguous.
    if (change > 5000000 || change < -5000000) return false;
    // ALS/PS advertise no batching. Bound age before subtraction, which also
    // rejects corrupt timestamps without signed integer overflow.
    if (timestamp < after.real - 10 * kSecond || timestamp > after.real + 1000000)
        return false;
    const int64_t converted = timestamp - offset;
    if (converted <= 0) return false;
    *result = converted;
    return true;
}
} // namespace m86
