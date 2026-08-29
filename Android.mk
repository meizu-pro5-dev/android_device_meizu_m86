# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := $(call my-dir)
M86_DEVICE_PATH := $(LOCAL_PATH)

ifneq ($(filter m86,$(TARGET_DEVICE)),)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
include hardware/meizu/m86/graphics/gralloc/Android.mk
LOCAL_PATH := $(M86_DEVICE_PATH)

# The PRO 5 bootloader reads a raw FDT from its dedicated dtb partition. The
# verified Flyme DTB is staged and hash-checked by install-local-trees.sh. The
# Every release disables the two unpopulated camera sensor nodes in place.
# NFC-only rollback builds additionally remove SPI4 secure-mode so the mutually
# exclusive raw AP-navigation driver can own the stock FPC node. The integrated
# and fingerprint-only products retain secure-mode for the TEE bridge. The
# kernel-generated DTB remains diagnostic-only.
M86_STOCK_DTB := $(M86_DEVICE_PATH)/prebuilt/dtb.img
M86_RELEASE_DTB_TOOL := $(M86_DEVICE_PATH)/tools/build-mback-dtb.py
M86_INSTALLED_DTB := $(PRODUCT_OUT)/dtb.img

ifeq ($(M86_FPC_BACKEND),tee)
$(M86_INSTALLED_DTB): $(M86_STOCK_DTB) $(M86_RELEASE_DTB_TOOL)
	@echo "Target m86 secure FPC DTB: $@"
	$(hide) python3 $(M86_RELEASE_DTB_TOOL) \
		--stock $(M86_STOCK_DTB) \
		--preserve-secure-mode \
		--output $@
else
$(M86_INSTALLED_DTB): $(M86_STOCK_DTB) $(M86_RELEASE_DTB_TOOL)
	@echo "Target m86 mBack DTB: $@"
	$(hide) python3 $(M86_RELEASE_DTB_TOOL) \
		--stock $(M86_STOCK_DTB) \
		--output $@
endif

.PHONY: m86-dtbimage
m86-dtbimage: $(M86_INSTALLED_DTB)

INSTALLED_RADIOIMAGE_TARGET += $(M86_INSTALLED_DTB)

endif
