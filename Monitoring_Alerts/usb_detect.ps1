$slackWebhookUrl = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

# HashSet to track recently detected devices
$previousDevices = New-Object 'System.Collections.Generic.HashSet[string]'

# Lists of ignored devices, manufacturers, and types
$ignoredDevices = @(
    #"HID-compliant mouse", "HID Keyboard Device", "HID-compliant system controller",
    #"HID-compliant consumer control device", "HID-compliant vendor-defined device",
    #"HID-compliant device", "USB Input Device", "USB Composite Device"
)

$ignoredManufacturers = @(
    "(Standard system devices)", "Standard system devices", "(Standard USB Host Controller)",
    "Standard USB Host Controller", "(Standard keyboards)", "Standard keyboards"
)

$ignoredDeviceTypes = @("Bluetooth", "MEDIA", "System", "Ports", "Net")

function Send-SlackNotification {
    param ([string]$message)

    try {
        $payload = @{ text = $message } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -Body $payload -ContentType 'application/json'
    } catch {
        Write-Host "⚠ Failed to send Slack notification: $_"
    }
}

function Monitor-USBDevices {
    # Get current date and time
    $currentDate = Get-Date -Format "dd-MM-yyyy HH:mm:ss"

    # Get hostname (machine name)
    $hostname = $env:COMPUTERNAME

    # Get IP address (IPv4)
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" } | Select-Object -ExpandProperty IPAddress)[0]

    # Get location info
    $locationInfo = "Hostname: $hostname, IP: $ipAddress, Date: $currentDate"

    $query = "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_PnPEntity'"
    $watcher = New-Object Management.ManagementEventWatcher
    $watcher.Query = $query
    $watcher.Scope = New-Object Management.ManagementScope "root\CIMV2"

    Write-Host "🔍 Monitoring USB devices... Press Ctrl+C to stop."

    while ($true) {
        $event = $watcher.WaitForNextEvent()
        $device = $event.TargetInstance
        $deviceID = $device.DeviceID
        $deviceName = $device.Name
        $deviceType = $device.PNPClass
        $manufacturer = $device.Manufacturer

        # Ignore devices based on name, manufacturer, or type
        if ([string]::IsNullOrEmpty($deviceName) -or
            $deviceName -in $ignoredDevices -or
            [string]::IsNullOrEmpty($manufacturer) -or
            $manufacturer -in $ignoredManufacturers -or
            [string]::IsNullOrEmpty($deviceType) -or
            $deviceType -in $ignoredDeviceTypes) {

            Write-Host "🚫 Ignored device: $deviceName ($manufacturer, $deviceType)"
            continue
        }

        # Avoid duplicate notifications
        if ($previousDevices.Add($deviceID)) {
            $deviceInfo = @"
****************************************************************************************************************************************
*New USB Device Detected!*
*Name:* $deviceName
*Manufacturer:* $manufacturer
*Device ID:* $deviceID
*Device Type:* $deviceType
*Location:* $locationInfo
"@
            Write-Host $deviceInfo
            Send-SlackNotification -message $deviceInfo
        }
    }
}

Monitor-USBDevices