# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := $(call my-dir)

# Android 10's all-subdir-makefiles only discovers Android.mk files one level
# below the caller.  Keep this wrapper so the device-level Android.mk reaches
# the nested M86Parts package.
include $(call all-subdir-makefiles,$(LOCAL_PATH))
