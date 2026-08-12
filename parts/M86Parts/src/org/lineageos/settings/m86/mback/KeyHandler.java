/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.mback;

import android.app.ActivityManager;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.hardware.input.InputManager;
import android.media.AudioManager;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.os.UserHandle;
import android.os.Vibrator;
import android.provider.MediaStore;
import android.util.Slog;
import android.view.InputDevice;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import android.view.SoundEffectConstants;

import com.android.internal.os.DeviceKeyHandler;
import org.lineageos.internal.util.ActionUtils;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

public final class KeyHandler implements DeviceKeyHandler {
    private static final String TAG = "M86MbackKeyHandler";

    private final Context mContext;
    private final Handler mHandler;
    private final PowerManager mPowerManager;
    private final AudioManager mAudioManager;
    private final Vibrator mVibrator;

    public KeyHandler(Context context) {
        mContext = context;
        mHandler = new Handler(Looper.getMainLooper());
        mPowerManager = context.getSystemService(PowerManager.class);
        mAudioManager = context.getSystemService(AudioManager.class);
        mVibrator = context.getSystemService(Vibrator.class);
        Slog.d(TAG, "initialized");
    }

    @Override
    public KeyEvent handleKeyEvent(KeyEvent event) {
        final int gesture = identifyGesture(event);
        if (!MbackKeyPolicy.shouldConsume(gesture)) {
            return event;
        }

        // A physical HOME is still a normal framework HOME key while mBack
        // navigation is enabled.  Passing it through here is required for
        // Lineage's Home long-press/double-tap settings to be honored.  When
        // mBack is disabled, consume both halves so the mechanical key does
        // not unexpectedly reveal a navigation-bar HOME action.
        if (gesture == MbackKeyPolicy.GESTURE_PHYSICAL_HOME) {
            final int userId = ActivityManager.getCurrentUser();
            MbackContract.migrateIfNeeded(mContext, userId);
            final boolean enabled = MbackContract.isMbackNavigationEnabled(
                    mContext.getContentResolver(), userId);
            Slog.d(TAG, "physical HOME enabled=" + enabled + " action=" + event.getAction());
            return enabled ? event : null;
        }

        Slog.d(TAG, "recognized gesture=" + gesture + " action=" + event.getAction()
                + " keyCode=" + event.getKeyCode() + " scanCode=" + event.getScanCode()
                + " device=" + event.getDeviceId());

        if (event.getAction() == KeyEvent.ACTION_UP && !event.isCanceled()
                && event.getRepeatCount() == 0) {
            mHandler.post(() -> performGesture(gesture, event.getDeviceId()));
        }

        // Consume both halves even when mBack is disabled. This prevents raw
        // FPC gestures from falling through to unrelated framework actions.
        return null;
    }

    private static int identifyGesture(KeyEvent event) {
        final InputDevice device = event.getDevice();
        if (device == null) {
            return MbackKeyPolicy.GESTURE_NONE;
        }
        return MbackKeyPolicy.identifyGesture(device.getName(), event.getKeyCode(),
                event.getScanCode());
    }

    private void performGesture(int gesture, int deviceId) {
        final int userId = ActivityManager.getCurrentUser();
        MbackContract.migrateIfNeeded(mContext, userId);
        final boolean enabled = MbackContract.isMbackNavigationEnabled(
                mContext.getContentResolver(), userId);
        Slog.d(TAG, "gesture=" + gesture + " enabled=" + enabled + " user=" + userId);
        if (!MbackKeyPolicy.shouldExecute(gesture, enabled)) {
            return;
        }

        final String setting;
        final int fallback;
        switch (gesture) {
            case MbackKeyPolicy.GESTURE_TAP:
                setting = MbackContract.SECURE_TAP_ACTION;
                fallback = MbackContract.ACTION_BACK;
                break;
            case MbackKeyPolicy.GESTURE_DOUBLE_TAP:
                setting = MbackContract.SECURE_DOUBLE_TAP_ACTION;
                fallback = MbackContract.ACTION_NOTHING;
                break;
            case MbackKeyPolicy.GESTURE_SWIPE_LEFT:
                setting = MbackContract.SECURE_SWIPE_LEFT_ACTION;
                fallback = MbackContract.ACTION_HOME;
                break;
            case MbackKeyPolicy.GESTURE_SWIPE_RIGHT:
                setting = MbackContract.SECURE_SWIPE_RIGHT_ACTION;
                fallback = MbackContract.ACTION_RECENTS;
                break;
            default:
                return;
        }

        final int action = MbackContract.getSecureInt(mContext.getContentResolver(),
                setting, fallback, userId);
        Slog.d(TAG, "gesture=" + gesture + " actionId=" + action + " setting=" + setting);
        performAction(action, deviceId, userId);
        performFeedback(userId);
    }

    private void performAction(int action, int deviceId, int userId) {
        switch (action) {
            case MbackContract.ACTION_NOTHING:
                break;
            case MbackContract.ACTION_MENU:
                injectKey(KeyEvent.KEYCODE_MENU);
                break;
            case MbackContract.ACTION_RECENTS:
                // Invoke the policy's local StatusBar service directly.  An
                // injected APP_SWITCH key can be consumed as a hardware-key
                // customization before it reaches SystemUI, making the
                // default right-swipe action appear dead.
                if (!toggleRecentApps()) {
                    injectKey(KeyEvent.KEYCODE_APP_SWITCH);
                }
                break;
            case MbackContract.ACTION_ASSIST:
                startActivity(new Intent(Intent.ACTION_ASSIST), userId);
                break;
            case MbackContract.ACTION_VOICE_ASSIST:
                startActivity(new Intent(Intent.ACTION_VOICE_ASSIST), userId);
                break;
            case MbackContract.ACTION_IN_APP_SEARCH:
                injectKey(KeyEvent.KEYCODE_SEARCH);
                break;
            case MbackContract.ACTION_CAMERA:
                startActivity(new Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA), userId);
                break;
            case MbackContract.ACTION_SLEEP:
                if (mPowerManager != null) {
                    mPowerManager.goToSleep(SystemClock.uptimeMillis());
                }
                break;
            case MbackContract.ACTION_LAST_APP:
                ActionUtils.switchToLastApp(mContext, userId);
                break;
            case MbackContract.ACTION_SPLIT_SCREEN:
                toggleSplitScreen();
                break;
            case MbackContract.ACTION_HOME:
                injectKey(KeyEvent.KEYCODE_HOME);
                break;
            case MbackContract.ACTION_BACK:
                injectKey(KeyEvent.KEYCODE_BACK);
                break;
            default:
                Slog.w(TAG, "Ignoring invalid mBack action " + action
                        + " from device " + deviceId);
                break;
        }
    }

    private void injectKey(int keyCode) {
        final long now = SystemClock.uptimeMillis();
        final KeyEvent down = new KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode,
                0, 0, KeyCharacterMap.VIRTUAL_KEYBOARD, 0,
                KeyEvent.FLAG_FROM_SYSTEM, InputDevice.SOURCE_KEYBOARD);
        final KeyEvent up = KeyEvent.changeAction(down, KeyEvent.ACTION_UP);
        final InputManager inputManager = InputManager.getInstance();
        inputManager.injectInputEvent(down, InputManager.INJECT_INPUT_EVENT_MODE_ASYNC);
        inputManager.injectInputEvent(up, InputManager.INJECT_INPUT_EVENT_MODE_ASYNC);
    }

    private void startActivity(Intent intent, int userId) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            mContext.startActivityAsUser(intent, UserHandle.of(userId));
        } catch (ActivityNotFoundException | SecurityException e) {
            Slog.w(TAG, "Unable to handle mBack activity action " + intent, e);
        }
    }

    private void toggleSplitScreen() {
        try {
            // DeviceKeyHandler is instantiated by PhoneWindowManager inside
            // system_server. Use its existing local StatusBar extension
            // without adding an m86 method to frameworks/base.
            final Class<?> localServices = Class.forName("com.android.server.LocalServices");
            final Class<?> statusBarClass = Class.forName(
                    "com.android.server.statusbar.StatusBarManagerInternal");
            final Method getService = localServices.getMethod("getService", Class.class);
            final Object statusBar = getService.invoke(null, statusBarClass);
            if (statusBar != null) {
                statusBarClass.getMethod("toggleSplitScreen").invoke(statusBar);
            }
        } catch (ClassNotFoundException | IllegalAccessException | NoSuchMethodException
                | InvocationTargetException e) {
            Slog.w(TAG, "Unable to toggle split screen", e);
        }
    }

    private boolean toggleRecentApps() {
        try {
            final Class<?> localServices = Class.forName("com.android.server.LocalServices");
            final Class<?> statusBarClass = Class.forName(
                    "com.android.server.statusbar.StatusBarManagerInternal");
            final Method getService = localServices.getMethod("getService", Class.class);
            final Object statusBar = getService.invoke(null, statusBarClass);
            if (statusBar != null) {
                statusBarClass.getMethod("toggleRecentApps").invoke(statusBar);
                return true;
            }
        } catch (ClassNotFoundException | IllegalAccessException | NoSuchMethodException
                | InvocationTargetException e) {
            Slog.w(TAG, "Unable to toggle recent apps", e);
        }
        return false;
    }

    private void performFeedback(int userId) {
        if (MbackContract.getSecureInt(mContext.getContentResolver(),
                MbackContract.SECURE_SOUND_ENABLED, 0, userId) != 0
                && mAudioManager != null) {
            mAudioManager.playSoundEffect(SoundEffectConstants.CLICK);
        }
        final int duration = MbackContract.getSecureInt(mContext.getContentResolver(),
                MbackContract.SECURE_HAPTIC_DURATION, 20, userId);
        if (duration > 0 && duration <= 100 && mVibrator != null && mVibrator.hasVibrator()) {
            mVibrator.vibrate(duration);
        }
    }
}
