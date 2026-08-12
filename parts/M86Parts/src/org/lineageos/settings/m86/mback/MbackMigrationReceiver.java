/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.mback;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.UserHandle;

import org.lineageos.settings.m86.hifi.HifiPolicy;

public final class MbackMigrationReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            MbackContract.migrateIfNeeded(context, UserHandle.myUserId());
            HifiPolicy.sync(context);
        }
    }
}
