# Monitors the command channel connectivity to the external VISA endpoint.
# Sends a CRITICAL FAILURE email *ONLY* when the connection fails.
# Logs success silently without sending an email.

# --- Configuration Section ---

#Visa's FTPS server public IP (Command cahnnel)
$VISA_IP = "***.***.***.***"

#Visa's FTPS server port
$VISA_PORT = 8443


# --- Email Configuration for alert purpouses ---

#SMTP server name
$EMAIL_SMTP_SERVER = "Mail.***.com"

#SMTP server port
$EMAIL_SMTP_PORT = 587

#SERVER E-mail to send alerts
$EMAIL_SENDER = "***@***.COM.EG"

#The recipent of the alert
$EMAIL_RECIPIENT = "******************@***.COM.EG"

#Service account of the server (To access the SMTP server)
$EMAIL_USERNAME = "*******"

# WARNING: The password should not be stored in plaintext in production! Use an encrypted credential file.
$EMAIL_PASSWORD = "************************"

# --- Logging Configuration ---

#Path that recives the logs
$LOG_DIRECTORY = "C:\VCXMonitoringJobs\DestinationPingJob\PingLogs"

#Log file naming convention (Year then the month then the day)
$LOG_FILE = "VISA_Check_$(Get-Date -Format 'yyyyMMdd').log"

# --- Log writing function ---

function Write-Log {
    param([string]$Message, [string]$Level = "INFO") #The parameters to be accepted by the function are strings. One is a log message for the ping result and the other is just a constant string written in the log [INFO].

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" #The time stamp format (Year then month then day, then hours and minuites and seconds)
    $LogEntry = "[$Timestamp] [$Level] $Message" <#The final log will look something like this

    [2025-12-09 16:45:21] [INFO] SUCCESS: TCP connection confirmed to ***.***.***.***:8443.
    [2025-12-09 16:45:21] [INFO] Script execution finished.

    #>

    # Ensure log directory exists before writing
    if (-not (Test-Path $LOG_DIRECTORY)) {

        New-Item -Path $LOG_DIRECTORY -ItemType Directory -Force | Out-Null #If the directory is not there, create it using (New-Item) funtion, also (mkdir) could be used.

     }

    Add-Content -Path (Join-Path $LOG_DIRECTORY $LOG_FILE) -Value $LogEntry -ErrorAction SilentlyContinue <#

    (Add-Content) Used to append data to an existing file without overwriting its current contents. If the file doesn't exist,
    it will be created automatically as long as the directory exists.
    #>
    Write-Host $LogEntry
}

# --- E-mail alert function ---

function Send-NotificationEmail {
    param(
        [string]$Subject, #Here the parameters accepted by the function are two strings, one for the E-mail subject and the other for the body
        [string]$Body
    )

    # FIX: This bypasses certificate validation to solve the common 'invalid remote certificate' failure.
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    try {
        # Securely handle credentials (Password is in plaintext, which is a risk. should be modified in production.)
        $SecurePass = ConvertTo-SecureString -String $EMAIL_PASSWORD -AsPlainText -Force #Here the password is encrypted for security purpouses.

        <#
            (New-Object System.Management.Automation.PSCredential), This command is used to create a PSCredential object,
            which securely stores a username and password for authentication in scripts, and then be used for automated authentication instead of typing the credentials manually
        #>
        $Credential = New-Object System.Management.Automation.PSCredential($EMAIL_USERNAME, $SecurePass)

        Send-MailMessage -From $EMAIL_SENDER `
                         -To $EMAIL_RECIPIENT `
                         -Subject $Subject `
                         -Body $Body `
                         -SmtpServer $EMAIL_SMTP_SERVER `
                         -Port $EMAIL_SMTP_PORT `
                         -Credential $Credential `
                         -UseSsl

        Write-Log "ALERT SENT: Notification email sent successfully." "CRITICAL"
    } catch {
        Write-Log "ERROR: Failed to send notification email. $($_.Exception.Message)" "ERROR"
    }
}

# --- Main Logic ---

try {
    Write-Log "Starting VISA Endpoint connectivity check: ${VISA_IP}:${VISA_PORT}"

    # 2. Perform Network Test (TCP Ping)
    $Result = Test-NetConnection -ComputerName "***.***.***.***" -Port 8443 -InformationLevel Detailed -ErrorAction SilentlyContinue

    $Status = $Result.TcpTestSucceeded #The output is the parameter of the (TcpTestSucceeded)

    if ($Status -eq $true) { # -eq means equal to somthing, (TcpTestSucceeded       : True), -eq is not case sensitve.

        # Connection Succeeded (Only Log - NO EMAIL)
        Write-Log "SUCCESS: TCP connection confirmed to ${VISA_IP}:${VISA_PORT}." "INFO"

    } else {
        # Connection Failed (Send Mail)

        Write-Log "FAILURE: Connection to ${VISA_IP}:${VISA_PORT} failed. TCP Test Succeeded: $Status." "CRITICAL"

        $Subject = "VCX CRITICAL FAILURE: VISA Endpoint DOWN!"
        $Body = "CRITICAL ALERT: The scheduled check FAILED to establish a TCP connection to the VISA endpoint (${VISA_IP}:${VISA_PORT}). VCX clearing operations may be impacted. Immediate investigation required."
        Send-NotificationEmail -Subject $Subject -Body $Body
    }

} catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log "FATAL ERROR during script execution: $ErrorMessage" "ERROR"
}

Write-Log "Script execution finished."
