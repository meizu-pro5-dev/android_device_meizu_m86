# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_FINGERPRINT_EXPERIMENT_PATH := device/meizu/m86

# This experiment selects only Flyme's production Trustonic chain. The raw
# libfprint recovery implementation remains disabled and mutually exclusive.
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.1-service

# gatekeeperd on Android 10 obtains the gatekeeper through the
# android.hardware.gatekeeper@1.0 HIDL interface, not through a direct
# hw_get_module_by_class lookup. Without this passthrough service it silently
# falls back to SoftGateKeeperDevice and the Trustonic gatekeeper HAL is never
# loaded, so the 0401 matcher TA never sees a TEE-signed hw_auth_token. The
# passthrough implementation opens the legacy HAL class, which resolves to
# gatekeeper.m86.so (the renamed stock gatekeeper.exynos7420.so).
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-service \
    android.hardware.gatekeeper@1.0-impl

# The stock Flyme HAL stubs enumerate(), so FingerprintService's internal
# template cleanup would never complete and would block every client; the
# experiment overlay disables config_cleanupUnusedFingerprints.
PRODUCT_PACKAGE_OVERLAYS += \
    $(LOCAL_FINGERPRINT_EXPERIMENT_PATH)/experiments/overlay

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    $(LOCAL_FINGERPRINT_EXPERIMENT_PATH)/experiments/init.m86.fingerprint-experiment.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.m86.fingerprint-experiment.rc

$(call inherit-product-if-exists, vendor/meizu/m86/m86-fingerprint-experiment-vendor.mk)
