# -------------------------------------------------------------------------------------------------- 

# IIS CONFIGURATION BACKUP SCRIPT V1

# - Saves the uncompressed backup directly to the F: drive. 

# -------------------------------------------------------------------------------------------------- 



# ================================================================= 

# CONFIGURATION SECTION 

# ================================================================= 



# --- 1. LOGGING CONFIGURATION --- 

$LOG_DIRECTORY_NAME = "IISJobLog"  



# --- 2. TOOL & PATH CONFIGURATION --- 

# NOTE: 7-Zip is no longer used, so this variable is commented out. 

# $sevenZipPath = "C:\Program Files (x86)\7-Zip\7z.exe"  

$DESTINATION_PATH = "F:\IISSettingsBackup" # Destination for the final archive. 



# ================================================================= 

# LOGGING FUNCTION DEFINITION  

# ================================================================= 





#This function is used for logging the script actions to the log file desinated to it.

function Log-DailyEntry { 

    param( 

        [Parameter(Mandatory=$true)] # Ensures that a paramter is a must for the function to execute.

        [string]$Message # The parameters accepted by the function is a string, and this string is the log sentence.

    ) 



    

    <# 1- Automatic, read-only variable that contains the full path to the directory where the currently executing script is found.

                                               It is extremely useful for referencing files relative to the script’s location.

                                               In short, the if condtion asks, "Do I know where I am currently?"

                                               #>

    $ScriptDirectory = if ($PSScriptRoot) { 

        $PSScriptRoot #If yes, the scriptDirectory path will be filled with the script actual path.

    } else { 

        "C:\VCXMonitoringJobs\IISJob"  # Fallback to the expected absolute path if you do not know where you are.

    } 



    # Define the Log Paths 

    $LogDirectory = Join-Path -Path $ScriptDirectory -ChildPath $LOG_DIRECTORY_NAME #We join the main absolute path with the directory path of the logs

    $LogFilePath = Join-Path -Path $LogDirectory -ChildPath "IISBackupLog_$(Get-Date -Format 'yyyy-MM-dd').txt" #Now, we join the log file name with date, to the log file path.



    # Ensure log directory exists = (C:\VCXSchedualedJobs\IISJob\IISJobLog)

    if (-not (Test-Path $LogDirectory)) { 



        # Create the log folder if it does not exist. While suppressing any possible error or informational message

        New-Item -Path $LogDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null 

    } 

      

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 

    $LogEntry = "[$Timestamp] $Message" 

      

    # Write to log file and to the host console.

    Add-Content -Path $LogFilePath -Value $LogEntry 

    Write-Host $LogEntry 

} 





# ================================================================= 

# MAIN EXECUTION 

# ================================================================= 



Log-DailyEntry "Starting IIS Configuration Backup Job..." 



# 1. Create a unique backup name and paths.

$backupName = "IIS_Backup_$(Get-Date -Format "dd-MM-yyyy_HH-mm-ss")" #The backup naming

$backupTempFolder = "C:\Windows\System32\inetsrv\backup\$backupName" ##IIS backup default path

$finalBackupPath = "$DESTINATION_PATH\$backupName" # Final destination is now a folder, not the compressed one 



# 2. Ensure the destination path exists. 

if (-not (Test-Path -Path $DESTINATION_PATH)) { 

    Log-DailyEntry "Destination path '$DESTINATION_PATH' not found. Creating directory..." 

    New-Item -Path $DESTINATION_PATH -ItemType Directory | Out-Null 

} 



# 3. Take the IIS configuration backup. 

Log-DailyEntry "Executing Backup-WebConfiguration for name: '$backupName'..." 

try { 

    Backup-WebConfiguration -Name $backupName -ErrorAction Stop #The (Backup-WebConfigration) is the command used to backup the IIS settings in powershell

    Log-DailyEntry "SUCCESS: IIS backup created in temporary folder: '$backupTempFolder'." 

} catch { 

    <#
    ($_.Exception.Message) used in describing an error in the exception message, which can be accessed within a catch block using the automatic variable ($_) or ($PSItem) 
    #>

    Log-DailyEntry "FATAL ERROR: IIS backup failed. Error: $($_.Exception.Message)" 

    exit 1  

} 



# 4. CRITICAL STEP: Copy the backup folder to the safe F: drive location. 

Log-DailyEntry "Copying backup from temporary C: drive to '$finalBackupPath'..." 

try { 

    # Copy the whole directory recursively 

    Copy-Item -Path $backupTempFolder -Destination $finalBackupPath -Recurse -ErrorAction Stop 

     

    # Verify the final backup path exists before logging success 

    if (Test-Path $finalBackupPath) { 

        Log-DailyEntry "SUCCESS: Backup folder successfully copied to F: drive." 

    } else { 

        Log-DailyEntry "FATAL ERROR: Copy failed. Final folder was NOT found at '$finalBackupPath'." 


    } 

} catch { 

    Log-DailyEntry "FATAL ERROR: Copy-Item failed. Error: $($_.Exception.Message)" 

} 



# 5. CRITICAL CLEANUP: Delete the temporary IIS backup folder. 

Log-DailyEntry "Starting cleanup: Deleting temporary IIS backup folder '$backupTempFolder'..." 

try { 

    Remove-Item -Path $backupTempFolder -Recurse -Force -ErrorAction Stop 

    Log-DailyEntry "Cleanup SUCCESS: Temporary backup folder deleted." 

} catch { 

    Log-DailyEntry "CRITICAL WARNING: Failed to delete temporary IIS backup folder. Error: $($_.Exception.Message)" 

} 



Log-DailyEntry "IIS Configuration Backup Job completed. Final backup is located at '$finalBackupPath'." 