#!/usr/bin/env python3
"""Inventory ELF dependencies without treating a legacy global namespace as Treble.

Run against an unpacked product directory containing system/ and vendor/.
The provider list is descriptive, not a linker simulation. A provider under
system does not establish namespace visibility or a stable ABI. Supply the
target's LLNDK/VNDK library lists to classify those names explicitly.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def inspect(path):
    with path.open('rb') as f:
        header = f.read(20)
    if header[:4] != b'\x7fELF':
        return None
    result = subprocess.run(['readelf', '-W', '-d', '--dyn-syms', str(path)],
                            check=True, capture_output=True, text=True)
    needed = re.findall(r'\(NEEDED\).*?\[(.*?)\]', result.stdout)
    sonames = re.findall(r'\(SONAME\).*?\[(.*?)\]', result.stdout)
    undefined, exported, unversioned = set(), set(), set()
    for line in result.stdout.splitlines():
        # GNU readelf can print Android IFUNC's type as '<OS specific>: 10'.
        # Match from binding onward instead of relying on fixed word offsets.
        match = re.match(r'\s*\d+:\s+\S+\s+\d+\s+.+?\s+'
                         r'(GLOBAL|WEAK)\s+(\S+)\s+(\S+)\s+(\S+)', line)
        if not match:
            continue
        binding, visibility, section, symbol = match.groups()
        name = symbol.replace('@@', '@')
        if section == 'UND':
            if binding == 'GLOBAL':
                undefined.add(name)
        elif visibility in ('DEFAULT', 'PROTECTED'):
            exported.add(name)
            if '@' not in symbol:
                unversioned.add(symbol)
            if '@@' in symbol:
                exported.add(name.split('@')[0])
    return {'abi': header[4], 'needed': needed,
            'soname': sonames[0] if sonames else path.name,
            'undefined': sorted(undefined), 'exports': sorted(exported),
            'unversioned_exports': sorted(unversioned)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('product', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--allowed-list', action='append', default=[], type=Path)
    parser.add_argument('--focus', action='append', default=[],
                        help='Additional device-owned system ELF, product-relative')
    args = parser.parse_args()
    root = args.product.resolve()
    if not (root / 'vendor').is_dir() or not (root / 'system').is_dir():
        parser.error('product must contain vendor and system directories')
    allowed = set()
    list_hashes = {}
    for path in args.allowed_list:
        list_hashes[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        for line in path.read_text().splitlines():
            line = line.split('#')[0].strip()
            if line:
                allowed.add(line.split()[0])
    paths = []
    for partition in ('vendor', 'odm', 'system', 'system_ext', 'product'):
        for directory, _, files in os.walk(root / partition, followlinks=False):
            for name in files:
                path = Path(directory) / name
                if not path.is_symlink():
                    paths.append(path)
    elfs = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for path, info in zip(paths, pool.map(inspect, paths)):
            if info:
                elfs[str(path.relative_to(root))] = info
    providers = {}
    for path, info in elfs.items():
        providers.setdefault((info['abi'], info['soname']), []).append(path)
    roots = sorted(p for p in elfs if p.startswith(('vendor/', 'odm/')))
    for path in args.focus:
        if path not in elfs:
            parser.error(f'focus ELF missing: {path}')
        if path not in roots:
            roots.append(path)
    edges, external = [], []
    for path in roots:
        info = elfs[path]
        for name in info['needed']:
            candidates = providers.get((info['abi'], name), [])
            local = [p for p in candidates if p.startswith(('vendor/', 'odm/'))]
            classification = ('vendor-local-candidate' if local else
                              'declared-llndk-or-vndk' if name in allowed else
                              'unclassified-external' if candidates else 'missing')
            used = {}
            for candidate in candidates:
                matches = set(info['undefined']) & set(elfs[candidate]['exports'])
                if matches:
                    used[candidate] = sorted(matches)
            edge = {'consumer': path, 'abi': info['abi'], 'needed': name,
                    'classification': classification,
                    'provider_candidates': sorted(candidates),
                    'matching_undefined_symbols': used}
            edges.append(edge)
            if not local:
                external.append(edge)
    report = {
        'schema': 1, 'product': str(root), 'elf_count': len(elfs),
        'roots': roots, 'allowed_list_sha256': list_hashes,
        'external_reference_count': len(external),
        'external_sonames': sorted({e['needed'] for e in external}),
        'edges': edges,
        'limitations': [
            'All vendor ELFs are examined, including transitive vendor providers.',
            'External providers are candidates, not namespace accessibility proof.',
            'External system/APEX closures are not approved by name alone.',
            'dlopen, symbol interposition, Binder protocols, paths and runtime '
            'namespace isolation require separate review and device tests.',
            'This report never certifies Treble or replacement-system boot.',
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in
                      ('elf_count', 'external_reference_count', 'external_sonames')}))


if __name__ == '__main__':
    main()
