Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Đường dẫn file .bacpac
$bacpacPath = "D:\Database\DB\Backup\trail-crm-dev 20260701.bacpac"

# Load .NET ZIP library
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Mở file .bacpac như một ZIP
$zip = [System.IO.Compression.ZipFile]::Open($bacpacPath, 'Update')

# Tìm file BCP của bảng Audit.DDLEvents
$entry = $zip.Entries | Where-Object { $_.FullName -like "*DDLEvents*" }

# Xóa nội dung file (ghi đè bằng rỗng)
$stream = $entry.Open()
$stream.SetLength(0)
$stream.Close()

# Đóng ZIP
$zip.Dispose()

Write-Host "Done! File BCP đã được xóa trắng."