$source = "source path"
$destination = "destination path"
$slackWebhook = "REPLACE_WITH_YOUR_SLACK_WEBHOOK_URL"

$filesMoved = @()
$errors = @()

if (!(Test-Path -Path $destination)) {
    New-Item -ItemType Directory -Path $destination | Out-Null
}

# Get all files and subfolders recursively
Get-ChildItem -Path $source -Recurse -File | ForEach-Object {
    try {
        $extension = $_.Extension.TrimStart(".").ToUpper()
        if (-not $extension) { $extension = "Unknown" }

        # Get the relative path of the file (subfolder included)
        $relativePath = $_.FullName.Substring($source.Length)
        
        # Create the target folder path (keeping the original folder structure)
        $targetFolder = Join-Path -Path $destination -ChildPath (Split-Path -Path $relativePath -Parent)

        if (!(Test-Path -Path $targetFolder)) {
            New-Item -ItemType Directory -Path $targetFolder | Out-Null
        }

        # Create the target file path
        $targetPath = Join-Path -Path $targetFolder -ChildPath $_.Name
        Move-Item -Path $_.FullName -Destination $targetPath -Force

        $filesMoved += $relativePath
    }
    catch {
        $errors += "❌ $($_.FullName): $($_.Exception.Message)"
    }
}

# Get current date/time
$currentTime = (Get-Date).ToString("dd-MM-yyyy HH:mm")

# Start summary
$summary = ":inbox_tray: *File Move Summary* ($currentTime)" + "`n"
$summary += ":page_facing_up: *Total files moved:* $($filesMoved.Count)" + "`n"

# Add moved files
if ($filesMoved.Count -gt 0) {
    $summary += ":file_folder: *Moved files:*" + "`n:small_orange_diamond: " + ($filesMoved -join "`n:small_orange_diamond: ") + "`n"
}

# Add any errors
if ($errors.Count -gt 0) {
    $summary += "`n:warning: *Errors:*" + "`n:small_orange_diamond: " + ($errors -join "`n:small_orange_diamond: ")
}

# Send to Slack
Invoke-RestMethod -Uri $slackWebhook -Method Post -Body (@{
    text = $summary
} | ConvertTo-Json)

# Delete all files and folders in the source folder (Downloads)
Remove-Item -Path $source\* -Recurse -Force
