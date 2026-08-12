# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_ENABLE_NFC_EXPERIMENT := true

$(call inherit-product, device/meizu/m86/lineage_m86.mk)
$(call inherit-product, device/meizu/m86/experiments/nfc-product.mk)

PRODUCT_NAME := lineage_m86_nfc_experiment
PRODUCT_MODEL := PRO 5 (NFC experiment)
