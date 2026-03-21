#!/bin/bash
#
# Extra application configuration script
#
# Sets up:
# - GitHub CLI config
# - Espanso text expander config
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
# Setup Functions
# =============================================================================

setup_gh_config() {
    info "Setting up GitHub CLI configuration..."

    if [[ ! -f "$CONFIG_DIR/gh/config.yml" ]]; then
        warning "GitHub CLI config not found: $CONFIG_DIR/gh/config.yml"
        return 0
    fi

    create_symlink "$CONFIG_DIR/gh/config.yml" "$HOME/.config/gh/config.yml"

    success "GitHub CLI configuration set up"
}

setup_espanso_config() {
    info "Setting up Espanso configuration..."

    if [[ ! -d "$CONFIG_DIR/espanso" ]]; then
        warning "Espanso config directory not found: $CONFIG_DIR/espanso/"
        return 0
    fi

    # Symlink each config file from the espanso config directory
    for config_file in "$CONFIG_DIR/espanso"/*; do
        [[ ! -e "$config_file" ]] && continue

        local filename
        filename=$(basename "$config_file")
        create_symlink "$config_file" "$HOME/.config/espanso/$filename"
    done

    success "Espanso configuration set up"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up extra application configurations..."
    echo ""

    # Check if config directory exists
    if [[ ! -d "$CONFIG_DIR" ]]; then
        error "Config directory not found: $CONFIG_DIR"
        exit 1
    fi

    # Setup steps
    setup_gh_config
    setup_espanso_config

    echo ""
    success "Extra application configuration complete!"
    echo ""
}

main "$@"
