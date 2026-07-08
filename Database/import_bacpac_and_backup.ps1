<#
.SYNOPSIS
    Imports a .bacpac file into a local SQL Server instance, then backs up the resulting database to a .bak file.

.DESCRIPTION
    This script performs a two-step process:
    1. Uses SqlPackage.exe to import a .bacpac file into a local SQL Server instance, creating a new database.
    2. Runs a T-SQL BACKUP DATABASE command against that database to produce a .bak file.

    Prerequisites:
    - SqlPackage.exe must be installed and available (comes with SSMS/SSDT/Azure Data Studio,
      or install standalone via: dotnet tool install -g microsoft.sqlpackage).
    - The SqlServer PowerShell module (Invoke-Sqlcmd) OR the sqlcmd utility must be available for the backup step.
    - The account running SQL Server must have write access to the backup destination folder.

.PARAMETER BacpacPath
    Full path to the source .bacpac file.

.PARAMETER ServerInstance
    SQL Server instance to import into. Default: localhost (or ".\SQLEXPRESS" / "(localdb)\MSSQLLocalDB").

.PARAMETER DatabaseName
    Name of the database to create on import. Defaults to the bacpac file name if left blank.

.PARAMETER BakPath
    Full path where the .bak file should be written. Defaults to the same folder as the bacpac, using the database name, if left blank.

.PARAMETER SqlPackagePath
    Path to sqlpackage.exe. Defaults to "sqlpackage", assuming it is available on PATH.

.EXAMPLE
    .\Import-Bacpac-And-Backup.ps1 -BacpacPath "C:\Temp\MyDb.bacpac" -ServerInstance "localhost" -DatabaseName "MyDb_Restored"

.NOTES
    Default parameter values below can be edited directly so the script can be run with F5 in PowerShell ISE
    without needing to pass arguments manually.

    Performance tuning applied:
    - sqlpackage import uses /p:DisableIndexesForDataPhase and /p:MaxParallelism to speed up data load.
    - BACKUP DATABASE uses tuned BUFFERCOUNT/MAXTRANSFERSIZE for faster sequential I/O.
    - Module availability is checked once and cached instead of repeated Get-Module -ListAvailable calls.
#>

param(
    [string]$BacpacPath = "D:\Database\DB\Backup\trail-crm-dev 20260701.bacpac",
    [string]$ServerInstance = "localhost",
    [string]$DatabaseName = "trail-crm-dev",
    [string]$BakPath = "D:\Database\DB\Backup\trail-crm-dev.bak",
    [string]$SqlPackagePath = "sqlpackage"
)

$ErrorActionPreference = "Stop"

# Cache module availability once instead of calling Get-Module -ListAvailable repeatedly
$Script:HasSqlServerModule = [bool](Get-Module -ListAvailable -Name SqlServer)
if ($Script:HasSqlServerModule) {
    Import-Module SqlServer -ErrorAction SilentlyContinue
}

# ---- Validate input ----
if (-not (Test-Path $BacpacPath)) {
    throw "Bacpac file not found: $BacpacPath"
}

if (-not $DatabaseName) {
    $DatabaseName = [System.IO.Path]::GetFileNameWithoutExtension($BacpacPath)
}

if (-not $BakPath) {
    $folder = Split-Path -Parent $BacpacPath
    $BakPath = Join-Path $folder "$DatabaseName.bak"
}

Write-Host "=== Step 1: Import .bacpac into SQL Server ===" -ForegroundColor Cyan
Write-Host "Bacpac      : $BacpacPath"
Write-Host "Server      : $ServerInstance"
Write-Host "Database    : $DatabaseName"

# Check that sqlpackage is available
try {
    & $SqlPackagePath /version | Out-Null
}
catch {
    throw "sqlpackage not found. Install it with: dotnet tool install -g microsoft.sqlpackage, or pass the full path via -SqlPackagePath."
}

# ---- Helper: run a T-SQL query against the server, using Invoke-Sqlcmd if available, else sqlcmd ----
function Invoke-SqlQuery {
    param(
        [Parameter(Mandatory = $true)][string]$ServerInstance,
        [Parameter(Mandatory = $true)][string]$Query
    )

    if ($Script:HasSqlServerModule) {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $Query -QueryTimeout 0 -TrustServerCertificate
    }
    else {
        $tmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
        Set-Content -Path $tmpSql -Value $Query -Encoding UTF8
        & sqlcmd -S $ServerInstance -i $tmpSql -b -C
        $exitCode = $LASTEXITCODE
        Remove-Item $tmpSql -Force
        if ($exitCode -ne 0) {
            throw "sqlcmd query failed with exit code $exitCode"
        }
    }
}

# ---- Check whether a database with the same name already exists ----
Write-Host "`nChecking whether database [$DatabaseName] already exists on [$ServerInstance]..." -ForegroundColor Cyan

$checkQuery = "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name = N'$DatabaseName';"
$dbExists = $false

if ($Script:HasSqlServerModule) {
    $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $checkQuery -QueryTimeout 0 -TrustServerCertificate
    if ($result) { $dbExists = $true }
}
else {
    $tmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
    Set-Content -Path $tmpSql -Value $checkQuery -Encoding UTF8
    $output = & sqlcmd -S $ServerInstance -i $tmpSql -b -h -1 -W -C
    Remove-Item $tmpSql -Force
    if ($output -and ($output | Where-Object { $_.Trim() -eq $DatabaseName })) { $dbExists = $true }
}

if ($dbExists) {
    Write-Host "Database [$DatabaseName] already exists on [$ServerInstance]." -ForegroundColor Yellow
    $answer = Read-Host "Do you want to drop it and continue with the import? (y/n)"
    if ($answer -match '^(y|yes)$') {
        Write-Host "Dropping database [$DatabaseName]..." -ForegroundColor Yellow
        $dropQuery = @"
IF DB_ID(N'$DatabaseName') IS NOT NULL
BEGIN
    ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$DatabaseName];
END
"@
        Invoke-SqlQuery -ServerInstance $ServerInstance -Query $dropQuery
        Write-Host "Database [$DatabaseName] dropped." -ForegroundColor Green
    }
    else {
        Write-Host "Aborted: database [$DatabaseName] already exists and was not dropped." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "No existing database named [$DatabaseName] found. Proceeding." -ForegroundColor Green
}

# Import bacpac -> creates a new database on the local SQL Server instance
# Note: /p:VerboseLogging=false plus the built-in progress messages from SqlPackage
# (e.g. "xx percent complete") stream live only when the process is invoked directly
# with the call operator (&) below -- Start-Process with -NoNewWindow buffers the
# carriage-return-based progress lines and only shows the final output.
#
# Performance flags:
# - DisableIndexesForDataPhase: drops non-clustered indexes before the data load and
#   rebuilds them afterwards, avoiding per-row index maintenance during bulk insert.
# - MaxParallelism: raises the number of tables/objects sqlpackage processes concurrently.
$importArgs = @(
    "/Action:Import",
    "/SourceFile:$BacpacPath",
    "/TargetServerName:$ServerInstance",
    "/TargetDatabaseName:$DatabaseName",
    "/TargetTrustServerCertificate:True",
    "/p:CommandTimeout=0",
    "/p:DisableIndexesForDataPhase=True",
    "/p:MaxParallelism=8"
)

Write-Host "Running sqlpackage import..." -ForegroundColor Yellow
& $SqlPackagePath @importArgs
if ($LASTEXITCODE -ne 0) {
    throw "sqlpackage import failed with exit code $LASTEXITCODE"
}
Write-Host "Import succeeded: database [$DatabaseName] was created on [$ServerInstance]." -ForegroundColor Green

Write-Host "`n=== Step 2: Backup database to .bak file ===" -ForegroundColor Cyan
Write-Host "Bak output  : $BakPath"

# Ensure destination folder exists
$bakFolder = Split-Path -Parent $BakPath
if (-not (Test-Path $bakFolder)) {
    New-Item -ItemType Directory -Path $bakFolder -Force | Out-Null
}

# Performance flags:
# - MAXTRANSFERSIZE: larger I/O block size per transfer (4 MB), fewer round-trips to disk.
# - BUFFERCOUNT: more I/O buffers in parallel, improves throughput especially on SSD/RAID.
# Tune these down if the SQL Server host has limited memory available for backup buffers.
$backupQuery = @"
BACKUP DATABASE [$DatabaseName]
TO DISK = N'$BakPath'
WITH FORMAT, INIT, NAME = N'$DatabaseName-Full', COMPRESSION, STATS = 10,
MAXTRANSFERSIZE = 4194304, BUFFERCOUNT = 50;
"@

# Prefer the SqlServer module if available, otherwise fall back to sqlcmd
if ($Script:HasSqlServerModule) {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $backupQuery -QueryTimeout 0 -TrustServerCertificate
}
else {
    Write-Host "SqlServer module not found, using sqlcmd instead." -ForegroundColor Yellow
    $tmpSql = [System.IO.Path]::GetTempFileName() + ".sql"
    Set-Content -Path $tmpSql -Value $backupQuery -Encoding UTF8
    & sqlcmd -S $ServerInstance -i $tmpSql -b -C
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd backup failed with exit code $LASTEXITCODE"
    }
    Remove-Item $tmpSql -Force
}

if (Test-Path $BakPath) {
    Write-Host "`nDone! The .bak file was created at: $BakPath" -ForegroundColor Green
}
else {
    throw "The .bak file was not found after the backup step. Check that the SQL Server service account has write permission to the destination folder."
}