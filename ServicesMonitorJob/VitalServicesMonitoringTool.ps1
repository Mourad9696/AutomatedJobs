# --------------------------------------------------------------------------------------------------
# CRITICAL SERVICE MONITORING SCRIPT (V1)
# Implements state tracking via a flag file and includes logging, running off a batch loop.
# --------------------------------------------------------------------------------------------------

# =================================================================
# CONFIGURATION BLOCK
# =================================================================


$Style = @"
<style>
    body { font-family: Times New Roman, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th { background-color: #002060; color: white; border: 1px solid #ddd; padding: 8px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
</style>
"@

# --- 1. SERVICE ACCOUNT LOGIN DETAILS ---
$SERVICE_ACCOUNT = "*******"
$SERVICE_ACCOUNT_PLAIN_PASSWORD = "************************"

# --- 2. SMTP SERVER & EMAIL DESTINATION ---
$SMTP_SERVER_NAME = "Mail.***.com"
$SMTP_PORT = 587
$SERVICE_EMAIL = "***@***.COM.EG"
$RECIPIENT_EMAIL = "******************@***.COM.EG"

# --- 3. Array of services to monitor ---
$CRITICAL_SERVICES = @(
    "VCXService",
    "VCXProxyService",
    "IIS Admin Service",
    "postgresql-x64-16 - PostgreSQL Server 16"
)

# --- 4. EMAIL SUBJECT CUSTOMIZATION ---
$ALERT_SUBJECT_PREFIX = "CRITICAL ALERT: SERVICE FAILURE on VCX Test serve"
$RECOVERY_SUBJECT_PREFIX = "RECOVERY: SERVICE(S) RESTORED on $($env:COMPUTERNAME)"

# --- 5. LOGGING CONFIGURATION ---
$LOG_DIRECTORY_NAME = "ServiceLogs"

# =================================================================
# DO NOT EDIT BELOW THIS LINE
# =================================================================

# Define paths
$SCRIPT_DIRECTORY = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SERVICE_DOWN_FLAG_FILE = Join-Path -Path $SCRIPT_DIRECTORY -ChildPath "ServiceStatus.flag"
$LOG_DIRECTORY = Join-Path -Path $SCRIPT_DIRECTORY -ChildPath $LOG_DIRECTORY_NAME
$LOG_FILE_PATH = Join-Path -Path $LOG_DIRECTORY -ChildPath "Monitor_$(Get-Date -Format 'yyyy-MM-dd').log"


# --- LOGGING FUNCTION ---
function Write-log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    # Ensure log directory exists
    if (-not (Test-Path $LOG_DIRECTORY)) {
        New-Item -Path $LOG_DIRECTORY -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    }

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"

    # Write to log file
    Add-Content -Path $LOG_FILE_PATH -Value $LogEntry

    # Also write to host for console/task scheduler history debugging
    Write-Host $LogEntry
}


# --- SETUP AND PROTOCOL FIXES ---
Write-log "Starting service check on $($env:COMPUTERNAME)..."

try {
    # Credentials and security protocol setup
    $Credentials = New-Object System.Net.NetworkCredential($SERVICE_ACCOUNT, $SERVICE_ACCOUNT_PLAIN_PASSWORD)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
} catch {
    Write-log "FATAL ERROR during setup: $($_.Exception.Message)"
    exit 1
}

$DownServices = @()
$ServerName = $env:COMPUTERNAME


# 1. CHECK SERVICE STATUS
foreach ($Service in $CRITICAL_SERVICES) {
    try {
        $Status = Get-Service -Name $Service -ErrorAction Stop
        if ($Status.Status -ne "Running") {
            $DownServices += $Status
            Write-log "Service '$Service' is STOPPED. Status: $($Status.Status)"
        } else {
            Write-log "Service '$Service' is Running. Status: OK"
        }
    } catch {
        Write-log "Error checking service '$Service': $($_.Exception.Message)"
        $DownServices += [PSCustomObject]@{ Name = $Service; DisplayName = $Service; Status = "ERROR/MISSING" }
    }
}


# 2. DECISION LOGIC & EMAIL SENDING

if ($DownServices.Count -gt 0) {
    # --- SCENARIO A: SERVICE IS DOWN ---
    if (-not (Test-Path $SERVICE_DOWN_FLAG_FILE)) {
        Write-log "Service failure detected. Sending initial alert."
        Set-Content -Path $SERVICE_DOWN_FLAG_FILE -Value (Get-Date)

        $ServiceList = $DownServices | Select-Object -Property Name, Status, DisplayName | Format-List | Out-String
        $EmailBody = @"
<html>
<head>$Style</head>
<body>
    <h2 style='color: #002060;'>VCX Vital Service Alert</h2>
    <p>The following services are down, please check them <b>$ServiceList</b></p>
    $HtmlTable
    <br>
    <p><i>This is an automated message from the VCX Monitoring System.</i></p>
</body>
</html>
"@
        $Subject = $ALERT_SUBJECT_PREFIX

        try {
            # Send Alert Email
            $MailMessage = New-Object System.Net.Mail.MailMessage
            $MailMessage.From = $SERVICE_EMAIL
            $MailMessage.To.Add($RECIPIENT_EMAIL)
            $MailMessage.Subject = $Subject
            $MailMessage.Body = $EmailBody
            $MailMessage.IsBodyHtml = $false

            $SMTP = New-Object System.Net.Mail.SmtpClient($SMTP_SERVER_NAME, $SMTP_PORT)
            $SMTP.EnableSsl = $true
            $SMTP.Credentials = $Credentials
            $SMTP.Send($MailMessage)
            Write-log "CRITICAL ALERT EMAIL SENT."
        } catch {
            Write-log "FATAL ERROR: Could not send CRITICAL ALERT email. Error: $($_.Exception.Message)"
        }

    } else {
        Write-log "Services are still down. Flag file exists. Suppressing repeat alert."
    }

} else {
    # --- SCENARIO B: SERVICE IS UP ---
    if (Test-Path $SERVICE_DOWN_FLAG_FILE) {
        Write-log "Recovery detected. Sending recovery alert."
        Remove-Item $SERVICE_DOWN_FLAG_FILE -Force

        $EmailBody = "All critical service(s) have recovered and are now running on server $ServerName."
        $Subject = $RECOVERY_SUBJECT_PREFIX

        try {
            # Send Recovery Email
            $MailMessage = New-Object System.Net.Mail.MailMessage
            $MailMessage.From = $SERVICE_EMAIL
            $MailMessage.To.Add($RECIPIENT_EMAIL)
            $MailMessage.Subject = $Subject
            $MailMessage.Body = $EmailBody
            $MailMessage.IsBodyHtml = $false

            $SMTP = New-Object System.Net.Mail.SmtpClient($SMTP_SERVER_NAME, $SMTP_PORT)
            $SMTP.EnableSsl = $true
            $SMTP.Credentials = $Credentials
            $SMTP.Send($MailMessage)
            Write-log "RECOVERY EMAIL SENT."
        } catch {
            Write-log "FATAL ERROR: Could not send RECOVERY email. Error: $($_.Exception.Message)"
        }
    } else {
        Write-log "All services are running normally. No action required."
    }
}

# -------------------------------------
# V1: CRITICAL EXIT POINT FOR BATCH LOOP
# The script MUST exit so the batch file can continue to the 'timeout' command.
# -------------------------------------
exit 0
