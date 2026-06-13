package com.rasputin.accessibilitycopyhelper;

import android.accessibilityservice.AccessibilityButtonController;
import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
        box.addView(menuButton("Start selection", this::startManualSelection), menuButtonLayoutParams());
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
        AccessibilityNodeInfo node = findFocusedSelectableNode();
        if (node == null) {
            showToast("No selectable text found");
            return;
        }

        try {
            boolean ok = trySetSelectionRange(node, 0, getNodeTextLength(node));
            if (ok) {
                showToast("Selected all");
                StrictLogger.logLine("INFO", "Select all result: true");
                return;
            }

            boolean longClickOk = tryOpenSelectionHandles(node);
            if (longClickOk) {
                showToast("Selection menu opened");
                StrictLogger.logLine("WARNING", "Select all direct action blocked; opened selection menu fallback");
                clickSelectAllMenuItemDelayed();
                return;
            }

            showToast("Select all blocked");
            StrictLogger.logLine("WARNING", "Select all result: false");
        } finally {
            node.recycle();
        }
    }

    private void startManualSelection() {
        AccessibilityNodeInfo node = findFocusedSelectableNode();
        if (node == null) {
            showToast("No selectable text found");
            return;
        }

        try {
            boolean ok = tryOpenSelectionHandles(node);
            if (!ok) {
                ok = tryExtendSelectionByWord(node);
            }
            showToast(ok ? "Selection started" : "Selection blocked");
            StrictLogger.logLine(ok ? "INFO" : "WARNING", "Start selection result: " + ok);
        } finally {
            node.recycle();
        }
    }

    private void copyFocusedSelection() {
        AccessibilityNodeInfo node = findFocusedCopyNode();
        if (node == null) {
            showToast("No selected text found");
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
        if (node != null) {
            try {
                boolean ok = node.performAction(AccessibilityNodeInfo.ACTION_PASTE);
                if (ok) {
                    showToast("Pasted");
                    StrictLogger.logLine("INFO", "Paste result through focused editable node: true");
                    hideMenu();
                    return;
                }
                StrictLogger.logLine("WARNING", "Focused editable paste action was blocked; trying broader paste fallback");
            } finally {
                node.recycle();
            }
        } else {
            StrictLogger.logLine("WARNING", "No strict editable paste target found; trying broader paste fallback");
        }

        AccessibilityNodeInfo fallbackNode = findFocusedPasteNode();
        if (fallbackNode == null) {
            showToast("Paste blocked by target app");
            StrictLogger.logLine("WARNING", "Paste fallback failed: no focused paste-capable or long-click-capable node found");
            return;
        }

        try {
            boolean ok = fallbackNode.performAction(AccessibilityNodeInfo.ACTION_PASTE);
            if (ok) {
                showToast("Pasted");
                StrictLogger.logLine("INFO", "Paste result through broader focused node: true");
                hideMenu();
                return;
            }

            boolean menuOpened = tryOpenSelectionHandles(fallbackNode);
            if (menuOpened) {
                showToast("Paste menu opened");
                StrictLogger.logLine("WARNING", "Direct paste blocked; opened long-click paste menu fallback");
                clickPasteMenuItemDelayed();
                return;
            }

            showToast("Paste blocked by target app");
            StrictLogger.logLine("WARNING", "Paste result: false after strict and broader fallback attempts");
        } finally {
            fallbackNode.recycle();
        }
    }

    private boolean trySetSelectionRange(AccessibilityNodeInfo node, int start, int end) {
        if (node == null) {
            return false;
        }
        if (!supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_SELECTION)) {
            return false;
        }

        Bundle args = new Bundle();
        args.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, Math.max(0, start));
        args.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, Math.max(0, end));
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, args);
    }

    private boolean tryOpenSelectionHandles(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }
        if (!supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)) {
            return false;
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK);
    }

    private boolean tryExtendSelectionByWord(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }
        if (!supportsActionId(node, AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY)) {
            return false;
        }

        Bundle args = new Bundle();
        args.putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                AccessibilityNodeInfo.MOVEMENT_GRANULARITY_WORD
        );
        args.putBoolean(AccessibilityNodeInfo.ACTION_ARGUMENT_EXTEND_SELECTION_BOOLEAN, true);
        return node.performAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY, args);
    }

    private int getNodeTextLength(AccessibilityNodeInfo node) {
        if (node == null || node.getText() == null) {
            return 0;
        }
        return node.getText().length();
    }

    private void clickSelectAllMenuItemDelayed() {
        Handler handler = new Handler(Looper.getMainLooper());
        handler.postDelayed(() -> {
            try {
                boolean ok = clickFirstVisibleNodeByText("Select all")
                        || clickFirstVisibleNodeByText("Select all text")
                        || clickFirstVisibleNodeByText("בחר הכל");
                StrictLogger.logLine(ok ? "INFO" : "WARNING", "Delayed Select all menu click result: " + ok);
                if (ok) {
                    showToast("Select all requested");
                }
            } catch (Exception ex) {
                StrictLogger.logLine("ERROR", "Delayed Select all menu click failed", ex);
            }
        }, 350L);
    }

    private void clickPasteMenuItemDelayed() {
        Handler handler = new Handler(Looper.getMainLooper());
        handler.postDelayed(() -> {
            try {
                boolean ok = clickFirstVisibleNodeByText("Paste")
                        || clickFirstVisibleNodeByText("Paste as plain text")
                        || clickFirstVisibleNodeByText("הדבק")
                        || clickFirstVisibleNodeByText("הדבק כטקסט רגיל");
                StrictLogger.logLine(ok ? "INFO" : "WARNING", "Delayed Paste menu click result: " + ok);
                if (ok) {
                    showToast("Paste requested");
                    hideMenu();
                } else {
                    showToast("Paste blocked by target app");
                }
            } catch (Exception ex) {
                StrictLogger.logLine("ERROR", "Delayed Paste menu click failed", ex);
                showToast("Paste failed");
            }
        }, 350L);
    }

    private boolean clickFirstVisibleNodeByText(String text) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            StrictLogger.logLine("WARNING", "No active window root available while looking for menu text: " + text);
            return false;
        }

        try {
            List<AccessibilityNodeInfo> matches = root.findAccessibilityNodeInfosByText(text);
            if (matches == null) {
                return false;
            }

            for (AccessibilityNodeInfo match : matches) {
                if (match == null) {
                    continue;
                }
                try {
                    AccessibilityNodeInfo clickableNode = findClickableAncestorOrSelf(match);
                    if (clickableNode == null) {
                        continue;
                    }
                    try {
                        if (clickableNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                            return true;
                        }
                    } finally {
                        clickableNode.recycle();
                    }
                } finally {
                    match.recycle();
                }
            }
            return false;
        } finally {
            root.recycle();
        }
    }

    private AccessibilityNodeInfo findClickableAncestorOrSelf(AccessibilityNodeInfo node) {
        AccessibilityNodeInfo current = AccessibilityNodeInfo.obtain(node);
        while (current != null) {
            if (supportsActionId(current, AccessibilityNodeInfo.ACTION_CLICK) || current.isClickable()) {
                return current;
            }

            AccessibilityNodeInfo parent = current.getParent();
            current.recycle();
            current = parent;
        }
        return null;
    }

    private AccessibilityNodeInfo findFocusedSelectableNode() {
        return findFocusedNodeMatchingMode(SearchMode.SELECTABLE_TEXT);
    }

    private AccessibilityNodeInfo findFocusedCopyNode() {
        AccessibilityNodeInfo node = findFocusedNodeMatchingMode(SearchMode.COPY_TARGET);
        if (node != null) {
            return node;
        }
        return findFocusedEditableNode();
    }

    private AccessibilityNodeInfo findFocusedPasteNode() {
        AccessibilityNodeInfo node = findFocusedNodeMatchingMode(SearchMode.PASTE_TARGET);
        if (node != null) {
            return node;
        }
        return findFocusedEditableNode();
    }

    private AccessibilityNodeInfo findFocusedNodeMatchingMode(SearchMode mode) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            StrictLogger.logLine("WARNING", "No active window root available");
            return null;
        }

        AccessibilityNodeInfo inputFocus = null;
        AccessibilityNodeInfo accessibilityFocus = null;
        try {
            inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if (isUsableNodeForMode(inputFocus, mode)) {
                return AccessibilityNodeInfo.obtain(inputFocus);
            }

            accessibilityFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY);
            if (isUsableNodeForMode(accessibilityFocus, mode)) {
                return AccessibilityNodeInfo.obtain(accessibilityFocus);
            }

            return findFocusedNodeByModeDepthFirst(root, mode);
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

    private AccessibilityNodeInfo findFocusedNodeByModeDepthFirst(AccessibilityNodeInfo node, SearchMode mode) {
        if (node == null) {
            return null;
        }
        if (isUsableNodeForMode(node, mode)) {
            return AccessibilityNodeInfo.obtain(node);
        }

        int childCount = node.getChildCount();
        for (int index = 0; index < childCount; index++) {
            AccessibilityNodeInfo child = node.getChild(index);
            if (child == null) {
                continue;
            }
            try {
                AccessibilityNodeInfo result = findFocusedNodeByModeDepthFirst(child, mode);
                if (result != null) {
                    return result;
                }
            } finally {
                child.recycle();
            }
        }
        return null;
    }

    private boolean isUsableNodeForMode(AccessibilityNodeInfo node, SearchMode mode) {
        if (node == null || mode == null) {
            return false;
        }
        if (!node.isFocused() && !node.isAccessibilityFocused()) {
            return false;
        }

        switch (mode) {
            case SELECTABLE_TEXT:
                return hasVisibleText(node)
                        && (supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_SELECTION)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_COPY)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY));
            case COPY_TARGET:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_COPY);
            case PASTE_TARGET:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_PASTE)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || node.isEditable();
            default:
                return false;
        }
    }

    private boolean hasVisibleText(AccessibilityNodeInfo node) {
        return node != null && node.getText() != null && node.getText().length() > 0;
    }

    private boolean supportsActionId(AccessibilityNodeInfo node, int actionId) {
        if (node == null) {
            return false;
        }

        List<AccessibilityNodeInfo.AccessibilityAction> actions = node.getActionList();
        if (actions == null) {
            return false;
        }
        for (AccessibilityNodeInfo.AccessibilityAction action : actions) {
            if (action != null && action.getId() == actionId) {
                return true;
            }
        }
        return false;
    }

    private enum SearchMode {
        SELECTABLE_TEXT,
        COPY_TARGET,
        PASTE_TARGET
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
package com.rasputin.accessibilitycopyhelper;

import android.accessibilityservice.AccessibilityButtonController;
import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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
        box.addView(menuButton("Start selection", this::startManualSelection), menuButtonLayoutParams());
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
        AccessibilityNodeInfo node = findFocusedSelectableNode();
        if (node == null) {
            showToast("No selectable text found");
            return;
        }

        try {
            boolean ok = trySetSelectionRange(node, 0, getNodeTextLength(node));
            if (ok) {
                showToast("Selected all");
                StrictLogger.logLine("INFO", "Select all result: true");
                return;
            }

            boolean longClickOk = tryOpenSelectionHandles(node);
            if (longClickOk) {
                showToast("Selection menu opened");
                StrictLogger.logLine("WARNING", "Select all direct action blocked; opened selection menu fallback");
                clickSelectAllMenuItemDelayed();
                return;
            }

            showToast("Select all blocked");
            StrictLogger.logLine("WARNING", "Select all result: false");
        } finally {
            node.recycle();
        }
    }

    private void startManualSelection() {
        AccessibilityNodeInfo node = findFocusedSelectableNode();
        if (node == null) {
            showToast("No selectable text found");
            return;
        }

        try {
            boolean ok = tryOpenSelectionHandles(node);
            if (!ok) {
                ok = tryExtendSelectionByWord(node);
            }
            showToast(ok ? "Selection started" : "Selection blocked");
            StrictLogger.logLine(ok ? "INFO" : "WARNING", "Start selection result: " + ok);
        } finally {
            node.recycle();
        }
    }

    private void copyFocusedSelection() {
        AccessibilityNodeInfo node = findFocusedCopyNode();
        if (node == null) {
            showToast("No selected text found");
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

    private boolean trySetSelectionRange(AccessibilityNodeInfo node, int start, int end) {
        if (node == null) {
            return false;
        }
        if (!supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_SELECTION)) {
            return false;
        }

        Bundle args = new Bundle();
        args.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, Math.max(0, start));
        args.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, Math.max(0, end));
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, args);
    }

    private boolean tryOpenSelectionHandles(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }
        if (!supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)) {
            return false;
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK);
    }

    private boolean tryExtendSelectionByWord(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }
        if (!supportsActionId(node, AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY)) {
            return false;
        }

        Bundle args = new Bundle();
        args.putInt(
                AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                AccessibilityNodeInfo.MOVEMENT_GRANULARITY_WORD
        );
        args.putBoolean(AccessibilityNodeInfo.ACTION_ARGUMENT_EXTEND_SELECTION_BOOLEAN, true);
        return node.performAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY, args);
    }

    private int getNodeTextLength(AccessibilityNodeInfo node) {
        if (node == null || node.getText() == null) {
            return 0;
        }
        return node.getText().length();
    }

    private void clickSelectAllMenuItemDelayed() {
        Handler handler = new Handler(Looper.getMainLooper());
        handler.postDelayed(() -> {
            try {
                boolean ok = clickFirstVisibleNodeByText("Select all")
                        || clickFirstVisibleNodeByText("Select all text")
                        || clickFirstVisibleNodeByText("בחר הכל");
                StrictLogger.logLine(ok ? "INFO" : "WARNING", "Delayed Select all menu click result: " + ok);
                if (ok) {
                    showToast("Select all requested");
                }
            } catch (Exception ex) {
                StrictLogger.logLine("ERROR", "Delayed Select all menu click failed", ex);
            }
        }, 350L);
    }

    private boolean clickFirstVisibleNodeByText(String text) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            StrictLogger.logLine("WARNING", "No active window root available while looking for menu text: " + text);
            return false;
        }

        try {
            List<AccessibilityNodeInfo> matches = root.findAccessibilityNodeInfosByText(text);
            if (matches == null) {
                return false;
            }

            for (AccessibilityNodeInfo match : matches) {
                if (match == null) {
                    continue;
                }
                try {
                    AccessibilityNodeInfo clickableNode = findClickableAncestorOrSelf(match);
                    if (clickableNode == null) {
                        continue;
                    }
                    try {
                        if (clickableNode.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                            return true;
                        }
                    } finally {
                        clickableNode.recycle();
                    }
                } finally {
                    match.recycle();
                }
            }
            return false;
        } finally {
            root.recycle();
        }
    }

    private AccessibilityNodeInfo findClickableAncestorOrSelf(AccessibilityNodeInfo node) {
        AccessibilityNodeInfo current = AccessibilityNodeInfo.obtain(node);
        while (current != null) {
            if (supportsActionId(current, AccessibilityNodeInfo.ACTION_CLICK) || current.isClickable()) {
                return current;
            }

            AccessibilityNodeInfo parent = current.getParent();
            current.recycle();
            current = parent;
        }
        return null;
    }

    private AccessibilityNodeInfo findFocusedSelectableNode() {
        return findFocusedNodeMatchingMode(SearchMode.SELECTABLE_TEXT);
    }

    private AccessibilityNodeInfo findFocusedCopyNode() {
        AccessibilityNodeInfo node = findFocusedNodeMatchingMode(SearchMode.COPY_TARGET);
        if (node != null) {
            return node;
        }
        return findFocusedEditableNode();
    }

    private AccessibilityNodeInfo findFocusedNodeMatchingMode(SearchMode mode) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            StrictLogger.logLine("WARNING", "No active window root available");
            return null;
        }

        AccessibilityNodeInfo inputFocus = null;
        AccessibilityNodeInfo accessibilityFocus = null;
        try {
            inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if (isUsableNodeForMode(inputFocus, mode)) {
                return AccessibilityNodeInfo.obtain(inputFocus);
            }

            accessibilityFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY);
            if (isUsableNodeForMode(accessibilityFocus, mode)) {
                return AccessibilityNodeInfo.obtain(accessibilityFocus);
            }

            return findFocusedNodeByModeDepthFirst(root, mode);
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

    private AccessibilityNodeInfo findFocusedNodeByModeDepthFirst(AccessibilityNodeInfo node, SearchMode mode) {
        if (node == null) {
            return null;
        }
        if (isUsableNodeForMode(node, mode)) {
            return AccessibilityNodeInfo.obtain(node);
        }

        int childCount = node.getChildCount();
        for (int index = 0; index < childCount; index++) {
            AccessibilityNodeInfo child = node.getChild(index);
            if (child == null) {
                continue;
            }
            try {
                AccessibilityNodeInfo result = findFocusedNodeByModeDepthFirst(child, mode);
                if (result != null) {
                    return result;
                }
            } finally {
                child.recycle();
            }
        }
        return null;
    }

    private boolean isUsableNodeForMode(AccessibilityNodeInfo node, SearchMode mode) {
        if (node == null || mode == null) {
            return false;
        }
        if (!node.isFocused() && !node.isAccessibilityFocused()) {
            return false;
        }

        switch (mode) {
            case SELECTABLE_TEXT:
                return hasVisibleText(node)
                        && (supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_SELECTION)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_COPY)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY));
            case COPY_TARGET:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_COPY);
            default:
                return false;
        }
    }

    private boolean hasVisibleText(AccessibilityNodeInfo node) {
        return node != null && node.getText() != null && node.getText().length() > 0;
    }

    private boolean supportsActionId(AccessibilityNodeInfo node, int actionId) {
        if (node == null) {
            return false;
        }

        List<AccessibilityNodeInfo.AccessibilityAction> actions = node.getActionList();
        if (actions == null) {
            return false;
        }
        for (AccessibilityNodeInfo.AccessibilityAction action : actions) {
            if (action != null && action.getId() == actionId) {
                return true;
            }
        }
        return false;
    }

    private enum SearchMode {
        SELECTABLE_TEXT,
        COPY_TARGET
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
