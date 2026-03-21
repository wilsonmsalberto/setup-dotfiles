#!/bin/bash
#
# Update script for dotfiles
#
# Pulls the latest changes and re-applies configurations.
#

set -e
set -u
set -o pipefail

# =============================================================================
# Logging
# =============================================================================

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# Update Functions
# =============================================================================

update_dotfiles_repo() {
    info "Updating dotfiles repository..."

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        warning "You have uncommitted changes in the dotfiles repository"
        read -r -p "Stash changes and continue? [y/N] " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            git stash
            info "Changes stashed"
        else
            error "Please commit or stash your changes first"
            exit 1
        fi
    fi

    # Pull latest changes
    git pull origin main || git pull origin master

    success "Dotfiles repository updated"
}

update_homebrew() {
    info "Updating Homebrew..."

    brew update
    brew upgrade

    info "Installing any new packages from Brewfile..."
    brew bundle --file="$SCRIPT_DIR/Brewfile" --no-lock || true

    # Cleanup
    brew cleanup -s

    success "Homebrew updated"
}

update_znap_plugins() {
    info "Updating zsh-snap plugins..."

    local znap_dir="$HOME/.zsh-plugins/zsh-snap"
    if [[ -d "$znap_dir" ]]; then
        cd "$znap_dir"
        git pull --quiet
        cd "$SCRIPT_DIR"
        success "zsh-snap updated"
    else
        warning "zsh-snap not found, run ./scripts/shell.sh to install"
    fi

    # Note: znap plugins are updated when zsh starts
    info "Plugin updates will be applied on next shell restart"
}

update_node() {
    info "Checking for Node.js updates..."

    if command -v fnm &>/dev/null; then
        eval "$(fnm env --shell bash)"

        # Install latest LTS if not already installed
        fnm install --lts
        fnm default lts-latest

        success "Node.js LTS checked/updated"
    else
        warning "fnm not found, skipping Node.js update"
    fi
}

reapply_symlinks() {
    info "Re-applying symlinks..."

    local config_dir="$SCRIPT_DIR/config"

    # Shell & Git symlinks
    ln -sf "$config_dir/zshrc" "$HOME/.zshrc"
    ln -sf "$config_dir/zprofile" "$HOME/.zprofile"
    ln -sf "$config_dir/zsh-functions" "$HOME/.zsh-functions"
    ln -sf "$config_dir/p10k.zsh" "$HOME/.p10k.zsh"
    ln -sf "$config_dir/gitconfig" "$HOME/.gitconfig"
    ln -sf "$config_dir/gitignore_global" "$HOME/.gitignore_global"
    ln -sf "$config_dir/editorconfig" "$HOME/.editorconfig"

    # Claude Code symlinks (global tier)
    if [[ -d "$config_dir/claude-code/global" ]]; then
        ln -sf "$config_dir/claude-code/global/CLAUDE.md" "$HOME/.claude/CLAUDE.md" 2>/dev/null || true
        ln -sf "$config_dir/claude-code/global/mcp.json" "$HOME/.claude/.mcp.json" 2>/dev/null || true
        for hook in "$config_dir/claude-code/global/hooks/"*; do
            [[ -f "$hook" ]] && ln -sf "$hook" "$HOME/.claude/hooks/$(basename "$hook")" 2>/dev/null || true
        done
        for rule in "$config_dir/claude-code/global/rules/"*; do
            [[ -f "$rule" ]] && ln -sf "$rule" "$HOME/.claude/rules/$(basename "$rule")" 2>/dev/null || true
        done
    fi

    # Cursor symlinks
    if [[ -d "$config_dir/cursor" ]]; then
        local cursor_user_dir="$HOME/Library/Application Support/Cursor/User"
        if [[ -d "$cursor_user_dir" ]]; then
            ln -sf "$config_dir/cursor/settings.json" "$cursor_user_dir/settings.json" 2>/dev/null || true
            ln -sf "$config_dir/cursor/keybindings.json" "$cursor_user_dir/keybindings.json" 2>/dev/null || true
        fi
    fi

    # iTerm2 symlink
    if [[ -f "$config_dir/iterm2/profile.json" ]]; then
        local dyn_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
        if [[ -d "$dyn_dir" ]]; then
            ln -sf "$config_dir/iterm2/profile.json" "$dyn_dir/dotfiles-profile.json" 2>/dev/null || true
        fi
    fi

    # GH CLI symlink
    if [[ -f "$config_dir/gh/config.yml" ]]; then
        ln -sf "$config_dir/gh/config.yml" "$HOME/.config/gh/config.yml" 2>/dev/null || true
    fi

    success "Symlinks updated"
}

update_claude_code() {
    info "Updating Claude Code configuration..."

    # Re-run the claude-code script (it handles symlinks + plugin install)
    if [[ -f "$SCRIPT_DIR/scripts/claude-code.sh" ]]; then
        bash "$SCRIPT_DIR/scripts/claude-code.sh"
    fi

    success "Claude Code updated"
}

update_cursor() {
    info "Updating Cursor extensions..."

    if command -v cursor &>/dev/null; then
        # Export current extensions
        if [[ -f "$SCRIPT_DIR/scripts/cursor.sh" ]]; then
            bash "$SCRIPT_DIR/scripts/cursor.sh"
        fi
    else
        warning "Cursor CLI not found, skipping"
    fi

    success "Cursor updated"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  Dotfiles Update"
    echo "=============================================="
    echo ""

    # Parse arguments
    local update_all=false
    local update_repo=true
    local update_brew=false
    local update_plugins=false
    local update_node_flag=false
    local update_claude_flag=false
    local update_cursor_flag=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                update_all=true
                shift
                ;;
            --brew)
                update_brew=true
                shift
                ;;
            --plugins)
                update_plugins=true
                shift
                ;;
            --node)
                update_node_flag=true
                shift
                ;;
            --claude)
                update_claude_flag=true
                shift
                ;;
            --cursor)
                update_cursor_flag=true
                shift
                ;;
            --no-pull)
                update_repo=false
                shift
                ;;
            --help|-h)
                echo "Usage: ./update.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all       Update everything"
                echo "  --brew      Update Homebrew packages"
                echo "  --plugins   Update zsh-snap plugins"
                echo "  --node      Update Node.js to latest LTS"
                echo "  --claude    Update Claude Code config + plugins"
                echo "  --cursor    Update Cursor settings + extensions"
                echo "  --no-pull   Skip git pull"
                echo "  --help      Show this help"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # If --all flag, enable everything
    if [[ "$update_all" == true ]]; then
        update_brew=true
        update_plugins=true
        update_node_flag=true
        update_claude_flag=true
        update_cursor_flag=true
    fi

    # Run updates
    if [[ "$update_repo" == true ]]; then
        update_dotfiles_repo
        echo ""
    fi

    reapply_symlinks
    echo ""

    if [[ "$update_brew" == true ]]; then
        update_homebrew
        echo ""
    fi

    if [[ "$update_plugins" == true ]]; then
        update_znap_plugins
        echo ""
    fi

    if [[ "$update_node_flag" == true ]]; then
        update_node
        echo ""
    fi

    if [[ "$update_claude_flag" == true ]]; then
        update_claude_code
        echo ""
    fi

    if [[ "$update_cursor_flag" == true ]]; then
        update_cursor
        echo ""
    fi

    echo "=============================================="
    success "Update complete!"
    echo "=============================================="
    echo ""
    info "Restart your terminal or run: source ~/.zshrc"
    echo ""
}

main "$@"
