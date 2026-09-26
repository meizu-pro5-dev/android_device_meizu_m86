# m86 r22p0 Vulkan integration

The r22p0 Mali library already implements the Android Vulkan HAL. The previous
r15p0-era build excluded its loader entry points, so the Android 13 loader
reported zero physical devices even with the matching r22p0 stack installed.

`graphics/Android.mk` installs relative links for both ABIs:

- `/vendor/lib/vulkan.exynos5.so -> egl/libGLES_mali.so`
- `/vendor/lib64/vulkan.exynos5.so -> egl/libGLES_mali.so`

Android 13's `frameworks/native/vulkan/libvulkan/driver.cpp` selects
`vulkan.<ro.hardware.vulkan>.so`, falling back to `ro.board.platform` (`exynos5`
on m86), then loads it through the SP-HAL namespace. The links use that
namespace's library search path. No loader patch or replacement GLES blob is
needed. See the [AOSP Vulkan integration documentation](https://source.android.com/docs/core/graphics/implement-vulkan).

Both the links and product feature declarations are conditional on
`M86_GPU_DDK=r22p0`. The retained r15p0 configuration remains GLES-only.
The product advertises Vulkan 1.0.3 and hardware level 0. The actual tested
GPU reports Vulkan 1.0.61; no Vulkan 1.1+, level 1, compute feature flag, or
dated dEQP conformance claim is added without separate validation.
SurfaceFlinger remains on the existing GLES rendering path.

## Required matched stack

Use the existing r22p0 kernel and common gralloc contract selected by
`gpu-config.mk`, with the pinned Mali blobs:

| ABI | SHA-256 of libGLES_mali.so |
| --- | --- |
| 32-bit | 9d6a02557055ec1b145269cb39f602bce102da74ae4d71bd0a6169d8a4573da9 |
| 64-bit | 78411f9894554e0e85bc1d4b7b4394aa3d427be86a5d50eff77b346740111a39 |

## Build and verification

From the Android build root after selecting the desired m86 product:

```sh
m m86-vulkan-links \
  out/target/product/m86/vendor/etc/permissions/android.hardware.vulkan.version.xml \
  out/target/product/m86/vendor/etc/permissions/android.hardware.vulkan.level.xml
```

The normal image build includes both links and feature XMLs. On the device,
restart Android after installing the XMLs so PackageManager reads them and
long-lived loader instances do not retain their previous no-driver state:

```sh
adb shell pm list features
adb shell cmd gpu vkjson
```

Validation on 2026-09-26 with the LineageOS 20 vendor experiment product:

- Kernel `CONFIG_MALI_R22P0=y`, matching 32/64-bit blob hashes.
- Both ABIs through the public `libvulkan.so`: one Mali-T760 physical device,
  Vulkan 1.0.61, logical device and queue creation, GPU buffer fill/fence wait,
  and exact 4096-byte CPU readback.
- Both ABIs in an ordinary app: Android surface, 1080x1920 FIFO swapchain,
  and 60 acquired/cleared/presented frames. This tests buffer sharing with
  the Android display stack as well as the Vulkan loader.
- Reboot succeeded; PackageManager exposes the two declared Vulkan features;
  `cmd gpu vkjson` reports one device instead of zero.
- Existing GLES renderer remains r22p0; no GPU fault was found in the sampled
  kernel log during the smoke test.

These are functional smoke tests under the existing permissive ROM. They do
not establish CTS/dEQP conformance, Enforcing compatibility, shader compiler
coverage, or long-duration game stability. No complete ROM ZIP was built for
this change.
