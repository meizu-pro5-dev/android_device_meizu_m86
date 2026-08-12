/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.m86.hifi;

import android.app.AlertDialog;
import android.os.Bundle;
import android.preference.ListPreference;
import android.preference.Preference;
import android.preference.PreferenceFragment;
import android.preference.SwitchPreference;
import org.lineageos.settings.m86.R;

public final class HifiSettingsFragment extends PreferenceFragment
        implements Preference.OnPreferenceChangeListener {
    private static final String PREF_ENABLED = HifiPolicy.ENABLED;
    private static final String PREF_GAIN = HifiPolicy.GAIN;
    private static final int GAIN_AUTO = HifiPolicy.GAIN_AUTO;
    private static final int GAIN_HIGH = HifiPolicy.GAIN_HIGH;
    private static final int GAIN_LINE_OUT = HifiPolicy.GAIN_LINE_OUT;

    private SwitchPreference mEnabled;
    private ListPreference mGain;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        addPreferencesFromResource(R.xml.hifi_settings);
        mEnabled = (SwitchPreference) findPreference(PREF_ENABLED);
        mGain = (ListPreference) findPreference(PREF_GAIN);
        mEnabled.setOnPreferenceChangeListener(this);
        mGain.setOnPreferenceChangeListener(this);
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshState();
    }

    @Override
    public boolean onPreferenceChange(Preference preference, Object newValue) {
        if (preference == mEnabled) {
            final boolean enabled = (Boolean) newValue;
            if (!HifiPolicy.setEnabled(getActivity(), enabled)) {
                return false;
            }
            mGain.setEnabled(enabled);
            return true;
        }
        if (preference == mGain) {
            final int gain;
            try {
                gain = Integer.parseInt((String) newValue);
            } catch (NumberFormatException e) {
                return false;
            }
            if (gain == GAIN_LINE_OUT) {
                new AlertDialog.Builder(getActivity())
                        .setTitle(R.string.hifi_line_out_warning_title)
                        .setMessage(R.string.hifi_line_out_warning_message)
                        .setNegativeButton(android.R.string.cancel, null)
                        .setPositiveButton(android.R.string.ok,
                                (dialog, which) -> applyGain(GAIN_LINE_OUT))
                        .show();
                return false;
            }
            applyGain(gain);
            return true;
        }
        return false;
    }

    private void applyGain(int gain) {
        gain = Math.max(GAIN_AUTO, Math.min(GAIN_LINE_OUT, gain));
        HifiPolicy.setGain(getActivity(), gain);
        mGain.setValue(Integer.toString(gain));
        updateSummary();
    }

    private void refreshState() {
        final boolean enabled = HifiPolicy.isEnabled(getActivity().getContentResolver());
        final int gain = HifiPolicy.getGain(getActivity().getContentResolver());
        mEnabled.setChecked(enabled);
        mGain.setEnabled(enabled);
        mGain.setValue(Integer.toString(gain));
        updateSummary();
    }

    private void updateSummary() {
        if (mGain != null) {
            final int index = mGain.findIndexOfValue(mGain.getValue());
            if (index >= 0) {
                mGain.setSummary(mGain.getEntries()[index]);
            }
        }
    }
}
