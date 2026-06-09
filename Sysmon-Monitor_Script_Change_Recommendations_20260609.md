# Sysmon-Monitor Script Change Recommendations
Generated: [09]:[06]:[2026] - [09]:[25]:[00] Asia/Jerusalem

## [09]:[06]:[2026] - [09]:[25]:[01] Scope
- This document lists recommended script changes only. It is not a patch plan and does not include code.
- The purpose is to keep the next development session focused after cleanup.

## [09]:[06]:[2026] - [09]:[25]:[02] Current confirmed status
- The sysmontoast:// protocol route is the working model for toast buttons.
- Display Popup has been confirmed to write sysmon_popup_state.txt and trigger the monitor popup.
- The old raw powershell.exe/cmd.exe command-in-XML model should be treated as failed and removed from active code.
- The biggest remaining risk is not the toast mechanism; it is self-noise and excessive popup classification.

## [09]:[06]:[2026] - [09]:[25]:[03] Latest alert package interpretation
- Latest copied alert package: three EventID 11 file-create events from Firefox Developer Edition.
- Two events target Z:\InsPro\Tools\Ps1\ToastActions\Set-SysmonAlertState.ps1. This is likely expected browser/download/upload activity during helper work, but it should not become a repeated popup pattern once the helper is trusted.
- One event targets C:\Users\RASPUTIN4149\Downloads\PL0lguKE.ps1 with RuleName Downloads. A downloaded .ps1 from the browser should remain at least PopupMedium or EvidenceOnly until reviewed; do not auto-ignore all browser-created .ps1 files.

## [09]:[06]:[2026] - [09]:[25]:[04] Recommended changes
### [09]:[06]:[2026] - [09]:[25]:[05] 1. Add a classification layer before popup
- Priority: High
- Change: Separate event storage from user interruption. Use PopupHigh, PopupMedium, EvidenceOnly, KnownNoise, and Ignore.
- Reason: The logs show repeated alert batches and evidence creation even when popup is disabled. The prior handoff already identified classification as the main design direction.

### [09]:[06]:[2026] - [09]:[25]:[06] 2. Suppress confirmed monitor/helper self-noise
- Priority: High
- Change: Add targeted suppression or EvidenceOnly classification for monitor-created files, protocol helper logs, state files, ToAnalyze folders, clipboard packages, Add-Type/csc artifacts, and known helper scripts.
- Reason: Recent alerts show tool/helper activity becoming EventID 11 alerts. Older logs show PowerShell/self-noise producing repeated alert batches. Do not globally ignore PowerShell; match path, parent, command line, and known file names.

### [09]:[06]:[2026] - [09]:[25]:[07] 3. Finalize the sysmontoast protocol model
- Priority: High
- Change: Keep sysmontoast://popup-set, sysmontoast://alert-set, and sysmontoast://alert-unset as the only toast-button route. Remove raw powershell.exe/cmd.exe attempts from active XML.
- Reason: The protocol handler route has been validated. Raw command execution from Toast XML failed and should not return.

### [09]:[06]:[2026] - [09]:[25]:[08] 4. Re-check alert state after the toast action window
- Priority: Medium
- Change: After sending an alert toast, check sysmon_alert_state.txt more than once for a short window, or delay popup decision until the protocol handler has time to write SET/UNSET.
- Reason: Earlier logs show alert toast sent, then Show-SysmonAlert checked once and skipped when the control file was absent.

### [09]:[06]:[2026] - [09]:[25]:[09] 5. Create a controlled allowlist for ToastActions files
- Priority: Medium
- Change: Allowlist only exact helper filenames and expected hashes under Z:\InsPro\Tools\Ps1\ToastActions.
- Reason: The helper scripts are legitimate, but a broad ToastActions ignore rule would be unsafe because attacker-modified helper scripts could be missed.

### [09]:[06]:[2026] - [09]:[25]:[10] 6. Throttle and group alert bursts
- Priority: High
- Change: When one cycle has many related events, create one evidence package but suppress repeated popups. Add max events per batch, max folders per cycle, and clustering by ProcessGuid, Image, RuleName, and target path.
- Reason: The logs show batches of 13, 27, 55, 111, 274, and 287 events, plus event-window queries of hundreds of events.

### [09]:[06]:[2026] - [09]:[25]:[11] 7. Reduce Autoruns cost and false correlation
- Priority: Medium
- Change: Do not run a full Autoruns dump for every low-value/self-noise alert. Cache Autoruns for a time window and run full dumps only for PopupHigh/PopupMedium or persistence-related registry events.
- Reason: Logs show Autoruns repeatedly starts after popup, and PowerShell self-noise can still show MatchesFound correlation.

### [09]:[06]:[2026] - [09]:[25]:[12] 8. Keep EventID 16 high value but classify normal config loads
- Priority: Medium
- Change: Keep config hash/path checks. Popup only if config path, config hash, or Sysmon executable is unexpected. Normal matching loads should be EvidenceOnly.
- Reason: The prior handoff correctly treats EventID 16 as high-value evidence, but not every config load needs a popup.

### [09]:[06]:[2026] - [09]:[25]:[13] 9. Reclassify noisy EventID 5, 11, 13, and 24 patterns
- Priority: High
- Change: Classify these events by source/path/context, not by EventID alone.
- Reason: The logs and handoff show frequent PowerShell, browser, clipboard, tool, and registry noise.

### [09]:[06]:[2026] - [09]:[25]:[14] 10. Add log rotation and cleanup policy
- Priority: Medium
- Change: Rotate Sysmon-MonitorV14.log and protocol/helper logs by size or date. Keep the latest N days and archive only selected alert packages.
- Reason: The upload monitor shows the V14 log at about 4.1 MB, and debug verbosity will grow fast.

### [09]:[06]:[2026] - [09]:[25]:[15] 11. Verify protocol registration at startup
- Priority: Medium
- Change: Add startup sanity for HKCU:\Software\Classes\sysmontoast\shell\open\command and verify -WindowStyle Hidden plus the expected handler path.
- Reason: When Invoke-SysmonToastAction.ps1 was missing, protocol dispatch failed. Startup sanity should detect that immediately.

### [09]:[06]:[2026] - [09]:[25]:[16] 12. Protect helper files against tampering
- Priority: Medium
- Change: At startup, hash Invoke-SysmonToastAction.ps1, Set-SysmonPopupState.ps1, and Set-SysmonAlertState.ps1. Warn or popup if hashes differ from the saved baseline.
- Reason: The helper scripts now control popup behavior and should be treated as trusted control files.

### [09]:[06]:[2026] - [09]:[25]:[17] 13. Separate Debug mode from Production mode
- Priority: Medium
- Change: Use one flag such as $script:DebugVerbose = $true/$false. Production should keep only critical lines and per-alert summaries.
- Reason: The current debug logs are useful during development but too noisy for long-term monitoring.

### [09]:[06]:[2026] - [09]:[25]:[18] 14. Preserve evidence while reducing popups
- Priority: High
- Change: Do not solve noise by deleting evidence first. Save evidence packages as needed, then use classification to decide popup behavior.
- Reason: This preserves forensic value while reducing interruptions.

## [09]:[06]:[2026] - [09]:[26]:[00] Recommended next work order
1. Freeze the working sysmontoast protocol files and record their hashes.
1. Update Send-SysmonToast so the three action buttons use only sysmontoast:// URIs.
1. Add or verify classification before popup decision.
1. Add targeted self-noise handling for monitor/helper-generated files.
1. Add startup sanity check for protocol registration and helper file existence/hash.
1. Add log rotation and cleanup rules.
1. Run the three required checks before publishing: parser/syntax, logic review, and error logging verification.

## [09]:[06]:[2026] - [09]:[26]:[01] Do not change casually
- Do not broadly ignore all PowerShell events.
- Do not broadly ignore all Firefox-created .ps1 files.
- Do not delete evidence before classification is stable.
- Do not replace the working protocol route with raw command execution in Toast XML.
- Do not suppress EventID 16 globally.

## [09]:[06]:[2026] - [09]:[26]:[02] Source basis
- Uploaded Sysmon-MonitorV14.log and Sysmon-Monitor.log.
- Current copied Sysmon Alert Copy Package from 2026-06-09 09:19:26.
- Earlier development handoff recommending classification, evidence/popup separation, and self-noise reduction.