/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#include <cstdint>

#include <ui/GraphicBufferMapper.h>
#include <ui/Rect.h>
#include <utils/Errors.h>

// Flyme's Exynos OMX blobs were linked against the old four-argument member
// function. Export that exact mangled symbol and forward it to Android 10's
// source-compatible six-argument implementation.
extern "C" android::status_t m86_legacy_graphic_buffer_mapper_lock(
        android::GraphicBufferMapper* mapper,
        buffer_handle_t handle,
        uint32_t usage,
        const android::Rect& bounds,
        void** vaddr)
        __asm__("_ZN7android19GraphicBufferMapper4lockEPK13native_handlejRKNS_4RectEPPv");

extern "C" android::status_t m86_legacy_graphic_buffer_mapper_lock(
        android::GraphicBufferMapper* mapper,
        buffer_handle_t handle,
        uint32_t usage,
        const android::Rect& bounds,
        void** vaddr) {
    return mapper->lock(handle, usage, bounds, vaddr, nullptr, nullptr);
}
