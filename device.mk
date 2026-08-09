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

# Read the device's signed-factory serial payload from private slot 0 and
# publish only its validated serial field to the legacy USB gadget. The helper
# opens the identity partition read-only and never hardcodes a handset serial.
PRODUCT_PACKAGES += \
    m86_usb_serial

# Ramdisk
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.m86:$(TARGET_COPY_OUT_RAMDISK)/fstab.m86 \
    $(LOCAL_PATH)/rootdir/etc/fstab.m86:root/fstab.m86 \
    $(LOCAL_PATH)/rootdir/etc/init.m86.rc:root/init.m86.rc \
    $(LOCAL_PATH)/rootdir/etc/init.m86.boot-sync.sh:root/init.m86.boot-sync.sh \
    $(LOCAL_PATH)/rootdir/etc/init.m86.sensors.rc:root/init.m86.sensors.rc \
    $(LOCAL_PATH)/rootdir/etc/init.m86.usb.rc:root/init.m86.usb.rc \
    $(LOCAL_PATH)/rootdir/etc/ueventd.m86.rc:root/ueventd.m86.rc

# Input
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/fpc1020.kl:system/usr/keylayout/fpc1020.kl \
    $(LOCAL_PATH)/keylayout/fts.kl:system/usr/keylayout/fts.kl \
    $(LOCAL_PATH)/keylayout/gpio-keys.kl:system/usr/keylayout/gpio-keys.kl

# Minimum feature declaration for the first boot/recovery milestone.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:system/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.nfc.hce.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hce.xml \
    frameworks/native/data/etc/android.hardware.nfc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:system/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:system/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/com.android.nfc_extras.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/com.android.nfc_extras.xml \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml

# Graphics. The verified Flyme set supplies matching 32/64-bit Mali, HWC1 and
# memtrack implementations. The source-built Exynos gralloc provides the
# hardened fbdev path required by Android 10. These wrappers expose that legacy
# stack without inheriting the Galaxy product or its panel policy.
# configstore@1.1-service is already supplied by full_base_telephony.
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.mapper@2.0-impl \
    android.hardware.memtrack@1.0-impl \
    gralloc.exynos5 \
    hwcomposer.exynos5 \
    libcec \
    libexynosdisplay \
    libfimg \
    libhdmi \
    libhwc2on1adapter \
    libion

# Bluetooth. The same-SoC wrapper adds the required SCO configuration step;
# it loads the hash-locked m86 libbt-vendor.so at runtime.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-impl.zero \
    android.hardware.bluetooth@1.0-service.m86

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bluetooth/bt_vendor.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/bluetooth/bt_vendor.conf

# Wi-Fi. The PCIe bcmdhd driver is built into the m86 kernel, so no Samsung
# wifiloader or /efs macloader is used. Android 10's legacy HIDL service wraps
# the Broadcom HAL and switches the verified Flyme station/AP firmware through
# the bcmdhd module parameter.
PRODUCT_PACKAGES += \
    android.hardware.wifi@1.0-service.legacy \
    hostapd \
    wpa_supplicant \
    wpa_supplicant.conf

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf \
    $(LOCAL_PATH)/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf

# Audio. Android 10 requires XML policy, while the verified Flyme primary HAL
# still reads its exact mixer table from /system/etc/mixer_paths.xml.
PRODUCT_PACKAGES += \
    android.hardware.audio@5.0-impl \
    android.hardware.audio.effect@5.0-impl \
    audio.r_submix.default \
    audio.usb.default \
    libm86omx_shim

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audio/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml \
    $(LOCAL_PATH)/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(LOCAL_PATH)/audio/mixer_paths.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/mixer_paths.xml \
    $(LOCAL_PATH)/media/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(LOCAL_PATH)/media/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_telephony.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml \
    frameworks/av/services/audiopolicy/config/a2dp_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/a2dp_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml

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

# NFC. The pinned NXP PN5xx HIDL service drives m86's PN65T over /dev/pn544
# and consumes the final Flyme PN547 firmware plus device-specific RF tuning.
PRODUCT_PACKAGES += \
    android.hardware.nfc@1.1-service \
    com.android.nfc_extras \
    nfc_nci_nxp \
    NfcNci \
    Tag

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/nfc/libnfc-nxp.conf:$(TARGET_COPY_OUT_VENDOR)/etc/libnfc-nxp.conf \
    hardware/nxp/nfc/halimpl/libnfc-nci.conf:$(TARGET_COPY_OUT_VENDOR)/etc/libnfc-nci.conf

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

# USB. PRO5 has a fixed-role Micro-USB device port and no Type-C/dual-role
# class from which Android 10 can discover the active data role. The Lineage
# basic USB HAL reports the same immutable UFP + DEVICE + SINK port used by the
# Galaxy S6 universal7420 tree. Without it Settings receives DATA_ROLE_NONE
# and disables every entry in the "Use USB for" preference group even though
# the legacy android_usb gadget can switch functions correctly.
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service.basic

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

# Fingerprint. Android 10's generic HIDL 2.1 service wraps the source-built
# m86 FPC1020 transport and NBIS matcher. No compatible fingerprint TEE TA is
# available, so its authentication token is explicitly non-TEE-backed; this is
# a convenience unlock path and must not be treated as a strong biometric.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.1-service \
    fingerprint.m86 \
    libglib

# TARGET_SYSTEM_PROP is expanded after product makefiles have changed
# LOCAL_PATH. Use the stable device path so it cannot resolve under
# build/make/core during Ninja graph generation.
TARGET_SYSTEM_PROP := device/meizu/m86/system.prop

# Match Android 10's normal USB policy: start in the logical FUNCTION_NONE
# state, which exposes no storage until the user explicitly selects a data
# function.  UsbDeviceManager adds ADB only while USB debugging is enabled in
# Developer options.  Keep the synchronous FunctionFS compatibility path
# because m86's Samsung 3.10 gadget cannot service the newer nonblocking/AIO
# adbd transport reliably.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.adb.nonblocking_ffs=false \
    persist.sys.usb.config=none

$(call inherit-product-if-exists, vendor/meizu/m86/m86-vendor.mk)
