# === RAW_CHECK_ID: SysmonMonitor_README_0003 ===
# Sysmon Monitor Project Index

GeneratedAt: 2026-06-09 11:18:00 Asia/Jerusalem  
Project: Sysmon-Monitor  
Purpose: Live project index for Sysmon-Monitor scripts, backups, logs, data files, and recommendations.

---

## 1. RAW / Project Roots

```text
RAW_ROOT:
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/

PROJECT_ROOT:
Sysmon-Monitor/

README_RAW:
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/Sysmon-Monitor/ReadMe.md
```

---

## 2. Project Folder Structure

```text
Sysmon-Monitor/
├─ ReadMe.md
├─ WorkingScript/
│  ├─ Sysmon-Monitor[02].ps1
│  │  changes: classification layer before popup, targeted self-noise/evidence-only handling, sysmontoast:// route kept, selective Autoruns gating
│  └─ Sysmon-Monitor[1].ps1
│     changes: baseline working script
│
├─ Logs/
│  ├─ Sysmon-Monitor[01].log
│  ├─ SysmonToastActionProtocol[01].log
│  └─ SysmonToastAction[01].log
│
├─ DataToAnalyze/
│  └─ ToAnalyze[01].zip
│
├─ Backups/
│  ├─ Sysmon-Monitor[00].ps1
│  └─ Sysmon-Monitor[01].ps1
│
└─ Recommendations/
   └─ Sysmon-Monitor_Script_Change_Recommendations_20260609.md
```

---

## 3. Current Index

```text
CURRENT_INDEX:
02

ACTIVE_SCRIPT:
WorkingScript/Sysmon-Monitor[02].ps1

CURRENT_LOG:
Logs/[log][01].log

CURRENT_DATA:
DataToAnalyze/

ROLLBACK_SCRIPT:
Backups/Sysmon-Monitor[01].ps1

ACTIVE_RECOMMENDATIONS:
Recommendations/Sysmon-Monitor_Script_Change_Recommendations_20260609.md
```

---

## 4. Version Rule

Every approved test cycle increments the integer index by 1.

```text
script[01] -> log[01] -> data[01] -> backup[00]
script[02] -> log[02] -> data[02] -> backup[01]
script[03] -> log[03] -> data[03] -> backup[02]
```

Do not use sub-index formats:

```text
script[01_1]
script[01_2]
script[1-2]
```

---

## 5. File Naming Rule

Assistant publishes script files using this format only:

```text
WorkingScript/Sysmon-Monitor[NN].ps1
```

Example entry format:

```text
Sysmon-Monitor[03].ps1
changes: short description of the change
```

The file link may be written separately when needed.

---

## 6. ChatGPT Working Rules

When ChatGPT works on this project:

1. Use this README as the live project index.
2. Build RAW file URLs from `RAW_ROOT + PROJECT_ROOT + relative path`.
3. Use the active script as the base for code changes.
4. Compare script versions, logs, data files, and backups when diagnosing behavior.
5. Do not rename files outside the approved naming pattern.
6. Before publishing a script, run:
   - syntax/parser check;
   - logic-path review;
   - error/logging verification.
7. After the user tests, classify result as:
   - PASS;
   - PATCH;
   - ROLLBACK;
   - NOISE_TUNING;
   - STOP.

---

## 7. RAW Freshness Check

After updating this README on GitHub, check that the RAW view shows:

```text
RAW_CHECK_ID: SysmonMonitor_README_0003
```

Increase this number after each README update:

```text
SysmonMonitor_README_0004
SysmonMonitor_README_0005
SysmonMonitor_README_0006
```
