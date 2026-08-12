# m86 standard-key ownership

`gpio-keys.kl` maps the kernel's fixed Linux input codes for Home (102),
Volume Down (114), Volume Up (115) and Power (116). The m86 DTS declares Power
and Home as wake sources. `fts.kl` contains the touchscreen controller's
standard Home/Menu/Back mappings.

This domain contains no FPC keylayout, private mBack action, fingerprint HAL
package or userspace service. Its device gate is raw `getevent` identity plus
Power, both volume directions, Home and suspend wake testing before mBack is
enabled.
