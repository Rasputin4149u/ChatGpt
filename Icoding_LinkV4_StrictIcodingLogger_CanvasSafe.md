GENERAL INSTRUCTIONS HEADER (FOR ALL MODES)
Icoding Version: LinkV4_StrictIcodingLogger
Short description: Strict Icoding logger requirement. Any logger helper named log_line(), Write-DebugLine(), or equivalent must auto-add caller function name and caller code line number to every log event.

For GENERAL INSTRUCTIONS in this chat, before doing anything else, read and apply the file as mandatory instructions:
https://raw.githubusercontent.com/Rasputin4149u/ChatGpt/refs/heads/main/GENERAL%20INSTRUCTIONS

---

# WORK PROTOCOL – CODING / DEBUGGING

## A. Coding Rules

### 1. Before Coding

- Explain the logic in words.
- Wait for approval, unless the user already gave explicit approval to edit, patch, merge, or generate the requested file.

---

### 2. Logging — MANDATORY STRICT ICODING LOGGER

Every log event must include:

- timestamp
- caller function name
- caller code line number
- message/event text

Strict logger rule:

- The logger helper itself must auto-add the caller function name and caller line number.
- The caller must not be required to manually type its own function name or line number into every log message.
- For Python tools, `log_line()` must inspect the caller frame and add:
  - caller function name
  - caller line number
- For PowerShell tools, `Write-DebugLine` or an equivalent helper must use the call stack or an approved caller-info helper so touched logs include line number and function context automatically.
- For JavaScript tools, the logging helper must add caller context when practical, or the code must use an approved wrapper pattern that guarantees function and line context.
- Do not accept logger code that only logs timestamp + message.
- Do not accept logger code that requires every caller to manually write its own function name and line number.

Required Python logger behavior:

- `log_line("message")` must write a complete strict-Icoding log event.
- Output must include timestamp, caller function name, caller line number, and message.
- Preferred format:

```text
[timestamp] [LEVEL] [caller_function:caller_line] message
```

Required Python example:

```python
import inspect
from datetime import datetime
from typing import Any, Optional


def log_line(message: str, level: str = "INFO", data: Optional[dict[str, Any]] = None) -> None:
    """
    Purpose: Write one strict-Icoding log event with automatic caller function and line number.
    Params : message - Human-readable event message.
             level   - Log level such as INFO, WARNING, ERROR, DEBUG.
             data    - Optional structured values that are safe to log.
    Return : None.
    """
    frame = inspect.currentframe()
    caller = frame.f_back if frame else None

    caller_function = caller.f_code.co_name if caller else "<unknown>"
    caller_line = caller.f_lineno if caller else -1
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    safe_level = str(level).upper().strip() or "INFO"
    safe_message = str(message)

    if data:
        print(f"[{timestamp}] [{safe_level}] [{caller_function}:{caller_line}] {safe_message} | data={data}")
    else:
        print(f"[{timestamp}] [{safe_level}] [{caller_function}:{caller_line}] {safe_message}")

    # Avoid keeping frame reference cycles alive.
    del frame
    del caller
```

Required PowerShell logger behavior:

- `Write-DebugLine "message"` must write a complete strict-Icoding log event.
- The caller must not manually pass `$(Get-LineNumber)` into each log call.
- Output must include timestamp, caller function name, caller script line number, and message.

Required PowerShell example:

```powershell
function Write-DebugLine {
    <#
    Purpose: Write one strict-Icoding debug log event with automatic caller function and line number.
    Params : Message - Human-readable event message.
             Level   - Log level such as INFO, WARNING, ERROR, DEBUG.
    Return : None.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Level = "INFO"
    )

    $CallStack = Get-PSCallStack
    $Caller = if ($CallStack.Count -gt 1) { $CallStack[1] } else { $null }

    $CallerFunction = if ($Caller -and $Caller.FunctionName) { $Caller.FunctionName } else { "<script>" }
    $CallerLine = if ($Caller -and $Caller.ScriptLineNumber) { $Caller.ScriptLineNumber } else { -1 }
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $SafeLevel = $Level.ToUpperInvariant()

    Write-Host "[$Timestamp] [$SafeLevel] [$CallerFunction`:$CallerLine] $Message"
}
```

Correct PowerShell usage:

```powershell
Write-DebugLine "Entering Get-Data | Path=[$Path]"
Write-DebugLine "Doing step X"
Write-DebugLine "Exiting Get-Data"
```

Wrong PowerShell usage:

```powershell
Write-DebugLine "$(Get-LineNumber) Entering Get-Data | Path=[$Path]"
```

Rules:

- If logs do not include line numbers, fix them.
- If logs do not include function/caller context, fix them.
- All new code must include strict logger output.
- Existing logs missing line numbers or caller context must be corrected when touched.
- Do not log secrets, tokens, passwords, private keys, full cookies, or unnecessary personal data.

---

### 3. Function Structure

Each function must include:

```text
# Purpose: Describe function.
# Params : Describe params.
# Return : Describe return.
```

PowerShell example:

```powershell
function Example {
    <#
    Purpose: Describe function.
    Params : None.
    Return : None.
    #>
    param()

    Write-DebugLine "Entering Example"

    # Step description.
    Write-DebugLine "Doing step X"

    Write-DebugLine "Exiting Example"
}
```

Python example:

```python
def example(path: str) -> bool:
    """
    Purpose: Describe function.
    Params : path - Describe param.
    Return : True on success, False on handled failure.
    """
    log_line(f"Entering example | path=[{path}]")

    # Step description.
    log_line("Doing step X")

    log_line("Exiting example")
    return True
```

---

### 4. Code Readability

- Prefer simple logic.
- Nested IF is allowed.
- Debuggability is more important than cleverness.
- Logger helpers must be boring, explicit, and easy to verify.

---

### 5. Comments + Logs

Every important step must have:

- a comment
- a log line

The log line must use the approved strict logger helper.

---

### 6. Variable Logging

- Log important values only.
- Do not log secrets, tokens, passwords, private keys, full cookies, or unnecessary personal data.

---

## B. Debugging Rules

### 1. Root Cause Analysis

Must include:

- why the bug happens
- where it happens
- how the fix solves it

---

### 2. Instruction Format

- step-based
- each step has timestamp

---

### 3. Code Replacement Rules

- old code → with line numbers
- new code → clean copy/paste

---

### 4. Output Location

- instructions must be in canvas

---

## C. File / Version Control

- keep file name when appropriate
- increment version
- add short description
- when the change is a strict logger upgrade, use the version label:

```text
LinkV4_StrictIcodingLogger
```

---

## D. Missing Data Rule

- do not assume
- ask and pause only when missing data blocks safe or correct progress

---

## E. Output & Delivery Rules

When delivering files:

1. provide download link
2. verify file
3. re-check file
4. publish in canvas:
   - filename
   - version
   - changed sections

---

## F. Knowledge Tracking

Track:

- what worked
- what failed
- which logs were upgraded to strict caller function + line number format

---

## G. Persistence Rule

Applies to all coding/debug sessions.

---

# FINAL RULE

Simple code, strong logging, caller function name and caller line number always included, zero assumptions.
