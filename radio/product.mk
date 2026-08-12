# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# M4 radio owns only the m86-specific reset trigger. The Android 10 rild
# module and locked Flyme SITRIL libraries remain selected by device.mk.
LOCAL_PATH := device/meizu/m86/radio

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.m86.radio.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m86.radio.rc
