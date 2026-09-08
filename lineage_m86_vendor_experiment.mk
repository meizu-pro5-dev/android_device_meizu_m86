# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# Compile-time probe for a versioned vendor boundary. Do not release an image
# from this product until the dependency and replacement-system gates pass.
M86_VENDOR_INDEPENDENT := true
PRODUCT_FULL_TREBLE_OVERRIDE := true
PRODUCT_USE_VNDK_OVERRIDE := true

$(call inherit-product, device/meizu/m86/lineage_m86.mk)
PRODUCT_NAME := lineage_m86_vendor_experiment
