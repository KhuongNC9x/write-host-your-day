$slackWebhookUrl = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

try {
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    $settings = (Get-ItemProperty -Path $path).Settings
    $settings[8] = 2  # 0 = bottom, 1 = left, 2 = right, 3 = top
    Set-ItemProperty -Path $path -Name 'Settings' -Value $settings
    Stop-Process -f -ProcessName explorer

    $message = "*[$now]* Taskbar position changed to *Right* and Explorer restarted successfully"
}
catch {
    $message = "*[$now]* Failed to change taskbar position. Error: $_"
}

# Send to Slack
$payload = @{
    text = $message
} | ConvertTo-Json -Compress

Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType 'application/json' -Body $payload
