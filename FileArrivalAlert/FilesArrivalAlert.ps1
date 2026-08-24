# ==============================================================================
# Script: FilesArrivalAlert.ps1
# Purpose: Scans IIS FTP logs, alerts via Email, and remembers sent files.
# Author: Mohamed Mourad Abdelwahab
# ==============================================================================

# --- SECURITY CONFIGURATION ---

# This line tells the script to ignore SSL certificate errors when talking to the E-mail server
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# This line forces the script to use TLS 1.2, which is a secure communication standard required by the bank
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# --- CONSTANTS (UPPER_CASE) ---
# The name of your FTP site as defined in IIS
$SITE_NAME = "FTP"
# Your bank's SMTP (Email) server address
$SMTP_SERVER = "Mail.***.com"
# The port used for secure email sending
$SMTP_PORT = 587
# The automated sender address for VCX alerts
$FROM_EMAIL = "***@***.COM.EG"
# Your specific bank email address to receive the alerts
$TO_EMAIL = "******************@***.COM.EG"
# The service account name provided in your requirements
$SERVICE_ACCOUNT = "*******"
# The password for the service account to authenticate with the mail server
#THIS PART SHOULD BE PATCHED BY EITHER CALLING THIS PARAMETER FROM ANOTHER FILE (WHICH WILL BE CONTAINED IN ANOTEHR FUNCTION) OR THE PASSWORD COULD BE HASHED.
$EMAIL_PASSWORD = "************************"
# Number of hours to adjust the log time if the server time is different from local time
$TIME_OFFSET_HOURS = 0

# --- GLOBAL VARIABLES (PascalCase) ---
# The directory where this script stores its own execution logs
$LogFolder = "C:\VCXMonitoringJobs\FilesArrivalAlert\FilesArrivalLogs"
# The directory that stores the list of files (It acts as a memory to refer to it, so we won't send duplicate file each time the script is triggerd)
$MemoryFolder = "C:\VCXMonitoringJobs\FilesArrivalAlert\MemoryFolder"
# The full path to today's execution log file
$LogFile = "$LogFolder\FilesArrivalAlert_Log.txt"
# Gets the current date in a specific format to create a unique memory file for today
$TodayDate = Get-Date -Format "yyyy-MM-dd"
# The full path to the file that remembers processed transfers to avoid duplicate emails
$MemoryFile = "$MemoryFolder\ProcessedFiles_$TodayDate.txt"

# --- CSS STYLE (CSS for the Email) ---
# This block creates a professional look for the email table (Blue header, gray stripes) using cascade style sheet.
$Style = @"
<style>
    body { font-family: Times New Roman, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th { background-color: #002060; color: white; border: 1px solid #ddd; padding: 8px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
</style>
"@

# --- FUNCTIONS (Verb-Noun case) ---

# Function to write logs to the local log file for troubleshooting/investigation
function Write-Log {

    param ([string]$Message, [string]$Level="INFO") #Paramters used by the functions are two strings, one for the event that will be logged and the other is just a string having a default value (INFO)
    # Generate a timestamp for the log entry
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Append the formatted message to the log file
    Add-Content -Path $LogFile -Value "[$TimeStamp] [$Level] $Message" #The message after concatinating the components will look like this ( [2025-12-30 06:05:02] [INFO] Whatever the message is)
}

# Function to handle the actual sending of the HTML email via SMTP
function Send-NotificationEmail {

    param ([string]$To, [string]$From, [string]$Subject, [string]$Body, [string]$SmtpServer, [int]$Port, [string]$User, [string]$Password) <#
    Ok as you can see this function acccepts the following paramters, ( seven parameters of string type and an integer)

    1- $To --> This is the destination E-Mail that will recieve the alert
    2- $From --> This is the sender that will send the alert which is the service E-mail of the server
    3- $Subject --> The E-Mail subject
    4- $Body --> The E-mail content
    5- $SmtpServer --> The bank's SMTP server name
    6- $Port --> The SMTP server secure port used for connection
    7- $User --> The service user
    8- $Password --> The service E-mail password

    #>
    #This is the try block
    try {

        # Create a new email object (Written in C#)
        $MailMessage = New-Object System.Net.Mail.MailMessage
        # Set the sender and recipient
        $MailMessage.From = New-Object System.Net.Mail.MailAddress($From)
        $MailMessage.To.Add($To)
        # Set the subject line and the HTML content
        $MailMessage.Subject = $Subject
        $MailMessage.Body = $Body
        $MailMessage.IsBodyHtml = $true
        # Configure the SMTP client with server and port details
        $SmtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
        # Enable SSL encryption for the connection
        $SmtpClient.EnableSsl = $true
        # Provide the bank service account credentials
        $SmtpClient.Credentials = New-Object System.Net.NetworkCredential($User, $Password)
        # Set a 20-second timeout to prevent the script from hanging
        $SmtpClient.Timeout = 20000
        # Attempt to send the email
        $SmtpClient.Send($MailMessage)
        # Log success
        Write-Log -Message "The Email was sent successfully." -Level "SUCCESS" #The log looks like this ([2025-12-29 10:05:04] [SUCCESS] The Email was sent successfully.)
        return $true
    }
    catch {

        # If sending fails, capture the error and log it in the file
        $ErrorMsg = $_.Exception.Message
        Write-Log -Message "Failed to send email. ERROR: $ErrorMsg" -Level "ERROR" #The log looks like this ([2025-12-29 10:00:22] [ERROR] Failed to send email. DETAILED ERROR: Exception calling "Send" with "1" argument(s): "The operation has timed out." | Inner: The operation has timed out..)
        return $false
    }
}

# --- SCRIPT EXECUTION START ---

# Create log and memory folders if they don't exist

try{

    if (!(Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory
}

    if (!(Test-Path $MemoryFolder)) {

    New-Item -Path $MemoryFolder -ItemType Directory

} Write-Log -Message "log and memory folders not found intitating the creation process..."
  Write-Log -Message "log and memory folders has been created succssfully" -Level "SUCCESS"
    }


catch{

    $ErrorMsg = $_.Exception.Message
    Write-Log -Message "Failed to create log or memory folders. ERROR: $ErrorMsg" -Level "ERROR"
}



# Check if we have a memory file from earlier today; if so, load the list of files already processed
if (Test-Path $MemoryFile) {

    $ProcessedFiles = Get-Content $MemoryFile
} else {

    # If no file exists, start with an empty list
    $ProcessedFiles = @()
}

# Try to find where IIS is storing the FTP logs automatically (via the FTP site name)
try {

    <# Load the IIS management module

    1- (Import-Module WebAdministration): Loads the module manages IIS websites and application pools.
    It also creates the IIS: drive for navigating IIS settings like a file system.

    2- (-ErrorAction Stop): A common parameter that instructs PowerShell to treat any error (e.g., the module is missing)
    as a terminating error. This immediately stops script execution rather than just displaying a warning,
    which is useful for ensuring subsequent IIS commands don't fail silently.

    #>
    Import-Module WebAdministration -ErrorAction Stop

    # Get the ID of the FTP site to locate its specific log folder
    $SiteID = (Get-ItemProperty "IIS:\Sites\$SITE_NAME").id
    # Constructing the path
    $LogPath = "$env:SystemDrive\inetpub\logs\LogFiles\FTPSVC$SiteID" #$SiteID = SVC2
    Write-Log -Message "Auto-detected Log Path: $LogPath"
}
catch {

    # If auto-detect fails,hardcoded fallback path is used
    $LogPath = "C:\inetpub\logs\LogFiles\FTPSVC2"
    Write-Log -Message "Auto-detect failed. Defaulting to: $LogPath" -Level "WARNING" #The log looks like this ([2025-12-29 10:05:03] [INFO] Auto-detected Log Path: C:\inetpub\logs\LogFiles\FTPSVC2)
}

# Look for the most recent log file in the folder
if (Test-Path $LogPath) {

    $LatestLog = Get-ChildItem -Path $LogPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} else {

    $LatestLog = $null
}

# If no log file is found, we cannot proceed
if (!$LatestLog) {

    Write-Log -Message "No log file found." -Level "ERROR"
    Exit
}

Write-Log -Message "Scanning log file: $($LatestLog.Name)"

# Read the log file and look for "RNTO" (Rename To) and "250" (Success code)
# This indicates a file was fully uploaded and finalized
<#
    1- (Get-Content): Reads the latest log file line-by-line.
    2- (RNTO): This is an FTP command for "Rename To." In my FTP server, a file upload is completed by uploading a temporary file and then renaming it to the final name.
    3- (\s250\s): The number 250 is the standard FTP "Success" code. This filter ensures the script only looks at files that were successfully renamed/uploaded.

       3A- (\s): This is a regular expression (regex) symbol that stands for whitespace. When you see it in the pattern "\s250\s",
       it is being used to make sure the script matches the exact number 250 and not part of a larger number (like 1250 or 2500)
#>

$NewFiles = Get-Content $LatestLog.FullName | Where-Object {
    $_ -match "RNTO" -and $_ -match "\s250\s"
} | ForEach-Object {

    # Split the log line into individual pieces of data
    <#
    the code ($Fields = $_ -split "\s+") is the code that turns a messy line of text into a clean list of data parts.

        What it does (Step-by-Step):
        ############################

        1- ($_): This is a shortcut for "the current line of text" being read from the log file.
        2- (-split): This operator tells PowerShell to cut the text into separate pieces.
        3- ("\s+"): This is the "cutting rule" (a regular expression):
        4- (\s): Stands for any whitespace (a space, a tab, or a new line).
        5- (+): Means "one or more".

        Why use (\s+) instead of just a space?
        #####################################

        If you only split on a single space, and your log file has multiple spaces between columns to make them look aligned,
        you would end up with a bunch of "empty" data fields.

        Using (\s+) ensures that no matter how many spaces or tabs are between your data, they are all treated as one single divider.

        Real log example:
        ##################

        If your log line looks like this:
        #################################\

        2025-12-30 04:21:41 ***.***.***.*** *********\******** ***.***.***.*** 8443 RNTO ************************************* 250 0 0 e8816a08-4398-4d47-9fe0-083bb2b1d520 /*************************************

        The split creates the following numbered $Fields:
        ##################################################

        $Fields[0]: 2025-12-30 (The Date)
        $Fields[1]: 04:21:41 (The Time)
        $Fields[2]: ***.***.***.*** (Visa's IP Address)
        $Fields[3]: *********\******** (The user that access the server from Visa's side)
        $Fields[12]: /************************************* (The Filename)

        By doing this, the rest of the script can easily grab exactly what it needs just by using its index number.
    #>

    $Fields = $_ -split "\s+"

    try {

        # This line retrives the very last line in the log file, if it was (-last 2), this will retrieve the last two items and so on...
        $FileName = $Fields | Select-Object -Last 1

        # Check if we have already sent an email for this specific filename today
        if ($ProcessedFiles -notcontains $FileName) {

            # Combine the date and time from the log into a proper date object
            <#
               1- ($null) Default Culture: When I pass $null, PowerShell uses the Current Culture of the computer running the script. Including how the date and time is written
            #>
            $LogDateTime = [DateTime]::ParseExact("$($Fields[0]) $($Fields[1])", "yyyy-MM-dd HH:mm:ss", $null)

            # Apply the time offset (usually 0)
            $FinalTime = $LogDateTime.AddHours($TIME_OFFSET_HOURS)

            # Create an object representing the transfer for the email table (HTML table)
            [PSCustomObject]@{

                "Date Received" = $FinalTime.ToString("yyyy-MM-dd")
                "Time Received" = $FinalTime.ToString("hh:mm tt")
                "Settlement File" = $FileName
                "FTP server IP" = $Fields[2]
                "Status" = "Success"
                "RawName" = $FileName # Hidden field used for memory tracking
            }
        }
    } catch {

        Write-Log -Message "Error parsing line: $_" -Level "ERROR"
    }
}

# If we found files that haven't been processed yet
if ($NewFiles) {

    # Count how many new files there are (Files counter)
    $FileCount = ($NewFiles | Measure-Object).Count
    Write-Log -Message "Found $FileCount NEW file(s). Generating the HTML table..."

    <# Convert the file list into an HTML table, but hide the 'RawName' column.
       1- (-Fragment): A parameter that tells the (ConvertTo-Html) function to generate only the data table (the <table> tags and rows), rather than a full, valid HTML document.
    #>
    $HtmlTable = $NewFiles | Select-Object * -ExcludeProperty RawName | ConvertTo-Html -Fragment

    # Build the full email body with the style and the table
    $EmailBody = @"
<html>
<head>$Style</head>
<body>
    <h2 style='color: #002060;'>VCX Settlement File Alert</h2>
    <p>The following <b>$FileCount</b> NEW file(s) were successfully received and renamed on the VCX Server.</p>
    $HtmlTable
    <br>
    <p><i>This is an automated message from the VCX Monitoring System.</i></p>
</body>
</html>
"@
    # Create a subject line with the current time
    $EmailSubject = "[VCX Alert] Settlement Files Received - $(Get-Date -Format 'hh:mm tt')"

    # Call the function to send the email
    $IsSent = Send-NotificationEmail -To $TO_EMAIL -From $FROM_EMAIL -Subject $EmailSubject -Body $EmailBody -SmtpServer $SMTP_SERVER -Port $SMTP_PORT -User $SERVICE_ACCOUNT -Password $EMAIL_PASSWORD

    # If the email was sent successfully, remember these files so we don't alert again
    if ($IsSent) {

        foreach ($FileObj in $NewFiles) {
            Add-Content -Path $MemoryFile -Value $FileObj.RawName
        }

        Write-Log -Message "Memory file updated with $FileCount new filenames."
    }

} else {

    # If no new files were found, just log it and finish
    Write-Log -Message "Scan complete. No NEW files found (duplicates ignored)."
}

Write-Log -Message "Script execution finished."
