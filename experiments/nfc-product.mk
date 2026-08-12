# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_NFC_EXPERIMENT_PATH := device/meizu/m86

PRODUCT_PACKAGES += \
    android.hardware.nfc@1.1-service \
    com.android.nfc_extras \
    nfc_nci_nxp \
    NfcNci \
    Tag

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.nfc.hce.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hce.xml \
    frameworks/native/data/etc/android.hardware.nfc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/com.android.nfc_extras.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/com.android.nfc_extras.xml \
    $(LOCAL_NFC_EXPERIMENT_PATH)/nfc/libnfc-nxp.conf:$(TARGET_COPY_OUT_VENDOR)/etc/libnfc-nxp.conf \
    hardware/nxp/nfc/halimpl/libnfc-nci.conf:$(TARGET_COPY_OUT_VENDOR)/etc/libnfc-nci.conf \
    $(LOCAL_NFC_EXPERIMENT_PATH)/experiments/init.m86.nfc-experiment.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m86.nfc-experiment.rc

PRODUCT_PROPERTY_OVERRIDES += \
    ro.nfc.platform=nxppn547 \
    ro.nfc.port=I2C

$(call inherit-product-if-exists, vendor/meizu/m86/m86-nfc-experiment-vendor.mk)
