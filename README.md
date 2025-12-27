                                                            **VCX automated scripts for monitoring and backup support**


📝 Project Overview:
This repository hosts a custom-built automation suite designed to manage and protect VCX (Visa Clearing Exchange), a mission-critical banking web application used for financial settlement with Visa.

Because VCX is responsible for retrieving and settling bank funds, the system requires 100% uptime and guaranteed data backups. These scripts replace manual maintenance with a "set-and-forget" automation layer that handles database security, service monitoring, and log management.

What these scripts do (The Big Picture):
#########################################
Secure Data Archiving: Instead of just copying data, the system performs a professional "Dump-and-Lock" routine. It extracts the PostgreSQL database into a clear format, immediately shrinks it to save space, and locks it with a password. This ensures that even if the backup drive is stolen, the bank's data remains encrypted.

Intelligent Monitoring: The system acts as a "Digital Security Guard." Every 5 minutes, it checks if the VCX services are breathing. If something breaks, it sends an alert immediately. Once the system is fixed, it sends a "Recovery" email so the team knows the issue is resolved.

Log Simplification: Application logs are usually messy and hard to read (JSON format). These scripts act as a translator, digging through thousands of lines of code to pull out only the important details—like who logged in and out—and presenting them in a clean, human-readable report.

Professional Reliability: Every script is built with "Error-Handling." This means if a folder is missing, the script creates it. If a process fails, the script logs exactly why. This prevents the "silent failures" that often happen with basic automation.

Why this is important?
######################
In a banking environment, manual mistakes are costly. By using this PowerShell & .bat architecture, the VCX environment becomes self-sustaining. The scripts ensure that the database is backed up every night at midnight, the logs are cleaned by 6:00 AM, and the services are watched 24/7.

Key Technical Pillars:
######################
Security: Wiping passwords from memory after use.

Auditability: Every single action is time-stamped and logged.

Efficiency: Automated compression of files to protect server disk space.

Separtion of concerns: The backups are stored in a seprate disk.

How the Ecosystem Works?
########################

The project follows a consistent **"3-Layer Architecture"** for every task it performs:

The Trigger **(Starter.bat)**: A lightweight bridge that allows Windows Task Scheduler to run scripts seamlessly, bypassing permission issues and ensuring the environment starts correctly.

The Brain **(PowerShell Script)**: The core logic that performs the heavy lifting—whether it’s communicating with the PostgreSQL database, zipping files with 7-Zip, or checking IIS service health.

The Memory **(Log Folder)**: A self-generating audit trail. No action is taken in "silence"; every success or failure is recorded with a timestamp, allowing IT teams to review the system's history at any time.

Core Capabilities:
##################
Database Preservation: Automatically exports the entire database at midnight, compresses it to save disk space, and encrypts it with a password to meet bank security standards.

Active Surveillance: A "heartbeat" check runs every 5 minutes. It monitors the VCX service and sends email alerts if the system stops responding, including a "Recovery" notice once the system is back online.

Intelligence Extraction: It scans complex, messy .json application logs and "translates" them into simple, readable text files that show daily user login and logout activity.

System Resilience: The scripts are **"environment-aware."** They check for their own folders, manage their own memory _(cleaning up passwords)_, and handle errors gracefully without crashing the server.
