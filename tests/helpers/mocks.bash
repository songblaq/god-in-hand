#!/usr/bin/env bash
# ============================================================================
# Reusable mock functions for God in Hand BATS tests
# ============================================================================

# ---------------------------------------------------------------------------
# Mock getprop — returns predefined Android properties
# Usage: mock_getprop "ro.build.version.sdk=33" "ro.product.model=SM-S901B"
# ---------------------------------------------------------------------------
mock_getprop() {
    local -A props=()
    for pair in "$@"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        props["$key"]="$value"
    done

    # Export props to a temp file for the function to read
    local prop_file="${TEST_TEMP_DIR}/mock_props"
    for pair in "$@"; do
        echo "$pair" >> "$prop_file"
    done

    # Create a getprop function that reads from the prop file
    eval 'getprop() {
        local key="$1"
        local prop_file="'"${prop_file}"'"
        if [[ -f "$prop_file" ]]; then
            grep "^${key}=" "$prop_file" 2>/dev/null | head -1 | cut -d= -f2-
        fi
    }'
    export -f getprop
}

# ---------------------------------------------------------------------------
# create_proc_meminfo — creates a mock /proc/meminfo file
# Args: $1 = total KB, $2 = available KB
# ---------------------------------------------------------------------------
create_proc_meminfo() {
    local total_kb="${1:-8388608}"
    local avail_kb="${2:-4194304}"
    local meminfo_file="${TEST_TEMP_DIR}/meminfo"

    cat > "$meminfo_file" << EOF
MemTotal:       ${total_kb} kB
MemFree:        1048576 kB
MemAvailable:   ${avail_kb} kB
Buffers:         524288 kB
Cached:         2097152 kB
EOF
    echo "$meminfo_file"
}

# ---------------------------------------------------------------------------
# create_thermal_zone — creates mock thermal sysfs file
# Args: $1 = temperature in millidegrees (e.g., 35000 for 35C)
# ---------------------------------------------------------------------------
create_thermal_zone() {
    local temp_milli="${1:-35000}"
    local thermal_dir="${TEST_TEMP_DIR}/sys/class/thermal/thermal_zone0"
    mkdir -p "$thermal_dir"
    echo "$temp_milli" > "${thermal_dir}/temp"
    echo "$thermal_dir"
}

# ---------------------------------------------------------------------------
# mock_node — creates a mock node command
# Args: $1 = version string (e.g., "v22.0.0")
# ---------------------------------------------------------------------------
mock_node() {
    local version="${1:-v22.0.0}"
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/node" << SCRIPT
#!/usr/bin/env bash
if [[ "\$1" == "--version" ]]; then
    echo "${version}"
fi
SCRIPT
    chmod +x "${bin_dir}/node"
    export PATH="${bin_dir}:${PATH}"
}

# ---------------------------------------------------------------------------
# mock_ollama — creates a mock ollama command
# Args: $1 = version string (e.g., "0.27.0")
# ---------------------------------------------------------------------------
mock_ollama() {
    local version="${1:-0.27.0}"
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/ollama" << SCRIPT
#!/usr/bin/env bash
if [[ "\$1" == "--version" ]]; then
    echo "ollama version is ${version}"
fi
if [[ "\$1" == "list" ]]; then
    echo "NAME              ID           SIZE    MODIFIED"
    echo "gemma4:e2b        abc123       1.5 GB  2 hours ago"
fi
SCRIPT
    chmod +x "${bin_dir}/ollama"
    export PATH="${bin_dir}:${PATH}"
}

# ---------------------------------------------------------------------------
# mock_df — creates a mock df command
# Args: $1 = available KB
# ---------------------------------------------------------------------------
mock_df() {
    local avail_kb="${1:-52428800}"
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/df" << SCRIPT
#!/usr/bin/env bash
echo "Filesystem  1K-blocks     Used     Available Use% Mounted on"
echo "/dev/sda1   104857600  52428800   ${avail_kb}  50% /home/user"
SCRIPT
    chmod +x "${bin_dir}/df"
    export PATH="${bin_dir}:${PATH}"
}

# ---------------------------------------------------------------------------
# remove_command — hide a command from PATH for testing "not found" scenarios
# Args: $1 = command name
# ---------------------------------------------------------------------------
remove_command() {
    local cmd="$1"
    eval "${cmd}() { return 127; }"
    export -f "$cmd"
}

# ---------------------------------------------------------------------------
# restore_mocks — cleanup mock state
# ---------------------------------------------------------------------------
restore_mocks() {
    # Remove any exported mock functions
    for func in getprop node ollama df termux-battery-status openclaw pgrep; do
        unset -f "$func" 2>/dev/null
    done
}
