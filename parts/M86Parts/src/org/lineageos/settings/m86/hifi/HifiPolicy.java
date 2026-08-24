/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.hifi;

import android.content.ContentResolver;
import android.content.Context;
import android.media.AudioManager;
import android.provider.Settings;

/** Device-owned HiFi state contract. */
public final class HifiPolicy {
    static final String ENABLED = "hifi_music_enabled";
    static final String GAIN = "hifi_music_param";
    static final int GAIN_AUTO = 0;
    static final int GAIN_HIGH = 2;
    static final int GAIN_LINE_OUT = 3;

    private HifiPolicy() {
    }

    static boolean isEnabled(ContentResolver resolver) {
        return Settings.Global.getInt(resolver, ENABLED, 1) != 0;
    }

    static int getGain(ContentResolver resolver) {
        return clamp(Settings.Global.getInt(resolver, GAIN, GAIN_AUTO));
    }

    static boolean setEnabled(Context context, boolean enabled) {
        final ContentResolver resolver = context.getContentResolver();
        if (!Settings.Global.putInt(resolver, ENABLED, enabled ? 1 : 0)) {
            return false;
        }
        sync(context);
        return true;
    }

    static boolean setGain(Context context, int gain) {
        final ContentResolver resolver = context.getContentResolver();
        if (!Settings.Global.putInt(resolver, GAIN, clamp(gain))) {
            return false;
        }
        sync(context);
        return true;
    }

    /** Notify the m86 wrapper immediately; it persists and reapplies the state. */
    public static void sync(Context context) {
        final ContentResolver resolver = context.getContentResolver();
        final boolean enabled = isEnabled(resolver);
        final int gain = getGain(resolver);
        final AudioManager audio = (AudioManager) context.getSystemService(
                Context.AUDIO_SERVICE);
        if (audio != null) {
            audio.setParameters("m86_hifi_enabled=" + (enabled ? "on" : "off")
                    + ";hifi_gain=" + gain);
        }
    }

    private static int clamp(int gain) {
        return Math.max(GAIN_AUTO, Math.min(GAIN_LINE_OUT, gain));
    }
}
