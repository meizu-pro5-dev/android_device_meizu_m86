# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := device/meizu/m86

# Android 10 leaves tetherable interface lists empty by default. Advertise
# the Broadcom AP interface so Settings and Tethering expose Wi-Fi hotspot.
PRODUCT_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# PRO 5 launched on Android 5.1. This keeps Android 10 compatibility checks in
# legacy, non-Treble mode while the stock vendor ABI is brought up.
PRODUCT_SHIPPING_API_LEVEL := 22
PRODUCT_ENFORCE_VINTF_MANIFEST := false

PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

TARGET_SCREEN_HEIGHT := 1920
TARGET_SCREEN_WIDTH := 1080

PRODUCT_SOONG_NAMESPACES += \
    device/samsung/universal7420-common \
    hardware/samsung \
    hardware/samsung_slsi/exynos \
    hardware/samsung_slsi/exynos5 \
    hardware/samsung_slsi/exynos7420 \
    hardware/samsung_slsi/openmax

# Storage owns both Android fstab destinations and the recovery mount table.
$(call inherit-product, $(LOCAL_PATH)/storage/product.mk)

# USB owns the immutable role HAL, identity helper, gadget init and defaults.
$(call inherit-product, $(LOCAL_PATH)/usb/product.mk)

# Standard keys remain independent from FPC/mBack policy and processes.
$(call inherit-product, $(LOCAL_PATH)/input/standard-keys/product.mk)

# mBack policy, UI and gesture keylayouts live in the device-owned M86Parts.
$(call inherit-product, $(LOCAL_PATH)/parts/product.mk)

# Wi-Fi owns the legacy HIDL service, supplicant, init, feature declarations,
# interface properties and Broadcom overlays.
$(call inherit-product, $(LOCAL_PATH)/wifi/product.mk)

# Normal audio owns the Android 10 services, policy and locked tuning inputs.
# Its Flyme ABI remains globally compatible until the private wrapper gates pass.
$(call inherit-product, $(LOCAL_PATH)/audio/product.mk)

# Ramdisk
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.m86.rc:root/init.m86.rc \
    $(LOCAL_PATH)/rootdir/etc/init.m86.boot-sync.sh:root/init.m86.boot-sync.sh \
    $(LOCAL_PATH)/rootdir/etc/init.m86.sensors.rc:root/init.m86.sensors.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.m86.rc:root/ueventd.m86.rc

# Minimum feature declaration for the first boot/recovery milestone.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml

# Graphics is a self-contained product/manifest owner. The m86 adapter keeps
# the Samsung source dependency unmodified.
$(call inherit-product, $(LOCAL_PATH)/graphics/product.mk)

# Bluetooth. The m86-owned 32-bit wrapper consumes the verified Flyme vendor
# library and owns address derivation, SCO setup, service, and init lifecycle.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl.m86 \
    android.hardware.bluetooth@1.0-service.m86

# Radio lifecycle. The platform rild/libril selection and SITRIL ABI remain
# unchanged; the m86 fragment owns the reset trigger and service name.
$(call inherit-product, $(LOCAL_PATH)/radio/product.mk)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bluetooth/bt_vendor.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/bluetooth/bt_vendor.conf

# Media remains independent from the normal-audio ABI boundary.
PRODUCT_PACKAGES += \
    libm86omx_shim

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/media/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(LOCAL_PATH)/media/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_telephony.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml

# The stock Exynos OMX core queries uname while running inside media.codec.
# Android 10's base policy does not allow it, so install the same narrow
# device policy used by the maintained universal7420 family.
PRODUCT_COPY_FILES += \
    device/samsung/universal7420-common/configs/seccomp/mediacodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy \
    device/samsung/universal7420-common/configs/seccomp/mediaextractor.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediaextractor.policy

# PRO5 has no usable Keymaster blob in the final Flyme dump. Use Android's
# software Keymaster 4 implementation so keystore can start instead of
# aborting while probing an undeclared TEE device.
PRODUCT_PACKAGES += \
    android.hardware.keymaster@4.0-impl \
    android.hardware.keymaster@4.0-service

# Radio. AOSP's Android 10 rild/libril translates the legacy callback ABI to
# HIDL radio 1.1 for both slots. It loads the hash-locked Flyme 8 libsitril.so;
# the stock socket-only rild_exynos is deliberately not started.
PRODUCT_PACKAGES += \
    android.hardware.radio@1.0 \
    android.hardware.radio@1.1 \
    android.hardware.radio.deprecated@1.0 \
    libril \
    rild

# GNSS. The Exynos 7420 wrapper exposes the verified Flyme legacy GPS HAL as
# GNSS 1.0; gpsd continues to consume the byte-exact production configuration.
PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0 \
    android.hardware.gnss@1.0-impl.zero \
    android.hardware.gnss@1.0-service \
    libm86gps_shim

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/gps/gps.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/gps.conf \
    $(LOCAL_PATH)/gps/gps.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/gps.xml

# Sensors. Android 10's generic HIDL bridge loads sensors.m86.so. The custom
# service declaration adds the input group required by the Flyme ALS/PS path.
PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/sensors/android.hardware.sensors@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.sensors@1.0-service.rc

# Camera. Android 10's 32-bit provider loads the exact final-Flyme m86 HAL.
# libm86camera_shim supplies only the audited legacy ABI delta and pulls the
# SensorManager implementation out of its post-Nougat libsensor home.
PRODUCT_PACKAGES += \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service \
    libm86camera_shim

# Vibrator. The maintained Meizu kernel exposes the standard timed-output
# interface used by Android's source-built legacy module; the HIDL service
# wraps it without depending on Flyme's optional Immersion daemon.
PRODUCT_PACKAGES += \
    android.hardware.vibrator@1.0-impl \
    android.hardware.vibrator@1.0-service \
    vibrator.default

# Lights. A source-built legacy HAL converts framework RGB values and the
# m86-specific LP5562 mode bits; Android 10's generic HIDL service wraps it.
PRODUCT_PACKAGES += \
    android.hardware.light@2.0-impl \
    android.hardware.light@2.0-service \
    lights.m86

# Power. Android 10's generic HIDL bridge wraps a source-built m86 HAL. It
# limits battery-saver and interaction hints to the interfaces implemented by
# the maintained Meizu hotplug and interactive-governor drivers.
PRODUCT_PACKAGES += \
    android.hardware.power@1.0-impl \
    android.hardware.power@1.0-service \
    power.m86

# TARGET_SYSTEM_PROP is expanded after product makefiles have changed
# LOCAL_PATH. Use the stable device path so it cannot resolve under
# build/make/core during Ninja graph generation.
TARGET_SYSTEM_PROP := device/meizu/m86/system.prop

$(call inherit-product-if-exists, vendor/meizu/m86/m86-vendor.mk)
