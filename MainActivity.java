package com.rasputin.accessibilitycopyhelper;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

/**
 * Launcher activity.
 *
 * Purpose:
 * - explain how to enable the private manual accessibility helper
 * - open Android Accessibility settings
 *
 * This activity does not perform copy, paste, select, or write actions.
 */
public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        StrictLogger.logLine("MainActivity opened");
        setContentView(buildContentView());
    }

    private View buildContentView() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        int padding = dp(20);
        root.setPadding(padding, padding, padding, padding);

        TextView title = new TextView(this);
        title.setText("Manual Copy Paste Helper");
        title.setTextSize(22);
        title.setGravity(Gravity.CENTER_HORIZONTAL);
        root.addView(title, fullWidthWrap());

        TextView body = new TextView(this);
        body.setText(
                "Enable the accessibility service, then attach it to the Android accessibility shortcut.\n\n" +
                "Activation flow:\n" +
                "1. Tap the Android accessibility shortcut / small person icon.\n" +
                "2. A manual menu opens.\n" +
                "3. Choose Select all, Copy, or Paste.\n\n" +
                "No action is performed automatically when a text field receives focus."
        );
        body.setTextSize(16);
        body.setPadding(0, dp(16), 0, dp(16));
        root.addView(body, fullWidthWrap());

        Button settingsButton = new Button(this);
        settingsButton.setText("Open Accessibility Settings");
        settingsButton.setOnClickListener(v -> openAccessibilitySettings());
        root.addView(settingsButton, fullWidthWrap());

        return root;
    }

    private void openAccessibilitySettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            startActivity(intent);
            StrictLogger.logLine("Opened Android Accessibility settings");
        } catch (Exception ex) {
            StrictLogger.logLine("ERROR", "Failed to open Accessibility settings", ex);
            Toast.makeText(this, "Could not open Accessibility settings", Toast.LENGTH_SHORT).show();
        }
    }

    private LinearLayout.LayoutParams fullWidthWrap() {
        return new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        );
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
