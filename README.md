# AndroidAccessibilityCopyPasteHelper LinkV1

GeneratedAt: 2026-06-12 22:21:32 Asia/Jerusalem

## Purpose

Private manual Android accessibility helper for difficult copy/paste/select-all operations.

## Behavior

Activation flow:

```text
User taps Android accessibility shortcut / small person icon
→ custom overlay menu opens
→ user manually chooses Select all / Copy / Paste
```

## Non-goals / privacy posture

- No `INTERNET` permission.
- No analytics.
- No background clipboard monitoring.
- No automatic action on text-field focus.
- No chat-history reading.
- No upload.
- The service ignores accessibility events unless the user manually activates the shortcut.

## Project files

```text
settings.gradle
build.gradle
app/build.gradle
app/src/main/AndroidManifest.xml
app/src/main/res/xml/accessibility_service_config.xml
app/src/main/res/values/strings.xml
app/src/main/res/values/styles.xml
app/src/main/java/com/rasputin/accessibilitycopyhelper/MainActivity.java
app/src/main/java/com/rasputin/accessibilitycopyhelper/ManualTextAccessibilityService.java
app/src/main/java/com/rasputin/accessibilitycopyhelper/StrictLogger.java
```

## Build in Android Studio

1. Open the project folder in Android Studio.
2. Let Android Studio sync Gradle.
3. Build APK from:

```text
Build → Build App Bundle(s) / APK(s) → Build APK(s)
```

## Device setup

1. Install the APK.
2. Open the app.
3. Tap **Open Accessibility Settings**.
4. Enable **Manual Copy Paste Helper**.
5. Attach it to the Android accessibility shortcut / small person icon in Android Accessibility settings.
6. Open any app with an editable text field.
7. Tap the accessibility shortcut.
8. Use the manual menu.

## Notes

The optional **Write / Insert Text** feature is intentionally not implemented in LinkV1 because it can easily become unsafe if it stores text or steals focus. Add it later only as a deliberate preset/input feature after separate approval.
