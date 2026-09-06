# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# The maintained product now carries the two device-validated hardware paths:
# the PN547 reader/HCE stack and Flyme's Trustonic-backed FPC implementation.
# The single-domain products below remain available as rollback probes and set
# one of these flags false before inheriting this product definition.
M86_ENABLE_NFC_EXPERIMENT ?= true
M86_ENABLE_FINGERPRINT_EXPERIMENT ?= true
# Route D builds the m86-owned Camera3 module and engine from source.  Route A
# remains in history as a donor-analysis checkpoint, not as a product runtime.
M86_USE_NATIVE_EXYNOS_HAL3 ?= true
M86_USE_PREBUILT_EXYNOS_HAL3 ?= false

include device/meizu/m86/gpu-config.mk

ifeq ($(M86_GPU_DDK),r22p0)
ifneq ($(M86_USE_NATIVE_EXYNOS_HAL3),true)
$(error m86 r22p0 requires the source-owned native HAL3 camera)
endif
ifeq ($(M86_USE_PREBUILT_EXYNOS_HAL3),true)
$(error m86 r22p0 cannot use the old prebuilt camera handle ABI)
endif
endif

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

$(call inherit-product, device/meizu/m86/device.mk)

ifeq ($(M86_ENABLE_NFC_EXPERIMENT),true)
$(call inherit-product, device/meizu/m86/experiments/nfc-product.mk)
endif

ifeq ($(M86_ENABLE_FINGERPRINT_EXPERIMENT),true)
$(call inherit-product, device/meizu/m86/experiments/fingerprint-product.mk)
endif

# Let Lineage common keep authenticated ADB disabled by default. Developer
# options enable it dynamically without changing the default USB data policy.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_m86
PRODUCT_DEVICE := m86
PRODUCT_BRAND := Meizu
PRODUCT_MANUFACTURER := Meizu
PRODUCT_MODEL := PRO 5

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=meizu_PRO5 \
    TARGET_DEVICE=PRO5 \
    PRIVATE_BUILD_DESC="meizu_PRO5-user 7.0 NRD90M m86.Flyme_8.0.1594148303 release-keys"

BUILD_FINGERPRINT := Meizu/meizu_PRO5/PRO5:7.0/NRD90M/m86.Flyme_8.0.1594148303:user/release-keys
