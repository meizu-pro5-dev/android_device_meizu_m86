# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := $(call my-dir)

ifneq ($(filter m86,$(TARGET_DEVICE)),)
# Flyme's Mali driver exports both EGL/GLES and Vulkan entry points. Android's
# loader selects vulkan.$(ro.board.platform).so, so install only deterministic
# links to the two hash-locked driver blobs.
M86_MALI_LIB32 := $(TARGET_OUT_VENDOR)/lib/egl/libGLES_mali.so
M86_MALI_LIB64 := $(TARGET_OUT_VENDOR)/lib64/egl/libGLES_mali.so
M86_VULKAN_HAL32 := $(TARGET_OUT_VENDOR)/lib/hw/vulkan.exynos5.so
M86_VULKAN_HAL64 := $(TARGET_OUT_VENDOR)/lib64/hw/vulkan.exynos5.so
M86_VULKAN_HAL_SYMLINKS := \
    $(M86_VULKAN_HAL32) \
    $(M86_VULKAN_HAL64)

ALL_DEFAULT_INSTALLED_MODULES += $(M86_VULKAN_HAL_SYMLINKS)

$(M86_VULKAN_HAL32): $(M86_MALI_LIB32)
	@echo "Symlink m86 Vulkan HAL: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) ln -sf ../egl/libGLES_mali.so $@

$(M86_VULKAN_HAL64): $(M86_MALI_LIB64)
	@echo "Symlink m86 Vulkan HAL: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) ln -sf ../egl/libGLES_mali.so $@
endif
