# m86 Wi-Fi owner

This directory owns the Android 10 Broadcom Wi-Fi contract: product packages,
feature declarations, interface properties, HIDL manifest instances,
supplicant init, overlays, and board firmware-path selection.

The kernel-built `bcmdhd` driver loads the locked Flyme calibration and
firmware installed by `vendor/meizu/m86/m86-vendor.mk`:

- `/system/etc/wifi/bcmdhd.cal`
- `/system/vendor/firmware/fw_bcmdhd.bin`
- `/system/vendor/firmware/fw_bcmdhd_apsta.bin`

There is no Samsung `wifiloader` and no `/efs` MAC loader. Device completion
still requires scan, 2.4/5 GHz association, reconnect, hotspot, and P2P gates.
