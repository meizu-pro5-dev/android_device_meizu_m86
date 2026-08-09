# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

"""Install the reviewed Flyme-based hybrid DTB with the m86 OTA."""

import common


def _install_dtb(info):
  dtb = info.input_zip.read("RADIO/dtb.img")
  common.ZipWriteStr(info.output_zip, "dtb.img", dtb)
  info.script.Print("Installing the Flyme-based AP fingerprint DTB...")
  info.script.AppendExtra(
      'package_extract_file("dtb.img", '
      '"/dev/block/platform/15570000.ufs/by-name/dtb");')


def FullOTA_InstallEnd(info):
  _install_dtb(info)


def IncrementalOTA_InstallEnd(info):
  _install_dtb(info)
