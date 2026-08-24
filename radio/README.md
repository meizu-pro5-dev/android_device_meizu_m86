# M86 radio owner

This directory owns the m86-specific radio configuration and lifecycle.
Android 12's platform `rild` remains the single HIDL-facing daemon and loads
the locked 64-bit Flyme SITRIL library through `vendor.rild.libpath`.
`rild_exynos` and `radiooptions_exynos` remain historical extraction evidence
and are not started or packaged as active radio services.

The Android 12 platform module installs the service as `vendor.ril-daemon`.
The m86 reset trigger must use that exact init service name so modem recovery
restarts the HIDL-facing daemon rather than addressing a nonexistent service.

Flyme's `libril_sitril.so` imports four modified-UTF conversion symbols that
Android removed from libcutils after Android 10. The source-owned
`libm86cutils_sitril_shim` restores that legacy ABI, following the first
LineageOS 19.1 universal7420 solution. `TARGET_LD_SHIM_LIBS` injects it only
for `/system/lib64/libril_sitril.so`; Android 12's global `libcutils.so`
remains unchanged.
