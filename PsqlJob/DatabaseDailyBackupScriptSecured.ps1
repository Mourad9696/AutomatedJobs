# -------------------------------------------------------------------------------------------------- 
# DAILY POSTGRESQL BACKUP SCRIPT WITH LOGGING (V2).
# Author: Mohamed Mourad (Mohamed.a-elhenawy@qnb.com.eg)
# -------------------------------------------------------------------------------------------------- 

# ================================================================= 
# CONFIGURATION SECTION 
# ================================================================= 

# --- 1. Dumping logs configration --- 
$LOG_DIRECTORY_NAME = "PsqlJobLog" # The folder name to be created inside the script's directory (C:\VCXMonitoringJobs) 

# --- 2. DB access and compression configration --- 
$PG_BIN_PATH = "C:\Program Files\PostgreSQL\16\bin" #This is the absolute path that leads to PostgresSQL application.
$COMPRESSION_APP_PATH = "C:\Program Files (x86)\7-Zip\7z.exe" # This is the absolute path to 7-Zip application.
$DB_NAME = "vcxdb" # The name of the DB.
$DB_USERNAME = "postgres" # The username of the DB.
$DB_PASSWORD = "admin" # The DB password.
$BACKUP_PATH = "F:\DatabaseBackup" #The absolute path where the backup is stored.
$COMPRESSED_FOLDER_PASSWORD = "Bfmw6u4j" # The compressed file password.

# --- DEBUG & EXECUTION TRACER ---
$EXECUTION_START = "SCRIPT INITIATED..."
Write-Host $EXECUTION_START # This line is kept here only to promt that the script starts. In case of manual run, for testing purpouses.

# ================================================================= 
# LOGGING FUNCTION DEFINITION 
# ================================================================= 

#This function is used for logging the script actions to the log file desinated to it.

function Write-Log {
    param( 
        [Parameter(Mandatory=$true)] # Ensures that a paramter is a must for the function to execute.
        [string]$Message # The parameters accepted by the function is a string, and this string is the log sentence.
    )

    <#This part acts as a saftey net, as the task schedular interprets by default that the script
      runs in "C:\Windows\System32", so by that it would create a log folder inside this path and could be denied
      #>

    $scriptDirectory = if ($PSScriptRoot) { <# 1- Automatic, read-only variable that contains the full path to the directory where the currently executing script is found.
                                               It is extremely useful for referencing files relative to the script’s location.
                                               In short, the if condtion asks, "Do I know where I am currently?"
                                               #>
        $PSScriptRoot #If yes, the scriptDirectory path will be filled with the script actual path.

    } else {
        # Fallback to the expected absolute path if you do not know where you are.
        "C:\VCXSchedualedJobs\PsqlClearDBJob"  
    } 

    # Define the Log Paths 
    $logDirectory = Join-Path -Path $scriptDirectory -ChildPath $LOG_DIRECTORY_NAME #We join the main absolute path with the directory path of the logs
    $logFilePath = Join-Path -Path $logDirectory -ChildPath "BackupLog-$(Get-Date -Format 'dd-MM-yyyy').txt" #Now, we join the log file name with date, to the log file path.

    # Ensure log directory exists = (C:\VCXSchedualedJobs\PsqlClearDBJob\PsqlJobLog)
    if (-not (Test-Path $logDirectory)) { 

        # Create the log folder if it does not exist. While suppressing any possible error or informational message
        New-Item -Path $logDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null 
    } 
      
    $timeStamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss" 
    $logEntry = "[$timeStamp] $Message"
      
    # Write to log file and to the host console, the 
    Add-Content -Path $logFilePath -Value $logEntry 
    Write-Host $logEntry 
} 


# ================================================================= 
# MAIN EXECUTION 
# ================================================================= 

# Check if the backup directory exists, and create it if not. 
if (-not (Test-Path $BACKUP_PATH)) { 
    & Write-Log "Backup destination '$BACKUP_PATH' did not exist. Creating directory..." 
    New-Item -Path $BACKUP_PATH -ItemType Directory | Out-Null 
} 

# Create a timestamp for the sql filename, the inside one.

#The first output = day-month-year-hour-minute-second
$timeStamp = Get-Date -Format "dd-MM-yyyy_HH-mm-ss" 

#The second output = backup-vcxdb + first output
$backup_file = "Backup-$DB_NAME" + "-$timeStamp.sql"

# Create a zip file for the backup (name wise)
$backup_zip_file = "Backup-$DB_NAME" + "-$timeStamp.zip"

# Joining the full path (Full back up path + the backup file itself (DB name + time of creation) 
$backup_full_path = Join-Path -Path $BACKUP_PATH -ChildPath $backup_file 

# Here is the full path of the zipped file, (We join the backup full path + with the child path, the zipped file in this case)
$zip_full_path = Join-Path -Path $BACKUP_PATH -ChildPath $backup_zip_file 


<# Set the PostgreSQL password as an environment variable, the (PGPASSWORD) behaves
as a password connection parameter, well it is not recommended for security reasons,

	1- All non-root users are able to process the enviroment variable
	2- The DB password is also written in the script file which can be accessed by any non-root user

Solution: A passsword will be used for the next script update
#>

#N.B: "&" sign is as if you are saying to the powershell script, execute that as a command
$env:PGPASSWORD = $DB_PASSWORD

# Writing in the log that the password parameter is set (Invoking the Write_Log function)
Write-Log "Environment variable PGPASSWORD set." 

# Writing that the pg_dump command will run (Invoking the Write_Log function) 
Write-Log "Starting pg_dump to create clear-text database backup..." 

# Here I told him, go to the pg_dump.exe file path.
$pg_dump_command = Join-Path -Path $PG_BIN_PATH -ChildPath "pg_dump.exe"

#Here I told him to execeute it 
& $pg_dump_command -U $DB_USERNAME -d $DB_NAME -Fp -f $backup_full_path 

# Check if the backup was successful. 

#Here we invoke the (Test-Path) fuction to see if the path does exist or not,Boolean expression is returned
if (Test-Path $backup_full_path) { 

    #Here we execute a command that retirves the full size of the compressed file
    $fileSizeMB = (Get-Item $backup_full_path).Length / 1MB 
    Write-Log "SUCCESS: SQL backup file created successfully. Size: $($fileSizeMB.ToString('N2')) MB. Starting 7-Zip compression..." 

    # Use 7-Zip to compress the file with a password. 
    # 'a' = add to archive, '-p' = password 
    & $COMPRESSION_APP_PATH a "-p$COMPRESSED_FOLDER_PASSWORD" $zip_full_path $backup_full_path 

    # Check if the zip file was created. 
    if (Test-Path $zip_full_path) { 
        & Write-Log "SUCCESS: File compressed and password-protected. Deleting original SQL file." 
        Remove-Item $backup_full_path -ErrorAction SilentlyContinue 

        $zipSizeMB = (Get-Item $zip_full_path).Length / 1MB 
        Write-Log "Cleanup complete. Final zip size: $($zipSizeMB.ToString('N2')) MB." 
    } else { 
        Write-Log "FATAL ERROR: 7-Zip compression failed. Original SQL file remains." 
    } 
} else { 
    Write-Log "FATAL ERROR: Database backup failed. No SQL file was created by pg_dump." 
} 

# Remove the environment variable for security. 
Remove-Item env:PGPASSWORD 

& Write-Log "Automated backup process completed." 
