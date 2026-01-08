#!/bin/bash
#
# Optional GUI applications installation script
#
# Interactive script for installing optional GUI applications.
# Note: Apps you already have installed are marked and won't be reinstalled.
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

# =============================================================================
# Application Categories
# Note: Only apps NOT already installed on your machine
# =============================================================================

declare -A MENU_BAR_UTILITIES=(
    ["caffeine"]="Prevent Mac from sleeping"
    ["notunes"]="Prevent iTunes/Music from opening"
)

declare -A DEV_TOOLS=(
    ["postman"]="API development platform"
    ["tableplus"]="Database GUI client"
)

declare -A BROWSERS=(
    ["arc"]="Arc browser"
)

declare -A COMMUNICATION=(
    ["discord"]="Voice and text chat"
)

declare -A PRODUCTIVITY=(
    ["notion"]="Notes and docs"
    ["obsidian"]="Markdown knowledge base"
)

declare -A MEDIA=(
    ["vlc"]="Media player"
)

# =============================================================================
# Helper Functions
# =============================================================================

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

is_installed() {
    local cask=$1
    brew list --cask "$cask" &>/dev/null
}

install_cask() {
    local cask=$1
    local description=$2

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would install $cask"
        return 0
    fi

    if is_installed "$cask"; then
        info "$cask is already installed"
        return 0
    fi

    info "Installing $cask ($description)..."
    retry brew install --cask "$cask"
    success "$cask installed"
}

# =============================================================================
# Category Installation Functions
# =============================================================================

install_category() {
    local category_name=$1
    shift
    local -n apps=$1

    if [[ ${#apps[@]} -eq 0 ]]; then
        return 0
    fi

    echo ""
    info "$category_name:"
    echo ""

    local casks=("${!apps[@]}")

    for cask in "${casks[@]}"; do
        local description="${apps[$cask]}"
        local status="[ ]"

        if is_installed "$cask"; then
            status="[x]"
        fi

        echo "  $status $cask - $description"
    done

    echo ""
    read -r -p "Install all $category_name apps? [y/N/select] " answer

    case $answer in
        [Yy]|[Yy][Ee][Ss])
            for cask in "${casks[@]}"; do
                install_cask "$cask" "${apps[$cask]}"
            done
            ;;
        [Ss]|[Ss][Ee][Ll][Ee][Cc][Tt])
            for cask in "${casks[@]}"; do
                if ! is_installed "$cask"; then
                    read -r -p "  Install $cask? [y/N] " select_answer
                    if [[ "$select_answer" =~ ^[Yy] ]]; then
                        install_cask "$cask" "${apps[$cask]}"
                    fi
                fi
            done
            ;;
        *)
            info "Skipping $category_name"
            ;;
    esac
}

# =============================================================================
# Interactive Mode
# =============================================================================

run_interactive() {
    echo ""
    echo "=============================================="
    echo "  Optional Applications Installer"
    echo "=============================================="
    echo ""
    echo "Apps you already have installed are marked [x]"
    echo ""
    echo "Options:"
    echo "  y/yes    - Install all apps in category"
    echo "  n/no     - Skip category"
    echo "  s/select - Choose specific apps"
    echo ""

    install_category "Menu Bar Utilities" MENU_BAR_UTILITIES
    install_category "Development Tools" DEV_TOOLS
    install_category "Browsers" BROWSERS
    install_category "Communication" COMMUNICATION
    install_category "Productivity" PRODUCTIVITY
    install_category "Media" MEDIA
}

# =============================================================================
# Show Already Installed Apps
# =============================================================================

show_installed_apps() {
    echo ""
    info "Apps already installed on your machine:"
    echo ""
    echo "  Code Editors:"
    echo "    [x] Visual Studio Code"
    echo "    [x] Cursor"
    echo ""
    echo "  Development:"
    echo "    [x] Docker"
    echo "    [x] iTerm2"
    echo ""
    echo "  Window Management:"
    echo "    [x] Rectangle"
    echo ""
    echo "  Productivity:"
    echo "    [x] Raycast"
    echo "    [x] 1Password"
    echo ""
    echo "  Browsers:"
    echo "    [x] Google Chrome"
    echo "    [x] Firefox"
    echo ""
    echo "  Communication:"
    echo "    [x] Slack"
    echo "    [x] Zoom"
    echo ""
    echo "  Media:"
    echo "    [x] Spotify"
    echo ""
    echo "  Other:"
    echo "    [x] Figma"
    echo "    [x] Miro"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Optional Applications Installer"
    echo ""

    # Check for Homebrew
    if ! command -v brew &>/dev/null; then
        error "Homebrew is not installed. Please run bootstrap.sh first."
        exit 1
    fi

    case "$INSTALL_MODE" in
        full)
            # In full mode, install all categories
            for category in MENU_BAR_UTILITIES DEV_TOOLS BROWSERS COMMUNICATION PRODUCTIVITY MEDIA; do
                local -n apps=$category
                for cask in "${!apps[@]}"; do
                    install_cask "$cask" "${apps[$cask]}"
                done
            done
            ;;
        minimal)
            info "Minimal mode - skipping optional applications"
            exit 0
            ;;
        *)
            # Interactive mode
            echo "=============================================="
            echo "  Quick Install Options"
            echo "=============================================="
            echo ""
            echo "  1) Show what's already installed"
            echo "  2) Browse and install new apps"
            echo "  3) Exit"
            echo ""
            read -r -p "Select option [1-3]: " quick_choice

            case $quick_choice in
                1)
                    show_installed_apps
                    echo ""
                    read -r -p "Browse additional apps to install? [y/N] " browse
                    if [[ "$browse" =~ ^[Yy] ]]; then
                        run_interactive
                    fi
                    ;;
                2) run_interactive ;;
                3)
                    info "Exiting"
                    exit 0
                    ;;
                *) run_interactive ;;
            esac
            ;;
    esac

    echo ""
    success "Optional applications installation complete!"
    echo ""
}

main "$@"
