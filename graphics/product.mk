# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# Keep one allocator, mapper and composer stack. gralloc.m86 owns the hardened
# fbdev path; the remaining Exynos modules are consumed without modification.
# configstore@1.1-service is already supplied by full_base_telephony.
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.mapper@2.0-impl \
    android.hardware.memtrack@1.0-impl \
    gralloc.m86 \
    hwcomposer.exynos5 \
    memtrack.exynos5 \
    libexynosdisplay \
    libhdmi \
    libhwc2on1adapter \
    libhwc2onfbadapter \
    libion

PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.gralloc=m86
