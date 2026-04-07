#!/usr/bin/env bash
# ============================================================================
#  🤲 God in Hand — On-device AI Agent Installer
#  Local LLM + Agent Runtime + Skill System for Android (Termux)
#
#  Usage:
#    curl -sL https://raw.githubusercontent.com/user/god-in-hand/main/install.sh | bash
#    bash install.sh [OPTIONS]
#
#  Options:
#    --lang en|ko         Force language (default: auto-detect)
#    --dry-run            Check environment without installing
#    --skip-model         Skip model download (install later)
#    --device-role        Set role: hub | worker | power
#    --engine             Model serving engine: ollama | llamacpp (default: ollama)
#    --model              Specific model ID to install
#    --no-color           Disable colored output
#    --help               Show this help message
#
#  Docs: https://github.com/user/god-in-hand
# ============================================================================

set -o pipefail

# ---------------------------------------------------------------------------
# Bootstrap — Determine script location
# ---------------------------------------------------------------------------
if [[ -n "${BASH_SOURCE[0]}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Running via curl pipe — download the repo first
    SCRIPT_DIR=""
fi

GIH_HOME="${HOME}/.god-in-hand"
GIH_LOG_DIR="${GIH_HOME}/logs"
GIH_LOG="${GIH_LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
GIH_VERSION="0.1.0"

# ---------------------------------------------------------------------------
# Minimal color support (before lib loads)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
DRY_RUN=false
SKIP_MODEL=false
DEVICE_ROLE=""
ENGINE="ollama"
SPECIFIC_MODEL=""
FORCE_LANG=""
NO_COLOR=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)        FORCE_LANG="$2"; shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        --skip-model)  SKIP_MODEL=true; shift ;;
        --device-role) DEVICE_ROLE="$2"; shift 2 ;;
        --engine)      ENGINE="$2"; shift 2 ;;
        --model)       SPECIFIC_MODEL="$2"; shift 2 ;;
        --no-color)    NO_COLOR=true; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''; shift ;;
        --help|-h)
            head -25 "$0" | tail -18
            exit 0
            ;;
        *) shift ;;
    esac
done

# ---------------------------------------------------------------------------
# Core utility functions
# ---------------------------------------------------------------------------
mkdir -p "$GIH_LOG_DIR"

log() {
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[${ts}] $*" >> "$GIH_LOG"
}

die() {
    echo -e "${RED}${BOLD}ERROR:${NC} $1" >&2
    log "FATAL: $1"
    exit 1
}

print_ok()    { echo -e "  ${GREEN}✓${NC} $1"; log "OK: $1"; }
print_fail()  { echo -e "  ${RED}✗${NC} $1"; log "FAIL: $1"; }
print_warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; log "WARN: $1"; }
print_info()  { echo -e "  ${CYAN}ℹ${NC} $1"; log "INFO: $1"; }
print_step()  { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"; log "STEP: $1"; }

ask_yn() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    echo -ne "  ${prompt} "
    read -r answer
    answer="${answer:-$default}"
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

run_cmd() {
    local desc="$1"
    shift
    log "CMD: $*"
    if $DRY_RUN; then
        print_info "[dry-run] ${desc}: $*"
        return 0
    fi
    local output
    output=$("$@" 2>&1)
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        log "CMD FAILED (rc=${rc}): ${output}"
        echo "$output" >> "$GIH_LOG"
    fi
    return $rc
}

# ---------------------------------------------------------------------------
# Bootstrap: If running via curl pipe, clone the repo first
# ---------------------------------------------------------------------------
bootstrap_repo() {
    if [[ -z "$SCRIPT_DIR" || ! -f "${SCRIPT_DIR}/lib/detect.sh" ]]; then
        print_info "Downloading God in Hand repository..."

        local tmp_dir="${GIH_HOME}/repo"
        if [[ -d "$tmp_dir" ]]; then
            rm -rf "$tmp_dir"
        fi

        if command -v git &>/dev/null; then
            git clone --depth 1 "https://github.com/user/god-in-hand.git" "$tmp_dir" 2>/dev/null
        else
            # Fallback: download tarball
            mkdir -p "$tmp_dir"
            curl -sL "https://github.com/user/god-in-hand/archive/main.tar.gz" | tar -xz -C "$tmp_dir" --strip-components=1 2>/dev/null
        fi

        if [[ -f "${tmp_dir}/lib/detect.sh" ]]; then
            SCRIPT_DIR="$tmp_dir"
        else
            die "Failed to download repository. Please install git and retry."
        fi
    fi
}

# ---------------------------------------------------------------------------
# Load library modules
# ---------------------------------------------------------------------------
load_libs() {
    local lib_dir="${SCRIPT_DIR}/lib"

    if [[ -f "${lib_dir}/i18n.sh" ]]; then
        source "${lib_dir}/i18n.sh"
        if [[ -n "$FORCE_LANG" ]]; then
            GIH_LANG="$FORCE_LANG"
        fi
    fi

    if [[ -f "${lib_dir}/detect.sh" ]]; then
        source "${lib_dir}/detect.sh"
    else
        die "Missing lib/detect.sh"
    fi

    if [[ -f "${lib_dir}/models.sh" ]]; then
        source "${lib_dir}/models.sh"
    fi

    if [[ -f "${lib_dir}/health.sh" ]]; then
        source "${lib_dir}/health.sh"
    fi
}

# ============================================================================
#  PHASE 0: Pre-flight Checks
# ============================================================================
phase0_preflight() {
    print_step "$(msg phase0)"
    local failures=0

    # --- Termux check ---
    print_info "$(msg check_termux)"
    detect_termux
    case $? in
        0) print_ok "$(msg check_termux_ok) (v${TERMUX_VERSION:-unknown})" ;;
        1) print_fail "Not running inside Termux."
           die "This installer requires Termux on Android. See docs/ios-setup.md for iOS." ;;
        2) print_fail "$(msg check_termux_fail)"
           echo ""
           echo "  Download F-Droid Termux: https://f-droid.org/packages/com.termux/"
           die "Please reinstall Termux from F-Droid and retry." ;;
    esac

    # --- Android version ---
    print_info "$(msg check_android)"
    detect_android_version
    if [[ $ANDROID_API -ge 29 ]]; then
        print_ok "$(msg check_android_ok) (Android ${ANDROID_VERSION}, API ${ANDROID_API})"
    else
        print_fail "$(msg check_android_fail)${ANDROID_VERSION} (API ${ANDROID_API})"
        ((failures++))
    fi

    # --- CPU architecture ---
    print_info "$(msg check_arch)"
    if detect_cpu_arch; then
        print_ok "$(msg check_arch_ok)"
    else
        print_fail "$(msg check_arch_fail)${CPU_ARCH}"
        die "aarch64 architecture required. Cannot continue."
    fi

    # --- RAM ---
    print_info "$(msg check_ram)"
    detect_ram
    if [[ $TOTAL_RAM_GB -ge 6 ]]; then
        print_ok "$(msg check_ram_ok) (${TOTAL_RAM_MB}MB total, ~${TOTAL_RAM_GB}GB)"
    elif [[ $TOTAL_RAM_GB -ge 4 ]]; then
        print_warn "$(msg check_ram_warn) (${TOTAL_RAM_MB}MB total)"
    else
        print_fail "Insufficient RAM: ${TOTAL_RAM_MB}MB. Minimum 4GB recommended."
        ((failures++))
    fi

    # --- Storage ---
    print_info "$(msg check_storage)"
    detect_storage
    if [[ $AVAIL_STORAGE_GB -ge 10 ]]; then
        print_ok "$(msg check_storage_ok) (${AVAIL_STORAGE_GB}GB free)"
    elif [[ $AVAIL_STORAGE_GB -ge 5 ]]; then
        print_warn "Low storage: ${AVAIL_STORAGE_GB}GB free. 10GB+ recommended."
    else
        print_fail "$(msg check_storage_fail)${AVAIL_STORAGE_GB}GB"
        ((failures++))
    fi

    # --- Network ---
    print_info "$(msg check_network)"
    if detect_network; then
        print_ok "$(msg check_network_ok)"
    else
        print_fail "$(msg check_network_fail)"
        ((failures++))
    fi

    # --- Device summary ---
    detect_device_model
    detect_soc
    detect_battery
    detect_thermal
    print_device_summary

    if [[ $failures -gt 0 ]]; then
        echo ""
        print_fail "${failures} pre-flight check(s) failed."
        if ! ask_yn "Continue anyway? [y/N]" "n"; then
            die "$(msg abort)"
        fi
    fi

    log "Phase 0 complete. Failures: ${failures}"
}

# ============================================================================
#  PHASE 1: Existing Installation Check
# ============================================================================
phase1_existing() {
    print_step "$(msg phase1)"

    # --- Node.js ---
    if detect_existing_node; then
        print_info "$(msg found_node)${NODE_VERSION}"
        if [[ $NODE_MAJOR -lt 22 ]]; then
            print_warn "Node.js ${NODE_VERSION} found but v22+ required."
            if ask_yn "$(msg node_upgrade)" "y"; then
                log "User chose to upgrade Node.js"
            else
                print_warn "Skipping Node.js upgrade. OpenClaw may not work correctly."
            fi
        else
            print_ok "Node.js ${NODE_VERSION} — compatible"
        fi
    else
        print_info "Node.js not found. Will install."
    fi

    # --- proot-distro ---
    detect_proot
    if $PROOT_INSTALLED; then
        print_info "proot-distro found"
        if $PROOT_UBUNTU; then
            print_ok "Ubuntu distro installed"
            if ask_yn "Reuse existing Ubuntu? [Y/n]" "y"; then
                log "Reusing existing proot Ubuntu"
            else
                log "Will clean reinstall proot Ubuntu"
            fi
        fi
    fi

    # --- OpenClaw ---
    if detect_existing_openclaw; then
        print_info "$(msg found_openclaw) (${OPENCLAW_VERSION})"
        echo -ne "  $(msg openclaw_action) "
        read -r oc_choice
        case "${oc_choice,,}" in
            u|update)
                log "User chose to update OpenClaw"
                ;;
            r|reinstall)
                log "User chose to reinstall OpenClaw"
                ;;
            *)
                log "User chose to skip OpenClaw update"
                print_info "Skipping OpenClaw update"
                ;;
        esac
    fi

    # --- Existing models ---
    detect_existing_models
    if [[ ${#EXISTING_MODELS[@]} -gt 0 ]]; then
        print_info "$(msg found_models): ${#EXISTING_MODELS[@]} file(s)"
        for m in "${EXISTING_MODELS[@]:0:5}"; do
            echo "    $(basename "$m")"
        done
        if ask_yn "$(msg skip_models)" "y"; then
            log "Skipping existing model re-download"
        fi
    fi

    # --- Stale locks ---
    detect_stale_locks
    if [[ ${#STALE_LOCKS[@]} -gt 0 ]]; then
        print_warn "$(msg cleaning_locks) (${#STALE_LOCKS[@]} found)"
        if ! $DRY_RUN; then
            for lock in "${STALE_LOCKS[@]}"; do
                rm -f "$lock"
            done
        fi
        print_ok "Stale locks cleaned"
    fi

    log "Phase 1 complete"
}

# ============================================================================
#  PHASE 2: Permissions & Environment
# ============================================================================
phase2_permissions() {
    print_step "$(msg phase2)"

    # --- Termux:API ---
    if ! command -v termux-setup-storage &>/dev/null; then
        print_warn "Termux:API not found. Install from F-Droid for full features."
        echo "    https://f-droid.org/packages/com.termux.api/"
    fi

    # --- Storage permission ---
    print_info "$(msg storage_perm)"
    if [[ ! -d "$HOME/storage" ]]; then
        if ! $DRY_RUN; then
            termux-setup-storage 2>/dev/null || true
            sleep 2
        fi
        if [[ -d "$HOME/storage" ]]; then
            print_ok "Storage access granted"
        else
            print_warn "Storage access not granted. Some features may be limited."
        fi
    else
        print_ok "Storage already accessible"
    fi

    # --- Wake Lock ---
    print_info "$(msg wake_lock)"
    if command -v termux-wake-lock &>/dev/null; then
        if ! $DRY_RUN; then
            termux-wake-lock 2>/dev/null || true
        fi
        print_ok "Wake lock acquired"
    else
        print_warn "termux-wake-lock not available"
    fi

    # --- Battery optimization warning ---
    echo ""
    echo -e "  ${YELLOW}${BOLD}$(msg battery_warn)${NC}"
    echo -e "  ${YELLOW}$(msg battery_samsung)${NC}"
    echo ""
    echo "  Also disable: Settings > Apps > Termux > Battery > Unrestricted"
    echo "  And: Settings > Device care > Battery > Background usage limits > Remove Termux"
    echo ""

    # --- Termux:Boot ---
    if [[ ! -d "$HOME/.termux/boot" ]]; then
        print_info "Termux:Boot not configured. For auto-start on reboot:"
        echo "    1. Install Termux:Boot from F-Droid"
        echo "    2. Run: mkdir -p ~/.termux/boot"
        echo "    3. Create startup script in ~/.termux/boot/"
    else
        print_ok "Termux:Boot directory exists"
    fi

    log "Phase 2 complete"
}

# ============================================================================
#  PHASE 3: Core Installation
# ============================================================================
phase3_install() {
    print_step "$(msg phase3)"

    if $DRY_RUN; then
        print_info "$(msg dry_run)"
        print_info "[dry-run] Would install: nodejs-lts git build-essential cmake python proot-distro"
        print_info "[dry-run] Would install: OpenClaw (npm)"
        print_info "[dry-run] Would install: ${ENGINE}"
        return 0
    fi

    # --- pkg update ---
    print_info "$(msg updating_pkg)"

    # Try default mirror, fallback to alternatives
    if ! pkg update -y >> "$GIH_LOG" 2>&1; then
        print_warn "Default mirror failed. Trying alternative..."
        # Termux mirror auto-select
        if command -v termux-change-repo &>/dev/null; then
            termux-change-repo 2>/dev/null || true
        fi
        if ! pkg update -y >> "$GIH_LOG" 2>&1; then
            die "Failed to update packages. Check network and mirrors."
        fi
    fi
    pkg upgrade -y >> "$GIH_LOG" 2>&1
    print_ok "Packages updated"

    # --- Install dependencies ---
    print_info "$(msg installing_deps)"
    local deps="nodejs-lts git build-essential cmake python proot-distro curl wget"
    for dep in $deps; do
        if ! dpkg -s "$dep" >/dev/null 2>&1; then
            log "Installing: $dep"
            if ! pkg install -y "$dep" >> "$GIH_LOG" 2>&1; then
                print_warn "Failed to install: $dep"
            fi
        fi
    done
    print_ok "Dependencies installed"

    # --- Verify Node.js ---
    local node_ver
    node_ver=$(node --version 2>/dev/null || echo "none")
    local node_major
    node_major=$(echo "$node_ver" | grep -oE '^v([0-9]+)' | tr -d 'v')
    if [[ "${node_major:-0}" -lt 22 ]]; then
        print_warn "Node.js ${node_ver} — expected v22+. Attempting upgrade..."
        pkg install -y nodejs-lts >> "$GIH_LOG" 2>&1
        node_ver=$(node --version 2>/dev/null || echo "none")
    fi
    print_ok "Node.js: ${node_ver}"

    # --- Install OpenClaw ---
    print_info "$(msg installing_openclaw)"
    if ! npm install -g openclaw >> "$GIH_LOG" 2>&1; then
        print_warn "npm install openclaw failed. Retrying with --force..."
        npm install -g openclaw --force >> "$GIH_LOG" 2>&1 || true
    fi

    if command -v openclaw &>/dev/null; then
        local oc_ver
        oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        print_ok "OpenClaw installed: ${oc_ver}"
    else
        print_fail "OpenClaw installation failed. Check log: ${GIH_LOG}"
    fi

    # --- Model serving engine ---
    case "$ENGINE" in
        ollama)
            print_info "Installing Ollama..."
            if ! command -v ollama &>/dev/null; then
                # Ollama install for Termux
                if curl -fsSL https://ollama.com/install.sh 2>/dev/null | bash >> "$GIH_LOG" 2>&1; then
                    print_ok "Ollama installed"
                else
                    # Fallback: build from source or use prebuilt
                    print_warn "Ollama auto-install failed. Trying pkg..."
                    pkg install -y ollama >> "$GIH_LOG" 2>&1 || true
                fi
            fi

            if command -v ollama &>/dev/null; then
                local ollama_ver
                ollama_ver=$(ollama --version 2>/dev/null | head -1)
                print_ok "Ollama: ${ollama_ver}"

                # Start Ollama server in background
                print_info "Starting Ollama server..."
                ollama serve >> "${GIH_LOG_DIR}/ollama.log" 2>&1 &
                sleep 3

                if curl -sf "http://localhost:11434/api/version" >/dev/null 2>&1; then
                    print_ok "Ollama server running on :11434"
                else
                    print_warn "Ollama server failed to start. Check: ${GIH_LOG_DIR}/ollama.log"
                fi
            else
                print_fail "Ollama not available. Model serving will need manual setup."
            fi
            ;;

        llamacpp)
            print_info "Building llama.cpp from source..."
            local llamacpp_dir="${GIH_HOME}/llama.cpp"
            if [[ ! -d "$llamacpp_dir" ]]; then
                git clone --depth 1 "https://github.com/ggml-org/llama.cpp.git" "$llamacpp_dir" >> "$GIH_LOG" 2>&1
            fi
            cd "$llamacpp_dir" || die "Failed to enter llama.cpp directory"
            cmake -B build >> "$GIH_LOG" 2>&1
            cmake --build build --config Release -j$(nproc) >> "$GIH_LOG" 2>&1
            cd - >/dev/null || true

            if [[ -f "${llamacpp_dir}/build/bin/llama-server" ]]; then
                print_ok "llama.cpp built successfully"
                ln -sf "${llamacpp_dir}/build/bin/llama-server" "${PREFIX}/bin/llama-server" 2>/dev/null || true
            else
                print_fail "llama.cpp build failed. Check log."
            fi
            ;;

        *)
            print_warn "Unknown engine: ${ENGINE}. Skipping."
            ;;
    esac

    # --- Model download ---
    if $SKIP_MODEL; then
        print_info "Model download skipped (--skip-model). Install later:"
        echo "    ollama pull gemma4:e2b"
        echo "    ollama pull qwen3:0.6b"
    else
        echo ""
        if [[ -n "$SPECIFIC_MODEL" ]]; then
            # Download specific model
            if get_model_info "$SPECIFIC_MODEL"; then
                echo -e "  $(msg model_recommend)${BOLD}${MODEL_NAME}${NC}"
                if [[ "$ENGINE" == "ollama" && -n "$MODEL_OLLAMA_TAG" ]]; then
                    download_model_ollama "$MODEL_OLLAMA_TAG"
                fi
            fi
        else
            install_models "$TOTAL_RAM_GB" "$ENGINE"
        fi
    fi

    # --- OpenClaw onboarding ---
    if command -v openclaw &>/dev/null; then
        echo ""
        print_info "Running OpenClaw onboarding wizard..."
        echo "  (Follow the prompts to configure your agent)"
        echo ""
        if ! $DRY_RUN; then
            openclaw onboard 2>&1 || true
        fi
    fi

    log "Phase 3 complete"
}

# ============================================================================
#  PHASE 4: Verification & Health Check
# ============================================================================
phase4_verify() {
    print_step "$(msg phase4)"

    # --- OpenClaw doctor ---
    print_info "$(msg running_doctor)"
    run_openclaw_doctor || true

    # --- Model inference test ---
    print_info "$(msg testing_model)"
    local api_base="http://localhost:11434"
    if [[ "$ENGINE" == "llamacpp" ]]; then
        api_base="http://localhost:8080"
    fi

    if test_model_inference "$api_base"; then
        print_ok "$(msg test_ok)"
    else
        print_warn "$(msg test_fail)"
        echo "  This may be because no model is loaded yet."
        echo "  Try: ollama run gemma4:e2b"
    fi

    # --- Gateway test ---
    if check_openclaw_status; then
        print_ok "OpenClaw gateway is running"
        local gw_url="http://localhost:3000"
        echo -e "\n  $(msg dashboard_url)${CYAN}${gw_url}${NC}"
    else
        print_info "OpenClaw gateway not started yet."
        echo "  Start with: openclaw"
    fi

    # --- Termux:API test ---
    if command -v termux-camera-photo &>/dev/null; then
        print_ok "Termux:API available (camera, GPS, sensors)"
    fi

    # --- Full health check ---
    echo ""
    run_full_health_check || true

    log "Phase 4 complete"
}

# ============================================================================
#  PHASE 5: Hub & Multi-device Setup
# ============================================================================
phase5_hub() {
    print_step "$(msg phase5)"

    # --- Device role ---
    local rec_role
    rec_role=$(recommend_role)

    if [[ -z "$DEVICE_ROLE" ]]; then
        echo ""
        echo -e "  $(msg select_role)"
        echo -e "    Recommended: ${BOLD}${rec_role}${NC} (based on ${TOTAL_RAM_GB}GB RAM)"
        echo -ne "  Choice [H/W/P]: "
        read -r role_choice
        case "${role_choice,,}" in
            h|hub)   DEVICE_ROLE="hub" ;;
            w|worker) DEVICE_ROLE="worker" ;;
            p|power) DEVICE_ROLE="power" ;;
            *)       DEVICE_ROLE="$rec_role" ;;
        esac
    fi

    # Save role config
    mkdir -p "$GIH_HOME"
    cat > "${GIH_HOME}/config.json" <<CFGEOF
{
  "version": "${GIH_VERSION}",
  "device_role": "${DEVICE_ROLE}",
  "engine": "${ENGINE}",
  "total_ram_gb": ${TOTAL_RAM_GB},
  "device_model": "${DEVICE_MODEL}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "language": "${GIH_LANG}"
}
CFGEOF
    print_ok "Device role set: ${DEVICE_ROLE}"

    # --- Hub-specific setup ---
    if [[ "$DEVICE_ROLE" == "hub" ]]; then
        # Copy hub dashboard
        if [[ -f "${SCRIPT_DIR}/hub/index.html" ]]; then
            mkdir -p "${GIH_HOME}/hub"
            cp "${SCRIPT_DIR}/hub/index.html" "${GIH_HOME}/hub/"
            print_ok "Hub dashboard installed"
            echo ""
            echo "  Start the dashboard:"
            echo "    cd ${GIH_HOME}/hub && python -m http.server 8080"
            echo "    Then open: http://localhost:8080"
        fi

        # Node pairing info
        echo ""
        echo "  Multi-device pairing:"
        echo "    Other Android devices: openclaw node pair"
        echo "    iOS devices: See docs/ios-setup.md"
        echo ""
        local local_ip
        local_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "unknown")
        echo -e "  Hub LAN IP: ${CYAN}${local_ip}${NC}"
        echo "  Other devices connect to: http://${local_ip}:3000"
    fi

    # --- Termux:Boot auto-start script ---
    if [[ -d "$HOME/.termux/boot" ]]; then
        cat > "$HOME/.termux/boot/god-in-hand.sh" <<'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/bash
# God in Hand — auto-start on boot
termux-wake-lock
sleep 5

# Start Ollama
ollama serve &>/dev/null &

# Start OpenClaw
sleep 3
openclaw &>/dev/null &
BOOTEOF
        chmod +x "$HOME/.termux/boot/god-in-hand.sh"
        print_ok "Auto-start script installed (Termux:Boot)"
    fi

    log "Phase 5 complete"
}

# ============================================================================
#  MAIN — Orchestrate all phases
# ============================================================================
main() {
    echo ""
    echo -e "${BOLD}${CYAN}🤲 God in Hand v${GIH_VERSION}${NC}"
    echo -e "${BOLD}   On-device AI Agent System${NC}"
    echo ""

    if $DRY_RUN; then
        echo -e "  ${YELLOW}$(msg dry_run)${NC}"
        echo ""
    fi

    echo -e "  $(msg log_location)${GIH_LOG}"
    echo ""

    # Bootstrap repo if needed (curl pipe install)
    bootstrap_repo

    # Load library modules
    load_libs

    # Run all phases
    phase0_preflight
    phase1_existing
    phase2_permissions
    phase3_install
    phase4_verify
    phase5_hub

    # --- Final summary ---
    echo ""
    echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  $(msg done)${NC}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "  Quick start:"
    echo "    ollama run gemma4:e2b        # Chat with local LLM"
    echo "    openclaw                      # Start AI agent"
    echo "    openclaw doctor               # Run diagnostics"
    echo ""
    echo -e "  $(msg log_location)${CYAN}${GIH_LOG}${NC}"
    echo ""
    echo "  Docs:  https://github.com/user/god-in-hand"
    echo "  Issues: https://github.com/user/god-in-hand/issues"
    echo ""

    log "Installation complete. Role: ${DEVICE_ROLE}, Engine: ${ENGINE}"
}

main "$@"
