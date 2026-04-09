#!/usr/bin/env bash
# ============================================================================
# God in Hand — Device & Environment Detection Module
# ============================================================================

# shellcheck disable=SC2034  # Variables are used by scripts that source this module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Color & formatting helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
print_fail() { echo -e "  ${RED}✗${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "  ${CYAN}ℹ${NC} $1"; }
print_step() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }

# ---------------------------------------------------------------------------
# detect_termux — Check if running inside Termux and validate version
# Returns: 0 = OK, 1 = not Termux, 2 = Play Store version
# Sets: TERMUX_VERSION, TERMUX_VERSION_CODE
# ---------------------------------------------------------------------------
detect_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        return 1
    fi

    TERMUX_VERSION=""
    TERMUX_VERSION_CODE=0

    # Try to get version from dpkg
    if command -v dpkg &>/dev/null; then
        local ver_info
        ver_info=$(dpkg -s termux-tools 2>/dev/null | grep -i "version:" | head -1)
        if [[ -n "$ver_info" ]]; then
            TERMUX_VERSION=$(echo "$ver_info" | sed 's/Version: //')
        fi
    fi

    # Check the APK path for F-Droid signature
    # F-Droid builds have versionCode >= 119
    if [[ -f "/data/data/com.termux/files/usr/bin/termux-info" ]]; then
        local info_output
        info_output=$(termux-info 2>/dev/null || echo "")
        if echo "$info_output" | grep -qi "play.store\|playstore"; then
            return 2
        fi
        local vc
        vc=$(echo "$info_output" | grep -i "TERMUX_APP_VERSION_CODE" | grep -oE '[0-9]+' | head -1)
        if [[ -n "$vc" ]]; then
            TERMUX_VERSION_CODE=$vc
        fi
    fi

    # Heuristic: If version code is known and < 119, likely Play Store
    if [[ $TERMUX_VERSION_CODE -gt 0 && $TERMUX_VERSION_CODE -lt 119 ]]; then
        return 2
    fi

    return 0
}

# ---------------------------------------------------------------------------
# detect_android_version — Get Android API level and version
# Sets: ANDROID_API, ANDROID_VERSION
# ---------------------------------------------------------------------------
detect_android_version() {
    ANDROID_API=0
    ANDROID_VERSION="unknown"

    if command -v getprop &>/dev/null; then
        ANDROID_API=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
        ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "unknown")
    fi
}

# ---------------------------------------------------------------------------
# detect_cpu_arch — Check CPU architecture
# Sets: CPU_ARCH
# Returns: 0 = aarch64, 1 = unsupported
# ---------------------------------------------------------------------------
detect_cpu_arch() {
    CPU_ARCH=$(uname -m 2>/dev/null || echo "unknown")
    if [[ "$CPU_ARCH" == "aarch64" || "$CPU_ARCH" == "arm64" ]]; then
        CPU_ARCH="aarch64"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# detect_ram — Get total and available RAM in MB
# Sets: TOTAL_RAM_MB, AVAIL_RAM_MB, TOTAL_RAM_GB
# ---------------------------------------------------------------------------
detect_ram() {
    TOTAL_RAM_MB=0
    AVAIL_RAM_MB=0
    TOTAL_RAM_GB=0

    if [[ -f /proc/meminfo ]]; then
        TOTAL_RAM_MB=$(awk '/^MemTotal:/ {printf "%.0f", $2/1024}' /proc/meminfo)
        AVAIL_RAM_MB=$(awk '/^MemAvailable:/ {printf "%.0f", $2/1024}' /proc/meminfo)
    elif command -v free &>/dev/null; then
        TOTAL_RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
        AVAIL_RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}')
    fi

    if [[ $TOTAL_RAM_MB -gt 0 ]]; then
        TOTAL_RAM_GB=$(( (TOTAL_RAM_MB + 512) / 1024 ))
    fi
}

# ---------------------------------------------------------------------------
# detect_storage — Get available storage in GB
# Sets: AVAIL_STORAGE_GB
# ---------------------------------------------------------------------------
detect_storage() {
    AVAIL_STORAGE_GB=0

    local avail_kb
    if command -v df &>/dev/null; then
        # Termux home directory
        avail_kb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
        if [[ -n "$avail_kb" && "$avail_kb" =~ ^[0-9]+$ ]]; then
            AVAIL_STORAGE_GB=$(( avail_kb / 1048576 ))
        fi
    fi
}

# ---------------------------------------------------------------------------
# detect_network — Check network connectivity
# Returns: 0 = connected, 1 = no connection
# ---------------------------------------------------------------------------
detect_network() {
    # Try multiple endpoints
    if curl -sf --connect-timeout 5 --max-time 10 "https://huggingface.co" >/dev/null 2>&1; then
        return 0
    fi
    if curl -sf --connect-timeout 5 --max-time 10 "https://ollama.com" >/dev/null 2>&1; then
        return 0
    fi
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# detect_battery — Get battery level and charging status
# Sets: BATTERY_LEVEL, BATTERY_CHARGING
# ---------------------------------------------------------------------------
detect_battery() {
    BATTERY_LEVEL=-1
    BATTERY_CHARGING="unknown"

    # Method 1: Termux API (most reliable on Android)
    if command -v termux-battery-status &>/dev/null; then
        local batt_json
        batt_json=$(termux-battery-status 2>/dev/null)
        if [[ -n "$batt_json" ]]; then
            BATTERY_LEVEL=$(echo "$batt_json" | grep -oE '"percentage"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+' || echo "-1")
            local status
            status=$(echo "$batt_json" | grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
            if [[ "$status" == "CHARGING" || "$status" == "FULL" ]]; then
                BATTERY_CHARGING="yes"
            else
                BATTERY_CHARGING="no"
            fi
        fi
    fi

    # Method 2: sysfs — try multiple power_supply paths
    # Samsung Exynos, Qualcomm, MediaTek devices use different paths
    if [[ $BATTERY_LEVEL -lt 0 ]]; then
        local batt_paths=(
            "/sys/class/power_supply/battery/capacity"
            "/sys/class/power_supply/BAT0/capacity"
            "/sys/class/power_supply/BAT1/capacity"
            "/sys/class/power_supply/bms/capacity"
            "/sys/class/power_supply/max170xx_battery/capacity"
        )
        local batt_path
        for batt_path in "${batt_paths[@]}"; do
            if [[ -f "$batt_path" ]]; then
                BATTERY_LEVEL=$(cat "$batt_path" 2>/dev/null || echo "-1")
                local status_path="${batt_path%/capacity}/status"
                local status
                status=$(cat "$status_path" 2>/dev/null || echo "")
                if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
                    BATTERY_CHARGING="yes"
                else
                    BATTERY_CHARGING="no"
                fi
                break
            fi
        done
    fi

    # Method 3: dumpsys battery (Android fallback, works on most devices)
    if [[ $BATTERY_LEVEL -lt 0 ]] && command -v dumpsys &>/dev/null; then
        local dumpsys_out
        dumpsys_out=$(dumpsys battery 2>/dev/null || echo "")
        if [[ -n "$dumpsys_out" ]]; then
            local level
            level=$(echo "$dumpsys_out" | grep -i "level:" | grep -oE '[0-9]+' | head -1)
            if [[ -n "$level" ]]; then
                BATTERY_LEVEL="$level"
                local ds_status
                ds_status=$(echo "$dumpsys_out" | grep -i "status:" | grep -oE '[0-9]+' | head -1)
                # Android BatteryManager: 2=CHARGING, 5=FULL
                if [[ "$ds_status" == "2" || "$ds_status" == "5" ]]; then
                    BATTERY_CHARGING="yes"
                else
                    BATTERY_CHARGING="no"
                fi
            fi
        fi
    fi
}

# ---------------------------------------------------------------------------
# detect_device_model — Attempt to identify the specific device
# Sets: DEVICE_MODEL, DEVICE_MANUFACTURER, DEVICE_CODENAME
# ---------------------------------------------------------------------------
detect_device_model() {
    DEVICE_MODEL="unknown"
    DEVICE_MANUFACTURER="unknown"
    DEVICE_CODENAME="unknown"

    if command -v getprop &>/dev/null; then
        DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "unknown")
        DEVICE_MANUFACTURER=$(getprop ro.product.manufacturer 2>/dev/null || echo "unknown")
        DEVICE_CODENAME=$(getprop ro.product.device 2>/dev/null || echo "unknown")
    fi
}

# ---------------------------------------------------------------------------
# detect_soc — Identify the SoC (System on Chip)
# Sets: SOC_NAME
# ---------------------------------------------------------------------------
detect_soc() {
    SOC_NAME="unknown"

    if [[ -f /proc/cpuinfo ]]; then
        # Try Qualcomm
        local hw
        hw=$(grep -i "Hardware" /proc/cpuinfo | head -1 | sed 's/.*: //')
        if [[ -n "$hw" ]]; then
            SOC_NAME="$hw"
            return
        fi
    fi

    if command -v getprop &>/dev/null; then
        local soc
        soc=$(getprop ro.hardware.chipname 2>/dev/null || getprop ro.board.platform 2>/dev/null || echo "")
        if [[ -n "$soc" ]]; then
            SOC_NAME="$soc"
        fi
    fi
}

# ---------------------------------------------------------------------------
# detect_thermal — Get thermal zone temperature (Celsius)
# Sets: THERMAL_TEMP_C
# ---------------------------------------------------------------------------
detect_thermal() {
    THERMAL_TEMP_C=-1

    # Try multiple thermal zones — different SoCs (Exynos, Snapdragon, MediaTek)
    # use different zone numbering for CPU temperature
    local zone
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [[ -f "$zone" ]]; then
            local raw
            raw=$(cat "$zone" 2>/dev/null || echo "0")
            if [[ "$raw" -gt 0 ]]; then
                if [[ $raw -gt 1000 ]]; then
                    THERMAL_TEMP_C=$(( raw / 1000 ))
                else
                    THERMAL_TEMP_C=$raw
                fi
                break
            fi
        fi
    done

    # Fallback: hwmon interface (some devices expose temp here)
    if [[ $THERMAL_TEMP_C -lt 0 ]]; then
        local hwmon_path
        for hwmon_path in /sys/class/hwmon/hwmon*/temp1_input; do
            if [[ -f "$hwmon_path" ]]; then
                local raw
                raw=$(cat "$hwmon_path" 2>/dev/null || echo "0")
                if [[ "$raw" -gt 0 ]]; then
                    if [[ $raw -gt 1000 ]]; then
                        THERMAL_TEMP_C=$(( raw / 1000 ))
                    else
                        THERMAL_TEMP_C=$raw
                    fi
                    break
                fi
            fi
        done
    fi

    # Fallback: dumpsys battery temperature (in tenths of degree C)
    if [[ $THERMAL_TEMP_C -lt 0 ]] && command -v dumpsys &>/dev/null; then
        local temp_raw
        temp_raw=$(dumpsys battery 2>/dev/null | grep -i "temperature:" | grep -oE '[0-9]+' | head -1)
        if [[ -n "$temp_raw" && "$temp_raw" -gt 0 ]]; then
            THERMAL_TEMP_C=$(( temp_raw / 10 ))
        fi
    fi
}

# ---------------------------------------------------------------------------
# detect_existing_node — Check for existing Node.js
# Sets: NODE_VERSION, NODE_MAJOR
# Returns: 0 = found, 1 = not found
# ---------------------------------------------------------------------------
detect_existing_node() {
    NODE_VERSION=""
    NODE_MAJOR=0

    if command -v node &>/dev/null; then
        NODE_VERSION=$(node --version 2>/dev/null || echo "")
        if [[ -n "$NODE_VERSION" ]]; then
            NODE_MAJOR=$(echo "$NODE_VERSION" | grep -oE '^v([0-9]+)' | tr -d 'v')
            return 0
        fi
    fi
    return 1
}

# ---------------------------------------------------------------------------
# detect_existing_openclaw — Check for existing OpenClaw installation
# Sets: OPENCLAW_VERSION, OPENCLAW_PATH
# Returns: 0 = found, 1 = not found
# ---------------------------------------------------------------------------
detect_existing_openclaw() {
    OPENCLAW_VERSION=""
    OPENCLAW_PATH=""

    if command -v openclaw &>/dev/null; then
        OPENCLAW_PATH=$(which openclaw)
        OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# detect_existing_ollama — Check for existing Ollama installation
# Sets: OLLAMA_VERSION
# Returns: 0 = found, 1 = not found
# ---------------------------------------------------------------------------
detect_existing_ollama() {
    OLLAMA_VERSION=""

    if command -v ollama &>/dev/null; then
        OLLAMA_VERSION=$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# detect_existing_models — Find cached model files
# Sets: EXISTING_MODELS (array of paths)
# ---------------------------------------------------------------------------
detect_existing_models() {
    EXISTING_MODELS=()

    # Ollama models
    if [[ -d "$HOME/.ollama/models" ]]; then
        while IFS= read -r -d '' f; do
            EXISTING_MODELS+=("$f")
        done < <(find "$HOME/.ollama/models" -name "*.gguf" -print0 2>/dev/null)
    fi

    # HuggingFace cache
    if [[ -d "$HOME/.cache/huggingface" ]]; then
        while IFS= read -r -d '' f; do
            EXISTING_MODELS+=("$f")
        done < <(find "$HOME/.cache/huggingface" -name "*.gguf" -print0 2>/dev/null)
    fi

    # Direct downloads
    local model_dir="${GIH_HOME:-${HOME}/.god-in-hand}/models"
    if [[ -d "$model_dir" ]]; then
        while IFS= read -r -d '' f; do
            EXISTING_MODELS+=("$f")
        done < <(find "$model_dir" -name "*.gguf" -print0 2>/dev/null)
    fi
}

# ---------------------------------------------------------------------------
# detect_stale_locks — Find and list stale OpenClaw session locks
# Sets: STALE_LOCKS (array)
# ---------------------------------------------------------------------------
detect_stale_locks() {
    STALE_LOCKS=()

    local lock_dir="$HOME/.openclaw/sessions"
    if [[ -d "$lock_dir" ]]; then
        while IFS= read -r -d '' f; do
            STALE_LOCKS+=("$f")
        done < <(find "$lock_dir" -name "*.lock" -mmin +60 -print0 2>/dev/null)
    fi
}

# ---------------------------------------------------------------------------
# detect_proot — Check for proot-distro and installed distros
# Sets: PROOT_INSTALLED, PROOT_UBUNTU
# ---------------------------------------------------------------------------
detect_proot() {
    PROOT_INSTALLED=false
    PROOT_UBUNTU=false

    if command -v proot-distro &>/dev/null; then
        PROOT_INSTALLED=true
        if proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
            PROOT_UBUNTU=true
        fi
    fi
}

# ---------------------------------------------------------------------------
# recommend_role — Auto-recommend device role based on RAM
# Returns: "hub", "worker", or "power"
# ---------------------------------------------------------------------------
recommend_role() {
    if [[ $TOTAL_RAM_GB -ge 14 ]]; then
        echo "power"
    elif [[ $TOTAL_RAM_GB -ge 10 ]]; then
        echo "hub"
    else
        echo "worker"
    fi
}

# ---------------------------------------------------------------------------
# print_device_summary — Display detected device info
# ---------------------------------------------------------------------------
print_device_summary() {
    echo ""
    echo -e "${BOLD}📱 Device Summary${NC}"
    echo "────────────────────────────────────"
    echo -e "  Model:         ${CYAN}${DEVICE_MANUFACTURER} ${DEVICE_MODEL}${NC}"
    echo -e "  SoC:           ${CYAN}${SOC_NAME}${NC}"
    echo -e "  Android:       ${CYAN}${ANDROID_VERSION} (API ${ANDROID_API})${NC}"
    echo -e "  CPU:           ${CYAN}${CPU_ARCH}${NC}"
    echo -e "  RAM:           ${CYAN}${TOTAL_RAM_MB}MB total (${AVAIL_RAM_MB}MB available)${NC}"
    echo -e "  Storage:       ${CYAN}${AVAIL_STORAGE_GB}GB available${NC}"
    echo -e "  Battery:       ${CYAN}${BATTERY_LEVEL}%${NC} (Charging: ${BATTERY_CHARGING})"
    echo -e "  Temperature:   ${CYAN}${THERMAL_TEMP_C}°C${NC}"
    echo -e "  Recommended:   ${BOLD}$(recommend_role) node${NC}"
    echo "────────────────────────────────────"
}

# ---------------------------------------------------------------------------
# run_all_detections — Run all detection functions
# ---------------------------------------------------------------------------
run_all_detections() {
    detect_android_version
    detect_cpu_arch
    detect_ram
    detect_storage
    detect_battery
    detect_device_model
    detect_soc
    detect_thermal
    detect_existing_node
    detect_existing_openclaw
    detect_existing_ollama
    detect_existing_models
    detect_stale_locks
    detect_proot
}
