# === RAW_CHECK_ID: SysmonMonitor_README_0003 ===
=== RAW_CHECK_ID: SysmonMonitor_README_0002 ===
Sysmon Monitor Project Index
GeneratedAt: 2026-06-09 10:10:30 Asia/Jerusalem
Project: Sysmon-Monitor
Purpose: Live project index for Sysmon-Monitor scripts, backups, logs, data files, and recommendations.

1. RAW / Project Roots
RAW_ROOT:
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/
PROJECT_ROOT:
Sysmon-Monitor/
README_RAW:
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/Sysmon-Monitor/README.md

2. Project Folder Structure
Sysmon-Monitor/
├─ README.md
├─ WorkingScript/
│  ├─ Sysmon-Monitor[02].ps1  | baseline working script ,changes: classification layer before popup, targeted self-noise/evidence-only handling, sysmontoast:// route kept, selective Autoruns gating.
│  └─ Sysmon-Monitor[01].log  | changes: 
│
├─ Logs/
│  ├─ Sysmon-Monitor[01].log 
│  ├─ SysmonToastActionProtocol[01].log 
│  └─ SysmonToastAction[01].log 
│
├─ DataToAnalyze/
│  ├─ ToAnalyze[01].zip
│  
│  
│  
│
├─ Backups/
│  ├─ Sysmon-Monitor[00].ps1
│  ├─ Sysmon-Monitor[01].ps1
│  
│ 
└─ Recommendations/
   └─ Sysmon-Monitor_Script_Change_Recommendations_20260609.md

4. Current Index
CURRENT_INDEX:
01
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

5. Version Rule
Every approved test cycle increments the integer index by 1.
Use:
script[01] -> log[01] -> data[01] -> backup[00]
script[02] -> log[02] -> data[02] -> backup[01]
script[03] -> log[03] -> data[03] -> backup[02]
Do not use sub-index formats such as:
script[01_1]
script[01_2]
script[1-2]

6. File Naming Rules
Assistant publishes script files using this format only:
WorkingScript/Sysmon-Monitor[NN].ps1
Example:
├─ Sysmon-Monitor[01].ps1   | changes: classification layer, selective Autoruns
The file link may be written separately when needed.

7. ChatGPT Working Rules
When ChatGPT works on this project:
    1. Use this README as the live project index.
    2. Build RAW file URLs from RAW_ROOT + PROJECT_ROOT + relative path.
    3. Use the active script as the base for code changes.
    4. Compare script versions, logs, data files, and backups when diagnosing behavior.
    5. Do not rename files outside the approved naming pattern.
    6. Before publishing a script, run:
        ◦ syntax/parser check;
        ◦ logic-path review;
        ◦ error/logging verification.
    7. After the user tests, classify result as:
        ◦ PASS;
        ◦ PATCH;
        ◦ ROLLBACK;
        ◦ NOISE_TUNING;
        ◦ STOP.

8. RAW Freshness Check
After updating this README on GitHub, check that the RAW view shows:
RAW_CHECK_ID: SysmonMonitor_README_0001
Increase this number after each README update:
SysmonMonitor_README_0002
SysmonMonitor_README_0003
SysmonMonitor_README_0004
