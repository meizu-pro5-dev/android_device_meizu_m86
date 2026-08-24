/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.mback;

import android.app.ActionBar;
import android.os.Bundle;
import android.os.UserHandle;
import android.preference.ListPreference;
import android.preference.Preference;
import android.preference.PreferenceFragment;
import android.preference.SwitchPreference;

import org.lineageos.settings.m86.R;

public final class MbackSettingsFragment extends PreferenceFragment
        implements Preference.OnPreferenceChangeListener {
    private static final String PREF_NAVIGATION = "mback_navigation";
    private static final String PREF_TAP = "mback_tap";
    private static final String PREF_SOUND = "mback_sound";
    private static final String PREF_HAPTIC = "mback_haptic";

    private int mUserId;
    private SwitchPreference mNavigation;
    private ListPreference mTap;
    private SwitchPreference mSound;
    private ListPreference mHaptic;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mUserId = UserHandle.myUserId();
        MbackContract.migrateIfNeeded(getActivity(), mUserId);
        addPreferencesFromResource(R.xml.mback_settings);

        final ActionBar actionBar = getActivity().getActionBar();
        if (actionBar != null) {
            actionBar.setDisplayHomeAsUpEnabled(true);
        }

        mNavigation = bindSwitch(PREF_NAVIGATION);
        mTap = bindList(PREF_TAP);
        mSound = bindSwitch(PREF_SOUND);
        mHaptic = bindList(PREF_HAPTIC);
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshState();
    }

    @Override
    public boolean onPreferenceChange(Preference preference, Object newValue) {
        if (preference == mNavigation) {
            return MbackContract.setMbackNavigationEnabled(getActivity().getContentResolver(),
                    (Boolean) newValue, mUserId);
        }
        if (preference == mSound) {
            return MbackContract.putSecureInt(getActivity().getContentResolver(),
                    MbackContract.SECURE_SOUND_ENABLED, (Boolean) newValue ? 1 : 0, mUserId);
        }

        final int value;
        try {
            value = Integer.parseInt((String) newValue);
        } catch (NumberFormatException e) {
            return false;
        }
        if (preference == mTap) {
            return putAction(mTap, MbackContract.SECURE_TAP_ACTION, value);
        } else if (preference == mHaptic) {
            return putAction(mHaptic, MbackContract.SECURE_HAPTIC_DURATION, value);
        }
        return false;
    }

    private SwitchPreference bindSwitch(String key) {
        final SwitchPreference preference = (SwitchPreference) findPreference(key);
        preference.setOnPreferenceChangeListener(this);
        return preference;
    }

    private ListPreference bindList(String key) {
        final ListPreference preference = (ListPreference) findPreference(key);
        preference.setOnPreferenceChangeListener(this);
        return preference;
    }

    private boolean putAction(ListPreference preference, String secureKey, int value) {
        if (!MbackContract.putSecureInt(getActivity().getContentResolver(), secureKey,
                value, mUserId)) {
            return false;
        }
        updateSummary(preference, Integer.toString(value));
        return true;
    }

    private void refreshState() {
        mNavigation.setChecked(MbackContract.isMbackNavigationEnabled(
                getActivity().getContentResolver(), mUserId));
        setListValue(mTap, MbackContract.SECURE_TAP_ACTION, MbackContract.ACTION_BACK);
        mSound.setChecked(MbackContract.getSecureInt(getActivity().getContentResolver(),
                MbackContract.SECURE_SOUND_ENABLED, 0, mUserId) != 0);
        setListValue(mHaptic, MbackContract.SECURE_HAPTIC_DURATION, 20);
    }

    private void setListValue(ListPreference preference, String secureKey, int fallback) {
        final String value = Integer.toString(MbackContract.getSecureInt(
                getActivity().getContentResolver(), secureKey, fallback, mUserId));
        preference.setValue(value);
        updateSummary(preference, value);
    }

    private static void updateSummary(ListPreference preference, String value) {
        final int index = preference.findIndexOfValue(value);
        if (index >= 0) {
            preference.setSummary(preference.getEntries()[index]);
        }
    }
}
