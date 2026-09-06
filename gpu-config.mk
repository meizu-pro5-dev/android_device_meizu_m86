# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# One selector owns the kernel, both GLES libraries and every private-handle
# consumer. Include during product evaluation as well as BoardConfig parsing.
M86_GPU_DDK ?= r22p0

ifeq ($(M86_GPU_DDK),r22p0)
M86_GRALLOC_CONTRACT_PATH := hardware/meizu/m86/graphics/gralloc/r22-contract
M86_GPU_KERNEL_CONFIG_SUFFIX := _r22p0
M86_GPU_BLOB_PREFIX := gpu/r22p0/
else ifeq ($(M86_GPU_DDK),r15p0)
M86_GRALLOC_CONTRACT_PATH := hardware/meizu/m86/graphics/gralloc/a10-contract
M86_GPU_KERNEL_CONFIG_SUFFIX :=
M86_GPU_BLOB_PREFIX :=
else
$(error Unsupported M86_GPU_DDK '$(M86_GPU_DDK)'; choose r15p0 or r22p0)
endif
