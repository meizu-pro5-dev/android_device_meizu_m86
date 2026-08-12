# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional
LOCAL_PACKAGE_NAME := M86Parts
LOCAL_SRC_FILES := $(call all-java-files-under, src)
LOCAL_RESOURCE_DIR := $(LOCAL_PATH)/res
LOCAL_CERTIFICATE := platform
LOCAL_PRIVATE_PLATFORM_APIS := true
LOCAL_PRIVILEGED_MODULE := true
LOCAL_USE_AAPT2 := true
LOCAL_PROGUARD_FLAG_FILES := proguard.flags

# DeviceKeyHandler, LineageSettings and ActionUtils are existing Lineage 17.1
# extension APIs. M86Parts adds no public SDK surface.
LOCAL_STATIC_JAVA_LIBRARIES := \
    org.lineageos.platform.internal

include $(BUILD_PACKAGE)
