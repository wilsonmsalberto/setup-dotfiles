#!/bin/bash
#
# Shell configuration script
#
# This script sets up Zsh with:
# - zsh-snap plugin manager
# - Powerlevel10k theme
# - Various plugins and configurations
#

set -e
set -u
set -o pipefail

# =============================================================================
# Logging (inherit from parent or define)
# =============================================================================

if ! declare -f info >/dev/null 2>&1; then
    info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
    success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
    warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
    error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
fi

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_DIR="${CONFIG_DIR:-$SCRIPT_DIR/config}"
DRY_RUN="${DRY_RUN:-false}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"

ZNAP_DIR="$HOME/.zsh-plugins/zsh-snap"

# =============================================================================
# Helper Functions
# =============================================================================

backup_file() {
    local file=$1
    if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        local filename
        filename=$(basename "$file")
        cp -a "$file" "$BACKUP_DIR/$filename"
        info "Backed up $file to $BACKUP_DIR/$filename"
    fi
}

create_symlink() {
    local source=$1
    local target=$2

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would symlink $source -> $target"
        return 0
    fi

    backup_file "$target"
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    info "Created symlink: $target -> $source"
}

# =============================================================================
# Installation Functions
# =============================================================================

install_znap() {
    info "Installing zsh-snap plugin manager..."

    if [[ -d "$ZNAP_DIR" ]]; then
        info "zsh-snap already installed, updating..."
        if [[ "$DRY_RUN" != true ]]; then
            cd "$ZNAP_DIR" && git pull --quiet
        fi
    else
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would clone zsh-snap to $ZNAP_DIR"
        else
            mkdir -p "$(dirname "$ZNAP_DIR")"
            git clone --depth 1 https://github.com/marlonrichert/zsh-snap.git "$ZNAP_DIR"
        fi
    fi

    success "zsh-snap installed"
}

setup_zsh_config() {
    info "Setting up Zsh configuration files..."

    # Create symlinks for config files
    create_symlink "$CONFIG_DIR/zshrc" "$HOME/.zshrc"
    create_symlink "$CONFIG_DIR/zprofile" "$HOME/.zprofile"
    create_symlink "$CONFIG_DIR/zsh-functions" "$HOME/.zsh-functions"
    create_symlink "$CONFIG_DIR/p10k.zsh" "$HOME/.p10k.zsh"

    success "Zsh configuration files set up"
}

set_default_shell() {
    info "Checking default shell..."

    local zsh_path
    zsh_path=$(which zsh)

    if [[ "$SHELL" == "$zsh_path" ]]; then
        info "Zsh is already the default shell"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would set default shell to $zsh_path"
        return 0
    fi

    # Add Homebrew zsh to allowed shells if not present
    local brew_zsh
    brew_zsh="$(brew --prefix)/bin/zsh"

    if [[ -f "$brew_zsh" ]]; then
        if ! grep -q "$brew_zsh" /etc/shells; then
            info "Adding Homebrew Zsh to /etc/shells..."
            echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
        fi

        info "Setting Homebrew Zsh as default shell..."
        chsh -s "$brew_zsh"
        success "Default shell changed to Homebrew Zsh"
    else
        # Use system zsh
        if ! grep -q "$zsh_path" /etc/shells; then
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi
        chsh -s "$zsh_path"
        success "Default shell changed to Zsh"
    fi
}

create_zsh_directories() {
    info "Creating Zsh directories..."

    local dirs=(
        "$HOME/.zsh-plugins"
        "$HOME/.cache/zsh"
    )

    for dir in "${dirs[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would create $dir"
        else
            mkdir -p "$dir"
        fi
    done

    success "Zsh directories created"
}

configure_fzf() {
    info "Configuring fzf..."

    local fzf_install
    fzf_install="$(brew --prefix 2>/dev/null)/opt/fzf/install"

    if [[ -f "$fzf_install" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would run fzf install script"
        else
            # Install fzf key bindings and completion (zsh only)
            "$fzf_install" --key-bindings --completion --no-update-rc --no-bash --no-fish
        fi
        success "fzf configured"
    else
        warning "fzf not found, skipping configuration"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up shell configuration..."
    echo ""

    # Check if config directory exists
    if [[ ! -d "$CONFIG_DIR" ]]; then
        error "Config directory not found: $CONFIG_DIR"
        exit 1
    fi

    # Setup steps
    create_zsh_directories
    install_znap
    setup_zsh_config
    configure_fzf
    set_default_shell

    echo ""
    success "Shell configuration complete!"
    echo ""
    info "Please restart your terminal or run: source ~/.zshrc"
    info "On first run, Powerlevel10k will prompt you to configure the theme."
    echo ""
}

main "$@"
