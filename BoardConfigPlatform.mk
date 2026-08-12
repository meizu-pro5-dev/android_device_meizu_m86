# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# m86-owned Exynos 7420 platform contract. These values used to arrive as
# side effects of Samsung's Galaxy product BoardConfig. Keep only values
# consumed by the Meizu product and make inherited ABI choices explicit.

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

# Android 10 behavior required by the old-kernel, legacy-vendor target.
USE_XML_AUDIO_POLICY_CONF := 1
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_PHONY_TARGETS := true
TARGET_FLATTEN_APEX := true
DEXPREOPT_GENERATE_APEX_IMAGE := false
WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := false
WITH_DEXPREOPT := true
EXTENDED_FONT_FOOTPRINT := true
BLOCK_BASED_OTA := true
BOARD_OVERRIDE_RS_CPU_VARIANT_32 := cortex-a53.a57
BOARD_OVERRIDE_RS_CPU_VARIANT_64 := cortex-a57

# Unmodified Exynos source modules consume these compile-time feature flags.
TARGET_SLSI_VARIANT := bsp
TARGET_SPECIFIC_HEADER_PATH := device/samsung/universal7420-common/include
BOARD_USE_STOREMETADATA := true
BOARD_USE_METADATABUFFERTYPE := true
BOARD_USE_DMA_BUF := true
BOARD_USE_ANB_OUTBUF_SHARE := true
BOARD_USE_IMPROVED_BUFFER := true
BOARD_USE_NON_CACHED_GRAPHICBUFFER := true
BOARD_USE_GSC_RGB_ENCODER := true
BOARD_USE_CSC_HW := false
BOARD_USE_QOS_CTRL := false
BOARD_USE_S3D_SUPPORT := true
BOARD_USE_TIMESTAMP_REORDER_SUPPORT := false
BOARD_USE_DEINTERLACING_SUPPORT := false
BOARD_USE_VP8ENC_SUPPORT := true
BOARD_USE_HEVCDEC_SUPPORT := true
BOARD_USE_HEVCENC_SUPPORT := true
BOARD_USE_HEVC_HWIP := false
BOARD_USE_VP9DEC_SUPPORT := true
BOARD_USE_VP9ENC_SUPPORT := false
BOARD_USE_CUSTOM_COMPONENT_SUPPORT := true
BOARD_USE_VIDEO_EXT_FOR_WFD_HDCP := false
BOARD_USE_SINGLE_PLANE_IN_DRM := false
BOARD_USES_VPP := true
BOARD_HDMI_INCAPABLE := true
BOARD_USES_SCALER := true
BOARD_USES_VIRTUAL_DISPLAY_DECON_EXT_WB := false
BOARD_USE_VIDEO_EXT_FOR_WFD_DRM := false
BOARD_USES_VDS_BGRA8888 := true
BOARD_VIRTUAL_DISPLAY_DISABLE_IDMA_G0 := false
TARGET_USES_UNIVERSAL_LIBHWJPEG := true
BOARD_USES_SKIA_FIMGAPI := true
BOARD_USES_FIMGAPI_V5X := true
BOARD_USES_DEFAULT_CSC_HW_SCALER := true
BOARD_USES_SCALER_M2M1SHOT := true

# Temporary A10 compatibility route. It only lets the unmodified common tree
# expose the legacy Bluetooth implementation and is removed with M4. No value
# in this file is inherited from the Samsung BoardConfig.
TARGET_DEVICE_IS_M86 := true
