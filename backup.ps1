# === Konfigurasi ===
$projectDir = "D:\Magang\SQL-Server"
$backupDir  = "$projectDir\backups"
$retensiHari = 14   # backup lebih tua dari ini akan dihapus otomatis

# === Baca kredensial dari .env ===
$config = @{}
Get-Content "$projectDir\.env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') {
        $config[$matches[1].Trim()] = $matches[2].Trim()
    }
}
$pass = $config['MYSQL_ROOT_PASSWORD']
$db   = $config['MYSQL_DATABASE']

# === Jalankan backup ===
Set-Location $projectDir
$stamp   = Get-Date -Format "yyyy-MM-dd_HHmm"
$outFile = "$backupDir\$($db)_$stamp.sql"

$dump = docker compose exec -T mysql mysqldump -u root -p"$pass" `
        --databases $db --single-transaction --routines --triggers

if ($LASTEXITCODE -ne 0 -or -not $dump) {
    Write-Host "GAGAL: backup tidak dibuat." -ForegroundColor Red
    exit 1
}

# Tulis tanpa BOM supaya file bisa di-restore dengan bersih
[System.IO.File]::WriteAllText($outFile, ($dump -join "`n"), (New-Object System.Text.UTF8Encoding $false))

$sizeKB = [math]::Round((Get-Item $outFile).Length / 1KB, 1)
Write-Host "OK: $outFile ($sizeKB KB)" -ForegroundColor Green

# === Hapus backup lama ===
Get-ChildItem "$backupDir\*.sql" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$retensiHari) } |
    Remove-Item -Force