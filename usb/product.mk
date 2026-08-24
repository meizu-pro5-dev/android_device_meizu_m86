# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_USB_PATH := device/meizu/m86/usb

# m86 owns its immutable USB role, factory-derived serial and legacy gadget
# state machine. The identity-ready property is a published input; this owner
# never starts or stops Bluetooth or any other foreign HAL.
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service.basic \
    m86_usb_serial

PRODUCT_COPY_FILES += \
    $(M86_USB_PATH)/rootdir/etc/init.m86.usb.rc:root/init.m86.usb.rc

# Start with no data function. UsbDeviceManager appends adb only when USB
# debugging is enabled. Synchronous FunctionFS is required by this 3.10 gadget.
# M1 bring-up keeps adb enabled by default; Settings can still change modes.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.adb.nonblocking_ffs=false \
    persist.sys.usb.config=adb

PRODUCT_PRODUCT_PROPERTIES += persist.sys.usb.config=adb
