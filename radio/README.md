# M86 radio owner

This directory owns the m86-specific radio lifecycle fragment. Android 10's
platform `rild` remains the single HIDL-facing daemon and loads the locked
64-bit Flyme SITRIL library through `rild.libpath`; `rild_exynos` and
`radiooptions_exynos` remain historical extraction evidence until the
target-files audit proves their removal.

The reset property uses the platform service name, `ril-daemon`. The old
`vendor.ril-daemon` spelling belonged to a different Treble layout and could
not restart this product's daemon.
