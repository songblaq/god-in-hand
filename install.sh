#!/usr/bin/env bash
# ============================================================================
#  God in Hand — Lightweight Bootstrap Installer
#  Downloads the CLI tool and creates a symlink. Run 'god-in-hand setup' after.
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

GIH_VERSION="0.2.1"
GIH_HOME="${HOME}/.god-in-hand"
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
            echo "Installs the God in Hand CLI. Run 'god-in-hand setup' afterwards."
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
    local cli_source="${GIH_HOME}/repo/bin/god-in-hand"

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

    local link_target="${prefix}/bin/god-in-hand"
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
    chmod +x "${GIH_HOME}/repo/bin/god-in-hand" 2>/dev/null || true
    chmod +x "${GIH_HOME}/repo/lib/"*.sh 2>/dev/null || true

    # Step 4: Success message
    echo ""
    echo -e "  ${GREEN}${BOLD}✓ God in Hand CLI installed.${NC}"
    echo ""
    echo "  Next step:"
    echo "    god-in-hand setup        # Full installation (Ollama, models, etc.)"
    echo ""
    echo "  Other commands:"
    echo "    god-in-hand setup --help  # See setup options"
    echo "    god-in-hand clear         # Clean up installation"
    echo "    god-in-hand update        # Update to latest version"
    echo "    god-in-hand health        # Run diagnostics"
    echo ""
}

main "$@"
