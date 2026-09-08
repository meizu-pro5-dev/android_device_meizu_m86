#!/usr/bin/env python3
"""Offline packaging gates; never certifies a replacement-system boot."""
import argparse
import json
from pathlib import Path
import re
import struct
import subprocess
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('product', type=Path)
args = parser.parse_args()
out = args.product
checks = {}

def check(name, condition):
    checks[name] = bool(condition)

def text(relative):
    path = out / relative
    return path.read_text() if path.is_file() else ''

def expanded_size(path):
    if not path.is_file():
        return 0
    with path.open('rb') as stream:
        data = stream.read(28)
    if len(data) == 28 and struct.unpack_from('<I', data)[0] == 0xed26ff3a:
        fields = struct.unpack('<I4H4I', data)
        return fields[5] * fields[6]
    return path.stat().st_size

fstabs = [text(p) for p in ['ramdisk/fstab.m86', 'root/fstab.m86', 'vendor/etc/fstab.m86']]
check('fstab_copies_identical', all(fstabs) and len(set(fstabs)) == 1)
rows = [line.split() for line in fstabs[0].splitlines()
        if line.strip() and not line.startswith('#')]
for mount, partition in [('/vendor', 'custom'), ('/cache', 'cache'),
                         ('/mnt/vendor/efs', 'efs'), ('/mnt/vendor/mnv', 'mnv')]:
    check('mount_' + partition, any(len(r) >= 5 and r[1] == mount
          and r[0].endswith('/by-name/' + partition) for r in rows))
check('userdata_not_formattable', any(r[1] == '/data' for r in rows)
      and all('formattable' not in r[4].split(',') for r in rows if r[1] == '/data'))
vendor_row = [r for r in rows if r[1] == '/vendor']
check('vendor_first_stage', len(vendor_row) == 1
      and 'first_stage_mount' in vendor_row[0][4].split(','))
check('vndk_33', 'ro.vndk.version=33' in text('vendor/build.prop').splitlines())
check('shipping_api_retained', 'ro.product.first_api_level=22' in text('vendor/build.prop').splitlines())
check('vendor_radio_path', 'vendor.rild.libpath=/vendor/lib64/libsitril.so' in text('vendor/build.prop'))
check('no_device_system_prop_fallback', 'ro.meizu.hardware.hifi=true' not in text('system/build.prop'))
manifest = out / 'vendor/etc/vintf/manifest.xml'
check('fcm_3', manifest.is_file() and ET.parse(manifest).getroot().get('target-level') == '3')
check('framework_sensor_contract', 'android.frameworks.sensorservice' in text('vendor/etc/vintf/compatibility_matrix.xml'))
for abi in ['lib', 'lib64']:
    check('mali_' + abi, (out / f'vendor/{abi}/egl/libGLES_mali.so').is_file())
for name in ['fts', 'gpio-keys', 'fpc1020', 'uinput-fpc']:
    check('vendor_keylayout_' + name, (out / f'vendor/usr/keylayout/{name}.kl').is_file())
for name in ['lib/hw/camera.m86.so', 'lib/libexynoscamera3_m86.so',
             'lib/libm86camera_metadata.so', 'lib64/libm86gps_vendor.so', 'bin/gpsd']:
    path = out / 'vendor' / name
    needed = []
    if path.is_file():
        result = subprocess.check_output(['readelf', '-W', '-d', str(path)], text=True)
        needed = re.findall(r'\(NEEDED\).*?\[(.*?)\]', result)
    check('private_deps_removed_' + name, path.is_file()
          and not {'libgui.so', 'libcamera_client.so', 'libsensor.so'} & set(needed))
    if name == 'bin/gpsd':
        check('gps_explicit_adapter', 'libm86gps_vendor.so' in needed)
for name, label in [('cbd', 'm86_cbd_exec'), ('gpsd', 'm86_gpsd_exec'),
                    ('mcDriverDaemon', 'm86_mobicore_exec'), ('m86_usb_serial', 'm86_usb_serial_exec')]:
    check('service_label_' + name, label in text('vendor/etc/selinux/vendor_file_contexts'))
for executable, label in [
        ('android.hardware.thermal@2.0-service.samsung', 'hal_thermal_default_exec'),
        ('android.hardware.drm@1.4-service.clearkey', 'hal_drm_default_exec')]:
    rules = [line.split() for line in text('vendor/etc/selinux/vendor_file_contexts').splitlines()
             if line.strip() and not line.lstrip().startswith('#')]
    check('gsi_service_label_' + executable, any(
        len(rule) == 2 and rule[1] == 'u:object_r:' + label + ':s0'
        and re.fullmatch(rule[0], '/vendor/bin/hw/' + executable) for rule in rules))
check('gatekeeper_vendor_data', '/data/vendor/gatekeeper' in text('vendor/etc/init/zz-m86-gatekeeper.rc'))
check('nfc_vendor_discovery_compat_enabled',
      'M86_PN547_DISCOVERY_COMPAT=0x01' in text('vendor/etc/libnfc-nxp.conf').splitlines())
for abi in ['lib', 'lib64']:
    nfc = out / 'vendor' / abi / 'nfc_nci_nxp.so'
    check('nfc_vendor_discovery_compat_' + abi, nfc.is_file()
          and b'm86 PN547: removed unsupported discovery modes' in nfc.read_bytes())
kernel_config = text('obj/KERNEL_OBJ/.config').splitlines()
check('kernel_wifi_firmware_vendor_path',
      'CONFIG_BCMDHD_FW_PATH="/vendor/firmware/fw_bcmdhd.bin"' in kernel_config)
check('kernel_wifi_calibration_vendor_path',
      'CONFIG_BCMDHD_NVRAM_PATH="/vendor/etc/wifi/bcmdhd.cal"' in kernel_config)
kernel = out / 'kernel'
check('kernel_audience_vendor_firmware_path', kernel.is_file()
      and b'/vendor/etc/firmware/' in kernel.read_bytes())
for name, maximum in [('boot', 25161728), ('system', 2684354560), ('vendor', 536870912)]:
    check('image_fits_' + name, 0 < expanded_size(out / (name + '.img')) <= maximum)
report = {'offline_packaging_passed': all(checks.values()), 'checks': checks,
          'runtime_accepted': False,
          'limitations': ['ELF candidate closure and target GSI VINTF are separate audits.',
                          'Requires device boot and HAL tests, then unchanged boot/vendor with a replacement system.',
                          'Current kernel is permissive; this is not full Treble certification.']}
print(json.dumps(report, indent=2))
raise SystemExit(0 if all(checks.values()) else 1)
