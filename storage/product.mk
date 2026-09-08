# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_STORAGE_PATH := device/meizu/m86/storage
M86_ANDROID_FSTAB := $(M86_STORAGE_PATH)/rootdir/etc/fstab.m86
ifeq ($(M86_VENDOR_INDEPENDENT),true)
M86_ANDROID_FSTAB := device/meizu/m86/independent/fstab.m86
endif

# Keep the Android and recovery mount contracts together under the m86
# storage owner. Both ramdisk destinations intentionally contain the same
# Android fstab; recovery uses its separate TARGET_RECOVERY_FSTAB input.
PRODUCT_COPY_FILES += \
    $(M86_ANDROID_FSTAB):$(TARGET_COPY_OUT_RAMDISK)/fstab.m86 \
    $(M86_ANDROID_FSTAB):root/fstab.m86 \
    $(M86_ANDROID_FSTAB):$(TARGET_COPY_OUT_VENDOR)/etc/fstab.m86
