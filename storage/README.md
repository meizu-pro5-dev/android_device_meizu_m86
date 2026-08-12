# m86 storage ownership

This directory owns the Android and recovery mount contracts for the PRO 5.
The two Android ramdisk destinations are byte-identical inputs from
`rootdir/etc/fstab.m86`; `rootdir/etc/recovery.fstab` is selected directly by
`BoardConfig.mk`.

The Android 10 isolated-storage framework patch is deliberately not retired
by this directory move. Runtime evidence captured in
`work/nfc-logcat-cleanboot.txt` shows local and remote flags both at `0` while
the patched framework resolves the device default to `false`. Upstream
Android 10 resolves that same state to `true`, and exposes no product resource
whose overlay is equivalent to the patch. Retire the patch only after an
m86-owned product policy supplies the default before StorageManagerService and
passes encryption, internal storage, microSD, MTP/PTP and large-I/O tests on a
clean-data boot and an upgrade boot.
