/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.mback;

public final class MbackKeyPolicyTest {
    private static void expectGesture(String label, int expected,
            String device, int keyCode, int scanCode) {
        final int actual = MbackKeyPolicy.identifyGesture(device, keyCode, scanCode);
        if (actual != expected) {
            throw new AssertionError(label + ": expected " + expected + ", got " + actual);
        }
    }

    private static void expect(boolean value, String message) {
        if (!value) {
            throw new AssertionError(message);
        }
    }

    public static void main(String[] args) {
        expectGesture("raw tap", MbackKeyPolicy.GESTURE_TAP,
                "fpc1020", 139, 158);
        expectGesture("raw double tap", MbackKeyPolicy.GESTURE_DOUBLE_TAP,
                "fpc1020", 140, 139);
        expectGesture("raw F20 left", MbackKeyPolicy.GESTURE_SWIPE_LEFT,
                "fpc1020", 0, 190);
        expectGesture("raw F20 left repeat", MbackKeyPolicy.GESTURE_SWIPE_LEFT,
                "fpc1020", 141, 190);
        expectGesture("raw F21 right", MbackKeyPolicy.GESTURE_SWIPE_RIGHT,
                "fpc1020", 0, 191);
        expectGesture("raw F21 right repeat", MbackKeyPolicy.GESTURE_SWIPE_RIGHT,
                "fpc1020", 142, 191);
        expectGesture("optional Flyme tap", MbackKeyPolicy.GESTURE_TAP,
                "uinput-fpc", 139, 305);
        expectGesture("physical home", MbackKeyPolicy.GESTURE_PHYSICAL_HOME,
                "gpio-keys", 3, 102);

        expectGesture("external F9 isolated", MbackKeyPolicy.GESTURE_NONE,
                "USB Keyboard", 139, 158);
        expectGesture("gpio wrong scan isolated", MbackKeyPolicy.GESTURE_NONE,
                "gpio-keys", 3, 103);
        expectGesture("gpio wrong key isolated", MbackKeyPolicy.GESTURE_NONE,
                "gpio-keys", 4, 102);
        expectGesture("raw mismatched scan isolated", MbackKeyPolicy.GESTURE_NONE,
                "fpc1020", 3, 157);

        for (int gesture = MbackKeyPolicy.GESTURE_TAP;
                gesture <= MbackKeyPolicy.GESTURE_PHYSICAL_HOME; gesture++) {
            expect(MbackKeyPolicy.shouldConsume(gesture),
                    "recognized gesture must always be consumed " + gesture);
            expect(!MbackKeyPolicy.shouldExecute(gesture, false),
                    "disabled mBack must consume without executing gesture " + gesture);
            expect(MbackKeyPolicy.shouldExecute(gesture, true),
                    "enabled mBack must execute recognized gesture " + gesture);
        }
        expect(!MbackKeyPolicy.shouldExecute(MbackKeyPolicy.GESTURE_NONE, true),
                "unrecognized keys must never execute");
        expect(!MbackKeyPolicy.shouldConsume(MbackKeyPolicy.GESTURE_NONE),
                "unrecognized keys must not be consumed");
        System.out.println("MbackKeyPolicyTest passed");
    }
}
