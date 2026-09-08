# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_PARTS_PATH := device/meizu/m86/parts

PRODUCT_PACKAGES += \
    M86Parts

# FPC gesture aliases are private to mBack and must not be folded into the
# standard gpio/touchscreen key owner.
PRODUCT_COPY_FILES += \
    $(M86_PARTS_PATH)/mback/keylayout/fpc1020.kl:$(M86_DEVICE_COPY_OUT)/usr/keylayout/fpc1020.kl \
    $(M86_PARTS_PATH)/mback/keylayout/uinput-fpc.kl:$(M86_DEVICE_COPY_OUT)/usr/keylayout/uinput-fpc.kl \
    $(M86_PARTS_PATH)/M86Parts/privapp-permissions-org.lineageos.settings.m86.xml:system/etc/permissions/privapp-permissions-org.lineageos.settings.m86.xml
