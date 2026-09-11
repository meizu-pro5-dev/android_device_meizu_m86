# PRO 5 legacy sensor timestamp bridge

This device-specific HIDL 1.0 implementation retains the AOSP bridge API and
locked Flyme sensors.m86.so. Sensors.cpp/Sensors.h originate from
hardware/interfaces/sensors/1.0/default (Apache-2.0); only the legacy poll
boundary is changed. It installs under the standard implementation filename.
Do not select the generic and m86 implementation packages together.

Flyme ALS handle 4 and PS handles 3/27 expose evdev CLOCK_REALTIME timestamps.
The m86 bridge subtracts a freshly measured REALTIME minus BOOTTIME offset.
Both clocks advance during suspend. Values, handles, metadata, MCU sensors,
and batch/flush calls otherwise retain the original bridge behavior. No GSI
fingerprint check, framework patch, kernel change, or HAL version bump is used.

The clock sample brackets REALTIME with BOOTTIME reads and retries if the
bracket exceeds 1 ms. An offset change exceeding 5 ms across poll rejects the
ambiguous ALS/PS samples in that poll. Affected sensors advertise no batching;
samples older than 10 seconds, over 1 ms in the future, nonpositive, or from a
failed clock sample are rejected. The next poll recalibrates. This deliberately
loses ambiguous samples rather than reporting a fabricated capture time; after
a clock step an on-change sensor may need a new change or reactivation before
another reading. Small wall-clock steps within the tolerance cannot be fully
disambiguated from userspace; native BOOTTIME input timestamps remain preferable
if the kernel/legacy driver is replaced later. No fixed boot-time offset or
receive-time stamping is used.

The module is scoped to the locked Flyme blob SHA256
632b4d34abc1f2cf53526d6b781edb1fa3c6b1601ee3abbbb9b5f1cb98462a85.
Revalidate the handles and input clock before changing that blob.

Build: lunch lineage_m86_vendor_experiment-userdebug, then
m android.hardware.sensors@1.0-impl.m86.
Host regression: g++ -std=c++17 -Wall -Wextra -Werror
-fsanitize=undefined,address TimestampNormalizerTest.cpp -o /tmp/m86-time-test;
run the resulting binary. Device acceptance requires fresh ALS/PS samples in
BOOTTIME plus MCU sensor regression, and separate physical/suspend validation.
