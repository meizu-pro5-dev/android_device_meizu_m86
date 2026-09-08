# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := device/meizu/m86

M86_DEVICE_COPY_OUT := $(TARGET_COPY_OUT_SYSTEM)
M86_INIT_RC := $(LOCAL_PATH)/rootdir/etc/init.m86.rc
ifeq ($(M86_VENDOR_INDEPENDENT),true)
M86_DEVICE_COPY_OUT := $(TARGET_COPY_OUT_VENDOR)
M86_INIT_RC := $(LOCAL_PATH)/independent/init.m86.rc
endif

# Android 10 leaves tetherable interface lists empty by default. Advertise
# the Broadcom AP interface so Settings and Tethering expose Wi-Fi hotspot.
PRODUCT_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# PRO 5 launched on Android 5.1. Android 12 renamed the manifest override;
# keep legacy non-Treble behavior and let checkvintf own the final matrix.
PRODUCT_SHIPPING_API_LEVEL := 22
PRODUCT_ENFORCE_VINTF_MANIFEST_OVERRIDE := true

PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

TARGET_SCREEN_HEIGHT := 1920
TARGET_SCREEN_WIDTH := 1080

PRODUCT_SOONG_NAMESPACES += \
    hardware/meizu/m86 \
    hardware/samsung \
    hardware/samsung_slsi-linaro/exynos \
    hardware/samsung_slsi-linaro/exynos5 \
    hardware/samsung_slsi-linaro/graphics \
    hardware/samsung_slsi-linaro/interfaces \
    hardware/samsung_slsi-linaro/openmax

# Android 13's product image rules require the explicit non-A/B contract for
# legacy devices with standalone boot and recovery partitions.
$(call inherit-product, $(SRC_TARGET_DIR)/product/non_ab_device.mk)

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
    $(M86_INIT_RC):$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.m86.rc \
    $(LOCAL_PATH)/rootdir/etc/init.m86.boot-sync.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.m86.boot-sync.sh \
    $(LOCAL_PATH)/rootdir/etc/init.m86.sensors.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.m86.sensors.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.m86.rc:root/ueventd.m86.rc \
    $(LOCAL_PATH)/task_profiles.json:$(TARGET_COPY_OUT_VENDOR)/etc/task_profiles.json

# Android 12 ueventd reads device rules from /vendor/etc/ueventd.rc through
# the unconditional import in /system/etc/ueventd.rc. Without this, /dev/mali0,
# /dev/ion and /dev/ump fall back to 0600 root:root and SurfaceFlinger (uid
# system) cannot open the Mali DDK device.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/ueventd.m86.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.rc

# Android 13's networking BPF programs attach to the controller-less cgroup2
# hierarchy. Keep the vendor descriptor on the canonical path consumed by
# libprocessgroup and netd; initialization failures remain fatal with BPF on.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/cgroups.json:$(TARGET_COPY_OUT_VENDOR)/etc/cgroups.json

# Minimum feature declaration for the first boot/recovery milestone.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(M86_DEVICE_COPY_OUT)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
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
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(M86_DEVICE_COPY_OUT)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(M86_DEVICE_COPY_OUT)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:$(M86_DEVICE_COPY_OUT)/etc/permissions/handheld_core_hardware.xml

# Graphics is a self-contained product/manifest owner. The m86 adapter keeps
# the Samsung source dependency unmodified.
$(call inherit-product, $(LOCAL_PATH)/graphics/product.mk)

# Bluetooth. The m86-owned 32-bit wrapper owns the A12 IBluetoothHci service
# and installs under the canonical passthrough implementation name; the Flyme
# Broadcom vendor interface and firmware path remain the only blob boundary.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0 \
    android.hardware.bluetooth@1.0-impl.m86 \
    android.hardware.bluetooth@1.0-service.m86

ifeq ($(M86_VENDOR_INDEPENDENT),true)
PRODUCT_COPY_FILES += $(LOCAL_PATH)/bluetooth/bt_vendor.conf:$(TARGET_COPY_OUT_VENDOR)/etc/bt_vendor.conf
else
PRODUCT_COPY_FILES += $(LOCAL_PATH)/bluetooth/bt_vendor.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/bluetooth/bt_vendor.conf
endif

# Radio lifecycle. The platform rild/libril selection and SITRIL ABI remain
# unchanged; the m86 fragment owns the reset trigger and service name.
$(call inherit-product, $(LOCAL_PATH)/radio/product.mk)

# Media is source-owned from the Exynos OpenMAX stack. The m86 fragment only
# selects the codec modules; it does not modify the unmodified Samsung source.
$(call inherit-product, hardware/meizu/m86/media/product.mk)

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/media/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_telephony.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml

# Keep FHD rollback builds consistent with their Camera2 stream metadata.
ifeq ($(M86_ENABLE_CAMERA_UHD_BRINGUP),true)
PRODUCT_COPY_FILES += $(LOCAL_PATH)/media/media_profiles_uhd.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml
else
PRODUCT_COPY_FILES += $(LOCAL_PATH)/media/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml
endif

# PRO5 has no usable Keymaster blob in the final Flyme dump. Use Android's
# software Keymaster 4 implementation so keystore can start instead of
# aborting while probing an undeclared TEE device.
PRODUCT_PACKAGES += \
    android.hardware.keymaster@4.0-service

# Radio. AOSP's legacy rild/libril translates the Flyme callback ABI to HIDL
# radio 1.1 for both slots. Android 12 loads the hash-locked SITRIL through
# vendor.rild.* properties; the stock pre-HIDL rild_exynos remains disabled.
PRODUCT_PACKAGES += \
    android.hardware.radio@1.0 \
    android.hardware.radio@1.1 \
    android.hardware.radio.deprecated@1.0 \
    libril \
    rild

ifeq ($(M86_VENDOR_INDEPENDENT),true)
PRODUCT_PACKAGES += libm86cutils_sitril_shim.vendor
PRODUCT_PACKAGES += libm86_vendor_paths
PRODUCT_PACKAGES += libstdc++.vendor
# Parsed after the generic rild.rc; the override scopes path translation to
# this vendor process without changing the framework or global linker.
PRODUCT_COPY_FILES += device/meizu/m86/independent/rild.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/zz-m86-rild.rc
else
PRODUCT_PACKAGES += libm86cutils_sitril_shim
endif

# GNSS. The Exynos 7420 wrapper exposes the verified Flyme legacy GPS HAL as
# GNSS 1.0; gpsd continues to consume the byte-exact production configuration.
PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0 \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service

ifeq ($(M86_VENDOR_INDEPENDENT),true)
PRODUCT_PACKAGES += libm86gps_vendor
else
PRODUCT_PACKAGES += libm86gps_shim
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/gps/gps.conf:$(M86_DEVICE_COPY_OUT)/etc/gps.conf \
    $(LOCAL_PATH)/gps/gps.xml:$(M86_DEVICE_COPY_OUT)/etc/gps.xml

# Sensors. Android 10's generic HIDL bridge loads sensors.m86.so. The custom
# service declaration adds the input group required by the Flyme ALS/PS path.
PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/sensors/android.hardware.sensors@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.sensors@1.0-service.rc

# Camera. The 32-bit provider loads the m86-owned module selected by the
# product. Keep the mutually exclusive engines out of images that do not use
# them; the compatibility shim remains available to both donor and source
# implementations.
PRODUCT_PACKAGES += \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service.m86 \
    camera.m86

ifneq ($(M86_USE_NATIVE_EXYNOS_HAL3),true)
PRODUCT_PACKAGES += libm86camera_shim
endif

ifeq ($(M86_USE_PREBUILT_EXYNOS_HAL3),true)
PRODUCT_PACKAGES += libm86camera3_bridge
else ifeq ($(M86_USE_NATIVE_EXYNOS_HAL3),true)
PRODUCT_PACKAGES += libexynoscamera3_m86
else
PRODUCT_PACKAGES += libexynoscamera_m86
endif

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

# Power. Use the Android 12 AIDL interface so SurfaceFlinger can keep the GPU at
# a modest rendering floor through EXPENSIVE_RENDERING. The device service also
# owns the existing March interaction and staged Mali floor policy.
PRODUCT_PACKAGES += \
    android.hardware.power-service.m86

# Report the existing TMU through the standard HAL; kernel thermal mitigation
# remains authoritative. Do not install the optional thermal logging daemon.
PRODUCT_PACKAGES += android.hardware.thermal@2.0-service.samsung
PRODUCT_COPY_FILES += \
    device/meizu/m86/thermal/thermal_info_config.json:$(TARGET_COPY_OUT_VENDOR)/etc/thermal_info_config.json

# Android 12 BatteryService requires a registered IHealth HIDL service.
# The AOSP default reads the m86 power-supply uevents through libbatterymonitor.
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-impl.recovery \
    android.hardware.health@2.1-service

# TARGET_SYSTEM_PROP is expanded after product makefiles have changed
# LOCAL_PATH. Use the stable device path so it cannot resolve under
# build/make/core during Ninja graph generation.
TARGET_SYSTEM_PROP := device/meizu/m86/system.prop

ifeq ($(M86_VENDOR_INDEPENDENT),true)
TARGET_SYSTEM_PROP := device/meizu/m86/independent/system.prop
TARGET_VENDOR_PROP := device/meizu/m86/independent/vendor.prop
PRODUCT_PACKAGES += android.hardware.drm@1.4-service.clearkey
PRODUCT_COPY_FILES += device/meizu/m86/independent/gatekeeper.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/zz-m86-gatekeeper.rc
$(call inherit-product, vendor/meizu/m86/m86-independent-vendor.mk)
else
$(call inherit-product-if-exists, vendor/meizu/m86/m86-vendor.mk)
endif

# Pull in the Android 13 SLSI namespace contract used by the 7420 BSP.
$(call inherit-product, hardware/samsung_slsi-linaro/config/config.mk)

# Compile system application methods on the build host for the full-preopt test.
PRODUCT_DEX_PREOPT_DEFAULT_FLAGS += --compiler-filter=speed -j2
