# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_STANDARD_KEYS_PATH := device/meizu/m86/input/standard-keys

# Standard Linux input codes stay on Android's normal keylayout path. These
# files contain no FPC/mBack gesture aliases and have no userspace daemon
# dependency.
PRODUCT_COPY_FILES += \
    $(M86_STANDARD_KEYS_PATH)/keylayout/fts.kl:$(M86_DEVICE_COPY_OUT)/usr/keylayout/fts.kl \
    $(M86_STANDARD_KEYS_PATH)/keylayout/gpio-keys.kl:$(M86_DEVICE_COPY_OUT)/usr/keylayout/gpio-keys.kl
