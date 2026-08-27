/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.mback;

/** Pure input identity and navigation-mode policy for the PRO 5 mBack key. */
final class MbackKeyPolicy {
    // The TEE fingerprint stack can emit its tap when the finger leaves the
    // sensor after a mechanical HOME press. The same 500 ms debounce window
    // is used by the Meizu m1721 device policy for this hardware interaction.
    static final long PHYSICAL_HOME_TAP_COOLDOWN_MS = 500;

    static final int GESTURE_NONE = 0;
    static final int GESTURE_TAP = 1;
    static final int GESTURE_DOUBLE_TAP = 2;
    static final int GESTURE_SWIPE_LEFT = 3;
    static final int GESTURE_SWIPE_RIGHT = 4;
    static final int GESTURE_PHYSICAL_HOME = 5;

    private static final String DEVICE_FPC1020 = "fpc1020";
    private static final String DEVICE_UINPUT_FPC = "uinput-fpc";
    private static final String DEVICE_GPIO_KEYS = "gpio-keys";

    // Stable public android.view.KeyEvent values. Keeping the policy free of
    // Android classes lets the exact production classifier run as a host test.
    private static final int KEYCODE_HOME = 3;
    // Android KeyEvent F1 starts at 131, so F9..F12 are 139..142.
    private static final int KEYCODE_F9 = 139;
    private static final int KEYCODE_F10 = 140;
    private static final int KEYCODE_F11 = 141;
    private static final int KEYCODE_F12 = 142;

    private MbackKeyPolicy() {
    }

    static int identifyGesture(String deviceName, int keyCode, int scanCode) {
        if (DEVICE_GPIO_KEYS.equals(deviceName)) {
            return keyCode == KEYCODE_HOME && scanCode == 102
                    ? GESTURE_PHYSICAL_HOME : GESTURE_NONE;
        }
        if (DEVICE_UINPUT_FPC.equals(deviceName)) {
            return keyCode == KEYCODE_F9 && scanCode == 305
                    ? GESTURE_TAP : GESTURE_NONE;
        }
        if (!DEVICE_FPC1020.equals(deviceName)) {
            return GESTURE_NONE;
        }

        // The raw AP driver reports Linux KEY_F20/KEY_F21 for the two
        // swipes.  Android's keylayout aliases are not stable across Input
        // Reader revisions, so the device-local scan code is authoritative;
        // this also keeps the handler working if F11/F12 are exposed as a
        // different framework keyCode.
        switch (scanCode) {
            case 158:
                return GESTURE_TAP;
            case 139:
                return GESTURE_DOUBLE_TAP;
            case 190:
                return GESTURE_SWIPE_LEFT;
            case 191:
                return GESTURE_SWIPE_RIGHT;
            default:
                return GESTURE_NONE;
        }
    }

    static boolean isUinputTap(String deviceName, int keyCode, int scanCode) {
        return DEVICE_UINPUT_FPC.equals(deviceName)
                && keyCode == KEYCODE_F9 && scanCode == 305;
    }

    static boolean shouldSuppressUinputTap(boolean physicalHomeDown,
            long lastPhysicalHomeUpTime, long tapEventTime) {
        if (physicalHomeDown) {
            return true;
        }
        if (lastPhysicalHomeUpTime < 0 || tapEventTime < lastPhysicalHomeUpTime) {
            return false;
        }
        return tapEventTime - lastPhysicalHomeUpTime <= PHYSICAL_HOME_TAP_COOLDOWN_MS;
    }

    static boolean shouldExecute(int gesture, boolean mbackEnabled) {
        return gesture != GESTURE_NONE && mbackEnabled;
    }

    static boolean shouldConsume(int gesture) {
        return gesture != GESTURE_NONE;
    }
}
