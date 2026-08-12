# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_FINGERPRINT_EXPERIMENT_PATH := device/meizu/m86

# This experiment selects only Flyme's production Trustonic chain. The raw
# libfprint recovery implementation remains disabled and mutually exclusive.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.1-service

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    $(LOCAL_FINGERPRINT_EXPERIMENT_PATH)/experiments/init.m86.fingerprint-experiment.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m86.fingerprint-experiment.rc

$(call inherit-product-if-exists, vendor/meizu/m86/m86-fingerprint-experiment-vendor.mk)
