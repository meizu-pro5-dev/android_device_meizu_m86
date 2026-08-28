# Meizu PRO 5 (`m86`)

This directory is the LineageOS 20.0 / Android 13 device definition. It owns
the verified boot geometry, partition map, platform contract, ramdisk and
device-specific subsystem selection for the Meizu PRO 5.

The historical CyanogenMod 14.1 tree is preserved at
`legacy/device-meizu-m86-cm14`. The current tree does not inherit or parse
`device/samsung/universal7420-common`; required Exynos platform support comes
from the independently pinned Samsung SLSI repositories. Boot layout, audio,
camera, radio, NFC, Bluetooth, Wi-Fi, SELinux and MediaCodec seccomp policy are
owned by m86.

This directory also owns `proprietary-files.txt` and the extraction scripts.
They must stay outside `vendor/meizu/m86`, because LineageOS `setup_vendor`
cleans that generated output directory before recreating its makefiles and
ignored `proprietary/` payload.

Do not add a hardware feature merely because a Flyme blob exists. Each HAL or
shim must have a build result and runtime evidence before it enters
`PRODUCT_PACKAGES` or the device VINTF manifest.
