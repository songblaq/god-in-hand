#!/usr/bin/env bash
# ============================================================================
#  God in Hand — Lightweight Bootstrap Installer
#  Downloads the CLI tool and creates a symlink. Run 'gih setup' after.
#
#  Usage:
#    curl -sL https://raw.githubusercontent.com/songblaq/god-in-hand/main/install.sh | bash
#    bash install.sh [--lang en|ko]
#
#  Docs: https://github.com/songblaq/god-in-hand
# ============================================================================

set -o pipefail

# ---------------------------------------------------------------------------
# CRITICAL: When running via "curl | bash", stdin is the curl stream.
# We must reopen stdin from /dev/tty for interactive prompts,
# and use </dev/null for non-interactive commands (pkg, git, etc.)
# ---------------------------------------------------------------------------
PIPED_INSTALL=false
if [[ ! -t 0 ]]; then
    PIPED_INSTALL=true
    exec 3</dev/tty 2>/dev/null || exec 3</dev/null
fi

GIH_VERSION="0.3.0"
GIH_HOME="${HOME}/.gih"
GIH_LANG=""

# ---------------------------------------------------------------------------
# Minimal color support
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
FORCE_LANG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)    FORCE_LANG="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: curl -sL URL | bash"
            echo "       bash install.sh [--lang en|ko]"
            echo ""
            echo "Installs the God in Hand CLI. Run 'gih setup' afterwards."
            exit 0
            ;;
        *) shift ;;
    esac
done

die() {
    echo -e "${RED}${BOLD}ERROR:${NC} $1" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Check basic prerequisites
# ---------------------------------------------------------------------------
command -v bash &>/dev/null || die "bash is required."
command -v curl &>/dev/null || die "curl is required. Install with: pkg install curl"

# ---------------------------------------------------------------------------
# bootstrap_repo — Clone or download the repository
# ---------------------------------------------------------------------------
bootstrap_repo() {
    local repo_dir="${GIH_HOME}/repo"

    if [[ -d "$repo_dir" && -f "${repo_dir}/lib/detect.sh" ]]; then
        echo -e "  ${CYAN}ℹ${NC} Existing installation found. Updating..."
        if [[ -d "${repo_dir}/.git" ]]; then
            (cd "$repo_dir" && git pull --ff-only 2>/dev/null) || true
        fi
        return 0
    fi

    echo -e "  ${CYAN}ℹ${NC} Downloading God in Hand repository..."
    mkdir -p "$GIH_HOME"

    if [[ -d "$repo_dir" ]]; then
        rm -rf "$repo_dir"
    fi

    # SECURITY NOTE [MEDIUM]: No integrity verification (checksum/signature) on
    # downloaded repo. HTTPS provides transport security but not content verification.
    if command -v git &>/dev/null; then
        git clone --depth 1 "https://github.com/songblaq/god-in-hand.git" "$repo_dir" 2>/dev/null
    else
        # Fallback: download tarball
        mkdir -p "$repo_dir"
        curl -sL "https://github.com/songblaq/god-in-hand/archive/main.tar.gz" | tar -xz -C "$repo_dir" --strip-components=1 2>/dev/null
    fi

    if [[ ! -f "${repo_dir}/lib/detect.sh" ]]; then
        die "Failed to download repository. Please install git and retry."
    fi
}

# ---------------------------------------------------------------------------
# create_symlink — Link CLI to a directory in PATH
# ---------------------------------------------------------------------------
create_symlink() {
    local cli_source="${GIH_HOME}/repo/bin/gih"

    if [[ ! -f "$cli_source" ]]; then
        die "CLI entry point not found at ${cli_source}"
    fi

    chmod +x "$cli_source"

    # Determine install prefix
    local prefix=""
    if [[ -d "/data/data/com.termux/files/usr" ]]; then
        # Termux
        prefix="/data/data/com.termux/files/usr"
    elif [[ -d "${HOME}/.local/bin" ]]; then
        prefix="${HOME}/.local"
    elif [[ -w "/usr/local/bin" ]]; then
        prefix="/usr/local"
    else
        # Create ~/.local/bin as fallback
        mkdir -p "${HOME}/.local/bin"
        prefix="${HOME}/.local"
        # Warn about PATH
        if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
            echo -e "  ${YELLOW}⚠${NC} Add to your PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi

    local link_target="${prefix}/bin/gih"
    ln -sf "$cli_source" "$link_target" 2>/dev/null || {
        # Try with sudo for /usr/local
        if [[ "$prefix" == "/usr/local" ]]; then
            sudo ln -sf "$cli_source" "$link_target" 2>/dev/null || {
                echo -e "  ${YELLOW}⚠${NC} Could not create symlink at ${link_target}"
                echo "  Run manually: ln -sf ${cli_source} ${link_target}"
                return 1
            }
        fi
    }

    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${BOLD}${CYAN}God in Hand v${GIH_VERSION} — Installer${NC}"
    echo ""

    # Step 1: Download repo
    bootstrap_repo

    # Step 2: Create symlink
    echo -e "  ${CYAN}ℹ${NC} Installing CLI tool..."
    if create_symlink; then
        echo -e "  ${GREEN}✓${NC} CLI installed successfully"
    fi

    # Step 3: Make all scripts executable
    chmod +x "${GIH_HOME}/repo/bin/gih" 2>/dev/null || true
    chmod +x "${GIH_HOME}/repo/lib/"*.sh 2>/dev/null || true

    # Step 4: Device compatibility check
    echo -e "  ${GREEN}${BOLD}✓ CLI installed.${NC}"
    echo ""
    echo -e "${BOLD}━━━ Device Compatibility Check ━━━${NC}"
    echo ""

    # Source detect.sh for hardware checks
    source "${GIH_HOME}/repo/lib/detect.sh"

    # Detect key specs
    local ok_count=0
    local warn_count=0
    local fail_count=0

    # CPU
    detect_cpu_arch
    if [[ "$CPU_ARCH" == "aarch64" || "$CPU_ARCH" == "arm64" ]]; then
        echo -e "  ${GREEN}✓${NC} CPU: ${CPU_ARCH}"
        ((ok_count++))
    else
        echo -e "  ${RED}✗${NC} CPU: ${CPU_ARCH} (aarch64 required)"
        ((fail_count++))
    fi

    # RAM
    detect_ram
    local avail_gb=$(( AVAIL_RAM_MB / 1024 ))
    if [[ ${TOTAL_RAM_MB:-0} -ge 8000 ]]; then
        echo -e "  ${GREEN}✓${NC} RAM: ${TOTAL_RAM_GB}GB total, ${avail_gb}GB available"
        ((ok_count++))
    elif [[ ${TOTAL_RAM_MB:-0} -ge 4000 ]]; then
        echo -e "  ${YELLOW}⚠${NC} RAM: ${TOTAL_RAM_GB}GB total, ${avail_gb}GB available (minimum — limited model selection)"
        ((warn_count++))
    else
        echo -e "  ${RED}✗${NC} RAM: ${TOTAL_RAM_GB}GB total (4GB minimum required)"
        ((fail_count++))
    fi

    # Storage
    detect_storage
    if [[ ${AVAIL_STORAGE_GB:-0} -ge 10 ]]; then
        echo -e "  ${GREEN}✓${NC} Storage: ${AVAIL_STORAGE_GB}GB available"
        ((ok_count++))
    else
        echo -e "  ${RED}✗${NC} Storage: ${AVAIL_STORAGE_GB}GB (10GB minimum required)"
        ((fail_count++))
    fi

    # Network
    detect_network
    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} Network: connected"
        ((ok_count++))
    else
        echo -e "  ${RED}✗${NC} Network: not connected"
        ((fail_count++))
    fi

    # Model recommendation preview
    source "${GIH_HOME}/repo/lib/models.sh"
    echo ""
    echo -e "${BOLD}  Recommended Models (${TOTAL_RAM_GB}GB total / ${avail_gb}GB available):${NC}"
    local models
    models=$(recommend_models "${TOTAL_RAM_GB}")
    local model_id
    for model_id in $models; do
        if get_model_info "$model_id"; then
            local ram_status=""
            if [[ -n "$MODEL_RAM" ]] && command -v awk &>/dev/null; then
                local fits
                fits=$(awk "BEGIN { print (${avail_gb} >= ${MODEL_RAM}) ? 1 : 0 }")
                if [[ "$fits" == "0" ]]; then
                    ram_status=" ${RED}(insufficient RAM — needs ${MODEL_RAM}GB, ${avail_gb}GB available)${NC}"
                fi
            fi
            echo -e "    - ${MODEL_NAME} — ${MODEL_RAM}GB${ram_status}"
        fi
    done

    # Summary
    echo ""
    if [[ $fail_count -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}✗ ${fail_count} issue(s) found.${NC} Setup may not complete successfully."
    elif [[ $warn_count -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}⚠ Device compatible with limitations.${NC}"
    else
        echo -e "  ${GREEN}${BOLD}✓ Device fully compatible.${NC}"
    fi

    echo ""
    echo -e "${BOLD}  Next steps:${NC}"
    echo "    gih setup            # Start full installation"
    echo "    gih setup --lang ko  # Install in Korean"
    echo "    gih clear            # Clean up if needed"
    echo "    gih update           # Update later"
    echo ""
}

main "$@"
