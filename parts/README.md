# M86Parts ownership

M86Parts is the device-owned UI and policy package for m86-only features. Its
mBack `DeviceKeyHandler` is loaded by Lineage's existing extension point from
`/system/priv-app/M86Parts/M86Parts.apk`. It accepts only the `fpc1020` and
`uinput-fpc` identities with an exact gesture key/scan pair, plus the physical
`gpio-keys` HOME at Android HOME/Linux scan 102. It consumes both halves of
recognized events and performs one action on an uncancelled key-up. The
physical press keeps HOME semantics in mBack mode; navbar mode consumes it
without falling through to HOME.

Actions and feedback use private per-user `Settings.Secure` keys, covered by
Android's `WRITE_SECURE_SETTINGS` permission. Navigation bar visibility remains
the existing Lineage `force_show_navbar` contract, covered separately by
Lineage's `WRITE_SETTINGS` permission, so SystemUI and the handler agree. A
one-time per-user migration copies the four former LineageSettings mBack values
without retaining a public SDK constant.

The package has no fingerprint HAL dependency, Accessibility service or
foreground service. The default product selects the raw AP-navigation kernel
backend and derives its DTB from the hash-locked Flyme tree by NOPing only
SPI4 `secure-mode`. It installs no fingerprint service, feature declaration,
HAL or VINTF fragment. The independent M8 fingerprint experiment selects the
TEE bridge and unchanged secure DTB instead; the two backends are never active
in the same kernel.
