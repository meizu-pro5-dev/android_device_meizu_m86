# M86 system library incremental ZIP workflow

`make-system-lib-incremental-v5.sh` turns one or more rebuilt `/system/lib` or
`/system/lib64` files into the recovery-flashable v5 format used by the Camera3
bring-up packages.

The workflow is deliberately narrow: it cannot package boot, vendor, Magisk,
configuration files, or arbitrary system paths. Each replacement declares the
exact SHA-256 of its immediately preceding version. The recovery installer also
accepts the new SHA-256, making an already-installed ZIP safe to reflash.

## Camera3 example

Run after building the camera targets:

```bash
m libexynoscamera3_m86 camera.m86 -j8

device/meizu/m86/tools/make-system-lib-incremental-v5.sh \
  --name camera3-result-sync \
  --title "M86 Camera3 request/result synchronization fix" \
  --base-label "timestamp and Bayer lifecycle v5" \
  --output-dir ../../artifacts/camera-request-result-sync-incremental-20260826 \
  --payload \
    out/target/product/m86/system/lib/libexynoscamera3_m86.so:/system/lib/libexynoscamera3_m86.so:6cd06588f9dffc4951971165ae891960cfea6edbadf0da483296d807390e17c0 \
  --verify \
    /system/lib/hw/camera.m86.so:523ce14998cfdcd4a4922913ffb9b7d0af84aff35664505770d87d85defff455 \
  --commit hardware/samsung_slsi-linaro/exynos:fab0cfa \
  --test-note "Verify 2000 preview frames and no Timestamp: 0" \
  --test-note "Verify screen-off, screen-on, flush, and immediate reopen"
```

Use another `--payload` for every additional file that must be replaced. Use
`--verify` for a dependency that must match the baseline but must not be copied
again. Existing output files are rejected by default; pass `--force` only when
intentionally rebuilding the same package name.

The output directory contains:

- `m86-NAME-no-boot-v5.zip`;
- its v4 `.idsig`;
- `SHA256SUMS`;
- a generated `README.md` recording base/new hashes, commits, and test notes.

Before signing, the tool validates sources, target scope, hash syntax, updater
availability, shell syntax, and package boundaries. After signing, it validates
ZIP integrity, exact payload count, archived payload hashes, APK Signature
Block, and v4 idsig.
