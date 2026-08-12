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
# default product derives its mBack DTB by removing only SPI4 secure-mode so
# the mutually exclusive raw AP-navigation driver can own the stock FPC node.
# The M8 fingerprint experiment retains the unmodified secure DTB and selects
# only the TEE bridge. The kernel-generated DTB remains diagnostic-only.
M86_STOCK_DTB := $(M86_DEVICE_PATH)/prebuilt/dtb.img
M86_MBACK_DTB_TOOL := $(M86_DEVICE_PATH)/tools/build-mback-dtb.py
M86_INSTALLED_DTB := $(PRODUCT_OUT)/dtb.img

ifeq ($(M86_FPC_BACKEND),tee)
$(M86_INSTALLED_DTB): $(M86_STOCK_DTB)
	@echo "Target m86 fingerprint-experiment DTB: $@"
	$(hide) test -s $(M86_STOCK_DTB)
	$(hide) cp -f $(M86_STOCK_DTB) $@
else
$(M86_INSTALLED_DTB): $(M86_STOCK_DTB) $(M86_MBACK_DTB_TOOL)
	@echo "Target m86 mBack DTB: $@"
	$(hide) python3 $(M86_MBACK_DTB_TOOL) \
		--stock $(M86_STOCK_DTB) \
		--output $@
endif

.PHONY: m86-dtbimage
m86-dtbimage: $(M86_INSTALLED_DTB)

INSTALLED_RADIOIMAGE_TARGET += $(M86_INSTALLED_DTB)

endif
