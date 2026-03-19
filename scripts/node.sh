#!/bin/bash
#
# Node.js setup script
#
# Sets up Node.js via fnm (Fast Node Manager) with LTS version
# and optionally installs global npm packages.
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

DRY_RUN="${DRY_RUN:-false}"
INSTALL_MODE="${INSTALL_MODE:-interactive}"

# Global packages to install
ESSENTIAL_PACKAGES=(
    "pnpm"
)

OPTIONAL_PACKAGES=(
    "typescript"
    "ts-node"
    "npm-check-updates"
)

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

setup_fnm_for_script() {
    # Initialize fnm for this script if not already done
    if command_exists fnm; then
        eval "$(fnm env --shell bash)"
    fi
}

# =============================================================================
# Installation Functions
# =============================================================================

check_fnm() {
    if ! command_exists fnm; then
        error "fnm is not installed. Please run brew.sh first."
        exit 1
    fi
    success "fnm is installed"
}

install_node_lts() {
    info "Installing Node.js LTS version..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would install Node.js LTS"
        return 0
    fi

    setup_fnm_for_script

    # Install LTS version
    retry fnm install --lts

    # Set as default
    fnm default lts-latest

    # Use it now
    fnm use lts-latest

    success "Node.js LTS installed and set as default"

    # Show version
    local node_version
    node_version=$(node --version 2>/dev/null || echo "unknown")
    local npm_version
    npm_version=$(npm --version 2>/dev/null || echo "unknown")
    info "Node.js: $node_version"
    info "npm: $npm_version"
}

install_global_packages() {
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    info "Installing global npm packages..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would install: ${packages[*]}"
        return 0
    fi

    setup_fnm_for_script

    for package in "${packages[@]}"; do
        if npm list -g "$package" &>/dev/null; then
            info "$package already installed globally"
        else
            info "Installing $package..."
            retry npm install -g "$package"
        fi
    done

    success "Global packages installed"
}

configure_npm() {
    info "Configuring npm..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would configure npm settings"
        return 0
    fi

    setup_fnm_for_script

    # Set npm to save exact versions by default
    npm config set save-exact true 2>/dev/null || true

    # Set default init values (optional)
    # npm config set init-author-name "Your Name"
    # npm config set init-license "MIT"

    success "npm configured"
}

show_installed_versions() {
    echo ""
    info "Installed versions:"
    echo ""

    setup_fnm_for_script

    if command_exists node; then
        echo "  Node.js: $(node --version)"
    fi

    if command_exists npm; then
        echo "  npm: $(npm --version)"
    fi

    if command_exists pnpm; then
        echo "  pnpm: $(pnpm --version)"
    fi

    if command_exists fnm; then
        echo "  fnm: $(fnm --version)"
    fi

    echo ""
}

ask_optional_packages() {
    if [[ "$INSTALL_MODE" != "interactive" ]]; then
        return 1
    fi

    echo ""
    echo "Optional global packages available:"
    echo ""
    for i in "${!OPTIONAL_PACKAGES[@]}"; do
        echo "  $((i+1)). ${OPTIONAL_PACKAGES[$i]}"
    done
    echo ""

    read -r -p "Install optional packages? [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]]
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up Node.js development environment..."
    echo ""

    # Check prerequisites
    check_fnm

    # Install Node.js LTS
    install_node_lts
    echo ""

    # Configure npm
    configure_npm
    echo ""

    # Install essential packages (always)
    install_global_packages "${ESSENTIAL_PACKAGES[@]}"

    # Install optional packages (based on mode)
    case "$INSTALL_MODE" in
        full)
            install_global_packages "${OPTIONAL_PACKAGES[@]}"
            ;;
        interactive)
            if ask_optional_packages; then
                install_global_packages "${OPTIONAL_PACKAGES[@]}"
            fi
            ;;
        *)
            # minimal - skip optional packages
            ;;
    esac

    # Show summary
    show_installed_versions

    success "Node.js setup complete!"
    echo ""
    info "fnm will automatically switch Node versions when you enter"
    info "directories with .node-version or .nvmrc files."
    echo ""
}

main "$@"
