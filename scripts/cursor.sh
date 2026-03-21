#!/bin/bash
#
# Cursor Editor configuration script
#
# Sets up Cursor settings, keybindings, and extensions.
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

CURSOR_APP="/Applications/Cursor.app"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
CURSOR_CONFIG_DIR="$CONFIG_DIR/cursor"

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
# Configuration Functions
# =============================================================================

check_cursor_installed() {
    info "Checking for Cursor installation..."

    if [[ ! -d "$CURSOR_APP" ]]; then
        warning "Cursor.app not found at $CURSOR_APP"
        warning "Please install Cursor from https://cursor.sh"
        return 1
    fi

    info "Cursor.app found"

    if ! command -v cursor >/dev/null 2>&1; then
        warning "Cursor CLI not found in PATH"
        warning "To install it, open Cursor and run:"
        warning "  Cmd+Shift+P -> 'Shell Command: Install cursor command in PATH'"
    else
        info "Cursor CLI available"
    fi

    return 0
}

setup_cursor_settings() {
    info "Setting up Cursor settings..."

    # Symlink settings.json
    create_symlink "$CURSOR_CONFIG_DIR/settings.json" "$CURSOR_USER_DIR/settings.json"

    # Symlink keybindings.json
    create_symlink "$CURSOR_CONFIG_DIR/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"

    success "Cursor settings and keybindings linked"
}

install_cursor_extensions() {
    local extensions_file="$CURSOR_CONFIG_DIR/extensions.txt"

    if [[ ! -f "$extensions_file" ]]; then
        warning "Extensions file not found: $extensions_file"
        return 0
    fi

    if ! command -v cursor >/dev/null 2>&1; then
        warning "Cursor CLI not available, skipping extension installation"
        warning "Install extensions manually or install the Cursor CLI first"
        return 0
    fi

    info "Installing Cursor extensions..."

    local installed=0
    local skipped=0

    while IFS= read -r extension || [[ -n "$extension" ]]; do
        # Skip empty lines and comments
        [[ -z "$extension" ]] && continue
        [[ "$extension" =~ ^# ]] && continue

        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would install extension: $extension"
            ((installed++))
            continue
        fi

        if cursor --install-extension "$extension" 2>/dev/null || true; then
            ((installed++))
        else
            ((skipped++))
        fi
    done < "$extensions_file"

    success "Extensions complete: $installed processed, $skipped skipped"
}

export_cursor_extensions() {
    local extensions_file="$CURSOR_CONFIG_DIR/extensions.txt"

    if ! command -v cursor >/dev/null 2>&1; then
        error "Cursor CLI not available. Cannot export extensions."
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would export extensions to $extensions_file"
        return 0
    fi

    info "Exporting Cursor extensions..."

    cursor --list-extensions > "$extensions_file"

    local count
    count=$(wc -l < "$extensions_file" | tr -d ' ')

    success "Exported $count extensions to $extensions_file"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up Cursor Editor configuration..."
    echo ""

    # Check for Cursor
    if ! check_cursor_installed; then
        error "Cursor is not installed. Please install it first."
        exit 1
    fi

    # Setup steps
    setup_cursor_settings

    # Install extensions only if CLI is available
    if command -v cursor >/dev/null 2>&1; then
        install_cursor_extensions
    fi

    echo ""
    success "Cursor configuration complete!"
    echo ""
}

main "$@"
