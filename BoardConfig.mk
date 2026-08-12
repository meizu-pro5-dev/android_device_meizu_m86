# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

M86_PATH := device/meizu/m86

# Own the complete platform contract in the Meizu tree. Samsung sources may
# remain unmodified module dependencies, but no Galaxy BoardConfig is a parent
# of this product.
include $(M86_PATH)/BoardConfigPlatform.mk
include $(M86_PATH)/graphics/BoardConfigGraphics.mk

BOARD_VENDOR := meizu

# The verified Flyme primary HAL has matching 32/64-bit builds. Keep the
# Android 10 audio process on the donor-proven 32-bit ABI first, which also
# matches every required m86 TFA/SITRIL dependency.
AUDIOSERVER_MULTILIB := 32

# The final Flyme 8 camera stack is 32-bit. Its exact libexynoscamera imports
# five symbols no longer exported by Android 10 and expects SensorManager from
# the old libgui dependency graph. Inject only the source-built m86 shim.
TARGET_LD_SHIM_LIBS := \
    /system/lib/libexynoscamera.so|/system/lib/libm86camera_shim.so \
    /system/bin/gpsd|/system/lib64/libm86gps_shim.so

# Flyme's 32-bit Exynos OMX components use the pre-O GraphicBufferMapper
# four-argument lock ABI. Android 10 kept the operation but extended its C++
# signature with stride outputs, so inject the compatibility symbol into each
# legacy component when it is loaded by media.codec.
TARGET_LD_SHIM_LIBS += \
    /system/lib/omx/libOMX.Exynos.AVC.Decoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.AVC.Encoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.HEVC.Decoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.HEVC.Encoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.MPEG4.Decoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.MPEG4.Encoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.VP8.Decoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.VP8.Encoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.VP9.Decoder.so|/system/lib/libm86omx_shim.so \
    /system/lib/omx/libOMX.Exynos.WMV.Decoder.so|/system/lib/libm86omx_shim.so
# Flyme gpsd predates Q and still uses legacy linker greylist/APEX behavior.
# Scope the compatibility level to this one audited executable.
TARGET_PROCESS_SDK_VERSION_OVERRIDE := /system/bin/gpsd=27
# Android 10's AOSP libril remains the HIDL-facing compatibility layer. The
# verified Flyme SITRIL implements the Android 7 RIL v12 callback ABI and
# handles both m86 SIM sockets inside one process.
SIM_COUNT := 2

# Keep Galaxy model policy out of the m86 build, but label the two Meizu
# auxiliary-partition mountpoints that are materialized in the root image.
BOARD_SEPOLICY_DIRS := device/meizu/m86/sepolicy

# Assert
TARGET_OTA_ASSERT_DEVICE := m86,PRO5,pro5,mx5pro,niux,NIUX

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := PRO5
TARGET_NO_BOOTLOADER := true

# Display
TARGET_SCREEN_HEIGHT := 1920
TARGET_SCREEN_WIDTH := 1080
BACKLIGHT_PATH := /sys/class/backlight/pwm-backlight.0/brightness

# The maintained kernel exposes the fuel gauge under its real power-supply
# name. Do not inherit the Galaxy-only batt_lp_charging control path.
WITH_LINEAGE_CHARGER := false
BOARD_BATTERY_DEVICE_NAME := bq2753x-0
BOARD_CHARGER_ENABLE_SUSPEND := true

# Kernel and stock v0 boot-image geometry. Explicit positive offsets reproduce
# all four addresses in the verified Flyme header without relying on overflow.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/meizu/m86
ifeq ($(M86_ENABLE_FINGERPRINT_EXPERIMENT),true)
TARGET_KERNEL_CONFIG := cm_pro5_fingerprint_experiment_defconfig
M86_FPC_BACKEND := tee
else
TARGET_KERNEL_CONFIG := cm_pro5_defconfig
M86_FPC_BACKEND := raw-navigation
endif
TARGET_LINUX_KERNEL_VERSION := 3.10
TARGET_USES_UNCOMPRESSED_KERNEL := true
TARGET_KERNEL_CLANG_COMPILE := false
M86_KERNEL_BUILD_JOBS ?= 4
TARGET_KERNEL_ADDITIONAL_FLAGS += -j$(M86_KERNEL_BUILD_JOBS)

BOARD_KERNEL_BASE := 0x40000000
# androidboot.hardware is compiled into cm_pro5_defconfig. Keep the v0 header
# command line empty to match the verified Flyme boot image byte-for-byte.
BOARD_KERNEL_CMDLINE :=
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_KERNEL_PAGESIZE := 4096
# Android 10 unconditionally appends buildvariant=<variant> to the internal
# command line. mkbootimg accepts the last occurrence, so override it here to
# preserve the empty stock header without changing the platform for others.
BOARD_MKBOOTIMG_ARGS := \
    --cmdline "" \
    --kernel_offset 0x00080000 \
    --ramdisk_offset 0x02000000 \
    --second_offset 0x00f00000 \
    --tags_offset 0x00000100

# PRO 5 stores its raw DTB in a dedicated partition. No DTB is appended to
# boot.img and no Samsung boot-image container is selected.
BOARD_PACK_RADIOIMAGES += dtb

# Partitions, taken from the last booting m86 community tree and checked
# against the verified Flyme updater paths.
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 25161728
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33550336
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2684350464
BOARD_USERDATAIMAGE_PARTITION_SIZE := 27241979904
# Live Recovery blockdev inspection identifies m86 cache as sda43 with an
# exact 536870912-byte capacity. Keep the universal7420 real-/cache layout,
# using the verified Meizu geometry rather than Samsung's 200 MiB value.
BOARD_CACHEIMAGE_PARTITION_SIZE := 536870912
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
# Android 10 uses system-as-root, so mount points needed by the second-stage
# fstab must exist in the read-only root image. init cannot create a missing
# directory here after SwitchRoot().
BOARD_ROOT_EXTRA_FOLDERS += custom efs mnv

# Legacy non-Treble layout: vendor files live below system/vendor.
TARGET_COPY_OUT_VENDOR := system/vendor

# Recovery
TARGET_RECOVERY_FSTAB := $(M86_PATH)/storage/rootdir/etc/recovery.fstab
BOARD_HAS_NO_SELECT_BUTTON := true
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SUPPRESS_SECURE_ERASE := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBA_8888
TARGET_RELEASETOOLS_EXTENSIONS := $(M86_PATH)/releasetools

# Hardware
TARGET_BOARD_PLATFORM := exynos5
TARGET_SOC := exynos7420
BOARD_MODEM_TYPE := ss333

TARGET_NEEDS_NETD_DIRECT_CONNECT_RULE := true

# Broadcom Bluetooth
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(M86_PATH)/bluetooth
BOARD_HAVE_BLUETOOTH := true
# Flyme 8 supplies the m86-specific Broadcom vendor interface. Do not also
# define hardware/broadcom's same-named source module and depend on duplicate
# install-rule ordering.
BOARD_HAVE_BLUETOOTH_BCM :=

# Use a deliberately minimal manifest until each stock HAL has a validated
# Android 10 wrapper or replacement.
DEVICE_MANIFEST_FILE := \
    $(M86_PATH)/manifest.xml \
    $(M86_PATH)/graphics/manifest.xml
include $(M86_PATH)/wifi/BoardConfigWifi.mk
ifeq ($(M86_ENABLE_NFC_EXPERIMENT),true)
DEVICE_MANIFEST_FILE += $(M86_PATH)/experiments/manifest-nfc.xml
endif
ifeq ($(M86_ENABLE_FINGERPRINT_EXPERIMENT),true)
DEVICE_MANIFEST_FILE += $(M86_PATH)/experiments/manifest-fingerprint.xml
endif

# Verified from Flyme 8.0.5.0A /system/build.prop, not the Galaxy donor.
VENDOR_SECURITY_PATCH := 2019-08-01

-include vendor/meizu/m86/BoardConfigVendor.mk
