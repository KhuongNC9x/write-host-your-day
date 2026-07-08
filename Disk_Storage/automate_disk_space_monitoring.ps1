# Define Slack Webhook URL
$slackWebhook = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

# Function to send messages to Slack
function Send-SlackMessage($message) {
    $payload = @{ text = $message } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $slackWebhook -Method Post -Body $payload -ContentType 'application/json'
    } catch {
        Write-Host "Failed to send message to Slack: $_"
    }
}

# Convert size to readable format
function Convert-Size($bytes) {
    $kb = $bytes / 1024
    $mb = $bytes / 1MB  # binary MB
    return "{0:N0} KB ({1:N2} MB)" -f $kb, $mb
}

# Get Recycle Bin info using COM object
function Get-RecycleBinInfo {
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(10)  # 10 = Recycle Bin
        $items = $recycleBin.Items()
        $fileCount = $items.Count

        $totalSize = 0
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items.Item($i)
            $totalSize += $item.Size
        }

        return @{
            FileCount = $fileCount
            TotalSize = $totalSize
        }
    } catch {
        throw "Failed to access Recycle Bin info: $_"
    }
}

# Get computer name
$computerName = $env:COMPUTERNAME

# Get location based on public IP
try {
    $locationData = Invoke-RestMethod -Uri "http://ip-api.com/json"
    $city = $locationData.city
    $country = $locationData.country
    $location = "$city, $country"
} catch {
    $location = "Unknown Location"
    Send-SlackMessage ":warning: Could not retrieve location: $_"
}

# Start process
$startTime = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
Send-SlackMessage @"
    ****************************************************************************************************************************************
    :rocket: Disk Cleanup started at $startTime on *$computerName* in *$location*
"@

# Recycle Bin info
try {
    $info = Get-RecycleBinInfo
    $fileCount = $info.FileCount
    $readableSize = Convert-Size $info.TotalSize

    Send-SlackMessage ":mag: Files to delete: *$fileCount*, Total size: *$readableSize*"
} catch {
    Send-SlackMessage ":x: Failed to analyze Recycle Bin: $_"
}

# Clear Recycle Bin
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Send-SlackMessage ":white_check_mark: Recycle Bin emptied."
} catch {
    Send-SlackMessage ":x: Failed to empty Recycle Bin: $_"
}

# Run Disk Cleanup
try {
    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -NoNewWindow -Wait
    $endTime = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    Send-SlackMessage ":white_check_mark: Disk Cleanup completed at $endTime on *$computerName* in *$location*"
} catch {
    Send-SlackMessage ":x: Failed to run Disk Cleanup: $_"
}
