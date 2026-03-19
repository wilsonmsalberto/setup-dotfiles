#!/bin/bash
#
# Uninstall script for dotfiles
#
# Reverts changes made by the installation:
# - Removes symlinks
# - Restores backed-up files
# - Optionally removes installed packages
#

set -e
set -u
set -o pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="$HOME/.dotfiles_backup"

# =============================================================================
# Source common library if available
# =============================================================================

if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
    success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
    warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
    error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
fi

# Files that were symlinked
SYMLINKED_FILES=(
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.zsh-functions"
    "$HOME/.p10k.zsh"
    "$HOME/.gitconfig"
    "$HOME/.gitignore_global"
    "$HOME/.editorconfig"
)

# =============================================================================
# Helper Functions
# =============================================================================

remove_symlink() {
    local file=$1

    if [[ -L "$file" ]]; then
        rm "$file"
        info "Removed symlink: $file"
    elif [[ -e "$file" ]]; then
        warning "$file exists but is not a symlink"
    fi
}

find_latest_backup() {
    local filename=$1

    # Find the most recent backup directory
    local latest_dir
    latest_dir=$(ls -1dt "$BACKUP_BASE_DIR"/*/ 2>/dev/null | head -n1)

    if [[ -n "$latest_dir" ]] && [[ -f "$latest_dir/$filename" ]]; then
        echo "$latest_dir/$filename"
    else
        # Fallback: search all backup directories
        find "$BACKUP_BASE_DIR" -name "$filename" -type f 2>/dev/null | sort -r | head -n1
    fi
}

restore_from_manifest() {
    local backup_dir=$1

    if [[ -f "$backup_dir/.manifest" ]]; then
        info "Restoring from manifest..."
        while IFS= read -r original_path; do
            local filename
            filename=$(basename "$original_path")
            if [[ -f "$backup_dir/$filename" ]]; then
                cp -a "$backup_dir/$filename" "$original_path"
                success "Restored: $original_path"
            fi
        done < "$backup_dir/.manifest"
        return 0
    fi
    return 1
}

restore_backup() {
    local file=$1
    local filename
    filename=$(basename "$file")

    local backup_file
    backup_file=$(find_latest_backup "$filename")

    if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$file"
        success "Restored $file from backup"
    else
        info "No backup found for $filename"
    fi
}

# =============================================================================
# Uninstall Functions
# =============================================================================

remove_symlinks() {
    info "Removing symlinks..."

    for file in "${SYMLINKED_FILES[@]}"; do
        remove_symlink "$file"
    done

    success "Symlinks removed"
}

restore_backups() {
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        info "No backup directory found"
        return 0
    fi

    echo ""
    info "Available backup directories:"
    ls -1t "$BACKUP_BASE_DIR" 2>/dev/null || echo "  (none)"
    echo ""

    read -r -p "Restore from backups? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        info "Skipping backup restoration"
        return 0
    fi

    # Find the most recent backup directory
    local latest_dir
    latest_dir=$(ls -1dt "$BACKUP_BASE_DIR"/*/ 2>/dev/null | head -n1)

    if [[ -n "$latest_dir" ]]; then
        info "Using most recent backup: $(basename "$latest_dir")"

        # Try manifest-based restore first
        if restore_from_manifest "$latest_dir"; then
            success "Backups restored from manifest"
            return 0
        fi
    fi

    # Fall back to file-by-file restore
    info "Restoring files individually..."
    for file in "${SYMLINKED_FILES[@]}"; do
        restore_backup "$file"
    done

    success "Backups restored"
}

remove_znap() {
    local znap_dir="$HOME/.zsh-plugins"

    if [[ -d "$znap_dir" ]]; then
        read -r -p "Remove zsh-snap and plugins ($znap_dir)? [y/N] " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            rm -rf "$znap_dir"
            success "zsh-snap removed"
        else
            info "Keeping zsh-snap"
        fi
    fi
}

remove_directories() {
    echo ""
    info "The following directories were created by the installer:"
    echo "  - $HOME/Screenshots"
    echo "  - $HOME/Developer"
    echo "  - $HOME/Work"
    echo ""

    read -r -p "Remove these directories? [y/N] " answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        warning "This will delete any files in these directories!"
        read -r -p "Are you sure? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy] ]]; then
            rm -rf "$HOME/Screenshots" 2>/dev/null || true
            rm -rf "$HOME/Developer" 2>/dev/null || true
            rm -rf "$HOME/Work" 2>/dev/null || true
            success "Directories removed"
        fi
    else
        info "Keeping directories"
    fi
}

reset_shell() {
    read -r -p "Reset default shell to /bin/zsh? [y/N] " answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        chsh -s /bin/zsh
        success "Default shell reset to /bin/zsh"
    fi
}

show_homebrew_info() {
    echo ""
    info "Homebrew packages were NOT removed."
    echo ""
    echo "To remove Homebrew packages installed by dotfiles, run:"
    echo ""
    echo "  # Remove all packages from Brewfile"
    echo "  brew bundle cleanup --file=$SCRIPT_DIR/Brewfile --force"
    echo ""
    echo "  # Or remove specific packages"
    echo "  brew uninstall <package>"
    echo ""
    echo "  # To completely remove Homebrew:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
    echo ""
}

reset_macos_defaults() {
    echo ""
    read -r -p "Reset macOS defaults to system defaults? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        info "Keeping macOS defaults"
        return 0
    fi

    info "Resetting macOS defaults..."

    # Keyboard
    defaults delete -g InitialKeyRepeat 2>/dev/null || true
    defaults delete -g KeyRepeat 2>/dev/null || true
    defaults delete -g ApplePressAndHoldEnabled 2>/dev/null || true

    # Finder
    defaults delete com.apple.finder AppleShowAllFiles 2>/dev/null || true
    defaults delete com.apple.finder _FXShowPosixPathInTitle 2>/dev/null || true
    defaults delete com.apple.finder FXDefaultSearchScope 2>/dev/null || true
    defaults delete -g AppleShowAllExtensions 2>/dev/null || true
    defaults delete com.apple.finder _FXSortFoldersFirst 2>/dev/null || true

    # Text input
    defaults delete -g NSAutomaticSpellingCorrectionEnabled 2>/dev/null || true
    defaults delete -g NSAutomaticQuoteSubstitutionEnabled 2>/dev/null || true
    defaults delete -g NSAutomaticDashSubstitutionEnabled 2>/dev/null || true
    defaults delete -g NSAutomaticCapitalizationEnabled 2>/dev/null || true

    # Screenshots
    defaults delete com.apple.screencapture location 2>/dev/null || true
    defaults delete com.apple.screencapture disable-shadow 2>/dev/null || true

    # Dock
    defaults delete com.apple.dock autohide-delay 2>/dev/null || true
    defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
    defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true

    # Animations
    defaults delete -g NSAutomaticWindowAnimationsEnabled 2>/dev/null || true
    defaults delete -g NSWindowResizeTime 2>/dev/null || true

    # Restart affected apps
    killall Finder Dock SystemUIServer 2>/dev/null || true

    success "macOS defaults reset"
    warning "Some changes may require a logout/restart to fully revert"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  Dotfiles Uninstaller"
    echo "=============================================="
    echo ""
    warning "This will remove dotfiles configurations."
    echo ""
    read -r -p "Continue? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        info "Uninstall cancelled"
        exit 0
    fi

    echo ""

    # Remove symlinks
    remove_symlinks
    echo ""

    # Restore backups
    restore_backups
    echo ""

    # Remove zsh-snap
    remove_znap
    echo ""

    # Reset shell
    reset_shell
    echo ""

    # Reset macOS defaults
    reset_macos_defaults

    # Remove directories (optional)
    remove_directories

    # Show Homebrew info
    show_homebrew_info

    echo "=============================================="
    success "Uninstall complete!"
    echo "=============================================="
    echo ""
    info "Please restart your terminal for changes to take effect."
    echo ""
}

main "$@"
