# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# m86-owned Exynos 7420 platform contract for Android 12. The unmodified
# samsungexynos7420 lineage-19.1 SLSI BSP is an explicit build dependency;
# m86 keeps only the overrides proven on the Android 10 product baseline.

# Architecture and binder ABI
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a57
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53
TARGET_NR_CPUS := 8
TARGET_USES_64_BIT_BINDER := true

# Android 12 bring-up behavior for the 3.10 kernel and legacy-vendor target.
USE_XML_AUDIO_POLICY_CONF := 1
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
TARGET_FLATTEN_APEX := true
DEXPREOPT_GENERATE_APEX_IMAGE := false
WITH_DEXPREOPT := true
WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true
EXTENDED_FONT_FOOTPRINT := true
BLOCK_BASED_OTA := true
BOARD_RAMDISK_USE_GZIP := true
BOARD_OVERRIDE_RS_CPU_VARIANT_32 := cortex-a53.a57
BOARD_OVERRIDE_RS_CPU_VARIANT_64 := cortex-a57

TARGET_SPECIFIC_HEADER_PATH := device/samsung/universal7420-common/include

# Unmodified lineage-19.1 Exynos 7420 BSP defaults (TARGET_SLSI_VARIANT=linaro,
# TARGET_SOC_BASE=exynos7420, BOARD_HWC_VERSION=libhwc1, OpenMAX flags).
include hardware/samsung_slsi-linaro/config/BoardConfig7420.mk

# m86 overrides proven by the Android 10 integrated build.
BOARD_USE_STOREMETADATA := true
BOARD_USE_METADATABUFFERTYPE := true
BOARD_USE_ANB_OUTBUF_SHARE := true
BOARD_USE_IMPROVED_BUFFER := true
BOARD_USE_QOS_CTRL := false
BOARD_USE_S3D_SUPPORT := true
BOARD_USE_TIMESTAMP_REORDER_SUPPORT := false
BOARD_USE_DEINTERLACING_SUPPORT := false
BOARD_USE_VP8ENC_SUPPORT := true
BOARD_USE_HEVCDEC_SUPPORT := true
BOARD_USE_HEVCENC_SUPPORT := true
BOARD_USE_VP9DEC_SUPPORT := true
BOARD_HDMI_INCAPABLE := true
BOARD_HDMI_INCAPABE := true
BOARD_USES_SCALER := true
BOARD_USES_VIRTUAL_DISPLAY_DECON_EXT_WB := false
BOARD_USE_VIDEO_EXT_FOR_WFD_DRM := false
BOARD_USES_VDS_BGRA8888 := true
BOARD_VIRTUAL_DISPLAY_DISABLE_IDMA_G0 := false
# Route A installs the donor's original libhwjpeg.so and must be its sole
# owner. Other camera variants retain the source universal implementation.
ifeq ($(M86_USE_PREBUILT_EXYNOS_HAL3),true)
TARGET_USES_UNIVERSAL_LIBHWJPEG := false
else
TARGET_USES_UNIVERSAL_LIBHWJPEG := true
endif
BOARD_USES_SKIA_FIMGAPI := true
BOARD_USES_FIMGAPI_V5X := true
BOARD_USES_DEFAULT_CSC_HW_SCALER := true
BOARD_USES_SCALER_M2M1SHOT := true
