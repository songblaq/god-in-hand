#!/usr/bin/env bash
# ============================================================================
# Common test setup for God in Hand BATS tests
# ============================================================================

# Project root (two levels up from tests/helpers/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load BATS helpers
load "${PROJECT_ROOT}/tests/lib/bats-support/load.bash"
load "${PROJECT_ROOT}/tests/lib/bats-assert/load.bash"

# Disable color output for consistent test assertions
export NO_COLOR=1
RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
BOLD=''
NC=''

# Create temp directory for test artifacts
setup_temp_dir() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown_temp_dir() {
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Source a library file with color variables already neutralized
source_lib() {
    local lib_name="$1"
    # Override color variables before and after sourcing
    source "${PROJECT_ROOT}/lib/${lib_name}"
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
}
