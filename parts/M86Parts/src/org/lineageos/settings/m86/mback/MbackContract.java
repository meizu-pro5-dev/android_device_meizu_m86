/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.mback;

import android.content.ContentResolver;
import android.content.Context;
import android.provider.Settings;

import lineageos.providers.LineageSettings;

final class MbackContract {
    static final int ACTION_NOTHING = 0;
    static final int ACTION_MENU = 1;
    static final int ACTION_RECENTS = 2;
    static final int ACTION_ASSIST = 3;
    static final int ACTION_VOICE_ASSIST = 4;
    static final int ACTION_IN_APP_SEARCH = 5;
    static final int ACTION_CAMERA = 6;
    static final int ACTION_SLEEP = 7;
    static final int ACTION_LAST_APP = 8;
    static final int ACTION_SPLIT_SCREEN = 9;
    static final int ACTION_HOME = 10;
    static final int ACTION_BACK = 11;

    static final String SECURE_TAP_ACTION = "meizu_mback_tap_action";
    static final String SECURE_DOUBLE_TAP_ACTION = "meizu_mback_double_tap_action";
    static final String SECURE_SWIPE_LEFT_ACTION = "meizu_mback_swipe_left_action";
    static final String SECURE_SWIPE_RIGHT_ACTION = "meizu_mback_swipe_right_action";
    static final String SECURE_SOUND_ENABLED = "meizu_mback_sound_enabled";
    static final String SECURE_HAPTIC_DURATION = "meizu_mback_haptic_duration";
    static final String SECURE_MIGRATION_VERSION = "meizu_mback_migration_version";

    // Raw legacy names are intentionally private migration inputs. They do not
    // reintroduce public LineageSettings constants or validators.
    private static final String LEGACY_TAP_ACTION = "mback_tap_action";
    private static final String LEGACY_DOUBLE_TAP_ACTION = "mback_double_tap_action";
    private static final String LEGACY_SWIPE_LEFT_ACTION = "mback_swipe_left_action";
    private static final String LEGACY_SWIPE_RIGHT_ACTION = "mback_swipe_right_action";
    private static final int MIGRATION_VERSION = 1;
    private static final int LEGACY_MISSING = Integer.MIN_VALUE;

    private MbackContract() {
    }

    static int getSecureInt(ContentResolver resolver, String key, int fallback, int userId) {
        return Settings.Secure.getIntForUser(resolver, key, fallback, userId);
    }

    static boolean putSecureInt(ContentResolver resolver, String key, int value, int userId) {
        return Settings.Secure.putIntForUser(resolver, key, value, userId);
    }

    static boolean isMbackNavigationEnabled(ContentResolver resolver, int userId) {
        return LineageSettings.System.getIntForUser(resolver,
                LineageSettings.System.FORCE_SHOW_NAVBAR, 1, userId) == 0;
    }

    static boolean setMbackNavigationEnabled(ContentResolver resolver, boolean enabled,
            int userId) {
        return LineageSettings.System.putIntForUser(resolver,
                LineageSettings.System.FORCE_SHOW_NAVBAR, enabled ? 0 : 1, userId);
    }

    static void migrateIfNeeded(Context context, int userId) {
        final ContentResolver resolver = context.getContentResolver();
        if (getSecureInt(resolver, SECURE_MIGRATION_VERSION, 0, userId)
                >= MIGRATION_VERSION) {
            return;
        }

        migrateAction(resolver, userId, SECURE_TAP_ACTION, LEGACY_TAP_ACTION, ACTION_BACK);
        migrateAction(resolver, userId, SECURE_DOUBLE_TAP_ACTION,
                LEGACY_DOUBLE_TAP_ACTION, ACTION_NOTHING);
        migrateAction(resolver, userId, SECURE_SWIPE_LEFT_ACTION,
                LEGACY_SWIPE_LEFT_ACTION, ACTION_HOME);
        migrateAction(resolver, userId, SECURE_SWIPE_RIGHT_ACTION,
                LEGACY_SWIPE_RIGHT_ACTION, ACTION_RECENTS);

        if (Settings.Secure.getStringForUser(resolver, SECURE_SOUND_ENABLED, userId) == null) {
            putSecureInt(resolver, SECURE_SOUND_ENABLED, 0, userId);
        }
        if (Settings.Secure.getStringForUser(resolver, SECURE_HAPTIC_DURATION, userId) == null) {
            putSecureInt(resolver, SECURE_HAPTIC_DURATION, 20, userId);
        }
        putSecureInt(resolver, SECURE_MIGRATION_VERSION, MIGRATION_VERSION, userId);
    }

    private static void migrateAction(ContentResolver resolver, int userId, String secureKey,
            String legacyKey, int fallback) {
        if (Settings.Secure.getStringForUser(resolver, secureKey, userId) != null) {
            return;
        }
        final int legacyValue = LineageSettings.System.getIntForUser(
                resolver, legacyKey, LEGACY_MISSING, userId);
        putSecureInt(resolver, secureKey,
                translateLegacyAction(legacyValue, fallback), userId);
    }

    private static int translateLegacyAction(int legacyValue, int fallback) {
        switch (legacyValue) {
            case 0:
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9:
                return legacyValue;
            case 12:
                return ACTION_HOME;
            case 13:
                return ACTION_BACK;
            case LEGACY_MISSING:
            default:
                return fallback;
        }
    }
}
