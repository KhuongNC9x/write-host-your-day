# startup-alert.ps1

$vmName     = $env:COMPUTERNAME
$timestamp  = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
$osVersion  = (Get-CimInstance Win32_OperatingSystem).Caption
$userName   = $env:USERNAME
$ipAddress  = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip

$slackWebhook = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

$text = @"
****************************************************************************************************************************************
:rocket: *VM Started*
:computer: Hostname: *$vmName*
:bust_in_silhouette: User: *$userName*
:satellite: Public IP: *$ipAddress*
:dvd: OS: *$osVersion*
:clock1: Time: *$timestamp*
"@

$payload = @{ text = $text.Trim() } | ConvertTo-Json -Depth 3

try {
    Invoke-RestMethod -Uri $slackWebhook -Method Post -Body $payload -ContentType 'application/json'
    Write-Host "Slack notification sent successfully."
}
catch {
    Write-Error "Failed to send Slack notification. $_"
}
