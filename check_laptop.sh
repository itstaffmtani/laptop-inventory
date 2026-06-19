#!/bin/bash
# MTani — Inventarisasi Laptop Karyawan (Mac / Linux)

FORM_URL="https://itstaffmtani.github.io/laptop-inventory/"

encode() {
    python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1],safe=''))" -- "$1" 2>/dev/null \
    || python  -c "import sys,urllib; print(urllib.quote(sys.argv[1]))" -- "$1" 2>/dev/null \
    || printf '%s' "$1"
}

OS_TYPE=$(uname -s)

echo ""
echo "================================================"
echo "   MTani — Inventarisasi Laptop Karyawan"
echo "================================================"
echo ""
echo "Mendeteksi spesifikasi laptop..."
echo ""

HOSTNAME_VAL=$(hostname 2>/dev/null | sed 's/\.local$//')

# ──────────────────────────────────────────────────────────────
# macOS
# ──────────────────────────────────────────────────────────────
if [ "$OS_TYPE" = "Darwin" ]; then

    MERK="Apple"

    HW=$(system_profiler SPHardwareDataType 2>/dev/null)
    MODEL=$(echo "$HW" | grep -E "Model Name:|Model Identifier:" | head -1 \
            | sed 's/.*: *//')
    SERIAL=$(echo "$HW" | grep "Serial Number" | head -1 | awk '{print $NF}')

    # CPU — Intel vs Apple Silicon
    CPU_NAME=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    if [ -z "$CPU_NAME" ]; then
        CPU_NAME=$(echo "$HW" | grep "Chip:" | head -1 | sed 's/.*Chip: *//')
    fi
    CPU_CORES=$(sysctl -n hw.physicalcpu 2>/dev/null)
    CPU_THREADS=$(sysctl -n hw.logicalcpu 2>/dev/null)
    ARCH=$(uname -m)
    [ "$ARCH" = "arm64" ] && CPU_ARCH="ARM64" || CPU_ARCH="x64"

    # RAM
    RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    RAM_GB=$(( RAM_BYTES / 1073741824 ))
    if [ "$ARCH" = "arm64" ]; then
        RAM_TYPE="LPDDR5"
        RAM_SPEED=""
    else
        MEM_PROF=$(system_profiler SPMemoryDataType 2>/dev/null)
        RAM_TYPE=$(echo "$MEM_PROF" | grep "Type:" | grep -v "Unknown\|Empty" \
                   | head -1 | sed 's/.*Type: *//')
        RAM_SPEED=$(echo "$MEM_PROF" | grep "Speed:" | grep -v "Unknown\|Empty" \
                    | head -1 | sed 's/.*Speed: *//' | grep -o '[0-9]*' | head -1)
    fi

    # RAM usage via vm_stat
    PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
    VM=$(vm_stat 2>/dev/null)
    p_active=$(echo "$VM"  | grep "Pages active:"      | grep -o '[0-9]*\.' | tr -d '.')
    p_wired=$(echo "$VM"   | grep "Pages wired down:"  | grep -o '[0-9]*\.' | tr -d '.')
    p_compr=$(echo "$VM"   | grep "compressor:"        | grep -o '[0-9]*\.' | tr -d '.')
    p_active=${p_active:-0}; p_wired=${p_wired:-0}; p_compr=${p_compr:-0}
    PAGES_USED=$(( p_active + p_wired + p_compr ))
    PAGES_TOTAL=$(( RAM_BYTES / PAGE_SIZE ))
    if [ "$PAGES_TOTAL" -gt 0 ]; then
        RAM_USAGE_PCT=$(( PAGES_USED * 100 / PAGES_TOTAL ))
        RAM_USED_BYTES=$(( PAGES_USED * PAGE_SIZE ))
        RAM_USAGE_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_USED_BYTES / 1073741824}")
    else
        RAM_USAGE_PCT=""; RAM_USAGE_GB=""
    fi

    # GPU
    GPU=$(system_profiler SPDisplaysDataType 2>/dev/null \
          | grep "Chipset Model:" | head -1 | sed 's/.*Chipset Model: *//')

    # Storage — find the physical disk backing /
    ROOT_DISK=$(diskutil info / 2>/dev/null \
                | grep "Part of Whole:" | awk '{print $NF}')
    if [ -n "$ROOT_DISK" ]; then
        DISK_SIZE_RAW=$(diskutil info "/dev/$ROOT_DISK" 2>/dev/null \
                        | grep "Disk Size:" | grep -o '[0-9]*\.[0-9]* GB' | head -1)
        SSD_GB=$(echo "$DISK_SIZE_RAW" | grep -o '[0-9]*' | head -1)
    fi
    SSD_GB=${SSD_GB:-""}
    SSD_TYPES="NVMe"
    HDD_GB=""

    # OS partition
    OS_TOTAL=$(df -g / 2>/dev/null | tail -1 | awk '{print $2}')
    OS_FREE=$(df -g  / 2>/dev/null | tail -1 | awk '{print $4}')

    # Battery (ioreg AppleSmartBattery)
    BATTERY_PCT=""; BATTERY_WH=""; BATTERY_WH_DESIGN=""
    BATT=$(ioreg -r -n AppleSmartBattery 2>/dev/null)
    if [ -n "$BATT" ]; then
        DESIGN=$(echo "$BATT" | grep '"DesignCapacity"'       | grep -o '[0-9]*' | tail -1)
        MAXCAP=$(echo "$BATT" | grep '"MaxCapacity"'           | grep -o '[0-9]*' | tail -1)
        [ -z "$MAXCAP" ] && \
        MAXCAP=$(echo "$BATT" | grep '"AppleRawMaxCapacity"'   | grep -o '[0-9]*' | tail -1)
        VOLT=$(echo "$BATT"   | grep '"Voltage"'               | grep -o '[0-9]*' | tail -1)
        if [ -n "$DESIGN" ] && [ "$DESIGN" -gt 0 ] && [ -n "$MAXCAP" ]; then
            BATTERY_PCT=$(( MAXCAP * 100 / DESIGN ))
            if [ -n "$VOLT" ] && [ "$VOLT" -gt 0 ]; then
                BATTERY_WH=$(awk "BEGIN {printf \"%.1f\", $MAXCAP * $VOLT / 1000000}")
                BATTERY_WH_DESIGN=$(awk "BEGIN {printf \"%.1f\", $DESIGN * $VOLT / 1000000}")
            fi
        fi
    fi

    # OS string
    OS_STR="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null) $CPU_ARCH"

    # MAC address (en0 = Ethernet/Thunderbolt, en1 = Wi-Fi, or whichever has one)
    MAC_ADDR=$(ifconfig 2>/dev/null \
               | awk '/^en[0-9]+/{iface=$1} /ether /{if(iface)print $2}' \
               | grep -v "^00:00\|^ff:ff\|^ac:de:48\|^02:00" | head -1)

    open_browser() { open "$1"; }

# ──────────────────────────────────────────────────────────────
# Linux
# ──────────────────────────────────────────────────────────────
elif [ "$OS_TYPE" = "Linux" ]; then

    MERK=$(cat /sys/class/dmi/id/sys_vendor     2>/dev/null | tr -d '\n')
    MODEL=$(cat /sys/class/dmi/id/product_name  2>/dev/null | tr -d '\n')
    SERIAL=$(cat /sys/class/dmi/id/product_serial 2>/dev/null | tr -d '\n')

    # Fallback to dmidecode (may need sudo — silent if unavailable)
    [ -z "$MERK" ]   && MERK=$(dmidecode -s system-manufacturer   2>/dev/null | head -1)
    [ -z "$MODEL" ]  && MODEL=$(dmidecode -s system-product-name   2>/dev/null | head -1)
    [ -z "$SERIAL" ] && SERIAL=$(dmidecode -s system-serial-number 2>/dev/null | head -1)

    # Sanitize generic values
    echo "$MERK"   | grep -qiE "to be filled|default|o\.?e\.?m|system manufacturer" && MERK=""
    echo "$MODEL"  | grep -qiE "to be filled|default|o\.?e\.?m|system product"      && MODEL=""
    echo "$SERIAL" | grep -qiE "to be filled|default|n/a|none|^0$"                  && SERIAL=""

    # CPU
    CPU_NAME=$(grep "model name" /proc/cpuinfo 2>/dev/null \
               | head -1 | cut -d: -f2 | sed 's/^ *//;s/  */ /g')
    CPU_CORES=$(grep "cpu cores" /proc/cpuinfo 2>/dev/null \
                | head -1 | cut -d: -f2 | tr -d ' ')
    [ -z "$CPU_CORES" ] && CPU_CORES=$(nproc 2>/dev/null)
    CPU_THREADS=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)         CPU_ARCH="x64"   ;;
        i*86)           CPU_ARCH="x86"   ;;
        aarch64|arm64)  CPU_ARCH="ARM64" ;;
        armv*)          CPU_ARCH="ARM"   ;;
        *)              CPU_ARCH="$ARCH" ;;
    esac

    # GPU
    GPU=""
    if command -v lspci &>/dev/null; then
        GPU=$(lspci 2>/dev/null \
              | grep -iE "VGA|3D controller|Display controller" \
              | grep -iv "microsoft basic|vmware|virtual|hyper-v" \
              | head -1 | sed 's/.*: //')
    fi

    # RAM
    MEM_KB=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    MEM_FREE_KB=$(grep "^MemAvailable:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    RAM_GB=$(( ${MEM_KB:-0} / 1048576 ))
    RAM_TYPE=$(dmidecode -t memory 2>/dev/null \
               | grep "^\s*Type:" | grep -v "Unknown\|<OUT OF SPEC>" \
               | head -1 | awk '{print $2}')
    RAM_SPEED=$(dmidecode -t memory 2>/dev/null \
                | grep "Configured Memory Speed:" | grep -v "Unknown" \
                | head -1 | awk '{print $4}')
    if [ -n "$MEM_KB" ] && [ "$MEM_KB" -gt 0 ] && [ -n "$MEM_FREE_KB" ]; then
        MEM_USED_KB=$(( MEM_KB - MEM_FREE_KB ))
        RAM_USAGE_PCT=$(( MEM_USED_KB * 100 / MEM_KB ))
        RAM_USAGE_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED_KB / 1048576}")
    else
        RAM_USAGE_PCT=""; RAM_USAGE_GB=""
    fi

    # Storage via lsblk
    SSD_GB=0; HDD_GB=0; SSD_TYPES=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        NAME=$(echo "$line"  | awk '{print $1}')
        SIZE=$(echo "$line"  | awk '{print $2}')
        ROTA=$(echo "$line"  | awk '{print $3}')
        TYPE=$(echo "$line"  | awk '{print $4}')
        [ "$TYPE" != "disk" ] && continue
        # Parse size (e.g. "512G" or "1T")
        SIZE_G=$(echo "$SIZE" | awk '
            /T$/{gsub(/T/,""); printf "%d", $1*1024}
            /G$/{gsub(/G/,""); printf "%d", $1+0.5}
            /M$/{gsub(/M/,""); printf "%d", $1/1024}')
        [ -z "$SIZE_G" ] && SIZE_G=0
        if [ "$ROTA" = "0" ]; then
            SSD_GB=$(( SSD_GB + SIZE_G ))
            if echo "$NAME" | grep -q "nvme"; then
                SSD_TYPES="NVMe"
            else
                SSD_TYPES="SATA"
            fi
        else
            HDD_GB=$(( HDD_GB + SIZE_G ))
        fi
    done < <(lsblk -d -o NAME,SIZE,ROTA,TYPE --noheadings 2>/dev/null)
    [ "$SSD_GB" -gt 0 ] && SSD_GB="$SSD_GB" || SSD_GB=""
    [ "$HDD_GB" -gt 0 ] && HDD_GB="$HDD_GB" || HDD_GB=""

    # OS partition
    OS_TOTAL=$(df -BG / 2>/dev/null | tail -1 | awk '{print $2}' | tr -d 'G')
    OS_FREE=$(df  -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')

    # Battery
    BATTERY_PCT=""; BATTERY_WH=""; BATTERY_WH_DESIGN=""
    BAT_PATH=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
    if [ -n "$BAT_PATH" ] && [ -d "$BAT_PATH" ]; then
        E_NOW=$(cat "$BAT_PATH/energy_now"          2>/dev/null || echo "")
        E_FULL=$(cat "$BAT_PATH/energy_full"        2>/dev/null || echo "")
        E_DESIGN=$(cat "$BAT_PATH/energy_full_design" 2>/dev/null || echo "")
        if [ -n "$E_FULL" ] && [ -n "$E_DESIGN" ] && [ "$E_DESIGN" -gt 0 ]; then
            BATTERY_PCT=$(( E_FULL * 100 / E_DESIGN ))
            BATTERY_WH=$(awk "BEGIN {printf \"%.1f\", $E_FULL   / 1000000}")
            BATTERY_WH_DESIGN=$(awk "BEGIN {printf \"%.1f\", $E_DESIGN / 1000000}")
        fi
    fi

    # OS string
    OS_STR=$(lsb_release -d -s 2>/dev/null | tr -d '"')
    [ -z "$OS_STR" ] && \
        OS_STR=$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null \
                 | cut -d= -f2 | tr -d '"')
    [ -z "$OS_STR" ] && OS_STR=$(uname -sr)
    OS_STR="$OS_STR $CPU_ARCH"

    # MAC address
    MAC_ADDR=$(ip link show 2>/dev/null \
               | awk '/link\/ether/{print $2}' \
               | grep -v "^00:00:00\|^ff:ff:ff" | head -1)
    [ -z "$MAC_ADDR" ] && \
        MAC_ADDR=$(cat /sys/class/net/*/address 2>/dev/null \
                   | grep -v "^00:00:00\|^ff:ff:ff" | head -1)

    open_browser() {
        if   command -v xdg-open       &>/dev/null; then xdg-open "$1" 2>/dev/null &
        elif command -v sensible-browser &>/dev/null; then sensible-browser "$1" &
        elif command -v x-www-browser  &>/dev/null; then x-www-browser "$1" &
        else echo ""; echo ">>> Buka URL ini di browser kamu:"; echo "$1"; fi
    }

else
    echo "Sistem operasi tidak dikenal: $OS_TYPE"
    read -r
    exit 1
fi

# ──────────────────────────────────────────────────────────────
# Tampilkan hasil deteksi
# ──────────────────────────────────────────────────────────────
echo "Spesifikasi terdeteksi:"
echo "  Hostname : $HOSTNAME_VAL   MAC: $MAC_ADDR"
echo "  Merk     : $MERK   Model: $MODEL"
echo "  CPU      : $CPU_NAME"
echo "           : ${CPU_CORES} cores / ${CPU_THREADS} threads / $CPU_ARCH"
echo "  GPU      : $GPU"
echo "  RAM      : ${RAM_GB} GB  $RAM_TYPE  ${RAM_SPEED} MHz  [Usage: ${RAM_USAGE_PCT:-?}% / ${RAM_USAGE_GB:-?} GB]"
echo "  SSD      : ${SSD_GB} GB ($SSD_TYPES)"
echo "  HDD      : ${HDD_GB} GB"
echo "  Partisi  : OS Free ${OS_FREE} GB / ${OS_TOTAL} GB"
echo "  Battery  : ${BATTERY_PCT}% (${BATTERY_WH} Wh / ${BATTERY_WH_DESIGN} Wh)"
echo "  OS       : $OS_STR"
echo ""

# ──────────────────────────────────────────────────────────────
# Build URL & buka browser
# ──────────────────────────────────────────────────────────────
PARAMS="hostname=$(encode "$HOSTNAME_VAL")"
PARAMS="${PARAMS}&merk=$(encode "$MERK")"
PARAMS="${PARAMS}&model=$(encode "$MODEL")"
PARAMS="${PARAMS}&cpu=$(encode "$CPU_NAME")"
PARAMS="${PARAMS}&cpu_cores=$(encode "$CPU_CORES")"
PARAMS="${PARAMS}&cpu_threads=$(encode "$CPU_THREADS")"
PARAMS="${PARAMS}&cpu_arch=$(encode "$CPU_ARCH")"
PARAMS="${PARAMS}&gpu=$(encode "$GPU")"
PARAMS="${PARAMS}&ram_gb=$(encode "$RAM_GB")"
PARAMS="${PARAMS}&ram_type=$(encode "$RAM_TYPE")"
PARAMS="${PARAMS}&ram_speed=$(encode "$RAM_SPEED")"
PARAMS="${PARAMS}&ram_usage_pct=$(encode "$RAM_USAGE_PCT")"
PARAMS="${PARAMS}&ram_usage_gb=$(encode "$RAM_USAGE_GB")"
PARAMS="${PARAMS}&ssd_gb=$(encode "$SSD_GB")"
PARAMS="${PARAMS}&ssd_tipe=$(encode "$SSD_TYPES")"
PARAMS="${PARAMS}&hdd_gb=$(encode "$HDD_GB")"
PARAMS="${PARAMS}&battery_pct=$(encode "$BATTERY_PCT")"
PARAMS="${PARAMS}&battery_wh=$(encode "$BATTERY_WH")"
PARAMS="${PARAMS}&battery_wh_design=$(encode "$BATTERY_WH_DESIGN")"
PARAMS="${PARAMS}&os=$(encode "$OS_STR")"
PARAMS="${PARAMS}&os_free_gb=$(encode "$OS_FREE")"
PARAMS="${PARAMS}&os_total_gb=$(encode "$OS_TOTAL")"
PARAMS="${PARAMS}&serial=$(encode "$SERIAL")"
PARAMS="${PARAMS}&mac=$(encode "$MAC_ADDR")"

FULL_URL="${FORM_URL}?${PARAMS}"

echo "Membuka form di browser..."
echo "(Isi data diri & kondisi laptop, lalu klik Kirim)"
echo ""

open_browser "$FULL_URL"

echo "Form sudah terbuka di browser kamu."
echo "Setelah submit, jendela ini bisa ditutup."
echo ""
echo "================================================"
printf "Tekan Enter untuk tutup..."
read -r
