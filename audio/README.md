# m86 normal-audio ownership

This directory owns the Android 10 audio service selection, policy, mixer
table, and immutable Flyme primary-HAL contract. The source wrapper is the
candidate producer; the locked Flyme object remains a private input until the
runtime gates below are complete.

The production Flyme 8 primary HAL is a 32-bit Android 7-era module. Its
`audio_hw_device` inserts three private pointer slots after `get_mic_mute`, and
its output stream places a private `pcm_config` at offset 116. Android 10 reads
that first `pcm_config` word as `update_source_metadata`, producing the observed
invalid callback value `0x2`. The legacy device `dump` callback exists at
offset 136; Android 10 only sees it as absent because the public structure has
newer fields at different offsets.

`hardware/meizu/m86/audio/LegacyAudioAbiContract.h` records the verified
32-bit offsets without changing the platform `hardware/audio.h`. M86Parts
stores the device-wide HiFi state in `Settings.Global` and directly sends
`m86_hifi_enabled`/`hifi_gain` through `AudioManager`; the wrapper persists
that user policy separately from AudioFlinger's per-output `hifi_state`
request. The raw HAL sees HiFi enabled only when the user switch, a compatible
PRIMARY mixer route, and a wired output are all active. Route changes, output
reopen, and audioserver restart therefore fail closed instead of leaving the
DAC latched in its previous mode.

1. Install a 32-bit source wrapper as `audio.primary.m86.so` and rename the
   locked Flyme blob to a private, absolute-path-only input.
2. Prove the Android linker loads the private object despite its historical
   `audio.primary.m86.so` SONAME, then translate every device, output-stream,
   and input-stream pointer at the wrapper boundary.
3. Keep post-legacy output/input callbacks null or return `-ENOSYS`; never
   expose the Flyme private tail to the Android 10 HIDL wrapper.
4. Intercept `vendor.meizu.set_headphone_volume=1` and the HiFi policy keys in
   the public wrapper. Dispatch headphone volume to offset 104 on output open
   and every route transition, route HiFi state to the active output, and
   send gain to the private device callback. Persist both values so an
   audioserver restart restores them before the first output is opened.
   Unrelated parameters remain on the legacy path.
5. Pass speaker, receiver, microphone, wired headset, Bluetooth, call audio,
   mute/volume/route, `dumpsys`, audioserver restart, and suspend/resume tests.

The 64-bit primary HAL has no standard consumer while audioserver and the
passthrough manifest are 32-bit. It is an explicit removal candidate, but is
not removed until a full target-files gate proves there is no other 64-bit
legacy loader. HiFi UI, global persistence, and PRIMARY-mixer rate arbitration
remain separate layers; no application whitelist is part of that contract.

The legacy route contract is deliberate. The verified direct Flyme HAL reports
`AUDIO_DEVICE_API_VERSION_2_0`, so Android 10's `Device` implementation uses
the stream-level fallback and sends `routing=N` through the output stream's
`set_parameters`. The wrapper preserves that API version and forwards the
whole device/output/input prefix; it must not replace the route with a modern
device-level `create_audio_patch` call. Doing so leaves Flyme's DAPM route at
`none` and produces `out_device=0`/`-EBUSY`, even though the ALSA/mixer chain
itself is healthy.
