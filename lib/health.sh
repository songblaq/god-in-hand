#!/usr/bin/env bash
# ============================================================================
# God in Hand — Health Check & Diagnostics Module
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/detect.sh" 2>/dev/null

GIH_LOG_DIR="${HOME}/.god-in-hand/logs"
GIH_LOG="${GIH_LOG_DIR}/health-$(date +%Y%m%d-%H%M%S).log"

# ---------------------------------------------------------------------------
# init_health_log — Create log directory and file
# ---------------------------------------------------------------------------
init_health_log() {
    mkdir -p "$GIH_LOG_DIR"
    echo "=== God in Hand Health Check — $(date) ===" > "$GIH_LOG"
}

# ---------------------------------------------------------------------------
# log — Write to log file and optionally to stdout
# ---------------------------------------------------------------------------
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date "+%H:%M:%S")
    echo "[${timestamp}] [${level}] ${message}" >> "$GIH_LOG"
}

# ---------------------------------------------------------------------------
# check_ollama_status — Verify Ollama is running and responsive
# Returns: 0 = OK, 1 = not running, 2 = running but unhealthy
# ---------------------------------------------------------------------------
check_ollama_status() {
    local api_base="${1:-http://localhost:11434}"

    # Check if process is running
    if ! pgrep -x "ollama" >/dev/null 2>&1; then
        log "WARN" "Ollama process not found"
        return 1
    fi

    # Check API endpoint
    local version
    version=$(curl -sf --max-time 5 "${api_base}/api/version" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log "WARN" "Ollama API not responding at ${api_base}"
        return 2
    fi

    log "OK" "Ollama running: ${version}"
    return 0
}

# ---------------------------------------------------------------------------
# check_openclaw_status — Verify OpenClaw gateway is running
# Returns: 0 = OK, 1 = not running, 2 = running but unhealthy
# ---------------------------------------------------------------------------
check_openclaw_status() {
    local port="${1:-3000}"

    # Check if openclaw process exists
    if ! pgrep -f "openclaw" >/dev/null 2>&1; then
        log "WARN" "OpenClaw process not found"
        return 1
    fi

    # Check gateway port
    if curl -sf --max-time 5 "http://localhost:${port}/health" >/dev/null 2>&1; then
        log "OK" "OpenClaw gateway running on port ${port}"
        return 0
    fi

    # Try alternative health endpoints
    if curl -sf --max-time 5 "http://localhost:${port}/" >/dev/null 2>&1; then
        log "OK" "OpenClaw gateway running on port ${port} (no /health endpoint)"
        return 0
    fi

    log "WARN" "OpenClaw port ${port} not responding"
    return 2
}

# ---------------------------------------------------------------------------
# check_model_loaded — Verify a model is loaded and serving
# Args: $1 = api_base
# Returns: 0 = model loaded, 1 = no model
# ---------------------------------------------------------------------------
check_model_loaded() {
    local api_base="${1:-http://localhost:11434}"

    local models
    models=$(curl -sf --max-time 5 "${api_base}/api/tags" 2>/dev/null)
    if [[ $? -eq 0 && -n "$models" ]]; then
        local count
        count=$(echo "$models" | grep -c '"name"' || echo "0")
        if [[ $count -gt 0 ]]; then
            log "OK" "${count} model(s) available"
            return 0
        fi
    fi

    log "WARN" "No models loaded"
    return 1
}

# ---------------------------------------------------------------------------
# check_ram_pressure — Check if system is under memory pressure
# Returns: 0 = OK, 1 = warning, 2 = critical
# ---------------------------------------------------------------------------
check_ram_pressure() {
    detect_ram

    local used_pct=0
    if [[ $TOTAL_RAM_MB -gt 0 ]]; then
        used_pct=$(( (TOTAL_RAM_MB - AVAIL_RAM_MB) * 100 / TOTAL_RAM_MB ))
    fi

    if [[ $used_pct -gt 90 ]]; then
        log "CRIT" "RAM usage critical: ${used_pct}% (${AVAIL_RAM_MB}MB free)"
        return 2
    elif [[ $used_pct -gt 75 ]]; then
        log "WARN" "RAM usage high: ${used_pct}% (${AVAIL_RAM_MB}MB free)"
        return 1
    fi

    log "OK" "RAM usage: ${used_pct}% (${AVAIL_RAM_MB}MB free)"
    return 0
}

# ---------------------------------------------------------------------------
# check_thermal — Check device temperature
# Returns: 0 = OK, 1 = warm (throttling likely), 2 = hot (action needed)
# ---------------------------------------------------------------------------
check_thermal() {
    detect_thermal

    if [[ $THERMAL_TEMP_C -lt 0 ]]; then
        log "INFO" "Cannot read thermal sensor"
        return 0
    fi

    if [[ $THERMAL_TEMP_C -gt 50 ]]; then
        log "CRIT" "Device temperature critical: ${THERMAL_TEMP_C}°C — thermal throttling active"
        return 2
    elif [[ $THERMAL_TEMP_C -gt 40 ]]; then
        log "WARN" "Device warm: ${THERMAL_TEMP_C}°C — may throttle under load"
        return 1
    fi

    log "OK" "Temperature: ${THERMAL_TEMP_C}°C"
    return 0
}

# ---------------------------------------------------------------------------
# check_storage_space — Verify sufficient disk space
# Returns: 0 = OK, 1 = low, 2 = critical
# ---------------------------------------------------------------------------
check_storage_space() {
    detect_storage

    if [[ $AVAIL_STORAGE_GB -lt 2 ]]; then
        log "CRIT" "Storage critical: ${AVAIL_STORAGE_GB}GB free"
        return 2
    elif [[ $AVAIL_STORAGE_GB -lt 5 ]]; then
        log "WARN" "Storage low: ${AVAIL_STORAGE_GB}GB free"
        return 1
    fi

    log "OK" "Storage: ${AVAIL_STORAGE_GB}GB free"
    return 0
}

# ---------------------------------------------------------------------------
# check_battery_health — Verify battery level for heavy operations
# Returns: 0 = OK, 1 = low, 2 = critical
# ---------------------------------------------------------------------------
check_battery_health() {
    detect_battery

    if [[ "$BATTERY_CHARGING" == "yes" ]]; then
        log "OK" "Battery ${BATTERY_LEVEL}% (charging)"
        return 0
    fi

    if [[ $BATTERY_LEVEL -gt 0 && $BATTERY_LEVEL -lt 15 ]]; then
        log "CRIT" "Battery critical: ${BATTERY_LEVEL}%"
        return 2
    elif [[ $BATTERY_LEVEL -gt 0 && $BATTERY_LEVEL -lt 30 ]]; then
        log "WARN" "Battery low: ${BATTERY_LEVEL}%"
        return 1
    fi

    log "OK" "Battery: ${BATTERY_LEVEL}%"
    return 0
}

# ---------------------------------------------------------------------------
# check_network_connectivity — Verify network for API calls
# Returns: 0 = OK, 1 = no connectivity
# ---------------------------------------------------------------------------
check_network_connectivity() {
    if detect_network; then
        log "OK" "Network connected"
        return 0
    fi
    log "WARN" "No network connectivity"
    return 1
}

# ---------------------------------------------------------------------------
# run_openclaw_doctor — Wrapper around `openclaw doctor`
# Returns: 0 = all pass, 1 = some failures
# ---------------------------------------------------------------------------
run_openclaw_doctor() {
    if ! command -v openclaw &>/dev/null; then
        echo "OpenClaw not installed. Skipping doctor."
        log "SKIP" "openclaw doctor — not installed"
        return 1
    fi

    echo "Running openclaw doctor..."
    local output
    output=$(openclaw doctor 2>&1)
    local exit_code=$?

    echo "$output"
    echo "$output" >> "$GIH_LOG"

    if [[ $exit_code -eq 0 ]]; then
        log "OK" "openclaw doctor passed"
    else
        log "FAIL" "openclaw doctor reported issues"
    fi

    return $exit_code
}

# ---------------------------------------------------------------------------
# run_full_health_check — Run all health checks and print summary
# Returns: number of failures
# ---------------------------------------------------------------------------
run_full_health_check() {
    init_health_log

    echo ""
    echo -e "${BOLD}🏥 God in Hand — Health Check${NC}"
    echo "════════════════════════════════════════"

    local failures=0

    # System checks
    echo -e "\n${BOLD}System${NC}"

    check_ram_pressure
    case $? in
        0) print_ok "RAM: ${AVAIL_RAM_MB}MB available" ;;
        1) print_warn "RAM pressure (${AVAIL_RAM_MB}MB free)" ;;
        2) print_fail "RAM critical (${AVAIL_RAM_MB}MB free)"; ((failures++)) ;;
    esac

    check_thermal
    case $? in
        0) print_ok "Temperature: ${THERMAL_TEMP_C}°C" ;;
        1) print_warn "Warm: ${THERMAL_TEMP_C}°C" ;;
        2) print_fail "Hot: ${THERMAL_TEMP_C}°C (throttling)"; ((failures++)) ;;
    esac

    check_storage_space
    case $? in
        0) print_ok "Storage: ${AVAIL_STORAGE_GB}GB free" ;;
        1) print_warn "Storage low: ${AVAIL_STORAGE_GB}GB free" ;;
        2) print_fail "Storage critical: ${AVAIL_STORAGE_GB}GB free"; ((failures++)) ;;
    esac

    check_battery_health
    case $? in
        0) print_ok "Battery: ${BATTERY_LEVEL}%" ;;
        1) print_warn "Battery low: ${BATTERY_LEVEL}%" ;;
        2) print_fail "Battery critical: ${BATTERY_LEVEL}%"; ((failures++)) ;;
    esac

    check_network_connectivity
    case $? in
        0) print_ok "Network connected" ;;
        1) print_warn "No network"; ((failures++)) ;;
    esac

    # Services
    echo -e "\n${BOLD}Services${NC}"

    check_ollama_status
    case $? in
        0) print_ok "Ollama running" ;;
        1) print_fail "Ollama not running"; ((failures++)) ;;
        2) print_warn "Ollama running but unhealthy"; ((failures++)) ;;
    esac

    check_model_loaded
    case $? in
        0) print_ok "Models loaded" ;;
        1) print_warn "No models loaded"; ((failures++)) ;;
    esac

    check_openclaw_status
    case $? in
        0) print_ok "OpenClaw gateway running" ;;
        1) print_fail "OpenClaw not running"; ((failures++)) ;;
        2) print_warn "OpenClaw unhealthy"; ((failures++)) ;;
    esac

    # Summary
    echo ""
    echo "════════════════════════════════════════"
    if [[ $failures -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}All checks passed! ✅${NC}"
    else
        echo -e "${YELLOW}${BOLD}${failures} issue(s) found. Check log: ${GIH_LOG}${NC}"
    fi
    echo ""

    return $failures
}

# ---------------------------------------------------------------------------
# generate_status_json — Output machine-readable status
# Useful for the hub dashboard to poll
# ---------------------------------------------------------------------------
generate_status_json() {
    detect_ram
    detect_thermal
    detect_battery
    detect_storage

    local ollama_ok=false
    check_ollama_status >/dev/null 2>&1 && ollama_ok=true

    local openclaw_ok=false
    check_openclaw_status >/dev/null 2>&1 && openclaw_ok=true

    local model_ok=false
    check_model_loaded >/dev/null 2>&1 && model_ok=true

    cat <<STATUSJSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "device": {
    "model": "${DEVICE_MODEL:-unknown}",
    "manufacturer": "${DEVICE_MANUFACTURER:-unknown}"
  },
  "system": {
    "ram_total_mb": ${TOTAL_RAM_MB:-0},
    "ram_available_mb": ${AVAIL_RAM_MB:-0},
    "storage_available_gb": ${AVAIL_STORAGE_GB:-0},
    "temperature_c": ${THERMAL_TEMP_C:--1},
    "battery_level": ${BATTERY_LEVEL:--1},
    "battery_charging": "${BATTERY_CHARGING:-unknown}"
  },
  "services": {
    "ollama": ${ollama_ok},
    "openclaw": ${openclaw_ok},
    "model_loaded": ${model_ok}
  }
}
STATUSJSON
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_full_health_check
fi
