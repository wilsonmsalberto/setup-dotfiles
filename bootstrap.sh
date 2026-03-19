#!/bin/bash
#
# Bootstrap script for macOS dotfiles
# This script installs the minimum requirements to run the full setup:
# - Xcode Command Line Tools
# - Homebrew
# - Git (via Homebrew)
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/wilsonmsalberto/setup-dotfiles/main/bootstrap.sh)"
#

set -e
set -u
set -o pipefail

# =============================================================================
# Configuration
# =============================================================================

DOTFILES_REPO="https://github.com/wilsonmsalberto/setup-dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# =============================================================================
# Logging Functions
# =============================================================================

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# =============================================================================
# Error Handling
# =============================================================================

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        error "Bootstrap failed with exit code $exit_code"
        echo ""
        echo "Please check the error messages above and try again."
        echo "If the issue persists, please report it at:"
        echo "  https://github.com/wilsonmsalberto/setup-dotfiles/issues"
    fi
}
trap cleanup EXIT

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

# =============================================================================
# System Checks
# =============================================================================

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script is intended for macOS only."
        exit 1
    fi
    success "Running on macOS"
}

check_apple_silicon() {
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        success "Running on Apple Silicon (arm64)"
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        warning "Running on Intel ($arch) - Some paths may differ"
        HOMEBREW_PREFIX="/usr/local"
    fi
}

check_rosetta() {
    if [[ "$(uname -m)" == "arm64" ]]; then
        if ! /usr/bin/pgrep -q oahd; then
            info "Installing Rosetta 2 for Intel compatibility..."
            softwareupdate --install-rosetta --agree-to-license || {
                warning "Rosetta 2 installation failed (may not be needed)"
            }
        else
            success "Rosetta 2 is already installed"
        fi
    fi
}

# =============================================================================
# Installation Functions
# =============================================================================

install_xcode_cli_tools() {
    if xcode-select -p &>/dev/null; then
        success "Xcode Command Line Tools already installed"
        return 0
    fi

    info "Installing Xcode Command Line Tools..."

    # Create a temporary file to signal installation
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

    # Find the latest Command Line Tools package
    local cli_tools
    cli_tools=$(softwareupdate -l 2>/dev/null | \
        grep -B 1 -E "Command Line Tools" | \
        awk -F"*" '/^ *\*/ {print $2}' | \
        sed -e 's/^ *Label: //' -e 's/^ *//' | \
        sort -V | \
        tail -n1)

    if [[ -n "$cli_tools" ]]; then
        info "Found: $cli_tools"
        retry softwareupdate -i "$cli_tools" --verbose
    else
        # Fallback: trigger the GUI installer
        warning "Could not find CLI Tools via softwareupdate, triggering GUI installer..."
        xcode-select --install 2>/dev/null || true

        echo ""
        echo "=============================================="
        echo "  Please complete the installation in the"
        echo "  dialog that appeared, then run this script"
        echo "  again."
        echo "=============================================="
        echo ""

        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        exit 0
    fi

    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

    # Verify installation
    if xcode-select -p &>/dev/null; then
        success "Xcode Command Line Tools installed successfully"
    else
        error "Xcode Command Line Tools installation failed"
        exit 1
    fi
}

install_homebrew() {
    if command_exists brew; then
        success "Homebrew already installed"
        return 0
    fi

    info "Installing Homebrew..."

    # Install Homebrew non-interactively
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session
    if [[ -f "$HOMEBREW_PREFIX/bin/brew" ]]; then
        eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
        success "Homebrew installed successfully"
    else
        error "Homebrew installation failed"
        exit 1
    fi
}

configure_homebrew_path() {
    # Ensure Homebrew is in PATH for this session
    if [[ -f "$HOMEBREW_PREFIX/bin/brew" ]]; then
        eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
        success "Homebrew added to PATH"
    fi
}

install_git() {
    if command_exists git; then
        local git_path
        git_path=$(which git)
        if [[ "$git_path" == "$HOMEBREW_PREFIX/bin/git" ]]; then
            success "Git already installed via Homebrew"
            return 0
        fi
    fi

    info "Installing Git via Homebrew..."
    retry brew install git
    success "Git installed successfully"
}

clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR" ]]; then
        warning "Dotfiles directory already exists at $DOTFILES_DIR"
        info "Pulling latest changes..."
        cd "$DOTFILES_DIR"
        git pull origin main || git pull origin master || true
        return 0
    fi

    info "Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    success "Dotfiles cloned to $DOTFILES_DIR"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  macOS Dotfiles Bootstrap"
    echo "=============================================="
    echo ""

    # Pre-flight checks
    check_macos
    check_apple_silicon

    echo ""
    info "Starting bootstrap process..."
    echo ""

    # Install dependencies
    check_rosetta
    install_xcode_cli_tools
    install_homebrew
    configure_homebrew_path
    install_git

    echo ""

    # Check if we should clone the repo
    # Skip if running from within the repo already
    if [[ -f "./install.sh" ]] && [[ -f "./Brewfile" ]]; then
        info "Running from within dotfiles directory"
        DOTFILES_DIR="$(pwd)"
    else
        clone_dotfiles
    fi

    echo ""
    echo "=============================================="
    success "Bootstrap complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. cd $DOTFILES_DIR"
    echo ""
    echo "  2. Run the setup wizard:"
    echo "     ./setup.sh"
    echo ""
    echo "  Or run installation directly:"
    echo "     ./install.sh              # Interactive mode"
    echo "     ./install.sh --minimal    # CLI tools only"
    echo "     ./install.sh --full       # Everything"
    echo ""
    echo "  3. Restart your terminal or run:"
    echo "     source ~/.zshrc"
    echo ""
}

main "$@"
