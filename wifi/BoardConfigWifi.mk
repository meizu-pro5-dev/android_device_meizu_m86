# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

# Broadcom PCIe Wi-Fi. The firmware destinations are the exact paths compiled
# into the m86 bcmdhd kernel; the vendor makefile installs the locked Flyme
# calibration, station and AP inputs there.
BOARD_WLAN_DEVICE := bcmdhd
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_bcmdhd
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_bcmdhd
WIFI_DRIVER_FW_PATH_PARAM := /sys/module/bcmdhd/parameters/firmware_path
WIFI_DRIVER_FW_PATH_STA := /system/vendor/firmware/fw_bcmdhd.bin
WIFI_DRIVER_FW_PATH_AP := /system/vendor/firmware/fw_bcmdhd_apsta.bin
WIFI_BAND := 802_11_ABG

DEVICE_MANIFEST_FILE += $(M86_PATH)/wifi/manifest.xml
