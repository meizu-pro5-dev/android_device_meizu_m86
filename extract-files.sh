#!/usr/bin/env bash

# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

device="m86"
vendor="meizu"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lineage_root="$(cd "$script_dir/../../.." && pwd)"
helper="$lineage_root/tools/extract-utils/extract_utils.sh"

if [[ ! -f "$helper" ]]; then
  printf 'Unable to find extract helper: %s\n' "$helper" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$helper"

# Keep the checked-in vendor definitions by default. They exclude platform
# blobs replaced by source modules and preserve audited destination renames
# which this branch's old extract-utils generator cannot reproduce.
clean_vendor=false
regenerate_makefiles=false
section=""
source_path="adb"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n | --no-cleanup)
      clean_vendor=false
      ;;
    --regenerate-makefiles)
      regenerate_makefiles=true
      ;;
    -s | --section)
      if [[ $# -lt 2 ]]; then
        printf '%s requires a section name\n' "$1" >&2
        exit 2
      fi
      section="$2"
      clean_vendor=false
      shift
      ;;
    *)
      source_path="$1"
      ;;
  esac
  shift
done

# LineageOS 17.1's extract_utils.sh predates nounset-safe optional arguments
# and reads all six setup_vendor parameters directly. Pass the vendor makefile
# name explicitly so this script remains strict without changing its output.
set +u
setup_vendor \
  "$device" \
  "$vendor" \
  "$lineage_root" \
  false \
  "$clean_vendor" \
  "$device"
extract "$script_dir/proprietary-files.txt" "$source_path" "$section"
set -u

if [[ "$regenerate_makefiles" == true ]]; then
  printf '%s\n' \
    'WARNING: regenerating vendor makefiles; review source-owned replacements and destination renames afterwards.' >&2
  "$script_dir/setup-makefiles.sh"
else
  printf '%s\n' \
    'Preserved checked-in vendor makefiles (use --regenerate-makefiles to replace them).'
fi
