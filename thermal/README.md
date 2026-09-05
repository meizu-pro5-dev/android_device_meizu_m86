# m86 thermal reporting

Reuse the Samsung Thermal 2.0 service with the real `exynos-therm` zone
registered by `drivers/thermal/exynos7420_thermal.c`. Its temperature is in
millidegrees Celsius. The reported levels follow the 75/80/85/90/95 C throttle
table and 2 C falling threshold in the shipped m86 DTB, not Galaxy battery or
charger parameters. No Android shutdown threshold is invented.

`Monitor: false` deliberately leaves the kernel governor, trip points and
Exynos IPA mitigation in control. This supplies temperature/threshold queries;
it does not claim asynchronous thermal severity notifications. No unverified
battery, USB or GPU sensor and no cooling-device name is advertised.

On hardware, compare the HAL temperature to the `exynos-therm` sysfs reading
and confirm `dumpsys thermalservice` reports `HAL Ready: true`. Do not force
high temperatures or change kernel trip points to test this integration.
