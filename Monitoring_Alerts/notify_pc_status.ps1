# ==== CONFIG ====
$slackWebhookUrl = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

try {
    # ==== LOGIC ====
    $time = Get-Date -Format "HH:mm:ss"
    $date = Get-Date -Format "dd-MM-yyyy"
    $hostname = $env:COMPUTERNAME
    $username = $env:USERNAME

    # Get local IPv4 address (excluding loopback and virtual)
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 `
        | Where-Object { $_.IPAddress -notlike "127.*" -and $_.InterfaceAlias -notlike "*Virtual*" } `
        | Select-Object -First 1 -ExpandProperty IPAddress)

$message = @"
****************************************************************************************************************************************
:computer: *$hostname* has *started or resumed* at $time on $date.

:bust_in_silhouette: *User:* $username  
:globe_with_meridians: *IP:* $ipAddress
"@

    # ==== SEND TO SLACK ====
    $payload = @{ text = $message } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType 'application/json' -Body $payload
}
catch {
    $errorMessage = "Error sending notification from *$env:COMPUTERNAME*: $($_.Exception.Message)"
    $errorPayload = @{ text = $errorMessage } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -ContentType 'application/json' -Body $errorPayload
}
