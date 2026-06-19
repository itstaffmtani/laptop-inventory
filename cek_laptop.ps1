# =============================================================
# MTani — Inventarisasi Laptop Karyawan
# Jalankan via cek_laptop.bat (double-click)
# =============================================================

Add-Type -AssemblyName System.Web

function Encode($val) {
    return [System.Web.HttpUtility]::UrlEncode($val)
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   MTani — Inventarisasi Laptop Karyawan" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mendeteksi spesifikasi laptop..." -ForegroundColor Yellow

# ── Deteksi spesifikasi ──────────────────────────────────────

$cs       = Get-WmiObject Win32_ComputerSystem
$cpu_obj  = Get-WmiObject Win32_Processor | Select-Object -First 1
$os_obj   = Get-WmiObject Win32_OperatingSystem
$bios     = Get-WmiObject Win32_BIOS
$disks    = Get-WmiObject Win32_DiskDrive

# Merk & Model
$merk     = $cs.Manufacturer.Trim()
$model    = $cs.Model.Trim()

# Rapihkan nama merk yang aneh dari WMI
$merk = $merk -replace "(?i)^(to be filled|default string|system manufacturer|o\.e\.m\.).*", "Tidak diketahui"
$model = $model -replace "(?i)^(to be filled|default string|system product name|o\.e\.m\.).*", "Tidak diketahui"

# CPU
$cpu_name = $cpu_obj.Name.Trim() -replace "\s+", " "

# RAM
$ram_bytes = $cs.TotalPhysicalMemory
$ram_gb    = [math]::Round($ram_bytes / 1GB)
$ram_str   = "${ram_gb} GB"

# Storage — ambil semua disk, format ringkas
$storage_parts = @()
foreach ($disk in $disks) {
    $size_gb = [math]::Round($disk.Size / 1GB)
    $type = if ($disk.MediaType -match "SSD|Solid") { "SSD" } elseif ($disk.MediaType -match "HDD|Fixed") { "HDD" } else { "SSD/HDD" }
    $storage_parts += "${size_gb} GB $type"
}
$storage_str = if ($storage_parts.Count -gt 0) { $storage_parts -join ", " } else { "Tidak terdeteksi" }

# OS
$os_name  = $os_obj.Caption.Trim()
$os_arch  = if ($os_obj.OSArchitecture) { $os_obj.OSArchitecture } else { "" }
$os_str   = "$os_name $os_arch".Trim()

# Serial number (opsional, untuk audit)
$serial   = $bios.SerialNumber.Trim()
$serial   = if ($serial -match "(?i)^(to be filled|default|n/a|0|none)") { "" } else { $serial }

Write-Host ""
Write-Host "Spesifikasi terdeteksi:" -ForegroundColor Green
Write-Host "  Merk    : $merk"
Write-Host "  Model   : $model"
Write-Host "  CPU     : $cpu_name"
Write-Host "  RAM     : $ram_str"
Write-Host "  Storage : $storage_str"
Write-Host "  OS      : $os_str"
Write-Host ""

# ── Buka form di browser ─────────────────────────────────────

$FORM_URL = "https://itstaffmtani.github.io/laptop-inventory/"

$params = "merk=$(Encode $merk)" +
          "&model=$(Encode $model)" +
          "&cpu=$(Encode $cpu_name)" +
          "&ram=$(Encode $ram_str)" +
          "&storage=$(Encode $storage_str)" +
          "&os=$(Encode $os_str)" +
          "&serial=$(Encode $serial)"

$full_url = "${FORM_URL}?${params}"

Write-Host "Membuka form di browser..." -ForegroundColor Yellow
Write-Host "(Isi nama + status laptop + kerusakan, lalu klik Kirim)" -ForegroundColor Gray
Write-Host ""

Start-Process $full_url

Write-Host "Form sudah terbuka di browser kamu." -ForegroundColor Green
Write-Host "Setelah submit, jendela ini bisa ditutup." -ForegroundColor Gray
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Read-Host "Tekan Enter untuk tutup"
