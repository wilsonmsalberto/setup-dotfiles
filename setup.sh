#!/bin/bash
#
# Setup Wizard for macOS Dotfiles
#
# Interactive wizard to configure user-specific settings before installation.
# Creates a .env file with your preferences.
#
# Usage:
#   ./setup.sh              # Interactive setup
#   ./setup.sh --defaults   # Use defaults without prompts
#

set -e
set -u
set -o pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"

# Default values (your current configuration)
DEFAULT_GIT_NAME="Wilson Alberto"
DEFAULT_GIT_EMAIL="wilsonalberto@gmail.com"
DEFAULT_GIT_WORK_EMAIL="wilson.alberto@olx.com"

# =============================================================================
# Parse Arguments
# =============================================================================

USE_DEFAULTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --defaults|-d)
            USE_DEFAULTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: ./setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --defaults, -d  Use default values without prompts"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# Prompt Functions
# =============================================================================

prompt_with_default() {
    local prompt=$1
    local default=$2
    local varname=$3
    local value

    read -r -p "$prompt [$default]: " value
    value=${value:-$default}

    eval "$varname=\"$value\""
}

prompt_email_with_validation() {
    local prompt=$1
    local default=$2
    local varname=$3
    local value

    while true; do
        read -r -p "$prompt [$default]: " value
        value=${value:-$default}

        if validate_email "$value"; then
            eval "$varname=\"$value\""
            return 0
        else
            warning "Invalid email format. Please try again."
        fi
    done
}

# =============================================================================
# Display Banner
# =============================================================================

show_banner() {
    echo ""
    echo "=============================================="
    echo "  macOS Dotfiles Setup Wizard"
    echo "=============================================="
    echo ""
    echo "  This wizard will configure your environment"
    echo "  settings before running the installation."
    echo ""
}

# =============================================================================
# Show Current Defaults
# =============================================================================

show_defaults() {
    echo "Default configuration:"
    echo ""
    echo "  Git Name:       $DEFAULT_GIT_NAME"
    echo "  Git Email:      $DEFAULT_GIT_EMAIL"
    echo "  Work Email:     $DEFAULT_GIT_WORK_EMAIL"
    echo ""
}

# =============================================================================
# Interactive Setup
# =============================================================================

run_interactive_setup() {
    local git_name
    local git_email
    local git_work_email

    show_defaults

    if ask_yes_no "Use these defaults?" "y"; then
        git_name="$DEFAULT_GIT_NAME"
        git_email="$DEFAULT_GIT_EMAIL"
        git_work_email="$DEFAULT_GIT_WORK_EMAIL"
        success "Using default configuration"
    else
        echo ""
        info "Enter your configuration (press Enter to accept default):"
        echo ""

        prompt_with_default "Git user name" "$DEFAULT_GIT_NAME" git_name
        prompt_email_with_validation "Git email (personal)" "$DEFAULT_GIT_EMAIL" git_email
        prompt_email_with_validation "Git email (work)" "$DEFAULT_GIT_WORK_EMAIL" git_work_email
    fi

    # Confirm settings
    echo ""
    echo "=============================================="
    echo "  Configuration Summary"
    echo "=============================================="
    echo ""
    echo "  Git Name:       $git_name"
    echo "  Git Email:      $git_email"
    echo "  Work Email:     $git_work_email"
    echo ""

    if ! ask_yes_no "Save this configuration?" "y"; then
        warning "Setup cancelled"
        exit 0
    fi

    # Write .env file
    write_env_file "$git_name" "$git_email" "$git_work_email"
}

# =============================================================================
# Write .env File
# =============================================================================

write_env_file() {
    local git_name=$1
    local git_email=$2
    local git_work_email=$3

    local env_file="$SCRIPT_DIR/.env"

    cat > "$env_file" << EOF
# =============================================================================
# macOS Dotfiles Configuration
# =============================================================================
# Generated by setup.sh on $(date)
# =============================================================================

# Git Configuration
GIT_USER_NAME="$git_name"
GIT_USER_EMAIL="$git_email"
GIT_WORK_EMAIL="$git_work_email"
GIT_HOME_EMAIL="$git_email"

# Installation Options
# Set to "true" to skip interactive prompts
# INSTALL_HOMEBREW_PACKAGES=true
# INSTALL_SHELL_CONFIG=true
# INSTALL_GIT_CONFIG=true
# INSTALL_MACOS_DEFAULTS=true
# INSTALL_NODE=true
# INSTALL_OPTIONAL_APPS=false
EOF

    success "Configuration saved to .env"
}

# =============================================================================
# Main
# =============================================================================

main() {
    show_banner

    # Check if .env already exists
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        warning "A .env file already exists"
        if ! ask_yes_no "Overwrite existing configuration?" "n"; then
            info "Keeping existing configuration"
            echo ""
            info "Run ./install.sh to continue with installation"
            exit 0
        fi
    fi

    if [[ "$USE_DEFAULTS" == true ]]; then
        info "Using default configuration"
        write_env_file "$DEFAULT_GIT_NAME" "$DEFAULT_GIT_EMAIL" "$DEFAULT_GIT_WORK_EMAIL"
    else
        run_interactive_setup
    fi

    echo ""
    echo "=============================================="
    success "Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Review your configuration:"
    echo "     cat .env"
    echo ""
    echo "  2. Run the installation:"
    echo "     ./install.sh"
    echo ""

    if ask_yes_no "Run installation now?" "y"; then
        echo ""
        exec "$SCRIPT_DIR/install.sh"
    fi
}

main "$@"
