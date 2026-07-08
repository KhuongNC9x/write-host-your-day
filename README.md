# write-host-your-day

A personal collection of PowerShell scripts for system monitoring, disk alerts, database maintenance, and daily automation — most of them report status straight to Slack.

## Structure

```
Database/
  check_sql_services.ps1              # Checks a SQL Server service's status and alerts to Slack if it's down
  database_health_report.ps1          # Database health report
  import_bacpac_and_backup.ps1        # Imports a .bacpac into a local SQL Server instance, then backs it up to .bak
  remove_ddl_event_data.ps1           # Strips the Audit.DDLEvents entry out of a .bacpac archive
  stored_procedure_generation_script.ps1  # Scripts out all stored procedures from a database using SMO

Disk_Storage/
  automate_disk_space_monitoring.ps1  # Scheduled disk space check with Slack notification
  disk_space_alert.ps1                # Alerts to Slack when free space drops below a threshold
  move_downloads_to_another_drive.ps1 # Moves files from Downloads to an archive drive

Monitoring_Alerts/
  notify_pc_status.ps1                # Sends hostname, user, and IP info to Slack
  startup_alert.ps1                   # Posts a "VM started" notification to Slack on boot
  usb_detect.ps1                      # Watches for USB device connect/disconnect events

System_UI/
  disable_auto_hide_taskbar.ps1       # Moves the taskbar to the right and disables auto-hide
  enable_auto_hide_taskbar.ps1        # Restores default taskbar position/behavior
```

## Requirements

- Windows PowerShell 5.1+ (some scripts use Windows-only APIs like `Get-CimInstance`, registry paths, or Explorer restarts)
- SQL Server scripts additionally require:
  - `SqlPackage.exe` (from SSMS/SSDT/Azure Data Studio, or `dotnet tool install -g microsoft.sqlpackage`)
  - `SqlServer` PowerShell module or `sqlcmd`
  - SMO assemblies for the stored procedure generator

## Setup

Several scripts post to a Slack Incoming Webhook. The URLs in this repo are placeholders (`REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL`) — before running a script, replace the placeholder with your own webhook URL. Recommended: load it from an environment variable instead of hardcoding it:

```powershell
$slackWebhookUrl = $env:SLACK_WEBHOOK_URL
```

## Usage

Run scripts directly, e.g.:

```powershell
.\Disk_Storage\disk_space_alert.ps1
```

Several are intended to run on a schedule (Task Scheduler) — e.g. `startup_alert.ps1` on logon, `automate_disk_space_monitoring.ps1` on a recurring trigger.