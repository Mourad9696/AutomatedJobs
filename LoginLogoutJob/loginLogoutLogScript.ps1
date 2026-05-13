# --------------------------------------------------------------------------------------------------
# POWERSHELL SCRIPT TO AUDIT SUCCESSFUL LOGIN/LOGOUT EVENTS FROM JSON LOGS (V39)
# - Extracts login/logout attempts from JSON logs and generates a clean audit file.
# - Logs ALL processing steps to the dedicated 'AuthJobLog' folder.
# --------------------------------------------------------------------------------------------------

# =================================================================
# CONFIGURATION SECTION
# =================================================================

# --- 1. LOGGING CONFIGURATION ---
$LogDirectoryName = "AuthJobLog"
$ExpectedScriptPath = "C:\VCXMonitoringJobs" # Expected path for Task Scheduler reliability

# --- 2. AUDIT CONFIGURATION ---
# Source logs, found in the path below, to extract the login and logout attempts.
$LogFilePattern = "E:\vcx\logs\app-log-*"

# The results will be dumped in the following below path
$OutputAuditFile = "E:\vcx\logs\user\login_audit.txt"

# DIAGNOSTIC CONFIGURATION: Path to dump failing lines for inspection.
$DiagnosticFile = "E:\logs\user\failed\diagnostic_failing_line.txt"

# =================================================================
# LOGGING FUNCTION DEFINITION (The bulletproof version)
# =================================================================

function Log-DailyEntry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    # Use $PSScriptRoot for manual runs, or fall back to hardcoded path for scheduled runs.
    $ScriptDirectory = if ($PSScriptRoot) {
        $PSScriptRoot
    } else {
        $ExpectedScriptPath
    }

    # Define the Log Paths
    $LogDirectory = Join-Path -Path $ScriptDirectory -ChildPath $LogDirectoryName
    $LogFilePath = Join-Path -Path $LogDirectory -ChildPath "AuthAuditLog_$(Get-Date -Format 'yyyy-MM-dd').txt"

    # Ensure log directory exists
    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"

    # Write to log file and to the host console (Task Scheduler history)
    Add-Content -Path $LogFilePath -Value $LogEntry
    Write-Host $LogEntry
}

# =================================================================
# MAIN LOGIC FUNCTION
# =================================================================

function Process-LogFile {

    & Log-DailyEntry "Starting login/logout audit job."

    # Ensure the output directory exists.
    $OutputDir = Split-Path -Parent $OutputAuditFile

    & Log-DailyEntry "Ensuring output directory structure exists at: $OutputDir"
    New-Item -Path $OutputDir -Type Directory -Force | Out-Null

    # Ensure Diagnostic file path exists
    $DiagDir = Split-Path -Parent $DiagnosticFile
    New-Item -Path $DiagDir -Type Directory -Force | Out-Null

    # 1. Prepare the output file with a header
    $CurrentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Header = @"

                                ==============================================================
                            =============== * V C X   A C C E S S   S U M M A R Y * ============
                                ==============================================================

APPLICATION LOGIN/LOGOUT AUDIT LOG
GENERATED: $CurrentTime
------------------------------------------------------------------------------------------
| TIMESTAMP | EVENT TYPE | USER ID | SOURCE IP | REQUEST URL |
|---------------------|------------|---------------------------|-----------|-------------|
"@
    # Write header and use UTF8 encoding
    $Header | Out-File -FilePath $OutputAuditFile -Force -Encoding UTF8

    # --- Session Tracker for UNKNOWN LOGOUTS ---
    $LastUserEmail = "UNKNOWN_USER"
    # --- DEDUPLICATION TRACKER ---
    $LastDedupeKey = ""
    # --- LOGIN ATTEMPT COUNTER ---
    $LoginAttempts = @{}
    # ---------------------------------

    # 2. Find and process log files
    & Log-DailyEntry "Searching for log files matching pattern: $LogFilePattern..."

    # Sorting by Name defaults to ASCENDING (oldest file first).
    $LogFiles = Get-ChildItem -Path $LogFilePattern | Sort-Object Name

    if (-not $LogFiles) {
        & Log-DailyEntry "WARNING: No log files found matching pattern: $LogFilePattern. Exiting job."
        return
    }

    # Clean up the diagnostic file before starting
    Remove-Item -Path $DiagnosticFile -ErrorAction SilentlyContinue | Out-Null
    & Log-DailyEntry "Found $($LogFiles.Count) log files. Starting processing. Malformed lines sent to $DiagnosticFile."

    foreach ($file in $LogFiles) {
        & Log-DailyEntry "Processing file: $($file.Name)"

        Get-Content $file.FullName -Encoding UTF8 | ForEach-Object {
            $line = $_.Trim()

            if (-not $line) {
                return
            }

            try {
                # Use RegEx to isolate the pure JSON object.
                if ($line -match '(\{.*\})') {
                    $jsonString = $Matches[1]
                } else {
                    throw "No valid JSON object found in line."
                }

                # Attempt to parse the cleaned JSON string
                $logEntry = $jsonString | ConvertFrom-Json

                $timestamp = $logEntry.timestamp
                $message = $logEntry.message
                $level = $logEntry.level

                # Initialize event variables
                $eventType = "OTHER"
                $requestUrl = ""
                $userId = "UNKNOWN_USER"
                $sourceIp = "N/A"

                # 2a. Extract User ID (Email) - Logic remains the same
                $emailPattern = "([a-zA-Z0-9._%+*?-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"
                if ($message -match $emailPattern) {
                    $userId = $Matches[1]
                } elseif ($logEntry.metadata.user -ne $null -and $logEntry.metadata.user.email) {
                    $userId = $logEntry.metadata.user.email
                } elseif ($logEntry.metadata.body -ne $null -and $logEntry.metadata.body.email) {
                    $userId = $logEntry.metadata.body.email
                }

                # 2b. Extract IP address - Logic remains the same
                if ($message -match "ip: (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})") {
                    $sourceIp = $Matches[1]
                }

                # 3. Classify Event - Logic remains the same
                $eventFound = $false
                switch -Wildcard ($message) {
                    # --- 1. LOGOUT ---
                    "* /ep/users/logout *" {
                        $eventType = "LOGOUT"
                        $requestUrl = "/ep/users/logout"
                        $eventFound = $true

                        # Apply last known user to the unknown logout
                        if ($userId -eq "UNKNOWN_USER") {
                            $userId = $LastUserEmail
                        }
                    }

                    # --- 2. LOGIN / FAILED LOGIN ---
                    "* /ep/users/login/auth *" {
                        $requestUrl = "/ep/users/login/auth"
                        $eventFound = $true

                        if ($level -eq "info") {
                            $eventType = "LOGIN"
                            # Update the last known user upon successful login
                            $LastUserEmail = $userId
                        } elseif ($level -eq "error") {
                            $eventType = "FAILED"
                        }
                    }
                }

                # 4. Write Audit Line if a target event was found
                if ($eventFound) {
                    $ts_parts = $timestamp.Split(" ")[0] + " " + $timestamp.Split(" ")[1]
                    $currentDedupeKey = "$ts_parts|$eventType|$userId|$requestUrl"

                    # --- DEDUPLICATION CHECK ---
                    if ($currentDedupeKey -ceq $LastDedupeKey) {
                        return
                    }

                    # 5. TRACK LOGIN ATTEMPTS - Logic remains the same
                    if ($eventType -eq "LOGIN" -or $eventType -eq "FAILED") {
                        $datePart = $ts_parts.Split(" ")[0]
                        if (-not $LoginAttempts.ContainsKey($userId)) {
                            $LoginAttempts[$userId] = @{}
                        }
                        if (-not $LoginAttempts[$userId].ContainsKey($datePart)) {
                            $LoginAttempts[$userId][$datePart] = 0
                        }
                        $LoginAttempts[$userId][$datePart]++
                    }

                    $currentAuditLine = "| {0,-19} | {1,-10} | {2,-25} | {3,-11} | {4,-13} |" -f $ts_parts, $eventType, $userId, $sourceIp, $requestUrl
                    $currentAuditLine | Out-File -FilePath $OutputAuditFile -Append -Encoding UTF8
                    # Convert previous Write-Host call to log entry
                    & Log-DailyEntry "--> FOUND: $eventType for user $userId in $($file.Name)"
                    $LastDedupeKey = $currentDedupeKey
                }

            } catch {
                # Handle non-JSON lines or parsing errors
                $line | Out-File -FilePath $DiagnosticFile -Append -Encoding UTF8
                & Log-DailyEntry "WARNING: SKIPPED Non-JSON line written to '$DiagnosticFile' for analysis. Error: $($_.Exception.Message.Split("`n")[0])"
            }
        }
    }

    # 6. Generate and append the Login Attempts Summary
    & Log-DailyEntry "Generating Login Attempt Summary..."

    $SummaryHeader = @"

---------------------------------------------------------------------------------------------------
LOGIN ATTEMPT SUMMARY (Deduplicated Events)
---------------------------------------------------------------------------------------------------
| USER ID | DATE | TOTAL ATTEMPTS |
|---------------------------|------------|----------------|
"@
    $SummaryHeader | Out-File -FilePath $OutputAuditFile -Append -Encoding UTF8

    $SummaryData = @()
    foreach ($user in $LoginAttempts.Keys) {
        foreach ($date in $LoginAttempts[$user].Keys) {
            $SummaryData += [PSCustomObject]@{
                UserId = $user
                Date = $date
                Attempts = $LoginAttempts[$user][$date]
            }
        }
    }

    # Sort by User ID, then by Date (ascending)
    $SummaryData | Sort-Object UserId, Date | ForEach-Object {
        $summaryLine = "| {0,-25} | {1,-10} | {2,-14} |" -f $_.UserId, $_.Date, $_.Attempts
        $summaryLine | Out-File -FilePath $OutputAuditFile -Append -Encoding UTF8
    }

    & Log-DailyEntry "SUCCESS: Summary appended to $OutputAuditFile."
    & Log-DailyEntry "Analysis complete. Clean log saved to $OutputAuditFile"
    & Log-DailyEntry "************************ D   a   y  C  o  m  p l e t e d *********************"
}

# Run the main function
Process-LogFile
