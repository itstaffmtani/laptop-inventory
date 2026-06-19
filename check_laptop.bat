@echo off
:: MTani — Laptop Inventory · Self-contained (no external .ps1 needed)
set "BAT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $f = (Get-Content $env:BAT_PATH -Raw); Invoke-Expression ($f -split '#PS1#\r?\n',2)[1] }"
exit /b
#PS1#
Add-Type -AssemblyName System.Web

function Encode($val) {
    return [System.Web.HttpUtility]::UrlEncode($val)
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   MTani -- Inventarisasi Laptop Karyawan" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Mendeteksi spesifikasi laptop..." -ForegroundColor Yellow

$cs       = Get-WmiObject Win32_ComputerSystem
$cpu_obj  = Get-WmiObject Win32_Processor | Select-Object -First 1
$os_obj   = Get-WmiObject Win32_OperatingSystem
$bios     = Get-WmiObject Win32_BIOS

$merk     = $cs.Manufacturer.Trim()
$model    = $cs.Model.Trim()

$merk  = $merk  -replace "(?i)^(to be filled|default string|system manufacturer|o\.e\.m\.).*", "Tidak diketahui"
$model = $model -replace "(?i)^(to be filled|default string|system product name|o\.e\.m\.).*", "Tidak diketahui"

$cpu_name = $cpu_obj.Name.Trim() -replace "\s+", " "

$ram_modules  = Get-WmiObject Win32_PhysicalMemory
$ram_total_gb = [math]::Round(($ram_modules | Measure-Object -Property Capacity -Sum).Sum / 1GB)
$first_mod    = $ram_modules | Select-Object -First 1
$ddr_map      = @{ 20="DDR"; 21="DDR2"; 22="DDR2"; 24="DDR3"; 26="DDR4"; 34="DDR5" }
$ddr_type     = $ddr_map[[int]$first_mod.SMBIOSMemoryType]
if (-not $ddr_type) { $ddr_type = "" }
$spd          = if ($first_mod.ConfiguredClockSpeed -gt 0) { $first_mod.ConfiguredClockSpeed } else { $first_mod.Speed }
$ram_str      = if ($ddr_type -and $spd -gt 0) { "${ram_total_gb} GB $ddr_type ${spd} MHz" }
                elseif ($ddr_type)              { "${ram_total_gb} GB $ddr_type" }
                else                            { "${ram_total_gb} GB" }

$storage_parts = @()
try {
    foreach ($pd in (Get-PhysicalDisk -ErrorAction Stop)) {
        $size_gb = [math]::Round($pd.Size / 1GB)
        $bus     = $pd.BusType
        $media   = $pd.MediaType
        $name_lc = $pd.FriendlyName.ToLower()
        if     ($media -eq "SSD" -and $bus -eq "NVMe") { $type = "SSD NVMe" }
        elseif ($media -eq "SSD")                       { $type = "SSD" }
        elseif ($media -eq "HDD")                       { $type = "HDD" }
        elseif ($name_lc -match "nvme")                 { $type = "SSD NVMe" }
        elseif ($name_lc -match "ssd")                  { $type = "SSD" }
        else                                            { $type = "HDD" }
        $storage_parts += "${size_gb} GB $type"
    }
} catch {
    foreach ($disk in (Get-WmiObject Win32_DiskDrive)) {
        $size_gb = [math]::Round($disk.Size / 1GB)
        $m       = $disk.Model.ToLower()
        if     ($m -match "nvme")    { $type = "SSD NVMe" }
        elseif ($m -match "ssd")     { $type = "SSD" }
        else                         { $type = "HDD" }
        $storage_parts += "${size_gb} GB $type"
    }
}
$storage_str = if ($storage_parts.Count -gt 0) { $storage_parts -join ", " } else { "Tidak terdeteksi" }

$os_name  = $os_obj.Caption.Trim()
$os_arch  = if ($os_obj.OSArchitecture) { $os_obj.OSArchitecture } else { "" }
$os_str   = "$os_name $os_arch".Trim()

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
