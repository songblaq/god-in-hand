#!/usr/bin/env bash
# ============================================================================
# God in Hand — Clear/Cleanup Command
# Remove previous installation data, stop services, fix broken state
#
# Usage:
#   god-in-hand clear [OPTIONS]
#
# Options:
#   --force              Skip confirmation prompts
#   --keep-models        Keep downloaded models
#   --no-color           Disable colored output
# ============================================================================

cmd_clear() {
    local force=false
    local keep_models=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)       force=true; shift ;;
            --keep-models) keep_models=true; shift ;;
            --no-color)    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''; shift ;;
            --help|-h)
                echo "Usage: god-in-hand clear [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force              Skip confirmation prompts"
                echo "  --keep-models        Keep downloaded models"
                echo "  --no-color           Disable colored output"
                return 0
                ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${BOLD}${CYAN}God in Hand — Cleanup${NC}"
    echo ""

    # Confirm unless --force
    if ! $force; then
        echo -e "  ${YELLOW}This will remove God in Hand installation data.${NC}"
        echo -e "  ${YELLOW}The CLI tool itself will remain installed.${NC}"
        echo ""
        echo -ne "  Continue? [y/N] "
        local answer
        read -r answer
        if [[ "${answer,,}" != "y" && "${answer,,}" != "yes" ]]; then
            echo "  Aborted."
            return 0
        fi
    fi

    # --- Stop services ---
    print_info "Stopping services..."
    if pgrep -x "ollama" >/dev/null 2>&1; then
        pkill -x "ollama" 2>/dev/null || true
        print_ok "Ollama stopped"
    else
        print_info "Ollama not running"
    fi

    if pgrep -f "openclaw" >/dev/null 2>&1; then
        pkill -f "openclaw" 2>/dev/null || true
        print_ok "OpenClaw stopped"
    else
        print_info "OpenClaw not running"
    fi

    # --- Fix broken dpkg state ---
    if command -v dpkg &>/dev/null; then
        print_info "Fixing package manager state..."
        dpkg --configure -a --force-confnew </dev/null 2>/dev/null || true
        print_ok "Package manager state cleaned"
    fi

    # --- Clean stale locks ---
    if [[ -d "${GIH_HOME}" ]]; then
        local lock_count=0
        while IFS= read -r -d '' lock; do
            rm -f "$lock"
            ((lock_count++))
        done < <(find "${GIH_HOME}" -name "*.lock" -print0 2>/dev/null)
        if [[ $lock_count -gt 0 ]]; then
            print_ok "Cleaned ${lock_count} stale lock(s)"
        fi
    fi

    # --- Remove models (optional) ---
    if ! $keep_models; then
        if [[ -d "${GIH_HOME}/models" ]]; then
            local model_size
            model_size=$(du -sh "${GIH_HOME}/models" 2>/dev/null | cut -f1)
            if $force; then
                rm -rf "${GIH_HOME}/models"
                print_ok "Removed downloaded models (${model_size})"
            else
                echo -ne "  Remove downloaded models (${model_size})? [y/N] "
                local rm_answer
                read -r rm_answer
                if [[ "${rm_answer,,}" == "y" || "${rm_answer,,}" == "yes" ]]; then
                    rm -rf "${GIH_HOME}/models"
                    print_ok "Removed downloaded models"
                else
                    print_info "Keeping models"
                fi
            fi
        fi
    fi

    # --- Remove installation data (preserve repo) ---
    if [[ -d "${GIH_HOME}" ]]; then
        print_info "Removing installation data..."
        # Remove everything except the repo directory itself
        find "${GIH_HOME}" -mindepth 1 -maxdepth 1 -not -name "repo" -exec rm -rf {} + 2>/dev/null
        print_ok "Installation data removed"
    fi

    # --- Remove boot script ---
    if [[ -f "$HOME/.termux/boot/god-in-hand.sh" ]]; then
        rm -f "$HOME/.termux/boot/god-in-hand.sh"
        print_ok "Removed auto-start script"
    fi

    echo ""
    echo -e "  ${GREEN}Cleanup complete.${NC}"
    echo "  Run 'god-in-hand setup' to reinstall."
    echo ""
}
