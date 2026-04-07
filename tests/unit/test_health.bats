#!/usr/bin/env bats
# ============================================================================
# Characterization tests for lib/health.sh
# Documents existing behavior of health check functions
# ============================================================================

setup() {
    load "../helpers/setup"
    load "../helpers/mocks"
    setup_temp_dir

    # Pre-set GIH_LANG so i18n sourcing does not fail
    export GIH_LANG="en"

    # Override log directory to temp
    export GIH_LOG_DIR="${TEST_TEMP_DIR}/logs"
    export GIH_LOG="${GIH_LOG_DIR}/health-test.log"
    mkdir -p "$GIH_LOG_DIR"

    # Source detect.sh first (health.sh depends on it), then health.sh
    source_lib "detect.sh"

    # Re-export overrides before sourcing health.sh which sets its own
    export GIH_LOG_DIR="${TEST_TEMP_DIR}/logs"
    export GIH_LOG="${GIH_LOG_DIR}/health-test.log"

    # Source health.sh but override its SCRIPT_DIR-based source of detect.sh
    # by sourcing it directly (detect.sh already loaded)
    source "${PROJECT_ROOT}/lib/health.sh"

    # Reset log paths after source
    GIH_LOG_DIR="${TEST_TEMP_DIR}/logs"
    GIH_LOG="${GIH_LOG_DIR}/health-test.log"

    # Neutralize colors again after health.sh sourced detect.sh
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
}

teardown() {
    restore_mocks
    teardown_temp_dir
}

# ---------------------------------------------------------------------------
# log — Message format
# ---------------------------------------------------------------------------

@test "characterize_health_log: writes timestamped message to log file" {
    init_health_log
    log "INFO" "test message here"
    local content
    content=$(cat "$GIH_LOG")
    # Log format: [HH:MM:SS] [LEVEL] message
    [[ "$content" == *"[INFO] test message here"* ]]
}

@test "characterize_health_log_warn: WARN level written correctly" {
    init_health_log
    log "WARN" "warning text"
    local content
    content=$(cat "$GIH_LOG")
    [[ "$content" == *"[WARN] warning text"* ]]
}

@test "characterize_health_log_crit: CRIT level written correctly" {
    init_health_log
    log "CRIT" "critical issue"
    local content
    content=$(cat "$GIH_LOG")
    [[ "$content" == *"[CRIT] critical issue"* ]]
}

# ---------------------------------------------------------------------------
# init_health_log — Creates log directory and file
# ---------------------------------------------------------------------------

@test "characterize_health_init_log: creates log directory" {
    local new_log_dir="${TEST_TEMP_DIR}/new_logs"
    GIH_LOG_DIR="$new_log_dir"
    GIH_LOG="${new_log_dir}/health-test.log"
    init_health_log
    [[ -d "$new_log_dir" ]]
}

@test "characterize_health_init_log: creates log file with header" {
    init_health_log
    [[ -f "$GIH_LOG" ]]
    local content
    content=$(cat "$GIH_LOG")
    [[ "$content" == *"God in Hand Health Check"* ]]
}

# ---------------------------------------------------------------------------
# check_ram_pressure — RAM pressure thresholds
# Returns: 0 = OK (<= 75%), 1 = warning (75-90%), 2 = critical (> 90%)
# ---------------------------------------------------------------------------

@test "characterize_health_check_ram_pressure_ok: low usage returns 0" {
    init_health_log
    # Override detect_ram to set known values
    detect_ram() {
        TOTAL_RAM_MB=8192
        AVAIL_RAM_MB=4096  # 50% usage
    }
    run check_ram_pressure
    assert_success
}

@test "characterize_health_check_ram_pressure_warning: high usage returns 1" {
    init_health_log
    detect_ram() {
        TOTAL_RAM_MB=8192
        AVAIL_RAM_MB=1638  # ~80% usage
    }
    run check_ram_pressure
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_ram_pressure_critical: very high usage returns 2" {
    init_health_log
    detect_ram() {
        TOTAL_RAM_MB=8192
        AVAIL_RAM_MB=410  # ~95% usage
    }
    run check_ram_pressure
    [[ "$status" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# check_thermal — Temperature thresholds
# Returns: 0 = OK (<= 40C), 1 = warm (40-50C), 2 = hot (> 50C)
# ---------------------------------------------------------------------------

@test "characterize_health_check_thermal_ok: 35C returns 0" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=35
    }
    run check_thermal
    assert_success
}

@test "characterize_health_check_thermal_warm: 45C returns 1" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=45
    }
    run check_thermal
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_thermal_hot: 55C returns 2 (AC-6)" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=55
    }
    run check_thermal
    [[ "$status" -eq 2 ]]
}

@test "characterize_health_check_thermal_no_sensor: -1 returns 0" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=-1
    }
    run check_thermal
    assert_success
}

@test "characterize_health_check_thermal_boundary_40: exactly 40C returns 0" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=40
    }
    run check_thermal
    assert_success
}

@test "characterize_health_check_thermal_boundary_41: 41C returns 1" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=41
    }
    run check_thermal
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_thermal_boundary_50: exactly 50C returns 1" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=50
    }
    run check_thermal
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_thermal_boundary_51: 51C returns 2" {
    init_health_log
    detect_thermal() {
        THERMAL_TEMP_C=51
    }
    run check_thermal
    [[ "$status" -eq 2 ]]
}

# ---------------------------------------------------------------------------
# check_storage_space — Storage thresholds
# Returns: 0 = OK (>= 5GB), 1 = low (2-5GB), 2 = critical (< 2GB)
# ---------------------------------------------------------------------------

@test "characterize_health_check_storage_ok: 50GB returns 0" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=50
    }
    run check_storage_space
    assert_success
}

@test "characterize_health_check_storage_low: 3GB returns 1" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=3
    }
    run check_storage_space
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_storage_critical: 1GB returns 2" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=1
    }
    run check_storage_space
    [[ "$status" -eq 2 ]]
}

@test "characterize_health_check_storage_boundary_5: exactly 5GB returns 0" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=5
    }
    run check_storage_space
    assert_success
}

@test "characterize_health_check_storage_boundary_4: 4GB returns 1" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=4
    }
    run check_storage_space
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_storage_boundary_2: exactly 2GB returns 1" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=2
    }
    run check_storage_space
    [[ "$status" -eq 1 ]]
}

@test "characterize_health_check_storage_boundary_0: 0GB returns 2" {
    init_health_log
    detect_storage() {
        AVAIL_STORAGE_GB=0
    }
    run check_storage_space
    [[ "$status" -eq 2 ]]
}
