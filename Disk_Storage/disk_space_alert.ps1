# Set disk space threshold (change as needed)
$threshold = 10GB

# Slack webhook URL
$slackWebhook = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

# Function to send a message to Slack
function Send-SlackMessage($message) {
    $payload = @{ text = $message } | ConvertTo-Json
    Invoke-RestMethod -Uri $slackWebhook -Method Post -Body $payload -ContentType 'application/json'
}

try {
    $currentDate = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $message = "*$currentDate*`n"

    # Get computer name
    $computerName = $env:COMPUTERNAME

    # Check all drives
    $drives = Get-PSDrive -PSProvider FileSystem

    foreach ($drive in $drives) {
        if ($drive.Free -ne $null -and $drive.Free -lt $threshold) {
            $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
            $totalSpaceGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
            $message += ":warning: *Low Disk Space Alert on $computerName*. Drive $($drive.Name): has only $freeSpaceGB GB free.`n"
        }
    }

    if ($message -match $computerName) {
        Send-SlackMessage $message
    }

} catch {
    Send-SlackMessage "Error: $($_.Exception.Message)"
}
