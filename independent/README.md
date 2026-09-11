# Independent vendor experiment

This product is under development. Enabling the Treble build switches is a
compile-time check, **not a device compatibility claim or a release gate**.
The known working physical-split images remain at
`/root/work/pro5-vendor-split-20260907/candidate` on the development host.

Build preparation from an Android 13 tree:

```sh
python3 device/meizu/m86/tools/prepare-independent-vendor.py "$PWD"
source build/envsetup.sh
lunch lineage_m86_vendor_experiment-userdebug
m -j3 systemimage vendorimage bootimage
```

The integration repository supplies `hardware/meizu/m86`, including the native
camera metadata library and the vendor gralloc correction. The paired Exynos `lineage-20.0-treble` branch already includes the native
camera header changes; do not apply the historical patch a second time. Switching products may trigger an
automatic installclean; preserve candidate images outside `out` first.

The current external-system target is Android 13 with both 32-bit and 64-bit
LLNDK/VNDK 33 providers. A ROM's Flyme/OriginOS/MIUI marketing version does not
establish these requirements. Android 12 images lacking VNDK 33 are not covered.
The downloaded TrebleDroid ci-20230131 system is the first test candidate.
Its HAL/VNDK metadata check passes with this vendor. Including the actual
3.10.61 kernel in checkvintf fails the standard kernel-version requirements;
the backported development kernel requires functional device validation and
does not become Treble-certified by setting target-level or ro.treble.enabled.

Changes owned by this experiment:

- VNDK 33 variants and platform/vendor build boundary checks.
- The preparation tool derives independent kernel defconfigs with Broadcom
  firmware and NVRAM defaults below `/vendor`; the baseline configs are retained.
  The Audience DSP kernel loader searches `/vendor/etc/firmware` first. These
  kernel file paths are necessary in addition to userspace ELF separation.
- FCM 3 manifest header preserves the implemented GNSS 1.0, NFC 1.1 and
  radio 1.1 contracts. AOSP ClearKey 1.4 supplies DRM factories; this adds
  neither Widevine provisioning nor a kernel compatibility claim.
- The device compatibility matrix requires the framework sensor HIDL service.
- Hardware feature XML and physical/gesture keylayouts are vendor-owned.
  M86Parts and Lineage framework enhancements remain optional system features;
  a replacement GSI must supply its own settings UI and gesture policy.
- Native camera uses the in-process CameraMetadata, CameraParameters and
  VendorTagDescriptor subset compiled as `libm86camera_metadata`; it does not
  use the system Camera/ICamera client. Value serialization still uses VNDK
  libbinder; it does not introduce a private camera-service protocol.
- GPS imports are implemented by `libm86gps_vendor` over
  `android.frameworks.sensorservice@1.0`. The queue has bounded buffering and
  eventfd readiness for the legacy Looper. No system libsensor/libgui is used.
  Symbol coverage, event layout, service failure and real GNSS operation must
  be validated before accepting this path.
- Explicit DT_NEEDED shim dependencies replace Lineage linker injection.
  The experiment does not use a per-process SDK override for gpsd.
- Factory blobs are generated from SHA-256-locked originals into a separate
  directory. The generator fixes GPS, audio, Bluetooth, Trustonic and modem
  file paths; the original proprietary inputs are never edited.
- Auxiliary partitions mount at `/mnt/vendor/efs` and `/mnt/vendor/mnv`.
  Only cbd and rild preload `libm86_vendor_paths` to translate their old
  `/efs` and `/mnv` paths. This uses the normal linker, not a system patch.
  The host file-I/O test is preliminary; Android symbol interposition and
  modem operation still require device verification.
- The experimental fstab has no userdata `formattable` flag. Recovery and GPT
  are not changed by preparation or component builds.
- Gatekeeper uses `/data/vendor/gatekeeper` in the experimental rc. Before
  first boot with existing userdata, back up data in recovery and copy the
  old `/data/misc/gatekeeper/*.rec` retry records without overwriting conflicting
  records or deleting originals. The new rc restores labels before HAL start.
  Platform gatekeeperd state stays in `/data/misc/gatekeeper`. A rollback after
  credential changes also needs a consistent userdata restore; restoring only
  boot/system/vendor is insufficient to undo credential state changes.
- Explicit service executable labels replace the permissive Lineage init
  fallback. Policy compilation passes do not establish enforcing operation:
  the retained development kernel is still permissive, and legacy GPS/Trustonic
  data directories still need an enforcing-policy migration review.

Acceptance requires complete image/ELF audits (including symbols and dlopen),
VINTF checks, split SELinux policy, successful boot in isolated namespaces,
hardware regression checks, and a replacement Android 13 system boot with
**unchanged boot/vendor**. A compiler success alone does not pass these gates.
The dependency inventory tool deliberately does not report a Treble pass:

```sh
python3 device/meizu/m86/tools/audit-vendor-boundary.py out/target/product/m86 \
    --output boundary.json
```

Keep runtime rc variants synchronized with their original device/USB/Trustonic
owners when changing common behavior. `blobs.lock.json` intentionally rejects
unexpected changes to the original vendor makefiles or transformed blobs;
review and update the lock rather than silently accepting new inputs.

## 2026-09-08 GSI follow-up

TrebleDroid ci-20230131 Android 13 reached Settings with this independent
vendor after correcting the Samsung thermal and HIDL ClearKey exec labels.
The runtime kernel firmware-path changes also allowed Wi-Fi to enable and
re-enable without a temporary sysfs override. This does not establish full
hardware or enforcing-policy acceptance.

The GSI exposed another former system dependency: Lineage's system/nfc filter
for unsupported PN547 discovery modes. The device now explicitly enables a
vendor NXP HAL filter with `M86_PN547_DISCOVERY_COMPAT=0x01`. Its source patch
and exact input/output hashes are in `source-patches.json`; the preparation
tool applies it only to matching inputs and recognizes exact applied output.
Both HAL ABIs and a host test of the observed discovery request pass.
Vendor v4 was subsequently tested with TrebleDroid ci-20230131: NFC discovery
and service stability passed, including a reboot with NFC enabled. Physical
tag, HCE and payment behavior remain untested. The sensor probe now waits through metadata events within its
original total deadline; it does not change production sensor event delivery.

Runtime evidence and the tested v4 candidate are under
`/root/work/pro5-vendor-independent-20260908-runtime`. A separate source patch
there addresses the selected GSI's missing-animation null dereference; it is
not a vendor change and is not included in the device image.

## Published Treble checkpoint

Use the paired repositories on `lineage-20.0-treble` and the integration
repository's `manifests/lineage-20.0-treble-m86.xml`. See its
`docs/lineage-20.0-treble-checkpoint.md` for image hashes and test limits.
A13 v4 completed boot in 27 seconds; front/rear preview, Wi-Fi scanning,
NFC restart and sensor events were verified. The kernel remains permissive.

A14 ci-20240508 required ordinary signed APEX payloads in place of CAPEX and
a kernel renameat2(flags=0) backport. Both BoringSSL self-tests and classpath
generation then passed. A14 has not completed boot: gralloc loading is
blocked by the old kernel's same-process thread procfs access behavior.
The proposed ptrace correction is not applied in this checkpoint.

## CAPEX dm-verity follow-up (2026-09-08)

The local kernel now enables DM_VERITY and implements ignore_zero_blocks and
restart_on_corruption for A14 apexd. Together with renameat2 and both procfs
thread-group fixes, the user's restored original A14 GSI completed boot.
All 20 original CAPEX hashes matched; 20 dm-verity targets reported valid,
and both Conscrypt self-tests passed. The earlier CAPEX-to-APEX workaround
is no longer required for this image. Nine file-backed integrity/argument
checks passed, including rejection of data and hash-tree corruption. A
corruption-triggered reboot was not deliberately tested. These follow-up
source changes are local until the next publication; the published manifest
checkpoint above predates them.

### TFA firmware path boundary

The TFA library embeds complete filenames beginning with `/etc/tfa98xx/`
(13 bytes). Its vendor replacement is `/vendor//tfa/` (also 13 bytes),
resolving to the packaged `/vendor/tfa` directory. Do not shorten this prefix:
NUL padding before the remaining filename turns all firmware reads into
reads of the directory itself. `prepare-independent-vendor.py` rejects
shortened replacements that would truncate a C-string suffix. Both ABI
inputs preserve all ten complete filenames; the current product installs
only the 32-bit TFA library. Speaker runtime verification remains required.
