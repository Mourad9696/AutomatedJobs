Enterprise Application Monitoring & Backup Suite

📝 Project Overview
This repository hosts a custom-built automation suite designed to manage and protect mission-critical enterprise web applications. Designed for high-stakes environments—such as banking and financial settlement—this system ensures 100% uptime through a "set-and-forget" automation layer that handles database security, service health, and log management.

🚀 Key Functionalities
Secure Data Archiving: The system performs a "Dump-and-Lock" routine. It extracts relational databases into a clear format, compresses them to save storage, and applies AES-256 encryption. This ensures that even if the backup media is compromised, the data remains encrypted and inaccessible.

Intelligent Health Monitoring: Acting as a "Digital Security Guard," the suite performs heartbeat checks every 5 minutes on vital system services. If a service failure is detected, an immediate alert is dispatched. It also features "Recovery Logic" to notify administrators once the system returns to a healthy state.

Log Parsing & Simplification: Ingests complex, high-volume application logs (JSON/Structured) and translates them into human-readable reports. It specifically filters for critical security events, such as user authentication attempts (login/logout), providing a clean daily summary.

Industrial Reliability: Every script is built with advanced Error-Handling. The suite is "environment-aware," meaning it self-heals by creating missing directories and logging specific failure points to prevent "silent failures."

🛠 How the Ecosystem Works
The project follows a consistent "3-Layer Architecture" for every task:

The Trigger (Starter.bat): A lightweight bridge for the Windows Task Scheduler. It ensures scripts run with the correct environment variables, bypasses execution policy hurdles, and maintains the correct directory context.

The Brain (PowerShell Script): The core engine. It manages communications with the Database (PostgreSQL/SQL), handles file manipulation (7-Zip), and monitors Web Server (IIS) health.

The Memory (Log Folder): A self-generating audit trail. Every success, warning, or failure is timestamped, ensuring full transparency for IT auditors and system administrators.

🛡 Key Technical Pillars
Security-First: Implements memory-wiping logic to remove sensitive credentials (like DB passwords) from environment variables immediately after use.

Auditability: Every action is recorded in a rotating log system for historical analysis.

Efficiency: Automated compression routines protect server disk space, while the "Separation of Concerns" principle ensures backups are stored on dedicated, independent storage volumes.

Resilience: Designed to handle 64-bit system redirection and permission-heavy directories (like System32) without manual intervention.
