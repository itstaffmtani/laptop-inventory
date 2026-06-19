# =============================================================
# MTani — Inventarisasi Laptop Karyawan
# Jalankan via check_laptop.bat (double-click)
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

$cs      = Get-WmiObject Win32_ComputerSystem
$cpu_obj = Get-WmiObject Win32_Processor | Select-Object -First 1
$os_obj  = Get-WmiObject Win32_OperatingSystem
$bios    = Get-WmiObject Win32_BIOS

# Hostname
$hostname = $env:COMPUTERNAME

# Merk & Model
$merk  = $cs.Manufacturer.Trim()
$model = $cs.Model.Trim()
$merk  = $merk  -replace "(?i)^(to be filled|default string|system manufacturer|o\.e\.m\.).*", "Tidak diketahui"
$model = $model -replace "(?i)^(to be filled|default string|system product name|o\.e\.m\.).*", "Tidak diketahui"

# CPU — nama, core fisik, thread, arsitektur
$cpu_name    = $cpu_obj.Name.Trim() -replace "\s+", " "
$cpu_cores   = [string]$cpu_obj.NumberOfCores
$cpu_threads = [string]$cpu_obj.NumberOfLogicalProcessors
$arch_map    = @{ 0="x86"; 5="ARM"; 9="x64"; 12="ARM64" }
$cpu_arch    = $arch_map[[int]$cpu_obj.Architecture]
if (-not $cpu_arch) { $cpu_arch = "x64" }

# GPU
$gpu_obj = Get-WmiObject Win32_VideoController |
           Where-Object { $_.Name -notmatch "Microsoft Basic|Remote Desktop|Virtual|VMware|Hyper-V" } |
           Select-Object -First 1
$gpu_str = if ($gpu_obj) { $gpu_obj.Name.Trim() } else { "" }

# RAM — kapasitas, tipe DDR, speed, dan usage saat ini
$ram_modules  = Get-WmiObject Win32_PhysicalMemory
$ram_total_gb = [math]::Round(($ram_modules | Measure-Object -Property Capacity -Sum).Sum / 1GB)
$first_mod    = $ram_modules | Select-Object -First 1
$ddr_map      = @{ 20="DDR"; 21="DDR2"; 22="DDR2"; 24="DDR3"; 26="DDR4"; 34="DDR5" }
$ddr_type     = $ddr_map[[int]$first_mod.SMBIOSMemoryType]
if (-not $ddr_type) { $ddr_type = "" }
$spd          = if ($first_mod.ConfiguredClockSpeed -gt 0) { $first_mod.ConfiguredClockSpeed } else { $first_mod.Speed }
$ram_size_str  = "${ram_total_gb} GB"
$ram_type_str  = $ddr_type
$ram_speed_str = if ($spd -gt 0) { "${spd} MHz" } else { "" }

$ram_free_bytes = $os_obj.FreePhysicalMemory * 1KB
$ram_used_pct   = [math]::Round(($cs.TotalPhysicalMemory - $ram_free_bytes) / $cs.TotalPhysicalMemory * 100)
$ram_used_gb    = [math]::Round(($cs.TotalPhysicalMemory - $ram_free_bytes) / 1GB, 1)
$ram_usage_str  = "${ram_used_pct}% (${ram_used_gb} GB digunakan)"

# Storage — SSD dan HDD dipisah, deteksi NVMe/SATA
$ssd_parts = @()
$hdd_parts = @()
try {
    foreach ($pd in (Get-PhysicalDisk -ErrorAction Stop)) {
        $size_gb = [math]::Round($pd.Size / 1GB)
        $bus     = $pd.BusType
        $media   = $pd.MediaType
        $name_lc = $pd.FriendlyName.ToLower()
        if     ($media -eq "SSD" -and $bus -eq "NVMe") { $ssd_parts += "${size_gb} GB NVMe" }
        elseif ($media -eq "SSD")                       { $ssd_parts += "${size_gb} GB SATA" }
        elseif ($media -eq "HDD")                       { $hdd_parts += "${size_gb} GB" }
        elseif ($name_lc -match "nvme")                 { $ssd_parts += "${size_gb} GB NVMe" }
        elseif ($name_lc -match "ssd")                  { $ssd_parts += "${size_gb} GB" }
        else                                            { $hdd_parts += "${size_gb} GB" }
    }
} catch {
    foreach ($disk in (Get-WmiObject Win32_DiskDrive)) {
        $size_gb = [math]::Round($disk.Size / 1GB)
        $m       = $disk.Model.ToLower()
        if     ($m -match "nvme")    { $ssd_parts += "${size_gb} GB NVMe" }
        elseif ($m -match "ssd")     { $ssd_parts += "${size_gb} GB" }
        else                         { $hdd_parts += "${size_gb} GB" }
    }
}
$ssd_str = if ($ssd_parts.Count -gt 0) { $ssd_parts -join " + " } else { "" }
$hdd_str = if ($hdd_parts.Count -gt 0) { $hdd_parts -join " + " } else { "" }

# OS partition — ruang bebas partisi OS
$os_free_str = ""
try {
    $os_drive = $os_obj.SystemDrive
    $ldd      = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$os_drive'" -ErrorAction Stop
    if ($ldd) {
        $total_gb    = [math]::Round($ldd.Size / 1GB)
        $free_gb     = [math]::Round($ldd.FreeSpace / 1GB)
        $os_free_str = "${os_drive} ${free_gb} GB free / ${total_gb} GB"
    }
} catch {}

# Battery health
$battery_str = ""
try {
    $static = Get-WmiObject -Namespace root/WMI -Class BatteryStaticData -ErrorAction Stop | Select-Object -First 1
    $full   = Get-WmiObject -Namespace root/WMI -Class BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1
    if ($static -and $full -and $static.DesignedCapacity -gt 0) {
        $pct        = [math]::Round($full.FullChargedCapacity / $static.DesignedCapacity * 100)
        $design_wh  = [math]::Round($static.DesignedCapacity / 1000, 1)
        $current_wh = [math]::Round($full.FullChargedCapacity / 1000, 1)
        $battery_str = "${pct}% (${current_wh} Wh / ${design_wh} Wh)"
    }
} catch {}

# MAC Address (adapter fisik aktif)
$mac_str = ""
try {
    $nic = Get-WmiObject Win32_NetworkAdapterConfiguration |
           Where-Object { $_.IPEnabled -and $_.MACAddress -and
                          $_.Description -notmatch "Virtual|VMware|Hyper-V|Bluetooth|Miniport|Loopback" } |
           Select-Object -First 1
    if ($nic) { $mac_str = $nic.MACAddress }
} catch {}

# OS
$os_name     = $os_obj.Caption.Trim()
$os_arch_str = if ($os_obj.OSArchitecture) { $os_obj.OSArchitecture } else { "" }
$os_str      = "$os_name $os_arch_str".Trim()

# Serial Number
$serial = $bios.SerialNumber.Trim()
$serial = if ($serial -match "(?i)^(to be filled|default|n/a|0|none)") { "" } else { $serial }

Write-Host ""
Write-Host "Spesifikasi terdeteksi:" -ForegroundColor Green
Write-Host "  Hostname : $hostname    MAC: $mac_str"
Write-Host "  Merk     : $merk    Model: $model"
Write-Host "  CPU      : $cpu_name"
Write-Host "           : $cpu_cores cores / $cpu_threads threads / $cpu_arch"
Write-Host "  GPU      : $gpu_str"
Write-Host "  RAM      : $ram_size_str  $ram_type_str  $ram_speed_str  [Usage: $ram_usage_str]"
Write-Host "  SSD      : $ssd_str"
Write-Host "  HDD      : $hdd_str"
Write-Host "  Partisi  : $os_free_str"
Write-Host "  Battery  : $battery_str"
Write-Host "  OS       : $os_str"
Write-Host ""

# ── Buka form di browser ─────────────────────────────────────

$FORM_URL = "https://itstaffmtani.github.io/laptop-inventory/"

$params = "hostname=$(Encode $hostname)" +
          "&merk=$(Encode $merk)" +
          "&model=$(Encode $model)" +
          "&cpu=$(Encode $cpu_name)" +
          "&cpu_cores=$(Encode $cpu_cores)" +
          "&cpu_threads=$(Encode $cpu_threads)" +
          "&cpu_arch=$(Encode $cpu_arch)" +
          "&gpu=$(Encode $gpu_str)" +
          "&ram_size=$(Encode $ram_size_str)" +
          "&ram_type=$(Encode $ram_type_str)" +
          "&ram_speed=$(Encode $ram_speed_str)" +
          "&ram_usage=$(Encode $ram_usage_str)" +
          "&ssd=$(Encode $ssd_str)" +
          "&hdd=$(Encode $hdd_str)" +
          "&os_free=$(Encode $os_free_str)" +
          "&battery=$(Encode $battery_str)" +
          "&os=$(Encode $os_str)" +
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
