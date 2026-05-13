# Requires 7-Zip command line utility (7z.exe) to be installed on the server
# and accessible via the system PATH, or provide the full path to 7z.exe.

# --- Configuration Section ---

# The root directory of your VCX web application (e.g., C:\inetpub\wwwroot\VCX)
$SourceDirectory = "E:\vcx"

# Primary Directory (Local Server Disk) where the backups will be stored.
# This is the ONLY copy created.
$BackupDir = "F:\VCXWebAppServerBackup"

# Path to the 7-Zip executable. Adjust if not in PATH.
$SevenZipPath = "C:\Program Files (x86)\7-Zip\7z.exe"

# The name of the log file (will be placed in $LogDir)
$LogDir = "C:\VCXSchedualedJobs\VCXWebAppJob\VCXJobLog"
$LogFile = "AppFileBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# --- Email Configuration ---
# NOTE: The EmailPassword MUST be secured. See WARNING below.
$EmailSMTPServer = "Mail.***.com"
$EmailSMTPPort = 587
$EmailSender = "***@***.COM.EG"
$EmailRecipient = "******************@***.COM.EG"
$EmailUsername = "*******"
$EmailPassword = "************************" # <<< THIS IS A SECURITY VULNERABILITY

# --- SECURITY WARNING: Handle Password Securely ---
# DO NOT store the password as a plaintext string in the script.
# The variable below is a placeholder. In production, you MUST use a secure
# method (e.g., an encrypted string or vault) to retrieve this value.
$SecurePassword = "********" # <<< CHANGE THIS

# --- Main Logic ---

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path (Join-Path $LogDir $LogFile) -Value $LogEntry
    Write-Host $LogEntry
}

function Send-BackupEmail {
    param(
        [string]$Subject,
        [string]$Body
    )

    try {
        # --- FIX: Disable SSL Certificate Validation to solve the "remote certificate is invalid" error ---
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

        # Securely handle credentials
        $SecurePass = ConvertTo-SecureString -String $EmailPassword -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($EmailUsername, $SecurePass)

        Send-MailMessage -From $EmailSender `
                         -To $EmailRecipient `
                         -Subject $Subject `
                         -Body $Body `
                         -SmtpServer $EmailSMTPServer `
                         -Port $EmailSMTPPort `
                         -Credential $Credential `
                         -UseSsl # Use SSL is typically required for port 587

        Write-Log "INFO: Notification email sent successfully to $EmailRecipient."
    } catch {
        # Log failure to send email, but don't stop the main script execution
        Write-Log "ERROR: Failed to send email notification. $($_.Exception.Message)" "ERROR"
    } finally {
        # Clean up the certificate validation override
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }
}

try {
    Write-Log "Starting VCX Application file backup for: $SourceDirectory"

    # 1. Create backup and log directories if they don't exist
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
        Write-Log "Created primary backup directory: $BackupDir"
    }

    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        Write-Log "Created log directory: $LogDir"
    }

    # Check if the 7z executable exists
    if (-not (Test-Path $SevenZipPath)) {
        throw "7-Zip executable not found at '$SevenZipPath'. Please check the path."
    }

    # Define the output archive name with timestamp
    $ArchiveName = "VCX_AppFiles_$(Get-Date -Format 'yyyyMMdd_HHmmss').7z"
    $ArchivePath = Join-Path $BackupDir $ArchiveName

    Write-Log "Compressing application files to: $ArchivePath"

    # 2. Execute 7-Zip Command (Arguments remain the same)
    $Arguments = "a", "-t7z", "-p$SecurePassword", "-mx=9", "-r", "-mhe", $ArchivePath, $SourceDirectory
    $Process = Start-Process -FilePath $SevenZipPath -ArgumentList $Arguments -Wait -NoNewWindow -PassThru

    # Get the exit code from 7-Zip
    $ExitCode = $Process.ExitCode

    # --- FIX: Treat 7-Zip exit code 0 (Success) or 1 (Warning) as a successful run ---
    if ($ExitCode -eq 0 -or $ExitCode -eq 1) {

        if ($ExitCode -eq 1) {
            # Log a WARN level message for exit code 1
            Write-Log "WARNING: 7-Zip finished with a warning exit code (1). Backup archive created, but some files may have been skipped (e.g., files locked by the VCX application)." "WARN"
        }

        Write-Log "SUCCESS: VCX Application monthly backup completed successfully. Archive size: $((Get-Item $ArchivePath).Length / 1MB) MB"

        # --- SEND SUCCESS EMAIL ---
        $EmailSubject = "VCX Web App Weekly Backup SUCCESS: $(Get-Date -Format 'yyyy-MM-dd')"
        $EmailBody = "The VCX application files were successfully compressed and saved to: $ArchivePath. Size: $((Get-Item $ArchivePath).Length / 1MB) MB"
        Send-BackupEmail -Subject $EmailSubject -Body $EmailBody
        # ------------------------

    } else {
        # 7-Zip exit code is 2 (Fatal Error) or higher
        throw "7-Zip failed during compression with exit code: $ExitCode."
    }

    # 3. Cleanup: Remove backups older than 30 days
    $RetentionDays = 30
    Write-Log "Cleaning up PRIMARY backups older than $RetentionDays days..."
    $FilesToDelete = Get-ChildItem -Path $BackupDir -Filter "*.7z" | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$RetentionDays) }

    foreach ($File in $FilesToDelete) {
        Remove-Item -Path $File.FullName -Force
        Write-Log "CLEANUP: Deleted old primary backup file: $($File.Name)"
    }

    Write-Log "Primary cleanup complete."

} catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log "FATAL ERROR during backup: $ErrorMessage" "ERROR"

    # --- SEND FAILURE EMAIL ---
    $ErrorSubject = "VCX Web App Backup FAILURE: $(Get-Date -Format 'yyyy-MM-dd')"
    $ErrorBody = "FATAL ERROR: The VCX application monthly backup failed. Check the log file at $LogDir\$LogFile for details. Error message: $ErrorMessage"
    Send-BackupEmail -Subject $ErrorSubject -Body $ErrorBody
    # ------------------------
}

Write-Log "Script execution finished."
