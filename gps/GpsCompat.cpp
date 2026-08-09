/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#include <openssl/ssl.h>

/*
 * Flyme's gpsd was linked against an SSLv3-named client-method selector.
 * Android 10's BoringSSL no longer negotiates SSLv3 and no longer exports the
 * legacy name. Return its current version-flexible TLS client method instead.
 */
extern "C" const SSL_METHOD* SSLv3_client_method()
{
    return TLS_client_method();
}
