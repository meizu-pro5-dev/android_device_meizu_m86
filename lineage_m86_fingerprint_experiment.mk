# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_ENABLE_FINGERPRINT_EXPERIMENT := true

$(call inherit-product, device/meizu/m86/lineage_m86.mk)
$(call inherit-product, device/meizu/m86/experiments/fingerprint-product.mk)

PRODUCT_NAME := lineage_m86_fingerprint_experiment
PRODUCT_MODEL := PRO 5 (Fingerprint experiment)
