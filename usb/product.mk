# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_USB_PATH := device/meizu/m86/usb

# m86 owns its immutable USB role, factory-derived serial and legacy gadget
# state machine. The identity-ready property is a published input; this owner
# never starts or stops Bluetooth or any other foreign HAL.
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service.basic

ifeq ($(M86_VENDOR_INDEPENDENT),true)
PRODUCT_PACKAGES += m86_usb_serial.vendor
else
PRODUCT_PACKAGES += m86_usb_serial
endif

ifeq ($(M86_VENDOR_INDEPENDENT),true)
PRODUCT_COPY_FILES += device/meizu/m86/independent/init.m86.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.m86.usb.rc
else
PRODUCT_COPY_FILES += $(M86_USB_PATH)/rootdir/etc/init.m86.usb.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.m86.usb.rc
endif

# Start with no data function. UsbDeviceManager appends adb only when USB
# debugging is enabled. Synchronous FunctionFS is required by this 3.10 gadget.
# M1 bring-up keeps adb enabled by default; Settings can still change modes.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.adb.nonblocking_ffs=false \
    persist.sys.usb.config=adb

PRODUCT_PRODUCT_PROPERTIES += persist.sys.usb.config=adb
