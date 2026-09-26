# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

ifeq ($(M86_GPU_DDK),r22p0)
# The pinned r22p0 library exports the Android Vulkan HAL as well as EGL/GLES.
# Android 13 loads vulkan.<ro.board.platform>.so through the SP-HAL namespace.
# Install both ABIs in its library search path without duplicating the blobs.
M86_VULKAN_HAL32 := $(TARGET_OUT_VENDOR)/lib/vulkan.exynos5.so
M86_VULKAN_HAL64 := $(TARGET_OUT_VENDOR)/lib64/vulkan.exynos5.so
M86_VULKAN_HAL_SYMLINKS := $(M86_VULKAN_HAL32) $(M86_VULKAN_HAL64)

ALL_DEFAULT_INSTALLED_MODULES += $(M86_VULKAN_HAL_SYMLINKS)

$(M86_VULKAN_HAL32): $(TARGET_OUT_VENDOR)/lib/egl/libGLES_mali.so
	@echo "Symlink m86 r22p0 Vulkan HAL: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) ln -sfn egl/libGLES_mali.so $@

$(M86_VULKAN_HAL64): $(TARGET_OUT_VENDOR)/lib64/egl/libGLES_mali.so
	@echo "Symlink m86 r22p0 Vulkan HAL: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) ln -sfn egl/libGLES_mali.so $@

.PHONY: m86-vulkan-links
m86-vulkan-links: $(M86_VULKAN_HAL_SYMLINKS)
endif
