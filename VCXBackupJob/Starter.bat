@echo off
REM --- This file forces the start of the PowerShell job and closes quietly. ---
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\VCXSchedualedJobs\VCXWebAppJob\VCXWebAppBackup.ps1"
EXIT