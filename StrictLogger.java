package com.rasputin.accessibilitycopyhelper;

import android.util.Log;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Strict Icoding logger.
 *
 * Every log event automatically includes:
 * - local timestamp
 * - log level
 * - caller method name
 * - caller source line number
 * - message text
 *
 * Callers must not manually pass their own method name or line number.
 */
public final class StrictLogger {
    private static final String TAG = "ManualCopyPasteHelper";

    private StrictLogger() {
        // Utility class. No instances.
    }

    public static void logLine(String message) {
        logLine("INFO", message, null);
    }

    public static void logLine(String level, String message) {
        logLine(level, message, null);
    }

    public static void logLine(String level, String message, Throwable throwable) {
        String safeLevel = sanitizeLevel(level);
        StackTraceElement caller = findCaller();
        String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(new Date());
        String callerFunction = caller == null ? "unknown" : caller.getMethodName();
        int callerLine = caller == null ? -1 : caller.getLineNumber();
        String payload = "[" + timestamp + "] [" + safeLevel + "] [" + callerFunction + ":" + callerLine + "] " + String.valueOf(message);

        int priority = toAndroidPriority(safeLevel);
        if (throwable == null) {
            Log.println(priority, TAG, payload);
        } else {
            Log.println(priority, TAG, payload + " | " + throwable.getClass().getSimpleName() + ": " + throwable.getMessage());
            Log.println(priority, TAG, Log.getStackTraceString(throwable));
        }
    }

    private static StackTraceElement findCaller() {
        StackTraceElement[] stack = Thread.currentThread().getStackTrace();
        String loggerClassName = StrictLogger.class.getName();
        for (StackTraceElement element : stack) {
            String className = element.getClassName();
            if (!loggerClassName.equals(className) && !Thread.class.getName().equals(className)) {
                return element;
            }
        }
        return null;
    }

    private static String sanitizeLevel(String level) {
        if (level == null) {
            return "INFO";
        }
        String value = level.trim().toUpperCase(Locale.US);
        return value.isEmpty() ? "INFO" : value;
    }

    private static int toAndroidPriority(String level) {
        switch (level) {
            case "ERROR":
                return Log.ERROR;
            case "WARNING":
            case "WARN":
                return Log.WARN;
            case "DEBUG":
                return Log.DEBUG;
            default:
                return Log.INFO;
        }
    }
}
