$serviceName = 'MSSQL$MSSQLSERVER01'
$slackWebhookUrl = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

# Get current date and time
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Check service status
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($null -eq $service) {
    $message = @"
    ****************************************************************************************************************************************
    *[$now]* SQL Server service '$serviceName' not found on this machine.
"@
}
elseif ($service.Status -ne "Running") {
    try {
        Start-Service -Name $serviceName -ErrorAction Stop
        $message = @"
    ****************************************************************************************************************************************
    *[$now]* SQL Server service '$serviceName' was *not running* and has been *restarted successfully*
"@
    }
    catch {
        $message = @"
    ****************************************************************************************************************************************
    *[$now]* SQL Server service '$serviceName' was not running and *failed to start*. Error: $_
"@
    }
}
else {
    $message = @"
    ****************************************************************************************************************************************
    *[$now]* SQL Server service '$serviceName' is already running
"@
}

# Send message to Slack
$payload = @{
    text = $message
} | ConvertTo-Json -Compress

Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType 'application/json' -Body $payload
