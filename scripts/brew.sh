#!/bin/bash
#
# Homebrew packages installation script
#
# This script installs packages from the Brewfile with support for
# different installation modes (minimal, full, interactive).
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
BREWFILE="$SCRIPT_DIR/Brewfile"
INSTALL_MODE="${INSTALL_MODE:-interactive}"
DRY_RUN="${DRY_RUN:-false}"

# =============================================================================
# Helper Functions
# =============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

retry() {
    local n=1
    local max=3
    local delay=5
    while true; do
        "$@" && break || {
            if [[ $n -lt $max ]]; then
                ((n++))
                warning "Command failed. Attempt $n/$max in ${delay}s..."
                sleep $delay
            else
                error "Command failed after $n attempts."
                return 1
            fi
        }
    done
}

brew_install() {
    local package=$1
    local type=${2:-formula}  # formula or cask

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would install $type: $package"
        return 0
    fi

    if [[ "$type" == "cask" ]]; then
        if brew list --cask "$package" &>/dev/null; then
            info "$package (cask) already installed"
        else
            info "Installing $package (cask)..."
            retry brew install --cask "$package"
        fi
    else
        if brew list "$package" &>/dev/null; then
            info "$package already installed"
        else
            info "Installing $package..."
            retry brew install "$package"
        fi
    fi
}

# =============================================================================
# Installation Functions
# =============================================================================

update_homebrew() {
    info "Updating Homebrew..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would update Homebrew"
        return 0
    fi

    retry brew update
    success "Homebrew updated"
}

install_essential_cli() {
    info "Installing essential CLI tools..."

    # Essential CLI tools
    local essential_formulas=(
        "git"
        "nano"
        "git-delta"
        "zoxide"
        "eza"
        "fnm"
        "fzf"
    )

    for formula in "${essential_formulas[@]}"; do
        brew_install "$formula" "formula"
    done

    success "Essential CLI tools installed"
}

install_terminal() {
    info "Installing terminal emulator..."

    brew_install "iterm2" "cask"

    success "Terminal emulator installed"
}

install_fonts() {
    info "Installing fonts..."

    # Ensure cask-fonts tap is available
    if [[ "$DRY_RUN" != true ]]; then
        brew tap homebrew/cask-fonts 2>/dev/null || true
    fi

    brew_install "font-meslo-lg-nerd-font" "cask"

    success "Fonts installed"
}

install_quicklook_plugins() {
    info "Installing Quick Look plugins..."

    local ql_plugins=(
        "qlcolorcode"
        "qlstephen"
        "qlmarkdown"
    )

    for plugin in "${ql_plugins[@]}"; do
        brew_install "$plugin" "cask"
    done

    # Reset Quick Look plugin cache
    if [[ "$DRY_RUN" != true ]]; then
        qlmanage -r &>/dev/null || true
        qlmanage -r cache &>/dev/null || true
    fi

    success "Quick Look plugins installed"
}

install_from_brewfile() {
    info "Installing from Brewfile..."

    if [[ ! -f "$BREWFILE" ]]; then
        error "Brewfile not found at $BREWFILE"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would run: brew bundle --file=$BREWFILE"
        return 0
    fi

    # Install all non-commented items from Brewfile
    retry brew bundle --file="$BREWFILE"

    success "Brewfile packages installed"
}

run_fzf_install() {
    # fzf requires a post-install script for key bindings
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would configure fzf key bindings"
        return 0
    fi

    local fzf_install
    fzf_install="$(brew --prefix)/opt/fzf/install"

    if [[ -f "$fzf_install" ]]; then
        info "Configuring fzf key bindings..."
        "$fzf_install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Starting Homebrew package installation..."
    echo ""

    # Update Homebrew first
    update_homebrew

    case "$INSTALL_MODE" in
        minimal)
            # Minimal: Just essential CLI tools
            install_essential_cli
            run_fzf_install
            ;;
        full)
            # Full: Everything from Brewfile
            install_from_brewfile
            run_fzf_install
            ;;
        interactive|*)
            # Interactive: Essential + terminal + fonts + QL plugins
            install_essential_cli
            install_terminal
            install_fonts
            install_quicklook_plugins
            run_fzf_install
            ;;
    esac

    # Cleanup
    if [[ "$DRY_RUN" != true ]]; then
        info "Cleaning up Homebrew..."
        brew cleanup -s 2>/dev/null || true
    fi

    echo ""
    success "Homebrew package installation complete!"
}

main "$@"
