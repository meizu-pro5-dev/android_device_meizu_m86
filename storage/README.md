# m86 storage ownership

This directory owns the Android and recovery mount contracts for the PRO 5.
The boot ramdisk, system root and vendor copies of `fstab.m86` are
byte-identical. `rootdir/etc/recovery.fstab` is selected by `BoardConfig.mk`.

## Separate vendor on stock custom

The stock `custom` GPT partition (sda42, 536870912 bytes) now carries an ext4
vendor image, mounted read-only at `/vendor` during first-stage init. GPT names
and sizes are unchanged. Recovery maps `/vendor` to the same `by-name/custom`
block device, which also makes the standard non-A/B OTA updater select that
block device for vendor updates. `/cache` remains on its original sda43.

This migration replaces the old custom-partition APK payload. It requires a
matching system and boot image as well as vendor.img. Back up custom, system,
boot and recovery before installation, verify the recovery path, and install
from recovery with these filesystems unmounted. Do not write a live mounted
system or vendor filesystem. Preserve user data and all modem/NV partitions.

When switching an existing build output from the embedded-vendor layout, run
`m installclean` before building (after preserving any needed old artifacts).
Otherwise stale system/vendor contents, the old root/vendor symlink or the
removed root/custom directory can prevent image creation. A fresh output
directory does not need this step.

Android build rules create `/system/vendor -> /vendor`; root `/vendor` is a
real mountpoint. Device init scripts live under `/vendor/etc/init/hw`, using
the standard init.m86.rc import; their mount_all command reads vendor fstab.

This is physical separation on the existing legacy ABI, not completed Treble
conversion. Keep ro.treble.enabled=false and the current linker behavior.
The system-owned cbd/gpsd, device shims, HALs and private framework libraries
remain a separate dependency-migration milestone. No GSI compatibility or
SELinux enforcing claim follows from the successful vendor image build.

Validate a clean boot, independent custom-to-vendor mount, HAL registration,
radio, audio, camera, Wi-Fi, USB and fingerprint before adopting the image.
Old incremental ZIPs that hard-code /system/vendor or only update system
must be audited against the new layout before use.

The Android 10 isolated-storage framework patch is deliberately not retired
by this directory move. Runtime evidence captured in
`work/nfc-logcat-cleanboot.txt` shows local and remote flags both at `0` while
the patched framework resolves the device default to `false`. Upstream
Android 10 resolves that same state to `true`, and exposes no product resource
whose overlay is equivalent to the patch. Retire the patch only after an
m86-owned product policy supplies the default before StorageManagerService and
passes encryption, internal storage, microSD, MTP/PTP and large-I/O tests on a
clean-data boot and an upgrade boot.

## Runtime checkpoint

On 2026-09-07, the 32 GB PRO 5 completed two boots of LineageOS 20 with
by-name/custom mounted read-only at /vendor. All three installed images passed
readback hash checks; the same 63 HIDL registration entries were present on
both boots, both cameras enumerated, and the crash buffers were empty. This
checks boot and service availability, not full peripheral function or Treble
compliance. Recovery and DTB were retained, and userdata was not formatted.
