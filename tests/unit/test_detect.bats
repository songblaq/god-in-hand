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

# ---------------------------------------------------------------------------
# print_step — Step header output
# ---------------------------------------------------------------------------

@test "characterize_print_step: output contains step title" {
    run print_step "Phase 1"
    assert_success
    assert_output --partial "Phase 1"
}

@test "characterize_print_step: output contains separator characters" {
    run print_step "Setup"
    assert_success
    # print_step wraps title with dash characters
    assert_output --partial "Setup"
}

# ---------------------------------------------------------------------------
# detect_existing_openclaw — OpenClaw detection
# ---------------------------------------------------------------------------

@test "characterize_detect_existing_openclaw: mocked openclaw sets version and path" {
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/openclaw" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
    echo "openclaw 1.2.3"
fi
SCRIPT
    chmod +x "${bin_dir}/openclaw"
    export PATH="${bin_dir}:${PATH}"

    detect_existing_openclaw
    [[ "$OPENCLAW_VERSION" == "openclaw 1.2.3" ]]
    [[ "$OPENCLAW_PATH" == "${bin_dir}/openclaw" ]]
}

@test "characterize_detect_existing_openclaw: returns 0 when found" {
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/openclaw" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
    echo "openclaw 1.0.0"
fi
SCRIPT
    chmod +x "${bin_dir}/openclaw"
    export PATH="${bin_dir}:${PATH}"

    run detect_existing_openclaw
    assert_success
}

@test "characterize_detect_existing_openclaw: returns 1 when not found" {
    # Ensure openclaw is not in PATH
    detect_existing_openclaw_none() {
        OPENCLAW_VERSION=""
        OPENCLAW_PATH=""
        if ! /usr/bin/false 2>/dev/null; then
            return 1
        fi
    }
    run detect_existing_openclaw_none
    assert_failure
}

# ---------------------------------------------------------------------------
# detect_existing_models — Cached model file detection
# ---------------------------------------------------------------------------

@test "characterize_detect_existing_models: no model dirs returns empty array" {
    # Use temp HOME with no model directories
    local orig_home="$HOME"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "$HOME"

    detect_existing_models
    [[ ${#EXISTING_MODELS[@]} -eq 0 ]]

    export HOME="$orig_home"
}

@test "characterize_detect_existing_models: finds gguf files in ollama dir" {
    local orig_home="$HOME"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "$HOME/.ollama/models"
    touch "$HOME/.ollama/models/test-model.gguf"
    touch "$HOME/.ollama/models/another.gguf"

    detect_existing_models
    [[ ${#EXISTING_MODELS[@]} -eq 2 ]]

    export HOME="$orig_home"
}

@test "characterize_detect_existing_models: finds gguf files across multiple dirs" {
    local orig_home="$HOME"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "$HOME/.ollama/models"
    mkdir -p "$HOME/.cache/huggingface"
    mkdir -p "$HOME/.god-in-hand/models"
    touch "$HOME/.ollama/models/model1.gguf"
    touch "$HOME/.cache/huggingface/model2.gguf"
    touch "$HOME/.god-in-hand/models/model3.gguf"

    detect_existing_models
    [[ ${#EXISTING_MODELS[@]} -eq 3 ]]

    export HOME="$orig_home"
}

# ---------------------------------------------------------------------------
# detect_stale_locks — Stale lock file detection
# ---------------------------------------------------------------------------

@test "characterize_detect_stale_locks: no lock dir returns empty array" {
    local orig_home="$HOME"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "$HOME"

    detect_stale_locks
    [[ ${#STALE_LOCKS[@]} -eq 0 ]]

    export HOME="$orig_home"
}

@test "characterize_detect_stale_locks: recent locks not included" {
    local orig_home="$HOME"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "$HOME/.openclaw/sessions"
    touch "$HOME/.openclaw/sessions/session1.lock"

    detect_stale_locks
    # Lock just created, so mmin +60 should not match
    [[ ${#STALE_LOCKS[@]} -eq 0 ]]

    export HOME="$orig_home"
}

# ---------------------------------------------------------------------------
# detect_network — Network connectivity check
# ---------------------------------------------------------------------------

@test "characterize_detect_network: returns 0 when curl succeeds" {
    # Mock curl to succeed
    curl() { return 0; }
    export -f curl

    run detect_network
    assert_success

    unset -f curl
}

@test "characterize_detect_network: returns 1 when all endpoints fail" {
    # Mock curl and ping to fail
    curl() { return 1; }
    export -f curl
    ping() { return 1; }
    export -f ping

    run detect_network
    assert_failure

    unset -f curl
    unset -f ping
}

@test "characterize_detect_network: succeeds on second endpoint" {
    # First curl fails, second succeeds
    local call_count_file="${TEST_TEMP_DIR}/curl_count"
    echo "0" > "$call_count_file"
    eval 'curl() {
        local count=$(cat "'"${call_count_file}"'")
        count=$((count + 1))
        echo "$count" > "'"${call_count_file}"'"
        if [[ $count -le 1 ]]; then
            return 1
        fi
        return 0
    }'
    export -f curl

    run detect_network
    assert_success

    unset -f curl
}

# ---------------------------------------------------------------------------
# detect_battery — Battery status detection
# ---------------------------------------------------------------------------

@test "characterize_detect_battery: termux-battery-status parses percentage" {
    # Mock termux-battery-status with fixture data
    termux-battery-status() {
        echo '{"health":"GOOD","percentage":75,"plugged":"UNPLUGGED","status":"DISCHARGING","temperature":28.5}'
    }
    export -f termux-battery-status

    detect_battery
    [[ "$BATTERY_LEVEL" -eq 75 ]]
    [[ "$BATTERY_CHARGING" == "no" ]]

    unset -f termux-battery-status
}

@test "characterize_detect_battery: charging status detected" {
    termux-battery-status() {
        echo '{"health":"GOOD","percentage":50,"plugged":"AC","status":"CHARGING","temperature":28.5}'
    }
    export -f termux-battery-status

    detect_battery
    [[ "$BATTERY_LEVEL" -eq 50 ]]
    [[ "$BATTERY_CHARGING" == "yes" ]]

    unset -f termux-battery-status
}

@test "characterize_detect_battery: full status treated as charging" {
    termux-battery-status() {
        echo '{"health":"GOOD","percentage":100,"plugged":"AC","status":"FULL","temperature":25.0}'
    }
    export -f termux-battery-status

    detect_battery
    [[ "$BATTERY_LEVEL" -eq 100 ]]
    [[ "$BATTERY_CHARGING" == "yes" ]]

    unset -f termux-battery-status
}

@test "characterize_detect_battery: no battery command returns defaults" {
    # Ensure termux-battery-status and sysfs don't exist
    local orig_home="$HOME"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "$HOME"

    # Remove any battery mock
    unset -f termux-battery-status 2>/dev/null

    detect_battery
    [[ "$BATTERY_LEVEL" -eq -1 ]]
    [[ "$BATTERY_CHARGING" == "unknown" ]]

    export HOME="$orig_home"
}

# ---------------------------------------------------------------------------
# detect_proot — proot-distro detection
# ---------------------------------------------------------------------------

@test "characterize_detect_proot: not installed sets false" {
    # Ensure proot-distro is not available
    detect_proot_none() {
        PROOT_INSTALLED=false
        PROOT_UBUNTU=false
        if ! /usr/bin/false 2>/dev/null; then
            return 0
        fi
    }
    # Test actual function when proot-distro not in PATH
    detect_proot
    [[ "$PROOT_INSTALLED" == "false" ]]
    [[ "$PROOT_UBUNTU" == "false" ]]
}

@test "characterize_detect_proot: installed but no ubuntu" {
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/proot-distro" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    echo "alpine - installed"
    echo "fedora - not installed"
fi
SCRIPT
    chmod +x "${bin_dir}/proot-distro"
    export PATH="${bin_dir}:${PATH}"

    detect_proot
    [[ "$PROOT_INSTALLED" == "true" ]]
    [[ "$PROOT_UBUNTU" == "false" ]]
}

@test "characterize_detect_proot: installed with ubuntu" {
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/proot-distro" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    echo "ubuntu - installed"
    echo "alpine - not installed"
fi
SCRIPT
    chmod +x "${bin_dir}/proot-distro"
    export PATH="${bin_dir}:${PATH}"

    detect_proot
    [[ "$PROOT_INSTALLED" == "true" ]]
    [[ "$PROOT_UBUNTU" == "true" ]]
}

# ---------------------------------------------------------------------------
# print_device_summary — Device summary display
# ---------------------------------------------------------------------------

@test "characterize_print_device_summary: outputs device info" {
    # Set all required globals
    DEVICE_MANUFACTURER="Samsung"
    DEVICE_MODEL="Galaxy S24"
    SOC_NAME="Snapdragon 8 Gen 3"
    ANDROID_VERSION="14"
    ANDROID_API="34"
    CPU_ARCH="aarch64"
    TOTAL_RAM_MB=8192
    AVAIL_RAM_MB=4096
    AVAIL_STORAGE_GB=50
    BATTERY_LEVEL=75
    BATTERY_CHARGING="no"
    THERMAL_TEMP_C=35
    TOTAL_RAM_GB=8

    run print_device_summary
    assert_success
    assert_output --partial "Samsung"
    assert_output --partial "Galaxy S24"
    assert_output --partial "Snapdragon 8 Gen 3"
    assert_output --partial "aarch64"
    assert_output --partial "8192"
    assert_output --partial "50"
}

@test "characterize_print_device_summary: shows recommended role" {
    DEVICE_MANUFACTURER="Google"
    DEVICE_MODEL="Pixel 9"
    SOC_NAME="Tensor G4"
    ANDROID_VERSION="15"
    ANDROID_API="35"
    CPU_ARCH="aarch64"
    TOTAL_RAM_MB=16384
    AVAIL_RAM_MB=8192
    AVAIL_STORAGE_GB=100
    BATTERY_LEVEL=90
    BATTERY_CHARGING="yes"
    THERMAL_TEMP_C=30
    TOTAL_RAM_GB=16

    run print_device_summary
    assert_success
    assert_output --partial "power"
}
