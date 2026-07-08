$slackWebhookUrl = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $settings = (Get-ItemProperty -Path $path).Settings
    $settings[8] = 3
    Set-ItemProperty -Path $path -Name 'Settings' -Value $settings
    Stop-Process -f -ProcessName explorer

    $message = "*[$now]* Task completed successfully: Taskbar position updated and Explorer restarted."
}
catch {
    $message = "*[$now]* Failed to update taskbar position. Error: $_"
}

# Send message to Slack
$payload = @{
    text = $message
} | ConvertTo-Json -Compress

Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType 'application/json' -Body $payload
