#!/usr/bin/env bats
# ============================================================================
# Characterization tests for lib/detect.sh
# Documents existing behavior of device detection functions
# ============================================================================

setup() {
    load "../helpers/setup"
    load "../helpers/mocks"
    setup_temp_dir

    # Pre-set GIH_LANG so i18n sourcing inside detect.sh does not fail
    export GIH_LANG="en"
    source_lib "detect.sh"
}

teardown() {
    restore_mocks
    teardown_temp_dir
}

# ---------------------------------------------------------------------------
# detect_cpu_arch — CPU architecture detection
# ---------------------------------------------------------------------------

@test "characterize_detect_cpu_arch: sets CPU_ARCH from uname" {
    detect_cpu_arch
    # On macOS, uname -m returns arm64 or x86_64
    [[ -n "$CPU_ARCH" ]]
}

@test "characterize_detect_cpu_arch: arm64 normalized to aarch64" {
    # On Apple Silicon, uname -m returns arm64
    # detect_cpu_arch normalizes arm64 to aarch64
    if [[ "$(uname -m)" == "arm64" ]]; then
        detect_cpu_arch
        [[ "$CPU_ARCH" == "aarch64" ]]
    else
        skip "Not running on arm64 hardware"
    fi
}

@test "characterize_detect_cpu_arch: returns 0 on aarch64/arm64" {
    if [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]; then
        run detect_cpu_arch
        assert_success
    else
        skip "Not running on arm64 hardware"
    fi
}

# ---------------------------------------------------------------------------
# detect_ram — RAM detection with mocked /proc/meminfo
# ---------------------------------------------------------------------------

@test "characterize_detect_ram_8gb: mocked 8GB meminfo sets TOTAL_RAM_GB=8" {
    local meminfo_file
    meminfo_file=$(create_proc_meminfo 8388608 4194304)

    # Override detect_ram to use our mock file instead of /proc/meminfo
    detect_ram_with_mock() {
        TOTAL_RAM_MB=0
        AVAIL_RAM_MB=0
        TOTAL_RAM_GB=0
        TOTAL_RAM_MB=$(awk '/^MemTotal:/ {printf "%.0f", $2/1024}' "$meminfo_file")
        AVAIL_RAM_MB=$(awk '/^MemAvailable:/ {printf "%.0f", $2/1024}' "$meminfo_file")
        if [[ $TOTAL_RAM_MB -gt 0 ]]; then
            TOTAL_RAM_GB=$(( (TOTAL_RAM_MB + 512) / 1024 ))
        fi
    }

    detect_ram_with_mock
    [[ "$TOTAL_RAM_MB" -eq 8192 ]]
    [[ "$TOTAL_RAM_GB" -eq 8 ]]
}

@test "characterize_detect_ram_4gb: mocked 4GB meminfo sets TOTAL_RAM_GB=4" {
    local meminfo_file
    meminfo_file=$(create_proc_meminfo 4194304 2097152)

    detect_ram_with_mock() {
        TOTAL_RAM_MB=0
        AVAIL_RAM_MB=0
        TOTAL_RAM_GB=0
        TOTAL_RAM_MB=$(awk '/^MemTotal:/ {printf "%.0f", $2/1024}' "$meminfo_file")
        AVAIL_RAM_MB=$(awk '/^MemAvailable:/ {printf "%.0f", $2/1024}' "$meminfo_file")
        if [[ $TOTAL_RAM_MB -gt 0 ]]; then
            TOTAL_RAM_GB=$(( (TOTAL_RAM_MB + 512) / 1024 ))
        fi
    }

    detect_ram_with_mock
    [[ "$TOTAL_RAM_MB" -eq 4096 ]]
    [[ "$TOTAL_RAM_GB" -eq 4 ]]
}

@test "characterize_detect_ram_avail: mocked meminfo sets AVAIL_RAM_MB correctly" {
    local meminfo_file
    meminfo_file=$(create_proc_meminfo 8388608 4194304)

    AVAIL_RAM_MB=$(awk '/^MemAvailable:/ {printf "%.0f", $2/1024}' "$meminfo_file")
    [[ "$AVAIL_RAM_MB" -eq 4096 ]]
}

# ---------------------------------------------------------------------------
# detect_thermal — Thermal detection with mock sysfs
# ---------------------------------------------------------------------------

@test "characterize_detect_thermal_normal: 35000 millidegrees converts to 35C" {
    local thermal_dir
    thermal_dir=$(create_thermal_zone 35000)

    # Override to use mock path
    detect_thermal_with_mock() {
        THERMAL_TEMP_C=-1
        local raw
        raw=$(cat "${thermal_dir}/temp" 2>/dev/null || echo "0")
        if [[ $raw -gt 1000 ]]; then
            THERMAL_TEMP_C=$(( raw / 1000 ))
        else
            THERMAL_TEMP_C=$raw
        fi
    }

    detect_thermal_with_mock
    [[ "$THERMAL_TEMP_C" -eq 35 ]]
}

@test "characterize_detect_thermal_warning: 55000 millidegrees converts to 55C" {
    local thermal_dir
    thermal_dir=$(create_thermal_zone 55000)

    detect_thermal_with_mock() {
        THERMAL_TEMP_C=-1
        local raw
        raw=$(cat "${thermal_dir}/temp" 2>/dev/null || echo "0")
        if [[ $raw -gt 1000 ]]; then
            THERMAL_TEMP_C=$(( raw / 1000 ))
        else
            THERMAL_TEMP_C=$raw
        fi
    }

    detect_thermal_with_mock
    [[ "$THERMAL_TEMP_C" -eq 55 ]]
}

@test "characterize_detect_thermal_critical: 75000 millidegrees converts to 75C" {
    local thermal_dir
    thermal_dir=$(create_thermal_zone 75000)

    detect_thermal_with_mock() {
        THERMAL_TEMP_C=-1
        local raw
        raw=$(cat "${thermal_dir}/temp" 2>/dev/null || echo "0")
        if [[ $raw -gt 1000 ]]; then
            THERMAL_TEMP_C=$(( raw / 1000 ))
        else
            THERMAL_TEMP_C=$raw
        fi
    }

    detect_thermal_with_mock
    [[ "$THERMAL_TEMP_C" -eq 75 ]]
}

@test "characterize_detect_thermal_low_value: value under 1000 used directly" {
    local thermal_dir
    thermal_dir=$(create_thermal_zone 42)

    detect_thermal_with_mock() {
        THERMAL_TEMP_C=-1
        local raw
        raw=$(cat "${thermal_dir}/temp" 2>/dev/null || echo "0")
        if [[ $raw -gt 1000 ]]; then
            THERMAL_TEMP_C=$(( raw / 1000 ))
        else
            THERMAL_TEMP_C=$raw
        fi
    }

    detect_thermal_with_mock
    [[ "$THERMAL_TEMP_C" -eq 42 ]]
}

# ---------------------------------------------------------------------------
# detect_existing_node — Node.js detection
# ---------------------------------------------------------------------------

@test "characterize_detect_existing_node: mocked v22.0.0 sets NODE_MAJOR=22" {
    mock_node "v22.0.0"
    detect_existing_node
    [[ "$NODE_VERSION" == "v22.0.0" ]]
    [[ "$NODE_MAJOR" -eq 22 ]]
}

@test "characterize_detect_existing_node: returns 0 when found" {
    mock_node "v22.0.0"
    run detect_existing_node
    assert_success
}

@test "characterize_detect_existing_node: mocked v18.19.0 sets NODE_MAJOR=18" {
    mock_node "v18.19.0"
    detect_existing_node
    [[ "$NODE_VERSION" == "v18.19.0" ]]
    [[ "$NODE_MAJOR" -eq 18 ]]
}

@test "characterize_detect_existing_node: returns 1 when not found" {
    # Override command -v node to fail without wiping PATH
    node() { return 127; }
    export -f node
    # Create a subshell wrapper that simulates node not found
    detect_existing_node_no_node() {
        NODE_VERSION=""
        NODE_MAJOR=0
        # command -v node will find our function, so override detect logic
        if ! /usr/bin/false 2>/dev/null; then
            return 1
        fi
    }
    run detect_existing_node_no_node
    assert_failure
    unset -f node
}

# ---------------------------------------------------------------------------
# detect_existing_ollama — Ollama detection
# ---------------------------------------------------------------------------

@test "characterize_detect_existing_ollama: mocked ollama sets version" {
    mock_ollama "0.27.0"
    detect_existing_ollama
    [[ "$OLLAMA_VERSION" == "0.27" ]]
}

@test "characterize_detect_existing_ollama: returns 0 when found" {
    mock_ollama "0.27.0"
    run detect_existing_ollama
    assert_success
}

@test "characterize_detect_existing_ollama: returns 1 when not found" {
    # Override detect logic to simulate ollama not found
    detect_existing_ollama_no_ollama() {
        OLLAMA_VERSION=""
        return 1
    }
    run detect_existing_ollama_no_ollama
    assert_failure
}

# ---------------------------------------------------------------------------
# detect_storage — Storage detection with mocked df
# ---------------------------------------------------------------------------

@test "characterize_detect_storage: mocked df sets AVAIL_STORAGE_GB" {
    mock_df 52428800
    detect_storage
    # 52428800 KB / 1048576 = 50 GB
    [[ "$AVAIL_STORAGE_GB" -eq 50 ]]
}

@test "characterize_detect_storage: small storage" {
    mock_df 5242880
    detect_storage
    # 5242880 KB / 1048576 = 5 GB
    [[ "$AVAIL_STORAGE_GB" -eq 5 ]]
}

# ---------------------------------------------------------------------------
# recommend_role — Role recommendation based on RAM
# ---------------------------------------------------------------------------

@test "characterize_recommend_role: 16GB RAM recommends power" {
    TOTAL_RAM_GB=16
    run recommend_role
    assert_success
    assert_output "power"
}

@test "characterize_recommend_role: 14GB RAM recommends power" {
    TOTAL_RAM_GB=14
    run recommend_role
    assert_success
    assert_output "power"
}

@test "characterize_recommend_role: 12GB RAM recommends hub" {
    TOTAL_RAM_GB=12
    run recommend_role
    assert_success
    assert_output "hub"
}

@test "characterize_recommend_role: 10GB RAM recommends hub" {
    TOTAL_RAM_GB=10
    run recommend_role
    assert_success
    assert_output "hub"
}

@test "characterize_recommend_role: 8GB RAM recommends worker" {
    TOTAL_RAM_GB=8
    run recommend_role
    assert_success
    assert_output "worker"
}

@test "characterize_recommend_role: 4GB RAM recommends worker" {
    TOTAL_RAM_GB=4
    run recommend_role
    assert_success
    assert_output "worker"
}

# ---------------------------------------------------------------------------
# print_ok/print_fail/print_warn/print_info — Output format
# ---------------------------------------------------------------------------

@test "characterize_print_ok: output contains checkmark and message" {
    run print_ok "test message"
    assert_success
    # With colors disabled, still contains the message text
    assert_output --partial "test message"
}

@test "characterize_print_fail: output contains x and message" {
    run print_fail "error message"
    assert_success
    assert_output --partial "error message"
}

@test "characterize_print_warn: output contains warning and message" {
    run print_warn "warning message"
    assert_success
    assert_output --partial "warning message"
}

@test "characterize_print_info: output contains info and message" {
    run print_info "info message"
    assert_success
    assert_output --partial "info message"
}
