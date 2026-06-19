@echo off
:: MTani — Laptop Inventory · Self-contained (no external .ps1 needed)
set "BAT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $f = (Get-Content $env:BAT_PATH -Raw -Encoding UTF8); $ps1 = ($f -split '#PS1#\r?\n',2)[1]; $tmp = [IO.Path]::GetTempFileName() + '.ps1'; [IO.File]::WriteAllText($tmp, $ps1, [Text.Encoding]::UTF8); try { & $tmp } finally { Remove-Item $tmp -Force -EA 0 } }"
exit /b
#PS1#
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

$cs      = Get-WmiObject Win32_ComputerSystem
$cpu_obj = Get-WmiObject Win32_Processor | Select-Object -First 1
$os_obj  = Get-WmiObject Win32_OperatingSystem
$bios    = Get-WmiObject Win32_BIOS

$hostname = $env:COMPUTERNAME

$merk  = $cs.Manufacturer.Trim()
$model = $cs.Model.Trim()
$merk  = $merk  -replace "(?i)^(to be filled|default string|system manufacturer|o\.e\.m\.).*", "Tidak diketahui"
$model = $model -replace "(?i)^(to be filled|default string|system product name|o\.e\.m\.).*", "Tidak diketahui"

$cpu_name    = $cpu_obj.Name.Trim() -replace "\s+", " "
$cpu_cores   = [string]$cpu_obj.NumberOfCores
$cpu_threads = [string]$cpu_obj.NumberOfLogicalProcessors
$arch_map    = @{ 0="x86"; 5="ARM"; 9="x64"; 12="ARM64" }
$cpu_arch    = $arch_map[[int]$cpu_obj.Architecture]
if (-not $cpu_arch) { $cpu_arch = "x64" }

$gpu_obj = Get-WmiObject Win32_VideoController |
           Where-Object { $_.Name -notmatch "Microsoft Basic|Remote Desktop|Virtual|VMware|Hyper-V" } |
           Select-Object -First 1
$gpu_str = if ($gpu_obj) { $gpu_obj.Name.Trim() } else { "" }

$ram_modules  = Get-WmiObject Win32_PhysicalMemory
$ram_total_gb = [math]::Round(($ram_modules | Measure-Object -Property Capacity -Sum).Sum / 1GB)
$first_mod    = $ram_modules | Select-Object -First 1
$ddr_map      = @{ 20="DDR"; 21="DDR2"; 22="DDR2 FB-DIMM"; 24="DDR3"; 26="DDR4"; 29="LPDDR2"; 30="LPDDR3"; 31="LPDDR4"; 34="DDR5"; 35="LPDDR5" }
$ddr_type     = $ddr_map[[int]$first_mod.SMBIOSMemoryType]
if (-not $ddr_type) { $ddr_type = "" }
$spd          = if ($first_mod.ConfiguredClockSpeed -gt 0) { $first_mod.ConfiguredClockSpeed } else { $first_mod.Speed }
$ram_gb_str    = [string]$ram_total_gb
$ram_type_str  = $ddr_type
$ram_speed_str = if ($spd -gt 0) { [string]$spd } else { "" }

$ram_free_bytes    = $os_obj.FreePhysicalMemory * 1KB
$ram_used_pct      = [math]::Round(($cs.TotalPhysicalMemory - $ram_free_bytes) / $cs.TotalPhysicalMemory * 100)
$ram_used_gb       = [math]::Round(($cs.TotalPhysicalMemory - $ram_free_bytes) / 1GB, 1)
$ram_usage_pct_str = [string]$ram_used_pct
$ram_usage_gb_str  = [string]$ram_used_gb

$ssd_gb_total = 0
$ssd_types    = @()
$hdd_gb_total = 0
try {
    foreach ($pd in (Get-PhysicalDisk -ErrorAction Stop)) {
        $size_gb = [math]::Round($pd.Size / 1GB)
        $bus     = $pd.BusType
        $media   = $pd.MediaType
        $name_lc = $pd.FriendlyName.ToLower()
        if     ($media -eq "SSD" -and $bus -eq "NVMe") { $ssd_gb_total += $size_gb; $ssd_types += "NVMe" }
        elseif ($media -eq "SSD")                       { $ssd_gb_total += $size_gb; $ssd_types += "SATA" }
        elseif ($media -eq "HDD")                       { $hdd_gb_total += $size_gb }
        elseif ($name_lc -match "nvme")                 { $ssd_gb_total += $size_gb; $ssd_types += "NVMe" }
        elseif ($name_lc -match "ssd")                  { $ssd_gb_total += $size_gb; $ssd_types += "SATA" }
        else                                            { $hdd_gb_total += $size_gb }
    }
} catch {
    foreach ($disk in (Get-WmiObject Win32_DiskDrive)) {
        $size_gb = [math]::Round($disk.Size / 1GB)
        $m       = $disk.Model.ToLower()
        if     ($m -match "nvme")    { $ssd_gb_total += $size_gb; $ssd_types += "NVMe" }
        elseif ($m -match "ssd")     { $ssd_gb_total += $size_gb; $ssd_types += "SATA" }
        else                         { $hdd_gb_total += $size_gb }
    }
}
$ssd_gb_str   = if ($ssd_gb_total -gt 0) { [string]$ssd_gb_total } else { "" }
$ssd_tipe_str = if ($ssd_types.Count -gt 0) { ($ssd_types | Select-Object -Unique) -join "/" } else { "" }
$hdd_gb_str   = if ($hdd_gb_total -gt 0) { [string]$hdd_gb_total } else { "" }

$os_free_gb_str  = ""
$os_total_gb_str = ""
try {
    $os_drive = $os_obj.SystemDrive
    $ldd      = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$os_drive'" -ErrorAction Stop
    if ($ldd) {
        $total_gb        = [math]::Round($ldd.Size / 1GB)
        $free_gb         = [math]::Round($ldd.FreeSpace / 1GB)
        $os_free_gb_str  = [string]$free_gb
        $os_total_gb_str = [string]$total_gb
    }
} catch {}

$battery_pct_str       = ""
$battery_wh_str        = ""
$battery_wh_design_str = ""
try {
    $static = Get-WmiObject -Namespace root/WMI -Class BatteryStaticData -ErrorAction Stop | Select-Object -First 1
    $full   = Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1
    if ($static -and $full -and $static.DesignedCapacity -gt 0) {
        $pct        = [math]::Round($full.FullChargedCapacity / $static.DesignedCapacity * 100)
        $design_wh  = [math]::Round($static.DesignedCapacity / 1000, 1)
        $current_wh = [math]::Round($full.FullChargedCapacity / 1000, 1)
        $battery_pct_str       = [string]$pct
        $battery_wh_str        = [string]$current_wh
        $battery_wh_design_str = [string]$design_wh
    }
} catch {}

$mac_str = ""
try {
    $nic = Get-WmiObject Win32_NetworkAdapterConfiguration |
           Where-Object { $_.IPEnabled -and $_.MACAddress -and
                          $_.Description -notmatch "Virtual|VMware|Hyper-V|Bluetooth|Miniport|Loopback" } |
           Select-Object -First 1
    if ($nic) { $mac_str = $nic.MACAddress }
} catch {}

$os_name     = $os_obj.Caption.Trim()
$os_arch_str = if ($os_obj.OSArchitecture) { $os_obj.OSArchitecture } else { "" }
$os_str      = "$os_name $os_arch_str".Trim()

$serial = $bios.SerialNumber.Trim()
$serial = if ($serial -match "(?i)^(to be filled|default|n/a|0|none)") { "" } else { $serial }

Write-Host ""
Write-Host "Spesifikasi terdeteksi:" -ForegroundColor Green
Write-Host "  Hostname : $hostname    MAC: $mac_str"
Write-Host "  Merk     : $merk    Model: $model"
Write-Host "  CPU      : $cpu_name"
Write-Host "           : $cpu_cores cores / $cpu_threads threads / $cpu_arch"
Write-Host "  GPU      : $gpu_str"
Write-Host "  RAM      : ${ram_gb_str} GB  $ram_type_str  ${ram_speed_str} MHz  [Usage: ${ram_usage_pct_str}% / ${ram_usage_gb_str} GB]"
Write-Host "  SSD      : ${ssd_gb_str} GB ($ssd_tipe_str)"
Write-Host "  HDD      : ${hdd_gb_str} GB"
Write-Host "  Partisi  : OS Free ${os_free_gb_str} GB / ${os_total_gb_str} GB"
Write-Host "  Battery  : ${battery_pct_str}% (${battery_wh_str} Wh / ${battery_wh_design_str} Wh)"
Write-Host "  OS       : $os_str"
Write-Host ""

$FORM_URL = "https://itstaffmtani.github.io/laptop-inventory/"

$params = "hostname=$(Encode $hostname)" +
          "&merk=$(Encode $merk)" +
          "&model=$(Encode $model)" +
          "&cpu=$(Encode $cpu_name)" +
          "&cpu_cores=$(Encode $cpu_cores)" +
          "&cpu_threads=$(Encode $cpu_threads)" +
          "&cpu_arch=$(Encode $cpu_arch)" +
          "&gpu=$(Encode $gpu_str)" +
          "&ram_gb=$(Encode $ram_gb_str)" +
          "&ram_type=$(Encode $ram_type_str)" +
          "&ram_speed=$(Encode $ram_speed_str)" +
          "&ram_usage_pct=$(Encode $ram_usage_pct_str)" +
          "&ram_usage_gb=$(Encode $ram_usage_gb_str)" +
          "&ssd_gb=$(Encode $ssd_gb_str)" +
          "&ssd_tipe=$(Encode $ssd_tipe_str)" +
          "&hdd_gb=$(Encode $hdd_gb_str)" +
          "&battery_pct=$(Encode $battery_pct_str)" +
          "&battery_wh=$(Encode $battery_wh_str)" +
          "&battery_wh_design=$(Encode $battery_wh_design_str)" +
          "&os=$(Encode $os_str)" +
          "&os_free_gb=$(Encode $os_free_gb_str)" +
          "&os_total_gb=$(Encode $os_total_gb_str)" +
          "&serial=$(Encode $serial)" +
          "&mac=$(Encode $mac_str)"

$full_url = "${FORM_URL}?${params}"

Write-Host "Membuka form di browser..." -ForegroundColor Yellow
Write-Host "(Isi data diri & kondisi laptop, lalu klik Kirim)" -ForegroundColor Gray
Write-Host ""

Start-Process $full_url

Write-Host "Form sudah terbuka di browser kamu." -ForegroundColor Green
Write-Host "Setelah submit, jendela ini bisa ditutup." -ForegroundColor Gray
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Read-Host "Tekan Enter untuk tutup"
