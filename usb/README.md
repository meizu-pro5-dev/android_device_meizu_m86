# m86 USB ownership

This domain owns the fixed UFP/device/sink HAL selection, Meizu gadget
compositions, FunctionFS lifecycle and the factory-derived serial helper. The
helper reads the private slot read-only, publishes the serial to `iSerial`, and
then sets `vendor.m86.identity.ready=1`. Other domains may consume that event,
but the USB init file contains no foreign service lifecycle commands.

The two historical `system/core` adbd patches are retired: they are absent
from `patches/series.tsv`, recorded in `docs/retired-platform-debt.tsv`, and
the active path uses unmodified Android 10 adbd with synchronous FunctionFS.
Runtime acceptance still requires cold-boot ADB, MTP, PTP, twenty physical
reconnects and bidirectional 500 MiB hash checks.
