package com.rasputin.accessibilitycopyhelper;

import android.accessibilityservice.AccessibilityButtonController;
import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

/**
 * Private manual accessibility helper.
 *
 * Important behavior:
 * - no default action
 * - no automatic paste/copy/select on focus
 * - no clipboard reading
 * - no internet permission
 * - menu opens only when the accessibility shortcut/button calls this service
 */
public class ManualTextAccessibilityService extends AccessibilityService {
    private WindowManager windowManager;
    private View menuView;
    private AccessibilityButtonController.AccessibilityButtonCallback accessibilityButtonCallback;

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        requestAccessibilityShortcutButton();
        StrictLogger.logLine("Accessibility service connected. Waiting for manual shortcut activation.");
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // Intentionally no-op.
        // The service must not act merely because a text field receives focus.
        // Do not log event text or inspect message content here.
    }

    @Override
    public void onInterrupt() {
        StrictLogger.logLine("WARNING", "Accessibility service interrupted");
        hideMenu();
    }

    @Override
    public void onDestroy() {
        StrictLogger.logLine("Accessibility service destroyed");
        unregisterAccessibilityShortcutButton();
        hideMenu();
        super.onDestroy();
    }

    private void requestAccessibilityShortcutButton() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            StrictLogger.logLine("WARNING", "Accessibility shortcut button requires Android 8.0 / API 26 or newer");
            return;
        }

        try {
            AccessibilityServiceInfo currentInfo = getServiceInfo();
            if (currentInfo != null) {
                currentInfo.flags |= AccessibilityServiceInfo.FLAG_REQUEST_ACCESSIBILITY_BUTTON;
                setServiceInfo(currentInfo);
            }

            AccessibilityButtonController controller = getAccessibilityButtonController();
            if (controller == null) {
                StrictLogger.logLine("WARNING", "Accessibility button controller is unavailable");
                return;
            }

            accessibilityButtonCallback = new AccessibilityButtonController.AccessibilityButtonCallback() {
                @Override
                public void onClicked(AccessibilityButtonController controller) {
                    StrictLogger.logLine("Manual accessibility shortcut clicked");
                    toggleMenu();
                }

                @Override
                public void onAvailabilityChanged(AccessibilityButtonController controller, boolean available) {
                    StrictLogger.logLine(available ? "INFO" : "WARNING", "Accessibility shortcut availability changed: " + available);
                }
            };
            controller.registerAccessibilityButtonCallback(accessibilityButtonCallback);
            StrictLogger.logLine("Accessibility shortcut callback registered");
        } catch (Exception ex) {
            StrictLogger.logLine("ERROR", "Failed to register accessibility shortcut callback", ex);
        }
    }

    private void unregisterAccessibilityShortcutButton() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || accessibilityButtonCallback == null) {
            return;
        }

        try {
            AccessibilityButtonController controller = getAccessibilityButtonController();
            if (controller != null) {
                controller.unregisterAccessibilityButtonCallback(accessibilityButtonCallback);
            }
        } catch (Exception ex) {
            StrictLogger.logLine("ERROR", "Failed to unregister accessibility shortcut callback", ex);
        } finally {
            accessibilityButtonCallback = null;
        }
    }

    private void toggleMenu() {
        if (menuView == null) {
            showMenu();
        } else {
            hideMenu();
        }
    }

    private void showMenu() {
        if (windowManager == null) {
            StrictLogger.logLine("ERROR", "WindowManager is unavailable; cannot show menu");
            showToast("Menu unavailable");
            return;
        }

        try {
            menuView = buildMenuView();
            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
            );
            params.gravity = Gravity.TOP | Gravity.END;
            params.x = dp(12);
            params.y = dp(120);
            windowManager.addView(menuView, params);
            StrictLogger.logLine("Manual overlay menu shown");
        } catch (Exception ex) {
            StrictLogger.logLine("ERROR", "Failed to show overlay menu", ex);
            menuView = null;
            showToast("Could not show menu");
        }
    }

    private View buildMenuView() {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(10), dp(10), dp(10), dp(10));

        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.argb(238, 250, 250, 250));
        background.setStroke(dp(1), Color.argb(255, 80, 80, 80));
        background.setCornerRadius(dp(10));
        box.setBackground(background);

        TextView title = new TextView(this);
        title.setText("Text actions");
        title.setTextColor(Color.BLACK);
        title.setGravity(Gravity.CENTER_HORIZONTAL);
        title.setPadding(0, 0, 0, dp(6));
        box.addView(title, menuButtonLayoutParams());

        box.addView(menuButton("Select all", this::selectAllFocusedText), menuButtonLayoutParams());
        box.addView(menuButton("Copy", this::copyFocusedSelection), menuButtonLayoutParams());
        box.addView(menuButton("Paste", this::pasteIntoFocusedText), menuButtonLayoutParams());
        box.addView(menuButton("Close", this::hideMenu), menuButtonLayoutParams());

        return box;
    }

    private Button menuButton(String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setOnClickListener(v -> safelyRunManualAction(label, action));
        return button;
    }

    private LinearLayout.LayoutParams menuButtonLayoutParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(dp(160), LinearLayout.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(3), 0, dp(3));
        return params;
    }

    private void safelyRunManualAction(String label, Runnable action) {
        try {
            StrictLogger.logLine("Manual action requested: " + label);
            action.run();
        } catch (Exception ex) {
            StrictLogger.logLine("ERROR", "Manual action failed: " + label, ex);
            showToast("Action failed: " + label);
        }
    }

    private void selectAllFocusedText() {
        AccessibilityNodeInfo node = findFocusedEditableNode();
        if (node == null) {
            showToast("No editable field selected");
            return;
        }

        try {
            CharSequence text = node.getText();
            int length = text == null ? 0 : text.length();
            Bundle args = new Bundle();
            args.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, 0);
            args.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, length);
            boolean ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, args);
            showToast(ok ? "Selected all" : "Select all blocked");
            StrictLogger.logLine(ok ? "INFO" : "WARNING", "Select all result: " + ok);
        } finally {
            node.recycle();
        }
    }

    private void copyFocusedSelection() {
        AccessibilityNodeInfo node = findFocusedEditableNode();
        if (node == null) {
            showToast("No editable field selected");
            return;
        }

        try {
            boolean ok = node.performAction(AccessibilityNodeInfo.ACTION_COPY);
            showToast(ok ? "Copied" : "Copy blocked or no selection");
            StrictLogger.logLine(ok ? "INFO" : "WARNING", "Copy result: " + ok);
        } finally {
            node.recycle();
        }
    }

    private void pasteIntoFocusedText() {
        AccessibilityNodeInfo node = findFocusedEditableNode();
        if (node == null) {
            showToast("No editable field selected");
            return;
        }

        try {
            boolean ok = node.performAction(AccessibilityNodeInfo.ACTION_PASTE);
            showToast(ok ? "Pasted" : "Paste blocked or clipboard empty");
            StrictLogger.logLine(ok ? "INFO" : "WARNING", "Paste result: " + ok);
            if (ok) {
                hideMenu();
            }
        } finally {
            node.recycle();
        }
    }

    private AccessibilityNodeInfo findFocusedEditableNode() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            StrictLogger.logLine("WARNING", "No active window root available");
            return null;
        }

        AccessibilityNodeInfo inputFocus = null;
        AccessibilityNodeInfo accessibilityFocus = null;
        try {
            inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if (isUsableEditableNode(inputFocus)) {
                return AccessibilityNodeInfo.obtain(inputFocus);
            }

            accessibilityFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY);
            if (isUsableEditableNode(accessibilityFocus)) {
                return AccessibilityNodeInfo.obtain(accessibilityFocus);
            }

            return findEditableFocusedNodeDepthFirst(root);
        } finally {
            if (inputFocus != null) {
                inputFocus.recycle();
            }
            if (accessibilityFocus != null) {
                accessibilityFocus.recycle();
            }
            root.recycle();
        }
    }

    private AccessibilityNodeInfo findEditableFocusedNodeDepthFirst(AccessibilityNodeInfo node) {
        if (node == null) {
            return null;
        }
        if (isUsableEditableNode(node)) {
            return AccessibilityNodeInfo.obtain(node);
        }

        int childCount = node.getChildCount();
        for (int index = 0; index < childCount; index++) {
            AccessibilityNodeInfo child = node.getChild(index);
            if (child == null) {
                continue;
            }
            try {
                AccessibilityNodeInfo result = findEditableFocusedNodeDepthFirst(child);
                if (result != null) {
                    return result;
                }
            } finally {
                child.recycle();
            }
        }
        return null;
    }

    private boolean isUsableEditableNode(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }

        if (!node.isEditable()) {
            return false;
        }

        if (!node.isFocused() && !node.isAccessibilityFocused()) {
            return false;
        }

        List<AccessibilityNodeInfo.AccessibilityAction> actions = node.getActionList();
        return containsAction(actions, AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_SELECTION)
                || containsAction(actions, AccessibilityNodeInfo.AccessibilityAction.ACTION_COPY)
                || containsAction(actions, AccessibilityNodeInfo.AccessibilityAction.ACTION_PASTE);
    }

    private boolean containsAction(List<AccessibilityNodeInfo.AccessibilityAction> actions,
                                   AccessibilityNodeInfo.AccessibilityAction expected) {
        if (actions == null || expected == null) {
            return false;
        }
        for (AccessibilityNodeInfo.AccessibilityAction action : actions) {
            if (expected.equals(action)) {
                return true;
            }
        }
        return false;
    }

    private void hideMenu() {
        if (menuView == null || windowManager == null) {
            menuView = null;
            return;
        }

        try {
            windowManager.removeView(menuView);
            StrictLogger.logLine("Manual overlay menu hidden");
        } catch (Exception ex) {
            StrictLogger.logLine("ERROR", "Failed to hide overlay menu", ex);
        } finally {
            menuView = null;
        }
    }

    private void showToast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
