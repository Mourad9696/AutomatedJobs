@echo off
REM --- This file forces the start of the PowerShell job and closes quietly. ---
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\VCXSchedualedJobs\LoginLogoutJob\loginLogoutLogScript.ps1"
EXIT