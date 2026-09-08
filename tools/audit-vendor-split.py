#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the m86 separate-vendor build output before any device installation."""

import argparse
import json
from pathlib import Path
import struct
import zipfile


def image_size(path):
    with path.open('rb') as stream:
        header = stream.read(28)
    if len(header) >= 28 and struct.unpack_from('<I', header)[0] == 0xED26FF3A:
        fields = struct.unpack('<I4H4I', header)
        return fields[5] * fields[6]
    return path.stat().st_size


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('product_out', type=Path)
    parser.add_argument('--ota', type=Path)
    args = parser.parse_args()
    out = args.product_out
    checks = {}

    def check(name, condition):
        checks[name] = bool(condition)

    system_vendor = out / 'system/vendor'
    check('system_vendor_compat_link', system_vendor.is_symlink()
          and str(system_vendor.readlink()) == '/vendor')
    check('root_vendor_real_directory', (out / 'root/vendor').is_dir()
          and not (out / 'root/vendor').is_symlink())
    check('no_stale_custom_mountpoint', not (out / 'root/custom').exists())
    fstabs = [out / 'ramdisk/fstab.m86', out / 'root/fstab.m86',
              out / 'vendor/etc/fstab.m86']
    check('three_fstab_copies_match', all(p.is_file() for p in fstabs)
          and len({p.read_bytes() for p in fstabs if p.is_file()}) == 1)
    for index, fstab in enumerate(fstabs):
        rows = [line.split() for line in fstab.read_text().splitlines()
                if line.strip() and not line.lstrip().startswith('#')] if fstab.is_file() else []
        vendor = [row for row in rows if row[1] == '/vendor']
        check(f'vendor_first_stage_{index}', len(vendor) == 1
              and vendor[0][0].endswith('/by-name/custom')
              and vendor[0][2] == 'ext4'
              and 'first_stage_mount' in vendor[0][4].split(','))
        check(f'cache_preserved_{index}', any(row[1] == '/cache'
              and row[0].endswith('/by-name/cache') for row in rows))
        check(f'no_custom_mount_{index}', not any(row[1] == '/custom' for row in rows))
    recovery = out / 'recovery/root/system/etc/recovery.fstab'
    if not recovery.is_file():
        recovery = out / 'recovery/root/etc/recovery.fstab'
    check('recovery_vendor_mapping', recovery.is_file() and any(
        len(row) >= 3 and row[0].endswith('/by-name/custom') and row[1] == '/vendor'
        for row in (line.split() for line in recovery.read_text().splitlines())))
    for suffix in ['rc', 'usb.rc', 'wifi.rc', 'sensors.rc']:
        check(f'vendor_init_{suffix}', (out / f'vendor/etc/init/hw/init.m86.{suffix}').is_file())
        check(f'no_duplicate_root_init_{suffix}', not (out / f'root/init.m86.{suffix}').exists())
    init = out / 'vendor/etc/init/hw/init.m86.rc'
    check('vendor_mount_all', init.is_file()
          and 'mount_all /vendor/etc/fstab.m86' in init.read_text())
    check('vendor_sync_script', (out / 'vendor/bin/init.m86.boot-sync.sh').is_file())
    props = out / 'system/build.prop'
    check('no_false_treble_claim', props.is_file()
          and 'ro.treble.enabled=false' in props.read_text().splitlines())
    image = out / 'vendor.img'
    size = image_size(image) if image.is_file() else None
    check('vendor_image_fits_custom', size is not None and 0 < size <= 536870912)
    if args.ota:
        with zipfile.ZipFile(args.ota) as ota:
            script = ota.read('META-INF/com/google/android/updater-script').decode()
            check('ota_has_vendor_payload', 'vendor.new.dat.br' in ota.namelist()
                  or 'vendor.new.dat' in ota.namelist())
            check('ota_vendor_targets_custom', any('block_image_update(' in line
                  and '/by-name/custom' in line and 'vendor.transfer.list' in line
                  for line in script.splitlines()))
            check('ota_preserves_userdata', not any('format(' in line
                  and ('/data' in line or 'userdata' in line) for line in script.splitlines()))
    print(json.dumps({'checks': checks, 'vendor_image_expanded_bytes': size,
                      'passed': all(checks.values())}, indent=2))
    raise SystemExit(0 if all(checks.values()) else 1)


if __name__ == '__main__':
    main()
