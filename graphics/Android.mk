# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# Flyme's r15p0 Mali userspace lacks the promoted physical-device query
# entry points required by Android 12's Vulkan loader. Keep the validated
# EGL/GLES path and do not install vulkan.exynos5 HAL links until the kernel,
# userspace DDK and gralloc contract can be upgraded together.
