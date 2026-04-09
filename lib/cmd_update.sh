#!/usr/bin/env bash
# ============================================================================
# God in Hand — Self-Update Command
# Update CLI and repository to latest version
#
# Usage:
#   god-in-hand update [OPTIONS]
#
# Options:
#   --no-color           Disable colored output
# ============================================================================

cmd_update() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-color) RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''; shift ;;
            --help|-h)
                echo "Usage: god-in-hand update [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --no-color           Disable colored output"
                return 0
                ;;
            *) shift ;;
        esac
    done

    echo ""
    echo -e "${BOLD}${CYAN}God in Hand — Self Update${NC}"
    echo ""

    local repo_dir="${GIH_REPO}"

    if [[ ! -d "$repo_dir" ]]; then
        print_fail "Repository not found at ${repo_dir}"
        echo "  Run the installer again to fix:"
        echo "    curl -sL https://raw.githubusercontent.com/songblaq/god-in-hand/main/install.sh | bash"
        return 1
    fi

    # Save current version
    local old_version="${GIH_VERSION}"

    # --- Update repo ---
    if [[ -d "${repo_dir}/.git" ]]; then
        print_info "Updating via git pull..."
        local pull_output
        if pull_output=$(cd "$repo_dir" && git pull --ff-only 2>&1); then
            if echo "$pull_output" | grep -q "Already up to date"; then
                print_ok "Already up to date (v${old_version})"
                echo ""
                return 0
            fi
            print_ok "Repository updated"
        else
            print_warn "git pull failed. Trying fresh download..."
            _update_via_tarball "$repo_dir" || return 1
        fi
    else
        # No git — re-download tarball
        print_info "Updating via tarball download..."
        _update_via_tarball "$repo_dir" || return 1
    fi

    # --- Read new version ---
    local new_version
    new_version=$(grep -oP 'GIH_VERSION="\K[^"]+' "${repo_dir}/install.sh" 2>/dev/null || echo "unknown")

    # --- Re-link CLI if needed ---
    local cli_source="${repo_dir}/bin/god-in-hand"
    if [[ -f "$cli_source" ]]; then
        chmod +x "$cli_source"

        # Determine PREFIX
        local prefix
        if [[ -d "/data/data/com.termux/files/usr" ]]; then
            prefix="/data/data/com.termux/files/usr"
        elif [[ -d "${HOME}/.local/bin" ]]; then
            prefix="${HOME}/.local"
        else
            prefix="/usr/local"
        fi

        local link_target="${prefix}/bin/god-in-hand"
        if [[ -L "$link_target" || -f "$link_target" ]]; then
            ln -sf "$cli_source" "$link_target" 2>/dev/null || true
        fi
        print_ok "CLI symlink verified"
    fi

    # --- Print result ---
    if [[ "$old_version" != "$new_version" && "$new_version" != "unknown" ]]; then
        echo ""
        echo -e "  ${GREEN}Updated: v${old_version} -> v${new_version}${NC}"
    else
        echo ""
        print_ok "Update complete (v${new_version})"
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# _update_via_tarball — Download and extract latest release
# ---------------------------------------------------------------------------
_update_via_tarball() {
    local repo_dir="$1"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    if ! curl -sL "https://github.com/songblaq/god-in-hand/archive/main.tar.gz" | tar -xz -C "$tmp_dir" --strip-components=1 2>/dev/null; then
        print_fail "Failed to download update"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Preserve .git if it exists
    if [[ -d "${repo_dir}/.git" ]]; then
        local git_backup
        git_backup=$(mktemp -d)
        mv "${repo_dir}/.git" "$git_backup/"
        rm -rf "$repo_dir"
        mv "$tmp_dir" "$repo_dir"
        mv "$git_backup/.git" "${repo_dir}/"
        rm -rf "$git_backup"
    else
        rm -rf "$repo_dir"
        mv "$tmp_dir" "$repo_dir"
    fi

    print_ok "Repository updated via tarball"
    return 0
}
