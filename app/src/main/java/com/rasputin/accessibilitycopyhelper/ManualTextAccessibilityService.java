package com.rasputin.accessibilitycopyhelper;

import android.accessibilityservice.AccessibilityButtonController;
import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
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
 * - no clipboard background reading
 * - no internet permission
 * - menu opens only when the accessibility shortcut/button calls this service
 */
public class ManualTextAccessibilityService extends AccessibilityService {
    private static final long CONTEXT_MENU_CLICK_DELAY_MS = 350L;

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
        AccessibilityNodeInfo node = findBestNodeForManualAction(TargetMode.SELECT_ALL);
        if (node == null) {
            showToast("No text target found");
            StrictLogger.logLine("WARNING", "Select all target not found");
            return;
        }

        try {
            boolean ok = trySetSelectionRange(node, 0, getNodeTextLength(node));
            if (ok) {
                showToast("Selected all");
                StrictLogger.logLine("INFO", "Select all result: true by ACTION_SET_SELECTION");
                return;
            }

            ok = node.performAction(AccessibilityNodeInfo.ACTION_SELECT);
            if (ok) {
                showToast("Selection requested");
                StrictLogger.logLine("INFO", "Select all fallback result: true by ACTION_SELECT");
                clickSelectAllMenuItemDelayed();
                return;
            }

            ok = tryOpenSelectionHandles(node);
            if (ok) {
                showToast("Selection menu opened");
                StrictLogger.logLine("WARNING", "Select all direct action blocked; opened selection menu fallback");
                clickSelectAllMenuItemDelayed();
                return;
            }

            ok = tryExtendSelectionByWord(node);
            if (ok) {
                showToast("Selection started");
                StrictLogger.logLine("WARNING", "Select all direct action blocked; movement selection fallback started");
                clickSelectAllMenuItemDelayed();
                return;
            }

            showToast("Select all blocked");
            StrictLogger.logLine("WARNING", "Select all result: false after broad fallbacks");
        } finally {
            node.recycle();
        }
    }

    private void startManualSelection() {
        AccessibilityNodeInfo node = findBestNodeForManualAction(TargetMode.START_SELECTION);
        if (node == null) {
            showToast("No text target found");
            StrictLogger.logLine("WARNING", "Start selection target not found");
            return;
        }

        try {
            boolean ok = tryOpenSelectionHandles(node);
            if (!ok) {
                ok = node.performAction(AccessibilityNodeInfo.ACTION_SELECT);
            }
            if (!ok) {
                ok = tryExtendSelectionByWord(node);
            }
            if (!ok && getNodeTextLength(node) > 0) {
                ok = trySetSelectionRange(node, 0, Math.min(1, getNodeTextLength(node)));
            }

            showToast(ok ? "Selection started" : "Selection blocked");
            StrictLogger.logLine(ok ? "INFO" : "WARNING", "Start selection result: " + ok);
        } finally {
            node.recycle();
        }
    }

    private void copyFocusedSelection() {
        AccessibilityNodeInfo node = findBestNodeForManualAction(TargetMode.COPY);
        if (node == null) {
            showToast("No copy target found");
            StrictLogger.logLine("WARNING", "Copy target not found");
            return;
        }

        try {
            boolean ok = node.performAction(AccessibilityNodeInfo.ACTION_COPY);
            if (ok) {
                showToast("Copied");
                StrictLogger.logLine("INFO", "Copy result: true by ACTION_COPY");
                return;
            }

            boolean menuOk = clickFirstVisibleNodeByText("Copy")
                    || clickFirstVisibleNodeByText("Copy text")
                    || clickFirstVisibleNodeByText("העתק");
            if (menuOk) {
                showToast("Copy requested");
                StrictLogger.logLine("INFO", "Copy result: true by visible context menu click");
                return;
            }

            boolean longClickOk = tryOpenSelectionHandles(node);
            if (longClickOk) {
                showToast("Copy menu requested");
                StrictLogger.logLine("WARNING", "Copy direct action blocked; opened selection menu fallback");
                clickCopyMenuItemDelayed();
                return;
            }

            showToast("Copy blocked or no selection");
            StrictLogger.logLine("WARNING", "Copy result: false after broad fallbacks");
        } finally {
            node.recycle();
        }
    }

    private void pasteIntoFocusedText() {
        AccessibilityNodeInfo node = findBestNodeForManualAction(TargetMode.PASTE);
        if (node == null) {
            showToast("No paste target found");
            StrictLogger.logLine("WARNING", "Paste target not found");
            return;
        }

        try {
            boolean ok = node.performAction(AccessibilityNodeInfo.ACTION_PASTE);
            if (ok) {
                showToast("Pasted");
                StrictLogger.logLine("INFO", "Paste result: true by ACTION_PASTE");
                hideMenu();
                return;
            }

            boolean directMenuOk = clickFirstVisibleNodeByText("Paste")
                    || clickFirstVisibleNodeByText("הדבק");
            if (directMenuOk) {
                showToast("Paste requested");
                StrictLogger.logLine("INFO", "Paste result: true by visible context menu click");
                hideMenu();
                return;
            }

            ok = tryManualClipboardSetTextFallback(node);
            if (ok) {
                showToast("Pasted by text fallback");
                StrictLogger.logLine("INFO", "Paste result: true by manual clipboard ACTION_SET_TEXT fallback; clipboard content not logged");
                hideMenu();
                return;
            }

            boolean longClickOk = tryOpenSelectionHandles(node);
            if (longClickOk) {
                showToast("Paste menu requested");
                StrictLogger.logLine("WARNING", "Paste direct action and text fallback blocked; opened context menu fallback");
                clickPasteMenuItemDelayed();
                return;
            }

            showToast("Paste blocked or clipboard empty");
            StrictLogger.logLine("WARNING", "Paste result: false after broad fallbacks");
        } finally {
            node.recycle();
        }
    }

    private boolean trySetSelectionRange(AccessibilityNodeInfo node, int start, int end) {
        if (node == null) {
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
        return node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK);
    }

    private boolean tryExtendSelectionByWord(AccessibilityNodeInfo node) {
        if (node == null) {
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

    private boolean tryManualClipboardSetTextFallback(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }

        CharSequence clipboardText = readClipboardTextOnlyAfterManualPasteTap();
        if (clipboardText == null || clipboardText.length() == 0) {
            StrictLogger.logLine("WARNING", "Manual paste fallback stopped because clipboard text is empty or unavailable");
            return false;
        }

        CharSequence replacementText = buildSetTextFallbackContent(node, clipboardText);
        Bundle args = new Bundle();
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, replacementText);
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args);
    }

    private CharSequence readClipboardTextOnlyAfterManualPasteTap() {
        // This method is called only from pasteIntoFocusedText(), after the user manually taps Paste.
        // It is not background clipboard monitoring and it never logs clipboard content.
        ClipboardManager clipboardManager = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboardManager == null) {
            StrictLogger.logLine("WARNING", "ClipboardManager unavailable during manual paste fallback");
            return null;
        }
        if (!clipboardManager.hasPrimaryClip()) {
            StrictLogger.logLine("WARNING", "No primary clipboard clip during manual paste fallback");
            return null;
        }

        ClipData clipData = clipboardManager.getPrimaryClip();
        if (clipData == null || clipData.getItemCount() < 1 || clipData.getItemAt(0) == null) {
            StrictLogger.logLine("WARNING", "Primary clipboard clip is empty during manual paste fallback");
            return null;
        }

        return clipData.getItemAt(0).coerceToText(this);
    }

    private CharSequence buildSetTextFallbackContent(AccessibilityNodeInfo node, CharSequence clipboardText) {
        CharSequence currentText = node.getText();
        if (currentText == null || currentText.length() == 0) {
            return clipboardText;
        }

        String before = currentText.toString();
        String insert = clipboardText.toString();
        int start = node.getTextSelectionStart();
        int end = node.getTextSelectionEnd();
        if (start >= 0 && end >= 0 && start <= before.length() && end <= before.length()) {
            int safeStart = Math.min(start, end);
            int safeEnd = Math.max(start, end);
            return before.substring(0, safeStart) + insert + before.substring(safeEnd);
        }

        return before + insert;
    }

    private int getNodeTextLength(AccessibilityNodeInfo node) {
        if (node == null || node.getText() == null) {
            return 0;
        }
        return node.getText().length();
    }

    private void clickSelectAllMenuItemDelayed() {
        clickMenuItemDelayed("Select all", "Select all text", "בחר הכל");
    }

    private void clickCopyMenuItemDelayed() {
        clickMenuItemDelayed("Copy", "Copy text", "העתק");
    }

    private void clickPasteMenuItemDelayed() {
        clickMenuItemDelayed("Paste", "הדבק");
    }

    private void clickMenuItemDelayed(String... labels) {
        Handler handler = new Handler(Looper.getMainLooper());
        handler.postDelayed(() -> {
            try {
                boolean ok = false;
                for (String label : labels) {
                    ok = clickFirstVisibleNodeByText(label);
                    if (ok) {
                        break;
                    }
                }
                StrictLogger.logLine(ok ? "INFO" : "WARNING", "Delayed menu click result: " + ok);
                if (ok) {
                    showToast("Menu action requested");
                    if (labels.length > 0 && "Paste".equals(labels[0])) {
                        hideMenu();
                    }
                }
            } catch (Exception ex) {
                StrictLogger.logLine("ERROR", "Delayed menu click failed", ex);
            }
        }, CONTEXT_MENU_CLICK_DELAY_MS);
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
                    if (isOwnOverlayNode(match)) {
                        continue;
                    }

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
            if (!isOwnOverlayNode(current) && (supportsActionId(current, AccessibilityNodeInfo.ACTION_CLICK) || current.isClickable())) {
                return current;
            }

            AccessibilityNodeInfo parent = current.getParent();
            current.recycle();
            current = parent;
        }
        return null;
    }

    private AccessibilityNodeInfo findBestNodeForManualAction(TargetMode mode) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) {
            StrictLogger.logLine("WARNING", "No active window root available");
            return null;
        }

        AccessibilityNodeInfo inputFocus = null;
        AccessibilityNodeInfo accessibilityFocus = null;
        try {
            inputFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
            if (isCandidateAllowed(inputFocus)) {
                StrictLogger.logLine("INFO", "Using input-focus node for manual action mode: " + mode);
                return AccessibilityNodeInfo.obtain(inputFocus);
            }

            accessibilityFocus = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY);
            if (isCandidateAllowed(accessibilityFocus)) {
                StrictLogger.logLine("INFO", "Using accessibility-focus node for manual action mode: " + mode);
                return AccessibilityNodeInfo.obtain(accessibilityFocus);
            }

            AccessibilityNodeInfo actionNode = findNodeByActionDepthFirst(root, mode);
            if (actionNode != null) {
                StrictLogger.logLine("INFO", "Using broad action-capable node for manual action mode: " + mode);
                return actionNode;
            }

            AccessibilityNodeInfo textNode = findAnyTextNodeDepthFirst(root);
            if (textNode != null) {
                StrictLogger.logLine("WARNING", "Using broad text node fallback for manual action mode: " + mode);
                return textNode;
            }

            return null;
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

    private AccessibilityNodeInfo findNodeByActionDepthFirst(AccessibilityNodeInfo node, TargetMode mode) {
        if (node == null) {
            return null;
        }
        if (isCandidateAllowed(node) && isActionCandidateForMode(node, mode)) {
            return AccessibilityNodeInfo.obtain(node);
        }

        int childCount = node.getChildCount();
        for (int index = 0; index < childCount; index++) {
            AccessibilityNodeInfo child = node.getChild(index);
            if (child == null) {
                continue;
            }
            try {
                AccessibilityNodeInfo result = findNodeByActionDepthFirst(child, mode);
                if (result != null) {
                    return result;
                }
            } finally {
                child.recycle();
            }
        }
        return null;
    }

    private AccessibilityNodeInfo findAnyTextNodeDepthFirst(AccessibilityNodeInfo node) {
        if (node == null) {
            return null;
        }
        if (isCandidateAllowed(node) && hasVisibleText(node)) {
            return AccessibilityNodeInfo.obtain(node);
        }

        int childCount = node.getChildCount();
        for (int index = 0; index < childCount; index++) {
            AccessibilityNodeInfo child = node.getChild(index);
            if (child == null) {
                continue;
            }
            try {
                AccessibilityNodeInfo result = findAnyTextNodeDepthFirst(child);
                if (result != null) {
                    return result;
                }
            } finally {
                child.recycle();
            }
        }
        return null;
    }

    private boolean isActionCandidateForMode(AccessibilityNodeInfo node, TargetMode mode) {
        if (node == null || mode == null) {
            return false;
        }

        switch (mode) {
            case SELECT_ALL:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_SELECTION)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_SELECT)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY)
                        || hasVisibleText(node);
            case START_SELECTION:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_SELECT)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_SELECTION)
                        || hasVisibleText(node);
            case COPY:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_COPY)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || hasVisibleText(node);
            case PASTE:
                return supportsActionId(node, AccessibilityNodeInfo.ACTION_PASTE)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_SET_TEXT)
                        || supportsActionId(node, AccessibilityNodeInfo.ACTION_LONG_CLICK)
                        || node.isEditable();
            default:
                return false;
        }
    }

    private boolean isCandidateAllowed(AccessibilityNodeInfo node) {
        if (node == null) {
            return false;
        }
        return !isOwnOverlayNode(node);
    }

    private boolean isOwnOverlayNode(AccessibilityNodeInfo node) {
        if (node == null || node.getPackageName() == null) {
            return false;
        }
        return getPackageName().contentEquals(node.getPackageName());
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

    private enum TargetMode {
        SELECT_ALL,
        START_SELECTION,
        COPY,
        PASTE
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
