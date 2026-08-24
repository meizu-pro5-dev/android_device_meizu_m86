/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#include <openssl/ssl.h>
#include <sensor/SensorManager.h>
#include <utils/String16.h>

/*
 * Flyme's gpsd was linked against an SSLv3-named client-method selector.
 * Android 10's BoringSSL no longer negotiates SSLv3 and no longer exports the
 * legacy name. Return its current version-flexible TLS client method instead.
 */
extern "C" const SSL_METHOD* SSLv3_client_method()
{
    return TLS_client_method();
}

/*
 * SensorManager::createEventQueue(String8, int) gained an attributionTag
 * parameter in Android 12. Flyme gpsd was linked against the two-argument
 * entry point. Export the legacy mangled member ABI and forward it to the
 * current implementation with an empty attribution tag.
 */
android::sp<android::SensorEventQueue> legacyCreateEventQueue(
        android::SensorManager* manager,
        android::String8 packageName,
        int mode)
        __asm__("_ZN7android13SensorManager16createEventQueueENS_7String8Ei");

android::sp<android::SensorEventQueue> legacyCreateEventQueue(
        android::SensorManager* manager,
        android::String8 packageName,
        int mode)
{
    return manager->createEventQueue(packageName, mode, android::String16());
}
