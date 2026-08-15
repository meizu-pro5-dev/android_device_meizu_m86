# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_ENABLE_NFC_EXPERIMENT := true
M86_ENABLE_FINGERPRINT_EXPERIMENT := false

$(call inherit-product, device/meizu/m86/lineage_m86.mk)

PRODUCT_NAME := lineage_m86_nfc_experiment
PRODUCT_MODEL := PRO 5 (NFC-only rollback)
