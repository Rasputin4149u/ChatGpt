<#
.SYNOPSIS
    Sysmon Monitor - Clean, Less Noisy, Rich Details
    Fixed version:
    - Removed duplicate monitor body.
    - Replaced invalid Event Log XPath contains(...) query with FilterHashtable EventID filtering.
    - Keeps RecordID tracking.
    - Keeps Q exit option.
    - Clipboard copy now includes a full ChatGPT-ready Sysmon analysis package.
    - Report rows now include TargetObject, Details, ProcessGuid, ProcessId, User, RuleName, EventType, and full EventData.
    - Suppresses Sysmon EventID 24 clipboard alerts created by this monitor's own PowerShell process.
    - Adds ServiceContext enrichment for svchost.exe / service-hosted PIDs at alert time.
    - Adds Sysmon EventID 16 config-load monitoring and context capture.
    - Adds ClipboardEvidenceContext for EventID 24 to capture current clipboard state, hash comparison, owner, and archive search.
    - Fixes Autoruns TXT conversion by skipping Sysinternals banner lines and using the real CSV header.
    - Adds Autorunsc -accepteula -nobanner so AutoRun CSV/TXT output keeps all columns.
    - This is a full merged runnable build based on Sysmon-Monitor(7).ps1, not an AN_ADD_ON block.
#>

Add-Type -AssemblyName System.Windows.Forms
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
# ==============================================================================
# Global Configuration & Paths
# ==============================================================================
$StateFile = "C:\Users\RASPUTIN4149\AppData\Local\Temp\sysmon_popup_state.txt"
$ScriptPath = "Z:\InsPro\Tools\Ps1\Sysmon-Monitor.ps1"

$MonitorIntervalSeconds = 300 # seconds; 300 seconds = 5 minutes
$LastEventsCount = 300        # Bounded read from Sysmon log
$SysmonLogName   = "Microsoft-Windows-Sysmon/Operational"

$SysmonReal     = "Z:\backup\Data\EventViewer\SysmonReal"
$SysmonRealAuto = "Z:\backup\Data\EventViewer\SysmonReal\Auto"
$SysmonRealTxt  = "Z:\backup\Data\EventViewer\SysmonReal\txt"
$SysmonRealServiceContext = "Z:\backup\Data\EventViewer\SysmonReal\ServiceContext"
$SysmonRealConfigLoad = "Z:\backup\Data\EventViewer\SysmonReal\ConfigLoadContext"
$SysmonRealClipboardEvidence = "Z:\backup\Data\EventViewer\SysmonReal\ClipboardEvidence"
$SysmonRealToAnalyze = "Z:\backup\Data\EventViewer\SysmonReal\ToAnalyze"
$TrustedSysmonExe = "Z:\InsPro\Sysmon\Sysmon64.exe"
$FallbackSysmonExe = "C:\Windows\Sysmon64.exe"
$ExpectedSysmonConfigPath = "Z:\InsPro\Sysmon\SysmonSettings.xml"
$DisplayPopup = $true
$Autorun        = "Z:\Installs\WinUtils\Autoruns\autorunsc64.exe"
$statePath = "C:\Users\RASPUTIN4149\AppData\Local\Temp\sysmon_popup_state.txt"
$AlertPath = "C:\Users\RASPUTIN4149\AppData\Local\Temp\sysmon_alert_state.txt"
$PopupButtons       = 4      # Yes / No
$PopupIcon          = 32     # Question icon
$PopupSystemModal   = 4096   # Try to keep above normal windows
$PopupSetForeground = 65536  # Try to bring to foreground

$PopupType = $PopupButtons + $PopupIcon + $PopupSystemModal + $PopupSetForeground


if ($args.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($args[0])) {
    if ($args[0] -match '^V') {
        $Ver = $args[0]
    }
    else {
        $Ver = "V" + $args[0]
    }
}
else {
    $Ver = "V_UNKNOWN"
}
$DebugLogDir = "Z:\InsPro\Tools\Logs"
New-Item -ItemType Directory -Path $DebugLogDir -Force | Out-Null

$DebugLogFile = Join-Path $DebugLogDir ("Sysmon-Monitor" + $Ver + ".log")
$global:DebugLogFile = $DebugLogFile
# Track the last processed Event Record ID to prevent duplicate processing.
$Script:LastRecordId = $null

# ==============================================================================
# Helper Functions
# ==============================================================================
function StartMssg {
    $Timeout = 30
    $wsa = New-Object -ComObject "WScript.Shell"
    $res = $wsa.Popup("Sysmon-Monitor Started 'Display Popups?", $Timeout, 'Sysmon Security Alert', 4 + 4096)
    if ($res -eq 7) { return $false }
    if ($Timeout -eq -1) { return $true }
    return $true
}

function Send-SysmonToast {
    param(
        [string]$Message = "Script is now running successfully!",
        [string]$Title   = "Sysmon-Monitor"
    )

    Write-DebugLine "$(Get-LineNumber)Displaying Toast."

    $AppId = "Microsoft.WindowsTerminal_8wekyb3d8bbwe!App"

    # Make sure these paths exist in function scope.
    if (-not $script:statePath) {
        $script:statePath = Join-Path $env:TEMP "sysmon_popup_state.txt"
    }

    if (-not $script:AlertPath) {
        $script:AlertPath = Join-Path $env:TEMP "sysmon_alert_state.txt"
    }

    $RestartScriptPath = "Z:\InsPro\Tools\Ps1\Restart-Script.ps1"
    $MonitorScriptPath = "Z:\InsPro\Tools\Ps1\Sysmon-Monitor.ps1"

    # Keep launch simple and XML-safe.
    # Important: launch is an activation argument, not guaranteed direct execution.
    $LaunchCommandRaw = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$RestartScriptPath`" `"$MonitorScriptPath`""

    $LaunchCommandXml = [System.Security.SecurityElement]::Escape($LaunchCommandRaw)
    $TitleXml         = [System.Security.SecurityElement]::Escape($Title)
    $MessageXml       = [System.Security.SecurityElement]::Escape($Message)

    $PopupSetArgsXml  = [System.Security.SecurityElement]::Escape("cmd.exe /c echo SET > `"$script:statePath`"")
    $AlertSetArgsXml  = [System.Security.SecurityElement]::Escape("cmd.exe /c echo SET > `"$script:AlertPath`"")
    $AlertUnsetArgsXml = [System.Security.SecurityElement]::Escape("cmd.exe /c echo UNSET > `"$script:AlertPath`"")

    $ToastXmlText = @"
<toast launch="$LaunchCommandXml" duration="long">
    <visual>
        <binding template="ToastGeneric">
            <text>$TitleXml</text>
            <text>$MessageXml</text>
        </binding>
    </visual>
    <actions>
        <action content="Display Popup"
                arguments="$PopupSetArgsXml"
                activationType="protocol" />

        <action content="Display Alert"
                arguments="$AlertSetArgsXml"
                activationType="protocol" />

        <action content="Hide Alert"
                arguments="$AlertUnsetArgsXml"
                activationType="protocol" />

        <action content="Dismiss"
                arguments="dismiss"
                activationType="system" />
    </actions>
</toast>
"@

    try {
        $ToastXml = [Windows.Data.Xml.Dom.XmlDocument]::New()
        $ToastXml.LoadXml($ToastXmlText)

        $Toast = [Windows.UI.Notifications.ToastNotification]::New($ToastXml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($Toast)
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)Toast failed: $($_.Exception.Message)"
        Write-DebugLine "$(Get-LineNumber)Toast XML was: $ToastXmlText"
        throw
    }
}





function CheckPopupFileExist {
	param(
        [Parameter(Mandatory = $true)][string]$File
    )
	Write-DebugLine "$(Get-LineNumber)CheckPopupFileExist."
	if (Test-Path -Path $File) {
        Write-DebugLine "$(Get-LineNumber)File Path = $File exists."
		return $True
	}
	Write-DebugLine "$(Get-LineNumber)File Path = $File not exists."
	return $False
}
        

# Dummy functions to maintain your logging format compatibility
function Get-LineNumber { return "" }
function Write-DebugLine ([string]$msg) { Write-Debug "[V11] $msg" }

# ==============================================================================
# Main Execution Flow
# ==============================================================================
function Get-LineNumber {
    #$Line = "$MyInvocation.ScriptLineNumber "
	$line = "[{0}] {1}" -f $MyInvocation.ScriptLineNumber , " "
	return $Line
}

function Write-H {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Text,

        [string]$Message
    )
	if ([string]::IsNullOrWhiteSpace($Text)) {
        $Text = $Message
    }
	$Text = [string]$Text

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $T  = "[$Ver] $Text"

    Write-Host $T
    Add-Content -Path $DebugLogFile -Value $T -Encoding UTF8
}

<#
.SYNOPSIS
Writes one timestamped line to the debug log.

.DESCRIPTION
Adds a timestamped message to the debug log file and mirrors it to the console for live troubleshooting.

.PARAMETER Message
Debug message text to write.

.OUTPUTS
None
#>
function Write-DebugLine {
    param(
        [Parameter(Mandatory = $false)][AllowNull()][string]$Message
    )
	
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

   try {
        if ($null -eq $Message) {
            $line = "[{0}] Write-DebugLine received NULL message - Exiting Write-DebugLine function" -f $ts
            Write-H -Text ("Write-DebugLine $line")
            return
        }
		#Write-H -Text ("$(Get-LineNumber)    Write-DebugLine -after mssg null")
        if ([string]::IsNullOrWhiteSpace($Message)) {
            #Write-H -Text ("$(Get-LineNumber)    Write-DebugLine -after mssg white")
			$visibleMessage = $Message.Replace("`r", "<CR>").Replace("`n", "<LF>").Replace("`t", "<TAB>")
            #Write-H -Text ("$(Get-LineNumber)    Write-DebugLine -after formating mssg ")
			if ($visibleMessage -eq "") { 
				$visibleMessage = "<EMPTY OR WHITESPACE>" 
			}
			#Write-H -Text ("$(Get-LineNumber)    Write-DebugLine -after vmssg ")
            $line = "[$Ver][{0}] Write-DebugLine received empty/whitespace message: [{1}] - Exiting Write-DebugLine function" -f $ts, $visibleMessage
            #Write-H -Text ("$(Get-LineNumber)    Write-DebugLine -after formating line ")
			Add-Content -Path $global:DebugLogFile -Value $line -Encoding UTF8
            Write-H -Text ("Write-DebugLine $line")
            return
        }

        $line = "[{0}] {1}" -f $ts, $Message
        #Add-Content -Path $global:DebugLogFile -Value $line -Encoding UTF8
        Write-H -Text ("Write-DebugLine $line")
    }
    catch {
        #Write-H -Text ("Write-DebugLine in catch ")
		Write-H -Text ("Write-DebugLine FAILED: {0}" -f $_.Exception.Message)
    }
}

function ConvertCsvTxt {
    param(
        [string]$SysmonFile = " ",
        [string]$AutoFile = " "
    )

    $CsvData = $null
    $TxtOutFile = $null

    if ($SysmonFile -ne " ") {
        $SysFilePath = Join-Path $SysmonReal ($SysmonFile + ".csv")

        if (Test-Path -Path $SysFilePath) {
            $CsvData = Import-Csv -Path $SysFilePath
            $TxtOutFile = Join-Path $SysmonRealTxt ($SysmonFile + ".txt")
        }
    }
    elseif ($AutoFile -ne " ") {
        $AutoFilePath = Join-Path $SysmonRealAuto ($AutoFile + ".csv")

        if (Test-Path -Path $AutoFilePath) {
            # Autorunsc may write Sysinternals banner lines before the real CSV header.
            # If Import-Csv reads the banner as the header, the TXT report becomes a one-column table named H1.
            # Therefore we locate the real Autoruns CSV header and convert only from that line forward.
            $RawLines = Get-Content -Path $AutoFilePath

            $HeaderIndex = -1
            for ($i = 0; $i -lt $RawLines.Count; $i++) {
                if ($RawLines[$i] -match '^"?Time"?\s*,\s*"?Entry Location"?\s*,') {
                    $HeaderIndex = $i
                    break
                }
            }

            if ($HeaderIndex -ge 0) {
                $CsvText = ($RawLines[$HeaderIndex..($RawLines.Count - 1)] -join "`r`n")
                $CsvData = $CsvText | ConvertFrom-Csv
            }
            else {
                # Fallback for already-clean CSV or unexpected Autoruns output.
                $CsvData = Import-Csv -Path $AutoFilePath
            }

            $TxtOutFile = Join-Path $SysmonRealTxt ($AutoFile + ".txt")
        }
    }

    if ($CsvData -and $TxtOutFile) {
        $Properties = $CsvData[0].psobject.Properties.Name

        $Header = "| " + ($Properties -join " | ") + " |"
        $Divider = "| " + (($Properties | ForEach-Object { "---" }) -join " | ") + " |"

        $Rows = $CsvData | ForEach-Object {
            $Obj = $_
            "| " + (($Properties | ForEach-Object { 
                $CellValue = [string]$Obj.$_
                $CellValue = $CellValue -replace "`r", " "
                $CellValue = $CellValue -replace "`n", " "
                $CellValue = $CellValue -replace "\|", "\|"
                $CellValue
            }) -join " | ") + " |"
        }

        ($Header, $Divider, ($Rows -join "`n")) -join "`n" | Out-File -FilePath $TxtOutFile -Encoding utf8
    }
}
function Test-SysmonStopFileRequested {
    $StopFilePath = "Z:\InsPro\Tools\Stop-Sysmon-Monitor.flag"

    try {
        if (Test-Path -LiteralPath $StopFilePath) {
            Write-DebugLine "$(Get-LineNumber)Stop file detected: $StopFilePath"
            return $true
        }
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)Stop file check failed: $($_.Exception.Message)"
    }

    return $false
}


function Test-ExitKey {
    try {
        if ([Console]::KeyAvailable) {
            $KeyInfo = [Console]::ReadKey($true)

            if ($KeyInfo.Key -eq [ConsoleKey]::Q) {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

function Wait-MonitorIntervalWithExit {
    param(
        [int]$Seconds
    )

    for ($Index = 1; $Index -le $Seconds; $Index++) {
        if ((Test-ExitKey) -or (Test-SysmonStopFileRequested)) {
            return $true
        }

        Start-Sleep -Seconds 1
    }

    return $false
}

function ConvertTo-ClipboardSafeText {
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return "N/A"
    }

    $Text = [string]$Value

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "N/A"
    }

    $Text = $Text -replace "`r`n", "`n"
    $Text = $Text -replace "`r", "`n"
    $Text = $Text.Replace("|", "\|")
    $Text = $Text -replace "`n", "<br>"

    return $Text
}

function Get-ReportValue {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$Default = "N/A"
    )

    if ($Row.PSObject.Properties.Name -contains $Name) {
        $Value = $Row.$Name

        if ($null -ne $Value) {
            $Text = [string]$Value

            if (-not [string]::IsNullOrWhiteSpace($Text)) {
                return $Text
            }
        }
    }

    return $Default
}

function Get-SysmonDataValue {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Data,
        [Parameter(Mandatory=$true)][string[]]$Names,
        [string]$Default = "N/A"
    )

    foreach ($Name in $Names) {
        if ($Data.ContainsKey($Name)) {
            $Value = $Data[$Name]

            if ($null -ne $Value) {
                $Text = [string]$Value

                if (-not [string]::IsNullOrWhiteSpace($Text)) {
                    return $Text
                }
            }
        }
    }

    return $Default
}

function New-SysmonClipboardReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [int]$EventCount = 0,
        [string]$AlertTime = (Get-Date -Format "yyyyMMdd_HHmmss")
    )

    $Lines = New-Object System.Collections.Generic.List[string]
    $GeneratedLocal = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    $Lines.Add("# Sysmon Alert Copy Package")
    $Lines.Add("")
    $Lines.Add("This text was copied by Sysmon-Monitor for ChatGPT analysis.")
    $Lines.Add("")
    $Lines.Add("| Field | Value |")
    $Lines.Add("| --- | --- |")
    $Lines.Add("| GeneratedLocalTime | $(ConvertTo-ClipboardSafeText $GeneratedLocal) |")
    $Lines.Add("| AlertFileStamp | $(ConvertTo-ClipboardSafeText $AlertTime) |")
    $Lines.Add("| EventCount | $(ConvertTo-ClipboardSafeText $EventCount) |")
    $Lines.Add("| ComputerName | $(ConvertTo-ClipboardSafeText $env:COMPUTERNAME) |")
    $Lines.Add("| SysmonLogName | $(ConvertTo-ClipboardSafeText $SysmonLogName) |")
    $Lines.Add("")

    $Index = 0

    foreach ($Row in $Report) {
        $Index++

        $Lines.Add("## Event $Index")
        $Lines.Add("")
        $Lines.Add("| Field | Value |")
        $Lines.Add("| --- | --- |")

        $Fields = @(
            "TimeCreatedLocal",
            "UtcTime",
            "EventID",
            "RecordID",
            "ProviderName",
            "LogName",
            "ComputerName",
            "Level",
            "RuleName",
            "EventType",
            "User",
            "ProcessGuid",
            "ProcessId",
            "Image",
            "CommandLine",
            "CurrentDirectory",
            "OriginalFileName",
            "ParentProcessGuid",
            "ParentProcessId",
            "ParentImage",
            "ParentCommandLine",
            "TargetObject",
            "Details",
            "NewName",
            "TargetFilename",
            "CreationUtcTime",
            "Hashes",
            "Signed",
            "Signature",
            "SignatureStatus",
            "SourceImage",
            "SourceProcessGuid",
            "SourceProcessId",
            "TargetImage",
            "TargetProcessGuid",
            "TargetProcessId",
            "DestinationHostname",
            "DestinationIp",
            "DestinationPort",
            "SourceHostname",
            "SourceIp",
            "SourcePort",
            "GrantedAccess",
            "CallTrace",
            "PipeName",
            "QueryName",
            "QueryStatus",
            "QueryResults",
            "Configuration",
            "ConfigurationFileHash",
            "Archived",
            "ClientInfo",
            "Session",
            "ConfigLoadCaptureLocal",
            "ConfigLoadStatus",
            "ConfigLoadEventConfigPath",
            "ConfigLoadEventHash",
            "ConfigLoadDiskHash",
            "ConfigLoadHashMatchesEvent",
            "ConfigLoadSysmonExe",
            "ConfigLoadArchiveDirectoryReported",
            "ConfigLoadSummaryFile",
            "ConfigLoadHashFile",
            "ClipboardEvidenceCaptureLocal",
            "ClipboardEvidenceStatus",
            "ClipboardScanTimeContainsText",
            "ClipboardScanTimeTextLength",
            "ClipboardScanTimeTextSHA256",
            "ClipboardEvidenceEventSHA256",
            "ClipboardEvidenceEventMD5",
            "ClipboardScanTimeHashMatchesEvent",
            "ClipboardScanTimeTextPreview",
            "ClipboardScanTimeTextFile",
            "ClipboardEvidenceOwnerProcessId",
            "ClipboardEvidenceOwnerProcessName",
            "ClipboardEvidenceOwnerProcessPath",
            "ClipboardEvidenceOwnerWindowTitle",
            "ClipboardEvidenceArchiveSearchStatus",
            "ClipboardEvidenceArchiveMatches",
            "ClipboardEvidenceArchiveSearchFile",
            "ServiceContextCaptureLocal",
            "ServiceContextStatus",
            "ServiceContextIsSvchost",
            "ServiceContextProcessName",
            "ServiceContextExePath",
            "ServiceContextCommandLine",
            "ServiceContextParentPid",
            "ServiceContextServiceCount",
            "ServiceContextServiceNames",
            "ServiceContextDisplayNames",
            "ServiceContextStates",
            "ServiceContextStartModes",
            "ServiceContextStartNames",
            "ServiceContextPathNames",
            "ServiceContextTaskListSvc"
        )

        foreach ($Field in $Fields) {
            $Value = Get-ReportValue -Row $Row -Name $Field
            $Lines.Add("| $Field | $(ConvertTo-ClipboardSafeText $Value) |")
        }

        $RecordId = Get-ReportValue -Row $Row -Name "RecordID"

        if ($RecordId -ne "N/A") {
            $RetrieveCommand = "Get-WinEvent -LogName `"$SysmonLogName`" | Where-Object { `$_.RecordId -eq $RecordId } | Format-List *"

            $Lines.Add("")
            $Lines.Add("### Exact PowerShell retrieval command")
            $Lines.Add("")
            $Lines.Add('```powershell')
            $Lines.Add($RetrieveCommand)
            $Lines.Add('```')

            $ProcessGuidForCommand = Get-ReportValue -Row $Row -Name "ProcessGuid"

            if ($ProcessGuidForCommand -ne "N/A") {
                $Lines.Add("")
                $Lines.Add("### Same ProcessGuid timeline command")
                $Lines.Add("")
                $Lines.Add('```powershell')
                $Lines.Add("`$Guid = `"$ProcessGuidForCommand`"")
                $Lines.Add("Get-WinEvent -LogName `"$SysmonLogName`" |")
                $Lines.Add("Where-Object { `$_.Message -match [regex]::Escape(`$Guid) } |")
                $Lines.Add("Sort-Object TimeCreated |")
                $Lines.Add("Select-Object TimeCreated, Id, RecordId, ProviderName, Message |")
                $Lines.Add("Format-List")
                $Lines.Add('```')
            }

            $Lines.Add("")
            $Lines.Add("### Nearby RecordID window command")
            $Lines.Add("")
            $Lines.Add('```powershell')
            $Lines.Add("`$RecordId = $RecordId")
            $Lines.Add("Get-WinEvent -LogName `"$SysmonLogName`" |")
            $Lines.Add("Where-Object { `$_.RecordId -ge (`$RecordId - 20) -and `$_.RecordId -le (`$RecordId + 20) } |")
            $Lines.Add("Sort-Object RecordId |")
            $Lines.Add("Select-Object TimeCreated, Id, RecordId, ProviderName, Message |")
            $Lines.Add("Format-List")
            $Lines.Add('```')
        }

        $AllEventData = Get-ReportValue -Row $Row -Name "AllEventData"

        if ($AllEventData -ne "N/A") {
            $Lines.Add("")
            $Lines.Add("### All parsed Sysmon EventData")
            $Lines.Add("")
            $Lines.Add('```text')
            $Lines.Add($AllEventData)
            $Lines.Add('```')
        }

        $FullMessage = Get-ReportValue -Row $Row -Name "FullMessage"

        if ($FullMessage -ne "N/A") {
            if ($FullMessage.Length -gt 6000) {
                $FullMessage = $FullMessage.Substring(0, 6000) + "`r`n[TRUNCATED AFTER 6000 CHARACTERS]"
            }

            $Lines.Add("")
            $Lines.Add("### Full Sysmon message")
            $Lines.Add("")
            $Lines.Add('```text')
            $Lines.Add($FullMessage)
            $Lines.Add('```')
        }

        $Lines.Add("")
    }

    return [System.String]::Join("`r`n", $Lines)
}

function Show-SysmonAlert {
    param (
        [Parameter(Mandatory=$true)]$Report,
        [int]$EventCount = 0,
        [string]$AlertTime = (Get-Date -Format "yyyyMMdd_HHmmss"),
        [int]$Timeout = 50
    )

    $ShouldDisplayPopup = $false

    if ($DisplayPopup -eq $true) {
        $ShouldDisplayPopup = $true
    }

    $AlertControl = "NONE"

    try {
        if (Test-Path -Path $AlertPath) {
            $AlertControl = ((Get-Content -Path $AlertPath -ErrorAction SilentlyContinue) -join "`n").Trim()
            Write-DebugLine "$(Get-LineNumber)Alert control file exists: $AlertPath Content=[$AlertControl]"
        }
        else {
            Write-DebugLine "$(Get-LineNumber)Alert control file does not exist: $AlertPath"
        }
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)Alert control file read failed: $($_.Exception.Message)"
        $AlertControl = "NONE"
    }

    if ($AlertControl -eq "SET") {
        $ShouldDisplayPopup = $true
    }
    elseif ($AlertControl -eq "UNSET") {
        $ShouldDisplayPopup = $false
    }
    elseif ($AlertControl -ne "NONE" -and $AlertControl -ne "") {
        Write-DebugLine "$(Get-LineNumber)Unknown alert control value ignored: [$AlertControl]"
    }

    try {
        if (Test-Path -Path $AlertPath) {
            Remove-Item -Path $AlertPath -ErrorAction SilentlyContinue -Force
            Write-DebugLine "$(Get-LineNumber)Alert control file removed: $AlertPath"
        }
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)Alert control file remove failed: $($_.Exception.Message)"
    }

    $ToAnalyzeFolder = "N/A"
    $ToAnalyzeFolderName = "N/A"

    try {
        $FirstReportRow = @($Report) | Select-Object -First 1
        if ($FirstReportRow -and ($FirstReportRow.PSObject.Properties.Name -contains "ToAnalyzeAlertFolder")) {
            $ToAnalyzeFolder = [string]$FirstReportRow.ToAnalyzeAlertFolder
        }
        if ($FirstReportRow -and ($FirstReportRow.PSObject.Properties.Name -contains "ToAnalyzeAlertFolderName")) {
            $ToAnalyzeFolderName = [string]$FirstReportRow.ToAnalyzeAlertFolderName
        }
    }
    catch {
        $ToAnalyzeFolder = "N/A"
        $ToAnalyzeFolderName = "N/A"
    }

    Write-DebugLine "$(Get-LineNumber)Show-SysmonAlert decision: DisplayPopup=$DisplayPopup AlertControl=[$AlertControl] ShouldDisplayPopup=$ShouldDisplayPopup ToAnalyzeFolder=[$ToAnalyzeFolderName]"

    if ($ShouldDisplayPopup -ne $true) {
        Write-DebugLine "$(Get-LineNumber)Show-SysmonAlert skipped because popup display is disabled."
        return $false
    }

    $msgText = "Sysmon Security Alert!`n`n$EventCount suspicious events found.`n`nSaved as: Sysmon_Alert_$AlertTime.csv`n`nToAnalyze folder:`n$ToAnalyzeFolderName`n$ToAnalyzeFolder`n`nAutorun exported to: $SysmonReal`n`nCopy full ChatGPT analysis package to clipboard?"

    try {
        Write-DebugLine "$(Get-LineNumber)Show-SysmonAlert displaying WScript popup."
        $wsh = New-Object -ComObject "WScript.Shell"
        $res = $wsh.Popup($msgText, $Timeout, 'Sysmon Security Alert', $PopupType)
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)WScript popup failed: $($_.Exception.Message)"
        return $false
    }

    if ($res -eq 6) {
        $ClipboardReport = New-SysmonClipboardReport -Report $Report -EventCount $EventCount -AlertTime $AlertTime

        # Save the same ChatGPT analysis package to disk before clipboard copy.
        # This preserves the evidence package even if the live clipboard is overwritten later.
        try {
            New-Item -ItemType Directory -Path $SysmonRealTxt -Force | Out-Null
            $ClipboardPackageFile = Join-Path $SysmonRealTxt ("ClipboardPackage_" + $AlertTime + ".md")
            $ClipboardReport | Out-File -FilePath $ClipboardPackageFile -Encoding UTF8
        }
        catch {
            $PackageSaveError = $_.Exception.Message
            try {
                $wsh.Popup("Clipboard package file save failed.`n$PackageSaveError", 15, 'Sysmon Package Save Failed', $PopupType) | Out-Null
            }
            catch {
                Write-DebugLine "$(Get-LineNumber)Clipboard package save error popup failed: $($_.Exception.Message)"
            }
        }

        try {
            Set-Clipboard -Value $ClipboardReport -ErrorAction Stop
            return $true
        }
        catch {
            $FirstError = $_.Exception.Message

            try {
                [System.Windows.Forms.Clipboard]::SetText($ClipboardReport)
                return $true
            }
            catch {
                $SecondError = $_.Exception.Message
                $FailMessage = "Clipboard copy failed.`nSet-Clipboard: $FirstError`nWindows.Forms: $SecondError"
                try {
                    $wsh.Popup($FailMessage, 15, 'Sysmon Clipboard Copy Failed', $PopupType) | Out-Null
                }
                catch {
                    Write-DebugLine "$(Get-LineNumber)Clipboard copy error popup failed: $($_.Exception.Message)"
                }
                return $false
            }
        }
    }

    Write-DebugLine "$(Get-LineNumber)Show-SysmonAlert closed without clipboard copy. Result=$res"
    return $false
}


function Get-EventDataMap {
    param(
        [Parameter(Mandatory=$true)]$Event
    )

    $Data = @{}

    try {
        $Xml = [xml]$Event.ToXml()

        $Xml.Event.EventData.Data | ForEach-Object {
            if ($_.Name) {
                $Data[$_.Name] = $_.InnerText
            }
        }
    }
    catch {
        # Return whatever was parsed before the error.
    }

    return $Data
}

function Test-SysmonEventSuspicious {
    param(
        [Parameter(Mandatory=$true)]$Event
    )

    $EventId = $Event.Id
    $Message = $Event.Message

    if ($Message -match "Sysmon-Monitor|__PSScriptPolicyTest|sdbinst.exe|Autoruns64.exe|Autorunsc64.exe") {
        return $false
    }

    $Data = Get-EventDataMap -Event $Event

    $CommandLine = ""
    if ($Data.ContainsKey("CommandLine")) {
        $CommandLine = $Data["CommandLine"]
    }

    $Image = ""
    if ($Data.ContainsKey("Image")) {
        $Image = $Data["Image"]
    }

    $RuleName = ""
    if ($Data.ContainsKey("RuleName")) {
        $RuleName = $Data["RuleName"]
    }

    $TargetObject = ""
    if ($Data.ContainsKey("TargetObject")) {
        $TargetObject = $Data["TargetObject"]
    }

    $EventProcessId = ""
    if ($Data.ContainsKey("ProcessId")) {
        $EventProcessId = [string]$Data["ProcessId"]
    }

    if ($EventId -eq 16) {
        # Sysmon config state changed / settings loaded.
        # We want this in the monitor so config-load evidence is preserved in the central alert flow.
        return $true
    }

    # Known low-noise Windows compatibility-assistant registry update.
    # Examples observed: SnippingTool.exe, AutoHotkey64.exe, Notepad.exe.
    # At this stage, this suppresses popup/alert flow. A later classification stage can keep it as evidence-only.
    if (
        $EventId -eq 13 -and
        $RuleName -match "(?i)^InvDB$" -and
        $Image -match "(?i)\\svchost\.exe$" -and
        $TargetObject -match "(?i)\\Software\\Microsoft\\Windows NT\\CurrentVersion\\AppCompatFlags\\Compatibility Assistant\\Store\\"
    ) {
        return $false
    }

    # Prevent the monitor from alerting on its own Set-Clipboard action.
    # Sysmon EventID 24 is useful for real clipboard monitoring, but the monitor itself
    # copies the ChatGPT package to clipboard through this same PowerShell process.
    if (
        $EventId -eq 24 -and
        $EventProcessId -eq [string]$PID -and
        $Image -match "(?i)\\powershell\.exe$" -and
        $RuleName -match "(?i)Clipboard"
    ) {
        return $false
    }

    $TargetFilename = ""
    if ($Data.ContainsKey("TargetFilename")) {
        $TargetFilename = $Data["TargetFilename"]
    }

    # Known self-noise from PowerShell Add-Type temporary compilation files.
    # This suppresses monitor-generated temp DLL/cmdline file-create events only.
    if (
        $EventId -eq 11 -and
        $TargetFilename -match "(?i)\\AppData\\Local\\Temp\\([^\\]+\\)?[^\\]+\.(dll|cmdline)$" -and
        (
            $Image -match "(?i)\\WindowsPowerShell\\v1\.0\\powershell\.exe$" -or
            $Image -match "(?i)\\Microsoft\.NET\\Framework64\\v4\.0\.30319\\csc\.exe$" -or
            $Image -match "(?i)\\Microsoft\.NET\\Framework\\v4\.0\.30319\\csc\.exe$"
        )
    ) {
        return $false
    }

    $DestinationPort = ""
    if ($Data.ContainsKey("DestinationPort")) {
        $DestinationPort = $Data["DestinationPort"]
    }

    $SourcePort = ""
    if ($Data.ContainsKey("SourcePort")) {
        $SourcePort = $Data["SourcePort"]
    }

    $IsSuspiciousProcess = (
        $EventId -eq 1 -and
        (
            $CommandLine -match "(?i)-enc|cmd\.exe /c|wscript|cscript|mshta|regsvr32|certutil|whoami|net user|mimikatz|lsass|bypass" -or
            $Image -match "(?i)\\wscript\.exe$|\\cscript\.exe$|\\mshta\.exe$|\\regsvr32\.exe$|\\certutil\.exe$"
        )
    )

    $IsSuspiciousNetwork = (
        $EventId -eq 3 -and
        (
            $DestinationPort -in @("445", "139", "3389", "23", "25", "587", "21", "53", "389") -or
            $SourcePort -in @("445", "139", "3389", "23", "21", "389")
        )
    )

    $IsSuspiciousFile = (
        $EventId -in @(11, 15) -and
        $TargetFilename -match "(?i)\.exe$|\.dll$|\.ps1$|\.bat$|AppData\\Roaming|\\Temp\\|Startup"
    )

    $IsSuspiciousRegistry = (
        $EventId -in @(12, 13)
    )

    $IsOtherHighRiskSysmonEvent = (
        $EventId -in @(5, 7, 8, 9, 10, 17, 18, 24)
    )

    if (
        $IsSuspiciousProcess -or
        $IsSuspiciousNetwork -or
        $IsSuspiciousFile -or
        $IsSuspiciousRegistry -or
        $IsOtherHighRiskSysmonEvent
    ) {
        return $true
    }

    return $false
}


function Convert-SysmonEventToReportRow {
    param(
        [Parameter(Mandatory=$true)]$Event
    )

    $Data = Get-EventDataMap -Event $Event

    $AllEventData = "N/A"

    if ($Data.Count -gt 0) {
        $AllEventData = (
            $Data.GetEnumerator() |
            Sort-Object -Property Name |
            ForEach-Object {
                "$($_.Name): $($_.Value)"
            }
        ) -join "`r`n"
    }

    [PSCustomObject]@{
        TimeCreatedLocal = $Event.TimeCreated
        UtcTime          = Get-SysmonDataValue -Data $Data -Names @("UtcTime")
        EventID          = $Event.Id
        RecordID         = $Event.RecordId
        ProviderName     = $Event.ProviderName
        LogName          = $Event.LogName
        ComputerName     = $Event.MachineName
        Level            = $Event.LevelDisplayName

        RuleName         = Get-SysmonDataValue -Data $Data -Names @("RuleName")
        EventType        = Get-SysmonDataValue -Data $Data -Names @("EventType")
        User             = Get-SysmonDataValue -Data $Data -Names @("User")
        Configuration    = Get-SysmonDataValue -Data $Data -Names @("Configuration")
        ConfigurationFileHash = Get-SysmonDataValue -Data $Data -Names @("ConfigurationFileHash")
        Archived         = Get-SysmonDataValue -Data $Data -Names @("Archived")
        ClientInfo       = Get-SysmonDataValue -Data $Data -Names @("ClientInfo")
        Session          = Get-SysmonDataValue -Data $Data -Names @("Session")

        ProcessGuid      = Get-SysmonDataValue -Data $Data -Names @("ProcessGuid")
        ProcessId        = Get-SysmonDataValue -Data $Data -Names @("ProcessId")
        Image            = Get-SysmonDataValue -Data $Data -Names @("Image", "SourceImage")
        CommandLine      = Get-SysmonDataValue -Data $Data -Names @("CommandLine")
        CurrentDirectory = Get-SysmonDataValue -Data $Data -Names @("CurrentDirectory")
        OriginalFileName = Get-SysmonDataValue -Data $Data -Names @("OriginalFileName")

        ParentProcessGuid = Get-SysmonDataValue -Data $Data -Names @("ParentProcessGuid")
        ParentProcessId   = Get-SysmonDataValue -Data $Data -Names @("ParentProcessId")
        ParentImage       = Get-SysmonDataValue -Data $Data -Names @("ParentImage")
        ParentCommandLine = Get-SysmonDataValue -Data $Data -Names @("ParentCommandLine")

        TargetObject    = Get-SysmonDataValue -Data $Data -Names @("TargetObject")
        Details         = Get-SysmonDataValue -Data $Data -Names @("Details")
        NewName         = Get-SysmonDataValue -Data $Data -Names @("NewName")
        TargetFilename  = Get-SysmonDataValue -Data $Data -Names @("TargetFilename")
        CreationUtcTime = Get-SysmonDataValue -Data $Data -Names @("CreationUtcTime")

        Hashes          = Get-SysmonDataValue -Data $Data -Names @("Hashes")
        Signed          = Get-SysmonDataValue -Data $Data -Names @("Signed")
        Signature       = Get-SysmonDataValue -Data $Data -Names @("Signature")
        SignatureStatus = Get-SysmonDataValue -Data $Data -Names @("SignatureStatus")

        SourceImage       = Get-SysmonDataValue -Data $Data -Names @("SourceImage")
        SourceProcessGuid = Get-SysmonDataValue -Data $Data -Names @("SourceProcessGuid")
        SourceProcessId   = Get-SysmonDataValue -Data $Data -Names @("SourceProcessId")
        TargetImage       = Get-SysmonDataValue -Data $Data -Names @("TargetImage")
        TargetProcessGuid = Get-SysmonDataValue -Data $Data -Names @("TargetProcessGuid")
        TargetProcessId   = Get-SysmonDataValue -Data $Data -Names @("TargetProcessId")

        DestinationHostname = Get-SysmonDataValue -Data $Data -Names @("DestinationHostname")
        DestinationIp       = Get-SysmonDataValue -Data $Data -Names @("DestinationIp")
        DestinationPort     = Get-SysmonDataValue -Data $Data -Names @("DestinationPort")
        SourceHostname      = Get-SysmonDataValue -Data $Data -Names @("SourceHostname")
        SourceIp            = Get-SysmonDataValue -Data $Data -Names @("SourceIp")
        SourcePort          = Get-SysmonDataValue -Data $Data -Names @("SourcePort")

        GrantedAccess = Get-SysmonDataValue -Data $Data -Names @("GrantedAccess")
        CallTrace     = Get-SysmonDataValue -Data $Data -Names @("CallTrace")

        PipeName     = Get-SysmonDataValue -Data $Data -Names @("PipeName")
        QueryName    = Get-SysmonDataValue -Data $Data -Names @("QueryName")
        QueryStatus  = Get-SysmonDataValue -Data $Data -Names @("QueryStatus")
        QueryResults = Get-SysmonDataValue -Data $Data -Names @("QueryResults")

        ShortMessage = $Event.Message.Substring(0, [Math]::Min(1200, $Event.Message.Length))
        FullMessage  = $Event.Message
        AllEventData = $AllEventData
    }
}


# ===============================================================================
# ToAnalyze evidence-pack helpers
# ===============================================================================
function Convert-ToSafeFileNameComponent {
    param(
        [string]$Text,
        [int]$MaxLength = 80
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or $Text -eq "N/A") {
        return "NA"
    }

    $Safe = [string]$Text
    $Safe = $Safe -replace '[\\/:*?"<>|]', '_'
    $Safe = $Safe -replace '\s+', '_'
    $Safe = $Safe.Trim([char[]]@('_', '.', ' '))

    if ([string]::IsNullOrWhiteSpace($Safe)) {
        $Safe = "NA"
    }

    if ($Safe.Length -gt $MaxLength) {
        $Safe = $Safe.Substring(0, $MaxLength)
    }

    return $Safe
}

function Test-LooksLikeFilePath {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq "N/A") {
        return $false
    }

    return ($Value -match '^[A-Za-z]:\\' -or $Value -match '^\\\\')
}

function Get-PathBaseNameSafe {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -eq "N/A") {
        return "N/A"
    }

    try {
        return [System.IO.Path]::GetFileName($Path)
    }
    catch {
        return "N/A"
    }
}


function Get-FileSha256Safe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $Result = [ordered]@{
        Hash = "N/A"
        Method = "N/A"
        Error = "N/A"
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        $Result.Error = "FileNotFoundOrEmptyPath"
        return [PSCustomObject]$Result
    }

    try {
        if (Get-Command -Name Get-FileHash -ErrorAction SilentlyContinue) {
            $Hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop
            $Result.Hash = $Hash.Hash
            $Result.Method = "Get-FileHash"
            return [PSCustomObject]$Result
        }
    }
    catch {
        $Result.Error = "Get-FileHash failed: $($_.Exception.Message)"
    }

    try {
        $CertUtil = Join-Path $env:WINDIR "System32\certutil.exe"

        if (Test-Path -LiteralPath $CertUtil) {
            $CertOutput = & $CertUtil -hashfile $Path SHA256 2>&1
            $HashLine = $CertOutput | Where-Object { $_ -match '^[0-9A-Fa-f]{64}$' } | Select-Object -First 1

            if ($HashLine) {
                $Result.Hash = ([string]$HashLine).Trim().ToUpperInvariant()
                $Result.Method = "certutil"
                $Result.Error = "N/A"
                return [PSCustomObject]$Result
            }

            $Result.Error = "certutil did not return a SHA256 hash line. Output: $($CertOutput -join ' | ')"
        }
    }
    catch {
        $Result.Error = "certutil failed: $($_.Exception.Message)"
    }

    try {
        $Sha = [System.Security.Cryptography.SHA256]::Create()
        $Stream = [System.IO.File]::OpenRead($Path)

        try {
            $Bytes = $Sha.ComputeHash($Stream)
            $Result.Hash = (($Bytes | ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant()
            $Result.Method = ".NET SHA256"
            $Result.Error = "N/A"
            return [PSCustomObject]$Result
        }
        finally {
            if ($Stream) { $Stream.Dispose() }
            if ($Sha) { $Sha.Dispose() }
        }
    }
    catch {
        $Result.Error = ".NET SHA256 failed: $($_.Exception.Message)"
    }

    return [PSCustomObject]$Result
}

function Get-ToAnalyzeFileEvidence {
    param(
        [string]$Label,
        [string]$Path,
        [string]$OutputFile
    )

    $Result = [ordered]@{
        Label = $Label
        Path = $Path
        Exists = "N/A"
        Length = "N/A"
        CreationTime = "N/A"
        LastWriteTime = "N/A"
        SHA256 = "N/A"
        HashMethod = "N/A"
        Error = "N/A"
    }

    try {
        if ([string]::IsNullOrWhiteSpace($Path) -or $Path -eq "N/A") {
            $Result.Exists = "N/A"
            $Result.Error = "EmptyOrNAPath"
        }
        elseif (-not (Test-LooksLikeFilePath -Value $Path)) {
            $Result.Exists = "N/A"
            $Result.Error = "ValueDoesNotLookLikeFilePath"
        }
        elseif (Test-Path -LiteralPath $Path) {
            $Item = Get-Item -LiteralPath $Path -ErrorAction Stop
            $Result.Exists = $true
            $Result.Length = $Item.Length
            $Result.CreationTime = $Item.CreationTime
            $Result.LastWriteTime = $Item.LastWriteTime

            $HashResult = Get-FileSha256Safe -Path $Path
            $Result.SHA256 = $HashResult.Hash
            $Result.HashMethod = $HashResult.Method

            if ($HashResult.Error -and $HashResult.Error -ne "N/A") {
                $Result.Error = $HashResult.Error
            }
        }
        else {
            $Result.Exists = $false
            $Result.Error = "FileNotFoundAtScanTime"
        }
    }
    catch {
        $Result.Exists = "Error"
        $Result.Error = $_.Exception.Message
    }

    if ($OutputFile) {
        try {
            $Lines = New-Object System.Collections.Generic.List[string]
            $Lines.Add("Label: $($Result.Label)")
            $Lines.Add("Path: $($Result.Path)")
            $Lines.Add("Exists: $($Result.Exists)")
            $Lines.Add("Length: $($Result.Length)")
            $Lines.Add("CreationTime: $($Result.CreationTime)")
            $Lines.Add("LastWriteTime: $($Result.LastWriteTime)")
            $Lines.Add("SHA256: $($Result.SHA256)")
            $Lines.Add("HashMethod: $($Result.HashMethod)")
            $Lines.Add("Error: $($Result.Error)")
            $Lines | Out-File -FilePath $OutputFile -Encoding UTF8
        }
        catch {
            # Evidence logging must not break the monitor.
        }
    }

    return [PSCustomObject]$Result
}


function Get-ToAnalyzeAutorunTerms {
    param($Row)

    $Terms = New-Object System.Collections.Generic.List[string]

    function Add-AutorunTerm {
        param([string]$Term)

        if ([string]::IsNullOrWhiteSpace($Term) -or $Term -eq "N/A") {
            return
        }

        $Clean = ([string]$Term).Trim()
        $Clean = $Clean.Trim([char[]]@('"', "'", ' ', "`t", ',', ';'))

        if ([string]::IsNullOrWhiteSpace($Clean) -or $Clean -eq "N/A") {
            return
        }

        if (-not ($Terms | Where-Object { $_ -ieq $Clean })) {
            [void]$Terms.Add($Clean)
        }
    }

    function Add-PathAutorunTerms {
        param([string]$Value)

        Add-AutorunTerm -Term $Value

        if (Test-LooksLikeFilePath -Value $Value) {
            $BaseName = Get-PathBaseNameSafe -Path $Value
            Add-AutorunTerm -Term $BaseName
        }
    }

    function Add-RegistryTargetTerms {
        param([string]$Value)

        Add-AutorunTerm -Term $Value

        if (-not [string]::IsNullOrWhiteSpace($Value) -and $Value -ne "N/A") {
            try {
                $Leaf = (($Value -split '\\') | Select-Object -Last 1)
                Add-AutorunTerm -Term $Leaf
            }
            catch {
                # Do not break term generation.
            }
        }
    }

    function Add-ExtractedTermsFromText {
        param([string]$Value)

        if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq "N/A") {
            return
        }

        Add-AutorunTerm -Term $Value

        try {
            $PathMatches = [regex]::Matches($Value, "(?i)([A-Za-z]:\\[^\s`"'|<>]+)")

            foreach ($Match in $PathMatches) {
                $PathTerm = $Match.Groups[1].Value
                Add-PathAutorunTerms -Value $PathTerm
            }
        }
        catch {
            # Do not break term generation.
        }

        try {
            $TokenMatches = [regex]::Matches($Value, '(?i)([A-Za-z0-9_.-]+\.exe|SysmonMonitor[^\s"'';|]+|SysmonIntentional[^\s"'';|]+)')

            foreach ($Match in $TokenMatches) {
                Add-AutorunTerm -Term $Match.Groups[1].Value
            }
        }
        catch {
            # Do not break term generation.
        }
    }

    foreach ($Field in @("TargetObject", "Details", "Image", "TargetFilename", "ParentImage", "CommandLine", "ParentCommandLine")) {
        $Value = Get-ReportValue -Row $Row -Name $Field

        switch ($Field) {
            "TargetObject" {
                Add-RegistryTargetTerms -Value $Value
            }
            "Details" {
                Add-ExtractedTermsFromText -Value $Value
            }
            "CommandLine" {
                Add-ExtractedTermsFromText -Value $Value
            }
            "ParentCommandLine" {
                Add-ExtractedTermsFromText -Value $Value
            }
            default {
                Add-PathAutorunTerms -Value $Value
            }
        }
    }

    # Prefer more specific terms first so the match file is easier to read.
    $SortedTerms = @($Terms | Sort-Object @{Expression={$_.Length};Descending=$true}, @{Expression={$_};Ascending=$true})
    return $SortedTerms
}


function Search-ToAnalyzeAutoruns {
    param(
        [string]$AutoCsvFile,
        [string]$AutoTxtFile,
        [string[]]$Terms,
        [string]$OutputFile
    )

    $Result = [ordered]@{
        Status = "NotRun"
        MatchCount = 0
        Terms = (($Terms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "; ")
        MatchesFile = $OutputFile
    }

    try {
        $SearchFiles = @()

        if ($AutoCsvFile -and $AutoCsvFile -ne "N/A" -and (Test-Path -LiteralPath $AutoCsvFile)) {
            $SearchFiles += $AutoCsvFile
        }

        if ($AutoTxtFile -and $AutoTxtFile -ne "N/A" -and (Test-Path -LiteralPath $AutoTxtFile)) {
            $SearchFiles += $AutoTxtFile
        }

        if ($SearchFiles.Count -eq 0) {
            $Result.Status = "AutorunDumpNotFound"
            "Autorun dump file not found." | Out-File -FilePath $OutputFile -Encoding UTF8
            return [PSCustomObject]$Result
        }

        $Lines = New-Object System.Collections.Generic.List[string]
        $AutorunHits = New-Object System.Collections.Generic.List[string]

        $Lines.Add("Autoruns correlation search")
        $Lines.Add("AutoCsvFile: $AutoCsvFile")
        $Lines.Add("AutoTxtFile: $AutoTxtFile")
        $Lines.Add("Terms: $($Result.Terms)")
        $Lines.Add("")

        foreach ($Term in $Terms) {
            if ([string]::IsNullOrWhiteSpace($Term) -or $Term -eq "N/A") {
                continue
            }

            $Lines.Add("===== TERM: $Term =====")

            foreach ($SearchFile in $SearchFiles) {
                try {
                    $Found = Select-String -Path $SearchFile -SimpleMatch -Pattern $Term -ErrorAction Stop

                    foreach ($Hit in $Found) {
                        $Line = "$($Hit.Path):$($Hit.LineNumber): $($Hit.Line)"
                        $AutorunHits.Add($Line)
                        $Lines.Add($Line)
                    }
                }
                catch {
                    $Lines.Add("Search failed in $SearchFile for term [$Term]: $($_.Exception.Message)")
                }
            }

            $Lines.Add("")
        }

        if ($AutorunHits.Count -gt 0) {
            $Result.Status = "MatchesFound"
            $Result.MatchCount = $AutorunHits.Count
        }
        else {
            $Result.Status = "NoMatches"
            $Result.MatchCount = 0
            $Lines.Add("No Autoruns matches found for supplied terms.")
        }

        $Lines | Out-File -FilePath $OutputFile -Encoding UTF8
    }
    catch {
        $Result.Status = "Error: $($_.Exception.Message)"

        try {
            "Autoruns correlation failed: $($_.Exception.Message)" | Out-File -FilePath $OutputFile -Encoding UTF8
        }
        catch {
            # Do not break the monitor because evidence logging failed.
        }
    }

    return [PSCustomObject]$Result
}

function Initialize-ToAnalyzeAlertStub {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)][string]$AlertTime,
        [Parameter(Mandatory=$true)][string]$OutputRoot,
        [string]$AutoCsvFile = "N/A",
        [string]$AutoTxtFile = "N/A"
    )

    $Rows = @($Report)

    if (-not $Rows -or $Rows.Count -eq 0) {
        return $Report
    }

    try {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

        $FirstRow = $Rows[0]
        $FirstEventId = Get-ReportValue -Row $FirstRow -Name "EventID"
        $FirstRecordId = Get-ReportValue -Row $FirstRow -Name "RecordID"
        $FirstRule = Get-ReportValue -Row $FirstRow -Name "RuleName"
        $FirstImage = Get-ReportValue -Row $FirstRow -Name "Image"
        $FirstTarget = Get-ReportValue -Row $FirstRow -Name "TargetFilename"

        $ImageBase = Get-PathBaseNameSafe -Path $FirstImage
        if ($ImageBase -eq "N/A") {
            $ImageBase = Get-PathBaseNameSafe -Path $FirstTarget
        }

        $FolderNameRaw = "${AlertTime}_Count$($Rows.Count)_E${FirstEventId}_R${FirstRecordId}_${FirstRule}_${ImageBase}"
        $FolderName = Convert-ToSafeFileNameComponent -Text $FolderNameRaw -MaxLength 150
        $AlertFolder = Join-Path $OutputRoot $FolderName
        $SourceFilesDir = Join-Path $AlertFolder "SourceFiles"
        $SummaryFile = Join-Path $AlertFolder "ToAnalyze_Summary.md"

        New-Item -ItemType Directory -Path $AlertFolder -Force | Out-Null
        New-Item -ItemType Directory -Path $SourceFilesDir -Force | Out-Null

        $SummaryLines = New-Object System.Collections.Generic.List[string]
        $SummaryLines.Add("# Sysmon ToAnalyze Evidence Pack")
        $SummaryLines.Add("")
        $SummaryLines.Add("Status: Initialized before popup. Heavy evidence enrichment may continue after popup.")
        $SummaryLines.Add("AlertTime: $AlertTime")
        $SummaryLines.Add("ComputerName: $env:COMPUTERNAME")
        $SummaryLines.Add("EventCount: $($Rows.Count)")
        $SummaryLines.Add("FolderName: $FolderName")
        $SummaryLines.Add("FolderPath: $AlertFolder")
        $SummaryLines.Add("AutoCsvFile: $AutoCsvFile")
        $SummaryLines.Add("AutoTxtFile: $AutoTxtFile")
        $SummaryLines.Add("")
        $SummaryLines.Add("This stub exists so the alert popup can show the ToAnalyze folder immediately.")
        $SummaryLines | Out-File -FilePath $SummaryFile -Encoding UTF8

        foreach ($Row in $Rows) {
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolderName" -Value $FolderName -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolder" -Value $AlertFolder -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeSummaryFile" -Value $SummaryFile -Force
        }

        Write-DebugLine "$(Get-LineNumber)ToAnalyze alert stub initialized before popup: $AlertFolder"
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)ToAnalyze alert stub initialization failed: $($_.Exception.Message)"

        foreach ($Row in $Rows) {
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolderName" -Value "FAILED" -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolder" -Value "FAILED: $($_.Exception.Message)" -Force
        }
    }

    return $Rows
}

function Add-ToAnalyzeEvidenceToReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)]$Events,
        [Parameter(Mandatory=$true)][string]$AlertTime,
        [Parameter(Mandatory=$true)][string]$OutputRoot,
        [string]$AutoCsvFile = "N/A",
        [string]$AutoTxtFile = "N/A"
    )

    $Rows = @($Report)
    $EventList = @($Events)

    if (-not $Rows -or $Rows.Count -eq 0) {
        return $Report
    }

    try {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

        $FirstRow = $Rows[0]
        $FirstEventId = Get-ReportValue -Row $FirstRow -Name "EventID"
        $FirstRecordId = Get-ReportValue -Row $FirstRow -Name "RecordID"
        $FirstRule = Get-ReportValue -Row $FirstRow -Name "RuleName"
        $FirstImage = Get-ReportValue -Row $FirstRow -Name "Image"
        $FirstTarget = Get-ReportValue -Row $FirstRow -Name "TargetFilename"

        $ImageBase = Get-PathBaseNameSafe -Path $FirstImage
        if ($ImageBase -eq "N/A") {
            $ImageBase = Get-PathBaseNameSafe -Path $FirstTarget
        }

        $FolderNameRaw = "${AlertTime}_Count$($Rows.Count)_E${FirstEventId}_R${FirstRecordId}_${FirstRule}_${ImageBase}"
        $FolderName = Convert-ToSafeFileNameComponent -Text $FolderNameRaw -MaxLength 150
        $AlertFolder = Join-Path $OutputRoot $FolderName

        New-Item -ItemType Directory -Path $AlertFolder -Force | Out-Null

        $SourceFilesDir = Join-Path $AlertFolder "SourceFiles"
        New-Item -ItemType Directory -Path $SourceFilesDir -Force | Out-Null

        if ($AutoCsvFile -and $AutoCsvFile -ne "N/A" -and (Test-Path -LiteralPath $AutoCsvFile)) {
            Copy-Item -LiteralPath $AutoCsvFile -Destination (Join-Path $SourceFilesDir (Split-Path -Path $AutoCsvFile -Leaf)) -Force -ErrorAction SilentlyContinue
        }

        if ($AutoTxtFile -and $AutoTxtFile -ne "N/A" -and (Test-Path -LiteralPath $AutoTxtFile)) {
            Copy-Item -LiteralPath $AutoTxtFile -Destination (Join-Path $SourceFilesDir (Split-Path -Path $AutoTxtFile -Leaf)) -Force -ErrorAction SilentlyContinue
        }

        $SummaryLines = New-Object System.Collections.Generic.List[string]
        $SummaryLines.Add("# Sysmon ToAnalyze Evidence Pack")
        $SummaryLines.Add("")
        $SummaryLines.Add("AlertTime: $AlertTime")
        $SummaryLines.Add("ComputerName: $env:COMPUTERNAME")
        $SummaryLines.Add("EventCount: $($Rows.Count)")
        $SummaryLines.Add("FolderName: $FolderName")
        $SummaryLines.Add("FolderPath: $AlertFolder")
        $SummaryLines.Add("AutoCsvFile: $AutoCsvFile")
        $SummaryLines.Add("AutoTxtFile: $AutoTxtFile")
        $SummaryLines.Add("")

        $AlertWindowEvents = @()
        try {
            $EventTimes = @($EventList | Where-Object { $_ -and $_.TimeCreated } | ForEach-Object { $_.TimeCreated } | Sort-Object)
            if ($EventTimes.Count -gt 0) {
                $WindowStart = $EventTimes[0].AddMinutes(-2)
                $WindowEnd = $EventTimes[$EventTimes.Count - 1].AddMinutes(2)
                Write-DebugLine "$(Get-LineNumber)ToAnalyze alert event-window query started: Start=$WindowStart End=$WindowEnd EventCount=$($EventList.Count)"
                $AlertWindowEvents = @(Get-WinEvent -FilterHashtable @{ LogName = $SysmonLogName; StartTime = $WindowStart; EndTime = $WindowEnd } -ErrorAction Stop)
                Write-DebugLine "$(Get-LineNumber)ToAnalyze alert event-window query completed: WindowEventCount=$($AlertWindowEvents.Count)"
            }
            else {
                Write-DebugLine "$(Get-LineNumber)ToAnalyze alert event-window query skipped: no event times available."
            }
        }
        catch {
            Write-DebugLine "$(Get-LineNumber)ToAnalyze alert event-window query failed: $($_.Exception.Message)"
            $AlertWindowEvents = @()
        }

        for ($Index = 0; $Index -lt $Rows.Count; $Index++) {
            $Row = $Rows[$Index]
            $Event = $null

            if ($Index -lt $EventList.Count) {
                $Event = $EventList[$Index]
            }

            $EventNumber = $Index + 1
            $EventId = Get-ReportValue -Row $Row -Name "EventID"
            $RecordId = Get-ReportValue -Row $Row -Name "RecordID"
            $ProcessGuid = Get-ReportValue -Row $Row -Name "ProcessGuid"
            $Image = Get-ReportValue -Row $Row -Name "Image"
            $TargetFilename = Get-ReportValue -Row $Row -Name "TargetFilename"
            $ParentImage = Get-ReportValue -Row $Row -Name "ParentImage"
            $Details = Get-ReportValue -Row $Row -Name "Details"
            $RuleName = Get-ReportValue -Row $Row -Name "RuleName"

            Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber started: EventID=$EventId RecordID=$RecordId RuleName=$RuleName Image=$Image"

            $EventLabelSource = Get-PathBaseNameSafe -Path $Image
            if ($EventLabelSource -eq "N/A") {
                $EventLabelSource = Get-PathBaseNameSafe -Path $TargetFilename
            }

            $EventFolderNameRaw = "Event{0:00}_E{1}_R{2}_{3}_{4}" -f $EventNumber, $EventId, $RecordId, $RuleName, $EventLabelSource
            $EventFolderName = Convert-ToSafeFileNameComponent -Text $EventFolderNameRaw -MaxLength 140
            $EventFolder = Join-Path $AlertFolder $EventFolderName
            New-Item -ItemType Directory -Path $EventFolder -Force | Out-Null

            $RawXmlFile = Join-Path $EventFolder ("RawEventXml_Record_${RecordId}.xml")
            $TimelineFile = Join-Path $EventFolder ("ProcessGuidTimeline_Record_${RecordId}.txt")
            $NearbyFile = Join-Path $EventFolder ("NearbyRecordWindow_Record_${RecordId}.txt")
            $CommandsFile = Join-Path $EventFolder ("InvestigationCommands_Record_${RecordId}.ps1")
            $FileEvidenceFile = Join-Path $EventFolder ("FileEvidence_Record_${RecordId}.txt")
            $AutorunMatchesFile = Join-Path $EventFolder ("AutorunMatches_Record_${RecordId}.txt")

            try {
                if ($Event) {
                    $Event.ToXml() | Out-File -FilePath $RawXmlFile -Encoding UTF8
                }
                else {
                    "Event object unavailable; use RecordID retrieval command." | Out-File -FilePath $RawXmlFile -Encoding UTF8
                }
            }
            catch {
                "Raw XML save failed: $($_.Exception.Message)" | Out-File -FilePath $RawXmlFile -Encoding UTF8
            }

            $CommandLines = New-Object System.Collections.Generic.List[string]
            $CommandLines.Add('# Same ProcessGuid timeline')
            $CommandLines.Add('$Guid = "' + $ProcessGuid + '"')
            $CommandLines.Add('Get-WinEvent -LogName "' + $SysmonLogName + '" |')
            $CommandLines.Add('Where-Object { $_.Message -match [regex]::Escape($Guid) } |')
            $CommandLines.Add('Sort-Object TimeCreated |')
            $CommandLines.Add('Select-Object TimeCreated, Id, RecordId, ProviderName, Message |')
            $CommandLines.Add('Format-List')
            $CommandLines.Add('')
            $CommandLines.Add('# Nearby RecordID window')
            $CommandLines.Add('$RecordId = ' + $RecordId)
            $CommandLines.Add('Get-WinEvent -LogName "' + $SysmonLogName + '" |')
            $CommandLines.Add('Where-Object { $_.RecordId -ge ($RecordId - 20) -and $_.RecordId -le ($RecordId + 20) } |')
            $CommandLines.Add('Sort-Object RecordId |')
            $CommandLines.Add('Select-Object TimeCreated, Id, RecordId, ProviderName, Message |')
            $CommandLines.Add('Format-List')
            $CommandLines | Out-File -FilePath $CommandsFile -Encoding UTF8

            try {
                if ($ProcessGuid -and $ProcessGuid -ne "N/A") {
                    Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber ProcessGuid timeline started: $ProcessGuid"
                    $TimelineEvents = @($AlertWindowEvents |
                        Where-Object { $_.Message -match [regex]::Escape($ProcessGuid) } |
                        Sort-Object TimeCreated |
                        Select-Object TimeCreated, Id, RecordId, ProviderName, Message)
                    Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber ProcessGuid timeline completed: Count=$($TimelineEvents.Count)"

                    if ($TimelineEvents) {
                        $TimelineEvents | Format-List | Out-File -FilePath $TimelineFile -Encoding UTF8
                    }
                    else {
                        "No events found for ProcessGuid: $ProcessGuid" | Out-File -FilePath $TimelineFile -Encoding UTF8
                    }
                }
                else {
                    "ProcessGuid is N/A; timeline not available." | Out-File -FilePath $TimelineFile -Encoding UTF8
                }
            }
            catch {
                "ProcessGuid timeline capture failed: $($_.Exception.Message)" | Out-File -FilePath $TimelineFile -Encoding UTF8
            }

            try {
                if ($RecordId -match '^\d+$') {
                    $Rid = [int64]$RecordId
                    Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber nearby RecordID window started: RecordID=$Rid"
                    $NearbyEvents = @($AlertWindowEvents |
                        Where-Object { $_.RecordId -ge ($Rid - 20) -and $_.RecordId -le ($Rid + 20) } |
                        Sort-Object RecordId |
                        Select-Object TimeCreated, Id, RecordId, ProviderName, Message)
                    Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber nearby RecordID window completed: Count=$($NearbyEvents.Count)"

                    if ($NearbyEvents) {
                        $NearbyEvents | Format-List | Out-File -FilePath $NearbyFile -Encoding UTF8
                    }
                    else {
                        "No nearby RecordID events found for RecordID: $RecordId" | Out-File -FilePath $NearbyFile -Encoding UTF8
                    }
                }
                else {
                    "RecordID is not numeric; nearby window not available." | Out-File -FilePath $NearbyFile -Encoding UTF8
                }
            }
            catch {
                "Nearby RecordID window capture failed: $($_.Exception.Message)" | Out-File -FilePath $NearbyFile -Encoding UTF8
            }

            Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber file evidence started."
            $ImageEvidence = Get-ToAnalyzeFileEvidence -Label "Image" -Path $Image -OutputFile $null
            $TargetEvidence = Get-ToAnalyzeFileEvidence -Label "TargetFilename" -Path $TargetFilename -OutputFile $null
            $ParentEvidence = Get-ToAnalyzeFileEvidence -Label "ParentImage" -Path $ParentImage -OutputFile $null
            $DetailsEvidence = Get-ToAnalyzeFileEvidence -Label "Details" -Path $Details -OutputFile $null
            Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber file evidence completed."

            $FileEvidenceLines = New-Object System.Collections.Generic.List[string]
            foreach ($Evidence in @($ImageEvidence, $TargetEvidence, $ParentEvidence, $DetailsEvidence)) {
                $FileEvidenceLines.Add("===== $($Evidence.Label) =====")
                $FileEvidenceLines.Add("Path: $($Evidence.Path)")
                $FileEvidenceLines.Add("Exists: $($Evidence.Exists)")
                $FileEvidenceLines.Add("Length: $($Evidence.Length)")
                $FileEvidenceLines.Add("CreationTime: $($Evidence.CreationTime)")
                $FileEvidenceLines.Add("LastWriteTime: $($Evidence.LastWriteTime)")
                $FileEvidenceLines.Add("SHA256: $($Evidence.SHA256)")
                $FileEvidenceLines.Add("HashMethod: $($Evidence.HashMethod)")
                $FileEvidenceLines.Add("Error: $($Evidence.Error)")
                $FileEvidenceLines.Add("")
            }
            $FileEvidenceLines | Out-File -FilePath $FileEvidenceFile -Encoding UTF8

            Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber autorun correlation started."
            $AutorunTerms = Get-ToAnalyzeAutorunTerms -Row $Row
            $AutorunResult = Search-ToAnalyzeAutoruns -AutoCsvFile $AutoCsvFile -AutoTxtFile $AutoTxtFile -Terms $AutorunTerms -OutputFile $AutorunMatchesFile
            Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber autorun correlation completed: Status=$($AutorunResult.Status) MatchCount=$($AutorunResult.MatchCount)"

            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolderName" -Value $FolderName -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolder" -Value $AlertFolder -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "EventToAnalyzeFolderName" -Value $EventFolderName -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "EventToAnalyzeFolder" -Value $EventFolder -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "RawEventXmlFile" -Value $RawXmlFile -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ProcessGuidTimelineFile" -Value $TimelineFile -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "NearbyRecordWindowFile" -Value $NearbyFile -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "InvestigationCommandsFile" -Value $CommandsFile -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "FileEvidenceFile" -Value $FileEvidenceFile -Force

            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ImageFileExists" -Value $ImageEvidence.Exists -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ImageFileLength" -Value $ImageEvidence.Length -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ImageFileCreationTime" -Value $ImageEvidence.CreationTime -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ImageFileLastWriteTime" -Value $ImageEvidence.LastWriteTime -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ImageFileSHA256" -Value $ImageEvidence.SHA256 -Force

            Add-Member -InputObject $Row -MemberType NoteProperty -Name "TargetFileExists" -Value $TargetEvidence.Exists -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "TargetFileLength" -Value $TargetEvidence.Length -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "TargetFileCreationTime" -Value $TargetEvidence.CreationTime -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "TargetFileLastWriteTime" -Value $TargetEvidence.LastWriteTime -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "TargetFileSHA256" -Value $TargetEvidence.SHA256 -Force

            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ParentImageFileExists" -Value $ParentEvidence.Exists -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ParentImageFileSHA256" -Value $ParentEvidence.SHA256 -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "DetailsFileExists" -Value $DetailsEvidence.Exists -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "DetailsFileSHA256" -Value $DetailsEvidence.SHA256 -Force

            Add-Member -InputObject $Row -MemberType NoteProperty -Name "AutorunCsvFile" -Value $AutoCsvFile -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "AutorunTxtFile" -Value $AutoTxtFile -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "AutorunSearchTerms" -Value $AutorunResult.Terms -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "AutorunSearchStatus" -Value $AutorunResult.Status -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "AutorunMatchCount" -Value $AutorunResult.MatchCount -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "AutorunMatchesFile" -Value $AutorunResult.MatchesFile -Force

            $SummaryLines.Add("## Event $EventNumber")
            $SummaryLines.Add("EventID: $EventId")
            $SummaryLines.Add("RecordID: $RecordId")
            $SummaryLines.Add("ProcessGuid: $ProcessGuid")
            $SummaryLines.Add("Image: $Image")
            $SummaryLines.Add("TargetFilename: $TargetFilename")
            $SummaryLines.Add("EventFolder: $EventFolder")
            $SummaryLines.Add("RawEventXmlFile: $RawXmlFile")
            $SummaryLines.Add("ProcessGuidTimelineFile: $TimelineFile")
            $SummaryLines.Add("NearbyRecordWindowFile: $NearbyFile")
            $SummaryLines.Add("FileEvidenceFile: $FileEvidenceFile")
            $SummaryLines.Add("AutorunMatchesFile: $AutorunMatchesFile")
            $SummaryLines.Add("AutorunSearchStatus: $($AutorunResult.Status)")
            $SummaryLines.Add("AutorunMatchCount: $($AutorunResult.MatchCount)")
            $SummaryLines.Add("")
            Write-DebugLine "$(Get-LineNumber)ToAnalyze Event $EventNumber completed: EventFolder=$EventFolder"
        }

        $SummaryFile = Join-Path $AlertFolder "ToAnalyze_Summary.md"
        $SummaryLines | Out-File -FilePath $SummaryFile -Encoding UTF8

        foreach ($Row in $Rows) {
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeSummaryFile" -Value $SummaryFile -Force
        }
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)ToAnalyze evidence pack failed: $($_.Exception.Message)"

        foreach ($Row in $Rows) {
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolderName" -Value "FAILED" -Force
            Add-Member -InputObject $Row -MemberType NoteProperty -Name "ToAnalyzeAlertFolder" -Value "FAILED: $($_.Exception.Message)" -Force
        }
    }

    return $Rows
}


# Service-context enrichment functions for svchost.exe / service-hosted PIDs.
function Write-ServiceContextLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $null
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $Line = "[$Time][$Level] $Message"

    if ($LogFile -and $LogFile.Trim().Length -gt 0) {
        try {
            $Folder = Split-Path -Path $LogFile -Parent
            if ($Folder -and -not (Test-Path -Path $Folder)) {
                New-Item -ItemType Directory -Path $Folder -Force | Out-Null
            }

            Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        }
        catch {
            # Do not break the monitor because logging failed.
        }
    }
}

function Enter-ServiceContextFunction {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$LogFile = $null
    )

    Write-ServiceContextLog -Message ("Entering " + $Name) -LogFile $LogFile
}

function Exit-ServiceContextFunction {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string]$LogFile = $null
    )

    Write-ServiceContextLog -Message ("Exiting " + $Name) -LogFile $LogFile
}

function Convert-ServiceContextValue {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return "N/A"
    }

    if ($Value -is [array]) {
        if ($Value.Count -eq 0) {
            return "N/A"
        }

        return ($Value -join "; ")
    }

    $Text = [string]$Value

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "N/A"
    }

    return $Text
}

function Get-ServiceContextByPid {
    param(
        [Parameter(Mandatory=$true)][int]$ProcessId,
        [string]$Image = "N/A",
        [string]$ProcessGuid = "N/A",
        [string]$EventUtcTime = "N/A",
        [string]$LogFile = $null
    )

    Enter-ServiceContextFunction -Name "Get-ServiceContextByPid" -LogFile $LogFile

    Write-ServiceContextLog -Message ("Input ProcessId=" + $ProcessId) -LogFile $LogFile
    Write-ServiceContextLog -Message ("Input Image=" + $Image) -LogFile $LogFile
    Write-ServiceContextLog -Message ("Input ProcessGuid=" + $ProcessGuid) -LogFile $LogFile
    Write-ServiceContextLog -Message ("Input EventUtcTime=" + $EventUtcTime) -LogFile $LogFile

    $CaptureLocal = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $Status = "Unknown"
    $ProcessName = "N/A"
    $ExecutablePath = "N/A"
    $CommandLine = "N/A"
    $ParentProcessId = "N/A"
    $ServiceNames = @()
    $ServiceDisplayNames = @()
    $ServiceStates = @()
    $ServiceStartModes = @()
    $ServiceStartNames = @()
    $ServicePathNames = @()
    $TaskListRaw = "N/A"

    try {
        $Process = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $ProcessId) -ErrorAction SilentlyContinue

        if ($null -eq $Process) {
            $Status = "ProcessNotFound"
            Write-ServiceContextLog -Message "Process was not found. PID may have exited or been reused." -Level "WARN" -LogFile $LogFile
        }
        else {
            $Status = "ProcessFound"
            $ProcessName = Convert-ServiceContextValue $Process.Name
            $ExecutablePath = Convert-ServiceContextValue $Process.ExecutablePath
            $CommandLine = Convert-ServiceContextValue $Process.CommandLine
            $ParentProcessId = Convert-ServiceContextValue $Process.ParentProcessId

            Write-ServiceContextLog -Message ("ProcessName=" + $ProcessName) -LogFile $LogFile
            Write-ServiceContextLog -Message ("ExecutablePath=" + $ExecutablePath) -LogFile $LogFile
            Write-ServiceContextLog -Message ("ParentProcessId=" + $ParentProcessId) -LogFile $LogFile
        }

        $Services = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProcessId -eq $ProcessId
            })

        Write-ServiceContextLog -Message ("Services in PID count=" + $Services.Count) -LogFile $LogFile

        if ($Services.Count -gt 0) {
            foreach ($Svc in $Services) {
                $ServiceNames += (Convert-ServiceContextValue $Svc.Name)
                $ServiceDisplayNames += (Convert-ServiceContextValue $Svc.DisplayName)
                $ServiceStates += ((Convert-ServiceContextValue $Svc.Name) + "=" + (Convert-ServiceContextValue $Svc.State))
                $ServiceStartModes += ((Convert-ServiceContextValue $Svc.Name) + "=" + (Convert-ServiceContextValue $Svc.StartMode))
                $ServiceStartNames += ((Convert-ServiceContextValue $Svc.Name) + "=" + (Convert-ServiceContextValue $Svc.StartName))
                $ServicePathNames += ((Convert-ServiceContextValue $Svc.Name) + "=" + (Convert-ServiceContextValue $Svc.PathName))
            }
        }

        try {
            $TaskListRawLines = @(cmd.exe /c ("tasklist /svc /fi ""PID eq " + $ProcessId + """") 2>&1)
            $TaskListRaw = Convert-ServiceContextValue ($TaskListRawLines -join " | ")
        }
        catch {
            $TaskListRaw = "tasklist failed: " + $_.Exception.Message
        }
    }
    catch {
        $Status = "Error"
        Write-ServiceContextLog -Message ("Error while collecting service context: " + $_.Exception.Message) -Level "ERROR" -LogFile $LogFile
    }

    $IsSvchostImage = "False"

    if ($Image -match "\\svchost\.exe$" -or $ProcessName -ieq "svchost.exe") {
        $IsSvchostImage = "True"
    }

    $Result = [PSCustomObject]@{
        ServiceContextCaptureLocal = $CaptureLocal
        ServiceContextStatus       = $Status
        ServiceContextIsSvchost    = $IsSvchostImage
        ServiceContextProcessName  = $ProcessName
        ServiceContextExePath      = $ExecutablePath
        ServiceContextCommandLine  = $CommandLine
        ServiceContextParentPid    = $ParentProcessId
        ServiceContextServiceCount = $Services.Count
        ServiceContextServiceNames = Convert-ServiceContextValue $ServiceNames
        ServiceContextDisplayNames = Convert-ServiceContextValue $ServiceDisplayNames
        ServiceContextStates       = Convert-ServiceContextValue $ServiceStates
        ServiceContextStartModes   = Convert-ServiceContextValue $ServiceStartModes
        ServiceContextStartNames   = Convert-ServiceContextValue $ServiceStartNames
        ServiceContextPathNames    = Convert-ServiceContextValue $ServicePathNames
        ServiceContextTaskListSvc  = $TaskListRaw
    }

    Exit-ServiceContextFunction -Name "Get-ServiceContextByPid" -LogFile $LogFile
    return $Result
}

function Add-ServiceContextToRow {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [string]$LogFile = $null
    )

    Enter-ServiceContextFunction -Name "Add-ServiceContextToRow" -LogFile $LogFile

    $PidText = Convert-ServiceContextValue $Row.ProcessId
    $Image = Convert-ServiceContextValue $Row.Image
    $ProcessGuid = Convert-ServiceContextValue $Row.ProcessGuid
    $UtcTime = Convert-ServiceContextValue $Row.UtcTime

    Write-ServiceContextLog -Message ("Row ProcessId=" + $PidText) -LogFile $LogFile
    Write-ServiceContextLog -Message ("Row Image=" + $Image) -LogFile $LogFile

    $PidNumber = 0
    $PidOk = [int]::TryParse($PidText, [ref]$PidNumber)

    if (-not $PidOk -or $PidNumber -le 0) {
        Write-ServiceContextLog -Message "Row has no valid ProcessId. Adding N/A service context." -Level "WARN" -LogFile $LogFile

        $Context = [PSCustomObject]@{
            ServiceContextCaptureLocal = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            ServiceContextStatus       = "NoValidPid"
            ServiceContextIsSvchost    = "N/A"
            ServiceContextProcessName  = "N/A"
            ServiceContextExePath      = "N/A"
            ServiceContextCommandLine  = "N/A"
            ServiceContextParentPid    = "N/A"
            ServiceContextServiceCount = 0
            ServiceContextServiceNames = "N/A"
            ServiceContextDisplayNames = "N/A"
            ServiceContextStates       = "N/A"
            ServiceContextStartModes   = "N/A"
            ServiceContextStartNames   = "N/A"
            ServiceContextPathNames    = "N/A"
            ServiceContextTaskListSvc  = "N/A"
        }
    }
    else {
        $Context = Get-ServiceContextByPid -ProcessId $PidNumber -Image $Image -ProcessGuid $ProcessGuid -EventUtcTime $UtcTime -LogFile $LogFile
    }

    foreach ($Prop in $Context.PSObject.Properties) {
        if ($Row.PSObject.Properties.Name -contains $Prop.Name) {
            $Row.$($Prop.Name) = $Prop.Value
        }
        else {
            Add-Member -InputObject $Row -MemberType NoteProperty -Name $Prop.Name -Value $Prop.Value -Force
        }
    }

    Exit-ServiceContextFunction -Name "Add-ServiceContextToRow" -LogFile $LogFile
    return $Row
}

function Add-ServiceContextToReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)][string]$OutputFolder,
        [Parameter(Mandatory=$true)][string]$AlertTime
    )

    $LogFile = Join-Path $OutputFolder ("ServiceContext_" + $AlertTime + ".log")
    $CsvFile = Join-Path $OutputFolder ("ServiceContext_" + $AlertTime + ".csv")
    $TxtFile = Join-Path $OutputFolder ("ServiceContext_" + $AlertTime + ".txt")

    Enter-ServiceContextFunction -Name "Add-ServiceContextToReport" -LogFile $LogFile

    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $Rows = @($Report)
    Write-ServiceContextLog -Message ("Report row count=" + $Rows.Count) -LogFile $LogFile

    $EnrichedRows = @()

    foreach ($Row in $Rows) {
        $EnrichedRows += Add-ServiceContextToRow -Row $Row -LogFile $LogFile
    }

    try {
        $EnrichedRows |
        Select-Object TimeCreatedLocal, UtcTime, EventID, RecordID, RuleName, EventType, User, ProcessId, Image,
            ServiceContextCaptureLocal,
            ServiceContextStatus,
            ServiceContextIsSvchost,
            ServiceContextProcessName,
            ServiceContextExePath,
            ServiceContextCommandLine,
            ServiceContextParentPid,
            ServiceContextServiceCount,
            ServiceContextServiceNames,
            ServiceContextDisplayNames,
            ServiceContextStates,
            ServiceContextStartModes,
            ServiceContextStartNames,
            ServiceContextPathNames,
            ServiceContextTaskListSvc,
            TargetObject |
        Export-Csv -Path $CsvFile -NoTypeInformation -Encoding UTF8

        $EnrichedRows |
        Format-List TimeCreatedLocal, UtcTime, EventID, RecordID, RuleName, EventType, User, ProcessId, Image,
            ServiceContextCaptureLocal,
            ServiceContextStatus,
            ServiceContextIsSvchost,
            ServiceContextProcessName,
            ServiceContextExePath,
            ServiceContextCommandLine,
            ServiceContextParentPid,
            ServiceContextServiceCount,
            ServiceContextServiceNames,
            ServiceContextDisplayNames,
            ServiceContextStates,
            ServiceContextStartModes,
            ServiceContextStartNames,
            ServiceContextPathNames,
            ServiceContextTaskListSvc,
            TargetObject |
        Out-File -FilePath $TxtFile -Encoding UTF8

        Write-ServiceContextLog -Message ("Saved CSV: " + $CsvFile) -LogFile $LogFile
        Write-ServiceContextLog -Message ("Saved TXT: " + $TxtFile) -LogFile $LogFile
    }
    catch {
        Write-ServiceContextLog -Message ("Failed to save service context evidence: " + $_.Exception.Message) -Level "ERROR" -LogFile $LogFile
    }

    Exit-ServiceContextFunction -Name "Add-ServiceContextToReport" -LogFile $LogFile
    return $EnrichedRows
}


# Sysmon config-load and clipboard evidence enrichment functions.
function Resolve-SysmonMonitorExe {
    param(
        [string]$LogFile = $null
    )

    if (Test-Path -Path $TrustedSysmonExe) {
        return $TrustedSysmonExe
    }

    if (Test-Path -Path $FallbackSysmonExe) {
        return $FallbackSysmonExe
    }

    return $null
}

function Get-HashValueFromSysmonHashField {
    param(
        [string]$Hashes,
        [string]$Algorithm
    )

    if ([string]::IsNullOrWhiteSpace($Hashes)) {
        return "N/A"
    }

    $Pattern = "(?i)(^|,)\s*" + [regex]::Escape($Algorithm) + "=([0-9a-f]+)"
    $Match = [regex]::Match($Hashes, $Pattern)

    if ($Match.Success) {
        return $Match.Groups[2].Value.ToUpperInvariant()
    }

    return "N/A"
}

function Get-StringSha256Hex {
    param(
        [AllowNull()][string]$Text
    )

    if ($null -eq $Text) {
        $Text = ""
    }

    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $Sha = [System.Security.Cryptography.SHA256]::Create()

    try {
        return (($Sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("X2") }) -join "")
    }
    finally {
        $Sha.Dispose()
    }
}

function Get-FileSha256ViaCertutil {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$OutFile = $null
    )

    $Result = [PSCustomObject]@{
        Status = "Unknown"
        Hash   = "N/A"
        Raw    = "N/A"
    }

    if (-not (Test-Path -Path $Path)) {
        $Result.Status = "FileNotFound"
        $Result.Raw = "File not found: $Path"
        return $Result
    }

    try {
        $RawLines = @(certutil -hashfile $Path SHA256 2>&1)
        $RawText = $RawLines -join "`r`n"

        if ($OutFile) {
            $Folder = Split-Path -Path $OutFile -Parent
            if ($Folder -and -not (Test-Path -Path $Folder)) {
                New-Item -ItemType Directory -Path $Folder -Force | Out-Null
            }

            $RawText | Out-File -FilePath $OutFile -Encoding UTF8
        }

        $Match = [regex]::Match($RawText, "(?im)^[0-9a-f]{64}$")

        if ($Match.Success) {
            $Result.Status = "OK"
            $Result.Hash = $Match.Value.ToUpperInvariant()
        }
        else {
            $Result.Status = "HashNotParsed"
        }

        $Result.Raw = $RawText
    }
    catch {
        $Result.Status = "Error"
        $Result.Raw = $_.Exception.Message
    }

    return $Result
}

function Get-ConfigLoadContextByRow {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)][string]$OutputFolder,
        [Parameter(Mandatory=$true)][string]$AlertTime,
        [string]$LogFile = $null
    )

    $CaptureLocal = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $EventId = Get-ReportValue -Row $Row -Name "EventID"

    $Context = [PSCustomObject]@{
        ConfigLoadCaptureLocal             = $CaptureLocal
        ConfigLoadStatus                   = "NotEvent16"
        ConfigLoadEventConfigPath          = "N/A"
        ConfigLoadEventHash                = "N/A"
        ConfigLoadDiskHash                 = "N/A"
        ConfigLoadHashMatchesEvent         = "N/A"
        ConfigLoadSysmonExe                = "N/A"
        ConfigLoadArchiveDirectoryReported = "N/A"
        ConfigLoadSummaryFile              = "N/A"
        ConfigLoadHashFile                 = "N/A"
    }

    if ([string]$EventId -ne "16") {
        return $Context
    }

    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $Context.ConfigLoadStatus = "Event16Detected"

    $ConfigPathFromEvent = Get-ReportValue -Row $Row -Name "Configuration"
    $HashFromEvent = Get-ReportValue -Row $Row -Name "ConfigurationFileHash"

    if ($ConfigPathFromEvent -eq "N/A") {
        $ConfigPathFromEvent = $ExpectedSysmonConfigPath
    }

    $Context.ConfigLoadEventConfigPath = $ConfigPathFromEvent
    $Context.ConfigLoadEventHash = $HashFromEvent

    $SafeRecord = Get-ReportValue -Row $Row -Name "RecordID"
    $SummaryFile = Join-Path $OutputFolder ("ConfigLoad_SysmonSummary_" + $AlertTime + "_Record_" + $SafeRecord + ".txt")
    $HashFile = Join-Path $OutputFolder ("ConfigLoad_ConfigHash_" + $AlertTime + "_Record_" + $SafeRecord + ".txt")

    $Context.ConfigLoadSummaryFile = $SummaryFile
    $Context.ConfigLoadHashFile = $HashFile

    $SysmonExe = Resolve-SysmonMonitorExe -LogFile $LogFile
    $Context.ConfigLoadSysmonExe = Convert-ServiceContextValue $SysmonExe

    if ($SysmonExe) {
        try {
            & $SysmonExe -c 2>&1 | Out-File -FilePath $SummaryFile -Encoding UTF8
            $SummaryText = Get-Content -Path $SummaryFile -Raw -ErrorAction SilentlyContinue

            $ArchiveMatch = [regex]::Match($SummaryText, "(?im)Archive Directory:\s*(.+)$")

            if ($ArchiveMatch.Success) {
                $Context.ConfigLoadArchiveDirectoryReported = $ArchiveMatch.Groups[1].Value.Trim()
            }
            else {
                $Context.ConfigLoadArchiveDirectoryReported = "NotFoundInSummary"
            }
        }
        catch {
            $Context.ConfigLoadArchiveDirectoryReported = "SysmonSummaryError: " + $_.Exception.Message
        }
    }
    else {
        "No Sysmon executable found." | Out-File -FilePath $SummaryFile -Encoding UTF8
        $Context.ConfigLoadArchiveDirectoryReported = "NoSysmonExe"
    }

    $HashResult = Get-FileSha256ViaCertutil -Path $ConfigPathFromEvent -OutFile $HashFile
    $Context.ConfigLoadDiskHash = $HashResult.Hash

    $EventHashClean = $HashFromEvent -replace "(?i)^SHA256=", ""
    $EventHashClean = $EventHashClean.Trim().ToUpperInvariant()

    if ($HashResult.Hash -ne "N/A" -and $EventHashClean -match "^[0-9A-F]{64}$") {
        if ($HashResult.Hash.ToUpperInvariant() -eq $EventHashClean) {
            $Context.ConfigLoadHashMatchesEvent = "True"
        }
        else {
            $Context.ConfigLoadHashMatchesEvent = "False"
        }
    }
    else {
        $Context.ConfigLoadHashMatchesEvent = "NotComparable"
    }

    return $Context
}

function Add-ConfigLoadContextToReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)][string]$OutputFolder,
        [Parameter(Mandatory=$true)][string]$AlertTime
    )

    $LogFile = Join-Path $OutputFolder ("ConfigLoadContext_" + $AlertTime + ".log")

    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $Rows = @($Report)
    $EnrichedRows = @()

    foreach ($Row in $Rows) {
        $Context = Get-ConfigLoadContextByRow -Row $Row -OutputFolder $OutputFolder -AlertTime $AlertTime -LogFile $LogFile

        foreach ($Prop in $Context.PSObject.Properties) {
            if ($Row.PSObject.Properties.Name -contains $Prop.Name) {
                $Row.$($Prop.Name) = $Prop.Value
            }
            else {
                Add-Member -InputObject $Row -MemberType NoteProperty -Name $Prop.Name -Value $Prop.Value -Force
            }
        }

        $EnrichedRows += $Row
    }

    return $EnrichedRows
}

function Ensure-ClipboardOwnerType {
    $ExistingType = "SysmonMonitorClipboardOwnerUtil" -as [type]

    if ($null -ne $ExistingType) {
        return
    }

    Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class SysmonMonitorClipboardOwnerUtil {
    [DllImport("user32.dll")]
    public static extern IntPtr GetOpenClipboardWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}
"@
}

function Get-ClipboardOwnerSnapshot {
    $Result = [PSCustomObject]@{
        OwnerProcessId      = "N/A"
        OwnerProcessName    = "N/A"
        OwnerProcessPath    = "N/A"
        OwnerWindowTitle    = "N/A"
        OwnerStatus         = "Unknown"
    }

    try {
        Ensure-ClipboardOwnerType

        $hWnd = [SysmonMonitorClipboardOwnerUtil]::GetOpenClipboardWindow()

        if ($hWnd -eq [IntPtr]::Zero) {
            $Result.OwnerStatus = "NoOpenClipboardWindow"
            return $Result
        }

        $PidNumber = 0
        [void][SysmonMonitorClipboardOwnerUtil]::GetWindowThreadProcessId($hWnd, [ref]$PidNumber)

        $Title = New-Object System.Text.StringBuilder 512
        [void][SysmonMonitorClipboardOwnerUtil]::GetWindowText($hWnd, $Title, $Title.Capacity)

        $Result.OwnerProcessId = [string]$PidNumber
        $Result.OwnerWindowTitle = $Title.ToString()
        $Result.OwnerStatus = "OpenClipboardWindowFound"

        $Proc = Get-Process -Id $PidNumber -ErrorAction SilentlyContinue

        if ($Proc) {
            $Result.OwnerProcessName = Convert-ServiceContextValue $Proc.ProcessName

            try {
                $Result.OwnerProcessPath = Convert-ServiceContextValue $Proc.Path
            }
            catch {
                $Result.OwnerProcessPath = "PathAccessError: " + $_.Exception.Message
            }
        }
    }
    catch {
        $Result.OwnerStatus = "Error: " + $_.Exception.Message
    }

    return $Result
}

function Search-ClipboardArchiveByHash {
    param(
        [string]$Sha256,
        [string]$Md5,
        [Parameter(Mandatory=$true)][string]$OutputFolder,
        [Parameter(Mandatory=$true)][string]$AlertTime,
        [string]$RecordId = "N/A"
    )

    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $OutFile = Join-Path $OutputFolder ("ClipboardArchiveSearch_" + $AlertTime + "_Record_" + $RecordId + ".txt")
    $Roots = @("C:\Sysmon", "C:\SysmonArchive", "Z:\Sysmon", "Z:\SysmonArchive")
    $Needles = @()

    if ($Sha256 -and $Sha256 -ne "N/A") {
        $Needles += $Sha256
    }

    if ($Md5 -and $Md5 -ne "N/A") {
        $Needles += $Md5
    }

    $Found = @()

    "=== Clipboard archive search ===" | Out-File -FilePath $OutFile -Encoding UTF8
    "AlertTime: $AlertTime" | Out-File -FilePath $OutFile -Append -Encoding UTF8
    "RecordId: $RecordId" | Out-File -FilePath $OutFile -Append -Encoding UTF8
    "SHA256: $Sha256" | Out-File -FilePath $OutFile -Append -Encoding UTF8
    "MD5: $Md5" | Out-File -FilePath $OutFile -Append -Encoding UTF8
    "" | Out-File -FilePath $OutFile -Append -Encoding UTF8

    foreach ($Root in $Roots) {
        "=== Root: $Root ===" | Out-File -FilePath $OutFile -Append -Encoding UTF8

        try {
            $Exists = Test-Path -Path $Root
            "Exists: $Exists" | Out-File -FilePath $OutFile -Append -Encoding UTF8

            if ($Exists) {
                $Files = @(Get-ChildItem -Path $Root -Recurse -Force -File -ErrorAction Stop)

                foreach ($File in $Files) {
                    foreach ($Needle in $Needles) {
                        if ($File.Name -match [regex]::Escape($Needle) -or $File.FullName -match [regex]::Escape($Needle)) {
                            $Found += $File.FullName
                            ("MATCH: " + $File.FullName) | Out-File -FilePath $OutFile -Append -Encoding UTF8
                        }
                    }
                }

                if ($Files.Count -eq 0) {
                    "No files listed." | Out-File -FilePath $OutFile -Append -Encoding UTF8
                }
            }
        }
        catch {
            "Access/List error: $($_.Exception.Message)" | Out-File -FilePath $OutFile -Append -Encoding UTF8
        }

        "" | Out-File -FilePath $OutFile -Append -Encoding UTF8
    }

    if ($Found.Count -gt 0) {
        return [PSCustomObject]@{
            Status  = "Found"
            Matches = ($Found -join "; ")
            File    = $OutFile
        }
    }

    return [PSCustomObject]@{
        Status  = "NotFoundOrNotAccessible"
        Matches = "N/A"
        File    = $OutFile
    }
}

function Get-ClipboardEvidenceContextByRow {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)][string]$OutputFolder,
        [Parameter(Mandatory=$true)][string]$AlertTime,
        [string]$LogFile = $null
    )

    $CaptureLocal = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $EventId = Get-ReportValue -Row $Row -Name "EventID"

    $Context = [PSCustomObject]@{
        ClipboardEvidenceCaptureLocal           = $CaptureLocal
        ClipboardEvidenceStatus                 = "NotEvent24"
        ClipboardScanTimeContainsText           = "N/A"
        ClipboardScanTimeTextLength             = "N/A"
        ClipboardScanTimeTextSHA256      = "N/A"
        ClipboardEvidenceEventSHA256            = "N/A"
        ClipboardEvidenceEventMD5               = "N/A"
        ClipboardScanTimeHashMatchesEvent = "N/A"
        ClipboardScanTimeTextPreview     = "N/A"
        ClipboardScanTimeTextFile        = "N/A"
        ClipboardEvidenceOwnerProcessId         = "N/A"
        ClipboardEvidenceOwnerProcessName       = "N/A"
        ClipboardEvidenceOwnerProcessPath       = "N/A"
        ClipboardEvidenceOwnerWindowTitle       = "N/A"
        ClipboardEvidenceArchiveSearchStatus    = "N/A"
        ClipboardEvidenceArchiveMatches         = "N/A"
        ClipboardEvidenceArchiveSearchFile      = "N/A"
    }

    if ([string]$EventId -ne "24") {
        return $Context
    }

    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $RecordId = Get-ReportValue -Row $Row -Name "RecordID"
    $Hashes = Get-ReportValue -Row $Row -Name "Hashes"
    $EventSha256 = Get-HashValueFromSysmonHashField -Hashes $Hashes -Algorithm "SHA256"
    $EventMd5 = Get-HashValueFromSysmonHashField -Hashes $Hashes -Algorithm "MD5"

    $Context.ClipboardEvidenceStatus = "Event24Detected"
    $Context.ClipboardEvidenceEventSHA256 = $EventSha256
    $Context.ClipboardEvidenceEventMD5 = $EventMd5

    $Owner = Get-ClipboardOwnerSnapshot
    $Context.ClipboardEvidenceOwnerProcessId = $Owner.OwnerProcessId
    $Context.ClipboardEvidenceOwnerProcessName = $Owner.OwnerProcessName
    $Context.ClipboardEvidenceOwnerProcessPath = $Owner.OwnerProcessPath
    $Context.ClipboardEvidenceOwnerWindowTitle = $Owner.OwnerWindowTitle

    try {
        $ContainsText = [System.Windows.Forms.Clipboard]::ContainsText()
        $Context.ClipboardScanTimeContainsText = [string]$ContainsText

        if ($ContainsText) {
            $ClipText = [System.Windows.Forms.Clipboard]::GetText()
            $TextFile = Join-Path $OutputFolder ("ClipboardText_" + $AlertTime + "_Record_" + $RecordId + ".txt")
            $ClipText | Out-File -FilePath $TextFile -Encoding UTF8

            $Context.ClipboardScanTimeTextFile = $TextFile
            $Context.ClipboardScanTimeTextLength = [string]$ClipText.Length
            $Context.ClipboardScanTimeTextSHA256 = Get-StringSha256Hex -Text $ClipText

            if ($ClipText.Length -gt 500) {
                $Context.ClipboardScanTimeTextPreview = $ClipText.Substring(0, 500) + "[TRUNCATED]"
            }
            else {
                $Context.ClipboardScanTimeTextPreview = $ClipText
            }

            if ($EventSha256 -ne "N/A") {
                if ($Context.ClipboardScanTimeTextSHA256 -eq $EventSha256) {
                    $Context.ClipboardScanTimeHashMatchesEvent = "True"
                }
                else {
                    $Context.ClipboardScanTimeHashMatchesEvent = "False"
                }
            }
            else {
                $Context.ClipboardScanTimeHashMatchesEvent = "NoEventSHA256"
            }
        }
        else {
            $Context.ClipboardEvidenceStatus = "Event24Detected_NoCurrentText"
        }
    }
    catch {
        $Context.ClipboardEvidenceStatus = "ClipboardReadError: " + $_.Exception.Message
    }

    $ArchiveSearch = Search-ClipboardArchiveByHash -Sha256 $EventSha256 -Md5 $EventMd5 -OutputFolder $OutputFolder -AlertTime $AlertTime -RecordId $RecordId
    $Context.ClipboardEvidenceArchiveSearchStatus = $ArchiveSearch.Status
    $Context.ClipboardEvidenceArchiveMatches = $ArchiveSearch.Matches
    $Context.ClipboardEvidenceArchiveSearchFile = $ArchiveSearch.File

    return $Context
}

function Add-ClipboardEvidenceContextToReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)][string]$OutputFolder,
        [Parameter(Mandatory=$true)][string]$AlertTime
    )

    $LogFile = Join-Path $OutputFolder ("ClipboardEvidenceContext_" + $AlertTime + ".log")

    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    }

    $Rows = @($Report)
    $EnrichedRows = @()

    foreach ($Row in $Rows) {
        $Context = Get-ClipboardEvidenceContextByRow -Row $Row -OutputFolder $OutputFolder -AlertTime $AlertTime -LogFile $LogFile

        foreach ($Prop in $Context.PSObject.Properties) {
            if ($Row.PSObject.Properties.Name -contains $Prop.Name) {
                $Row.$($Prop.Name) = $Prop.Value
            }
            else {
                Add-Member -InputObject $Row -MemberType NoteProperty -Name $Prop.Name -Value $Prop.Value -Force
            }
        }

        $EnrichedRows += $Row
    }

    return $EnrichedRows
}


# Ensure all target destination subdirectories exist automatically.
foreach ($Path in @($SysmonReal, $SysmonRealAuto, $SysmonRealTxt, $SysmonRealServiceContext, $SysmonRealConfigLoad, $SysmonRealClipboardEvidence, $SysmonRealToAnalyze)) {
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Write-DebugLine "$(Get-LineNumber)=== Sysmon Monitor Started ===" 
Write-DebugLine "$(Get-LineNumber)Using FilterHashtable EventID filtering and RecordID tracking... "
Write-DebugLine "$(Get-LineNumber)Checking every 5 minutes for suspicious activity... "
Write-DebugLine "$(Get-LineNumber)Press Q to exit cleanly, or Ctrl+C to force stop`n" 
function Write-SysmonStartupSanityLog {
    try {
        $StopFilePath = "Z:\InsPro\Tools\Stop-Sysmon-Monitor.flag"

        Write-DebugLine "$(Get-LineNumber)Startup sanity: ScriptPath=$PSCommandPath"
        Write-DebugLine "$(Get-LineNumber)Startup sanity: PID=$PID"
        Write-DebugLine "$(Get-LineNumber)Startup sanity: StopFilePath=$StopFilePath Exists=$(Test-Path -LiteralPath $StopFilePath)"

        $IntervalValue = "N/A"

        if (Get-Variable -Name MonitorIntervalSeconds -ErrorAction SilentlyContinue) {
            $IntervalValue = $MonitorIntervalSeconds
        }
        elseif (Get-Variable -Name MonitorInterval -ErrorAction SilentlyContinue) {
            $IntervalValue = $MonitorInterval
        }

        Write-DebugLine "$(Get-LineNumber)Startup sanity: MonitorIntervalSeconds=$IntervalValue"

        if ($SysmonLogName) {
            try {
                $LogInfo = Get-WinEvent -ListLog $SysmonLogName -ErrorAction Stop
                Write-DebugLine "$(Get-LineNumber)Startup sanity: SysmonLogName=$SysmonLogName Exists=True RecordCount=$($LogInfo.RecordCount)"
            }
            catch {
                Write-DebugLine "$(Get-LineNumber)Startup sanity: SysmonLogName=$SysmonLogName Exists=False Error=$($_.Exception.Message)"
            }
        }

        foreach ($VarName in @("SysmonReal","SysmonRealTxt","SysmonRealAuto","SysmonRealServiceContext","SysmonRealConfigLoad","SysmonRealClipboardEvidence","SysmonRealToAnalyze")) {
            $Var = Get-Variable -Name $VarName -ErrorAction SilentlyContinue

            if ($Var) {
                $Value = [string]$Var.Value
                Write-DebugLine "$(Get-LineNumber)Startup sanity: $VarName=$Value Exists=$(Test-Path -LiteralPath $Value)"
            }
        }

        $AutorunVar = Get-Variable -Name Autorun -ErrorAction SilentlyContinue

        if ($AutorunVar) {
            $AutorunPath = [string]$AutorunVar.Value
            Write-DebugLine "$(Get-LineNumber)Startup sanity: Autorun=$AutorunPath Exists=$(Test-Path -LiteralPath $AutorunPath)"
        }
    }
    catch {
        Write-DebugLine "$(Get-LineNumber)Startup sanity logging failed: $($_.Exception.Message)"
    }
}
Write-SysmonStartupSanityLog
$CheckFile = CheckPopupFileExist -File $statePath
if ($CheckFile -eq $true) {
	Write-DebugLine "$(Get-LineNumber)Deleting Popup File-$statePath." 
	Remove-Item -Path $statePath -ErrorAction SilentlyContinue -Force
	#Send-SysmonToast -Message "Sysmon Security Alert removing popup File." -Title "Warning"
}
$Result = StartMssg
Write-DebugLine "$(Get-LineNumber)StartMssg = $Result"
if ($Result -eq $false) {
	$DisplayPopup = $false
	Write-DebugLine "$(Get-LineNumber)Running without Displaying popup." 
	Send-SysmonToast -Message "Sysmon Security Alert Running without popup." -Title "Warning"
    
}else {
	$DisplayPopup = $true
	Write-DebugLine "$(Get-LineNumber)Running with Displaying popup." 
	Send-SysmonToast -Message "Sysmon Security Alert Running with popup." -Title "Warning"
}



# Seed the initial RecordID so the monitor does not scan old historical events on startup.
try {
    $InitialEvent = Get-WinEvent -LogName $SysmonLogName -MaxEvents 1 -ErrorAction SilentlyContinue

    if ($InitialEvent) {
        $Script:LastRecordId = $InitialEvent.RecordId
    }
}
catch {
    Write-DebugLine "$(Get-LineNumber)Initial RecordID seed failed: $($_.Exception.Message)" 

}
while ($true) {
    if ((Test-ExitKey) -or (Test-SysmonStopFileRequested)) {
        Write-Host "`nExit requested by user. Closing Sysmon Monitor." -ForegroundColor Yellow
        break
    }

    $CheckTime = Get-Date
    
    
    # CRITICAL FIX: Reset state tracking variables for this loop iteration
    $Set = $false 
	$CheckFile = CheckPopupFileExist -File $statePath
    if ($CheckFile -eq $true) {
        Write-DebugLine "$(Get-LineNumber)File Path = $statePath exists."
        
        # Read the file content cleanly and safely
        $FileContent = (Get-Content -Path $statePath -ErrorAction SilentlyContinue)
        
        if ($null -ne $FileContent) {
            # FIX: Added parentheses to .Trim() so it evaluates properly as a method
            if ($FileContent.ToString().Trim() -eq "SET") {
                $Set = $true
            }
            
            Write-DebugLine "$(Get-LineNumber)Set = $Set"
            
            if ($Set -eq $true) {
                $DisplayPopup = $true
                # Directly fires function inside this exact running instance!
                $Result = StartMssg 
                Write-DebugLine "$(Get-LineNumber)StartMssg from file loop = $Result"
                
                if ($Result -eq $false) {
                    $DisplayPopup = $false
                    Write-DebugLine "$(Get-LineNumber)Running without Displaying popup from file...." 
                }
            } else {
                Write-DebugLine "$(Get-LineNumber)File is missing SET content"
            }
            
            Write-DebugLine "$(Get-LineNumber)Removing file....$statePath" 
            Remove-Item -Path $statePath -ErrorAction SilentlyContinue -Force
        }
    }
    
    try {
        # ... Rest of your Get-WinEvent code logic continues down here completely unchanged ...
 
        $Filter = @{
            LogName = $SysmonLogName
            Id      = @(1, 3, 5, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 24)
        }

        $RawEvents = @(Get-WinEvent -FilterHashtable $Filter -MaxEvents $LastEventsCount -ErrorAction Stop)

        $NewCandidateEvents = @(
            $RawEvents | Where-Object {
                if ($Script:LastRecordId) {
                    $_.RecordId -gt $Script:LastRecordId
                }
                else {
                    $true
                }
            }
        )

        $Suspicious = @(
            $NewCandidateEvents | Where-Object {
                Test-SysmonEventSuspicious -Event $_
            }
        )

        if ($NewCandidateEvents) {
            $NewestSeenRecordId = ($NewCandidateEvents | Measure-Object -Property RecordId -Maximum).Maximum

            if ($NewestSeenRecordId -and ($NewestSeenRecordId -gt $Script:LastRecordId)) {
                $Script:LastRecordId = $NewestSeenRecordId
            }
        }

        if ($Suspicious -and $Suspicious.Count -gt 0) {
			$AlertTime = Get-Date -Format "yyyyMMdd_HHmmss"

			$SysName  = "Sysmon_Alert_${AlertTime}"
			$AutoName = "AutoRun_${AlertTime}"

			$SysFileName  = $SysName + $Ver
			$AutoFileName = $AutoName + $Ver
			
			$AlertStamp = $AlertTime + $Ver
			
			
			
			
			$ExportPath = Join-Path $SysmonReal ($SysFileName + ".csv")
			CheckTime = (Get-Date).AddMinutes(5)
			if($DisplayPopup -eq $true){
				Write-DebugLine "$(Get-LineNumber)`n[$CheckTime] ALERT: $($Suspicious.Count) new suspicious events detected, Displaying Popup! - Next check: $CheckTime" 
			} else{
				Write-DebugLine "$(Get-LineNumber)`n[$CheckTime] ALERT: $($Suspicious.Count) new suspicious events detected, Without Popup! - Next check: $CheckTime"
			}
			$Report = $Suspicious | ForEach-Object {
				Convert-SysmonEventToReportRow -Event $_
			}
			
			$Report = Add-ServiceContextToReport -Report $Report -OutputFolder $SysmonRealServiceContext -AlertTime $AlertTime
			$Report = Add-ConfigLoadContextToReport -Report $Report -OutputFolder $SysmonRealConfigLoad -AlertTime $AlertTime
			$Report = Add-ClipboardEvidenceContextToReport -Report $Report -OutputFolder $SysmonRealClipboardEvidence -AlertTime $AlertTime

			$AutoOut = "N/A"
			$AutoTxtOut = "N/A"

			Write-DebugLine "$(Get-LineNumber)Initializing ToAnalyze alert folder before popup for AlertStamp=$AlertStamp"
			$Report = Initialize-ToAnalyzeAlertStub -Report $Report -AlertTime $AlertStamp -OutputRoot $SysmonRealToAnalyze -AutoCsvFile $AutoOut -AutoTxtFile $AutoTxtOut

			# Write a lightweight CSV/TXT before popup so the alert has an immediate on-disk reference.
			try {
				$Report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
				ConvertCsvTxt -SysmonFile $SysFileName
			}
			catch {
				Write-DebugLine "$(Get-LineNumber)Pre-popup lightweight export failed: $($_.Exception.Message)"
			}

			# Popup decision hook.
			# Default remains true to preserve current behavior.
			# Later classification logic can set this to false for evidence-only events.
			#$DisplayPopup = $true
			$ToastToAnalyzeFolderName = "N/A"
			try {
				$FirstReportRowForToast = @($Report) | Select-Object -First 1
				if ($FirstReportRowForToast -and ($FirstReportRowForToast.PSObject.Properties.Name -contains "ToAnalyzeAlertFolderName")) {
					$ToastToAnalyzeFolderName = [string]$FirstReportRowForToast.ToAnalyzeAlertFolderName
				}
			}
			catch {
				$ToastToAnalyzeFolderName = "N/A"
			}
			Write-DebugLine "$(Get-LineNumber)Sending alert toast before heavy evidence. ToAnalyzeFolderName=$ToastToAnalyzeFolderName"
			if ( $DisplayPopup -eq $true  ) {
				Send-SysmonToast -Message ("Sysmon Security Alert. Popup ON -ToAnalyze folder: " + $ToastToAnalyzeFolderName) -Title "Warning"
			} else{
				Send-SysmonToast -Message ("Sysmon Security Alert. Popup OFF -ToAnalyze folder: " + $ToastToAnalyzeFolderName) -Title "Warning"
			}
			Start-Sleep -Seconds 10
			Write-DebugLine "$(Get-LineNumber)Calling Show-SysmonAlert before heavy evidence for AlertStamp=$AlertStamp"
			Show-SysmonAlert -Report $Report -EventCount $Suspicious.Count -AlertTime $AlertStamp | Out-Null
			Write-DebugLine "$(Get-LineNumber)Show-SysmonAlert returned before heavy evidence for AlertStamp=$AlertStamp"

			if (Test-Path -Path $Autorun) {
				try {
					Write-DebugLine "$(Get-LineNumber)Autoruns dump started after popup for AlertStamp=$AlertStamp"
					$AutoOut = Join-Path $SysmonRealAuto ($AutoFileName + ".csv")
					& $Autorun -accepteula -nobanner -a '*' -c | Out-File -FilePath $AutoOut -Encoding utf8
					ConvertCsvTxt -AutoFile $AutoFileName
					$AutoTxtOut = Join-Path $SysmonRealTxt ($AutoFileName + ".txt")
					Write-DebugLine "$(Get-LineNumber)Autoruns dump completed after popup for AlertStamp=$AlertStamp"
				}
				catch {
					Write-DebugLine "$(Get-LineNumber)Autoruns dump failed after popup: $($_.Exception.Message)"
				}
			}

			Write-DebugLine "$(Get-LineNumber)ToAnalyze evidence enrichment started after popup for AlertStamp=$AlertStamp EventCount=$($Suspicious.Count)"
			$Report = Add-ToAnalyzeEvidenceToReport -Report $Report -Events $Suspicious -AlertTime $AlertStamp -OutputRoot $SysmonRealToAnalyze -AutoCsvFile $AutoOut -AutoTxtFile $AutoTxtOut
			Write-DebugLine "$(Get-LineNumber)ToAnalyze evidence enrichment completed after popup for AlertStamp=$AlertStamp"

			$Report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
			ConvertCsvTxt -SysmonFile $SysFileName

			try {
				$FirstReportRow = @($Report) | Select-Object -First 1
				if ($FirstReportRow -and ($FirstReportRow.PSObject.Properties.Name -contains "ToAnalyzeAlertFolder")) {
					$ToAnalyzeCopyFolder = [string]$FirstReportRow.ToAnalyzeAlertFolder
					$ToAnalyzeSourceFiles = Join-Path $ToAnalyzeCopyFolder "SourceFiles"
					New-Item -ItemType Directory -Path $ToAnalyzeSourceFiles -Force | Out-Null
					if (Test-Path -LiteralPath $ExportPath) {
						Copy-Item -LiteralPath $ExportPath -Destination (Join-Path $ToAnalyzeSourceFiles (Split-Path -Path $ExportPath -Leaf)) -Force -ErrorAction SilentlyContinue
					}
					$SysTxtOut = Join-Path $SysmonRealTxt ($SysFileName + ".txt")
					if (Test-Path -LiteralPath $SysTxtOut) {
						Copy-Item -LiteralPath $SysTxtOut -Destination (Join-Path $ToAnalyzeSourceFiles (Split-Path -Path $SysTxtOut -Leaf)) -Force -ErrorAction SilentlyContinue
					}
				}
			}
			catch {
				Write-DebugLine "$(Get-LineNumber)ToAnalyze source file copy failed: $($_.Exception.Message)"
			}

			try {
				$PostEnrichmentPackage = New-SysmonClipboardReport -Report $Report -EventCount $Suspicious.Count -AlertTime $AlertStamp
				$PostEnrichmentPackageFile = Join-Path $SysmonRealTxt ("ClipboardPackage_" + $AlertStamp + "_AfterToAnalyze.md")
				$PostEnrichmentPackage | Out-File -FilePath $PostEnrichmentPackageFile -Encoding UTF8
				Write-DebugLine "$(Get-LineNumber)Post-ToAnalyze clipboard package saved: $PostEnrichmentPackageFile"
			}
			catch {
				Write-DebugLine "$(Get-LineNumber)Post-ToAnalyze clipboard package save failed: $($_.Exception.Message)"
			}
		}
		else {
			#Write-DebugLine "$(Get-LineNumber)[$($CheckTime.ToString('HH:mm:ss'))]Clean - No new suspicious activity" 
			if ( $DisplayPopup -eq $true  ) {
				$CheckTime = (Get-Date).AddMinutes(5)
				$Line = "Clean - No new suspicious activity with Popup - Next check: $CheckTime"
				#Send-SysmonToast -Message "Sysmon Security Alert with Popup - No new suspicious activity." -Title "Message"
			} else{
				$Line = "Clean - No new suspicious activity without popup- Next check: $CheckTime"
				#Send-SysmonToast -Message "Sysmon Security Alert without Popup - No new suspicious activity." -Title "Message"
			}
			Write-DebugLine "$(Get-LineNumber)$Line" 
		}
    }
    catch {
        #Write-DebugLine "$(Get-LineNumber)[$($CheckTime.ToString('HH:mm:ss'))] Error processing logs: $($_.Exception.Message)" 
		Write-DebugLine "$(Get-LineNumber) Error processing logs: $($_.Exception.Message)" 
    }

    $ShouldExit = Wait-MonitorIntervalWithExit -Seconds $MonitorIntervalSeconds

    if ($ShouldExit) {
        Write-DebugLine "$(Get-LineNumber)`nExit requested by user. Closing Sysmon Monitor." 
        break
    }
}

Write-DebugLine "$(Get-LineNumber)Sysmon Monitor safely stopped." 




