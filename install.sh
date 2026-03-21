#!/bin/bash
#
# Main installation script for macOS dotfiles
#
# Usage:
#   ./install.sh              # Interactive mode
#   ./install.sh --minimal    # Essential CLI tools only
#   ./install.sh --full       # Everything including optional apps
#   ./install.sh --dry-run    # Show what would be done
#   ./install.sh --verbose    # Verbose output
#

set -e
set -u
set -o pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIG_DIR="$SCRIPT_DIR/config"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Default options
INSTALL_MODE="interactive"  # minimal, full, interactive
DRY_RUN=false
VERBOSE=false

# =============================================================================
# Source common library if available, otherwise define functions
# =============================================================================

if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    # Fallback definitions
    info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
    success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
    warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
    error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
fi

debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\033[1;35m[DEBUG]\033[0m $1"
    fi
}

# =============================================================================
# Error Handling
# =============================================================================

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        error "Installation failed with exit code $exit_code"
        echo ""
        if [[ -d "$BACKUP_DIR" ]]; then
            info "Your original files are backed up in: $BACKUP_DIR"
            info "Run ./uninstall.sh to restore them"
        fi
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

    # Backup existing file if it's not already a symlink
    backup_file "$target"

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    # Create symlink (force overwrite)
    ln -sf "$source" "$target"
    debug "Created symlink: $target -> $source"
}

run_script() {
    local script=$1
    local script_name
    script_name=$(basename "$script" .sh)

    if [[ ! -f "$script" ]]; then
        warning "Script not found: $script"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would run: $script_name"
        return 0
    fi

    info "Running $script_name..."

    # Export our functions and variables for child scripts
    export -f info success warning error debug command_exists retry backup_file create_symlink
    export DRY_RUN VERBOSE SCRIPT_DIR CONFIG_DIR BACKUP_DIR INSTALL_MODE

    # Source the script in a subshell to isolate errors
    if bash "$script"; then
        success "$script_name completed"
    else
        error "$script_name failed"
        return 1
    fi
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-n}
    local answer

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    read -r -p "$prompt" answer
    answer=${answer:-$default}

    [[ "$answer" =~ ^[Yy] ]]
}

# =============================================================================
# Parse Arguments
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --minimal)
                INSTALL_MODE="minimal"
                shift
                ;;
            --full)
                INSTALL_MODE="full"
                shift
                ;;
            --interactive)
                INSTALL_MODE="interactive"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
  --minimal       Install essential CLI tools only
  --full          Install everything including optional apps
  --interactive   Prompt for each category (default)
  --dry-run       Show what would be done without making changes
  --verbose, -v   Enable verbose output
  --help, -h      Show this help message

Examples:
  ./install.sh                    # Interactive installation
  ./install.sh --minimal          # Quick setup with essentials
  ./install.sh --full --verbose   # Full install with detailed output
  ./install.sh --dry-run          # Preview changes
EOF
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

check_prerequisites() {
    info "Checking prerequisites..."

    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script is intended for macOS only."
        exit 1
    fi

    # Check for Homebrew
    if ! command_exists brew; then
        error "Homebrew is not installed. Please run bootstrap.sh first."
        exit 1
    fi

    # Load .env file if it exists
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        info "Loading configuration from .env file"
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/.env"
    elif [[ -f "$SCRIPT_DIR/.env.example" ]]; then
        warning "No .env file found. Consider copying .env.example to .env"
        warning "Using default values..."
    fi

    success "Prerequisites check passed"
}

# =============================================================================
# Installation Steps
# =============================================================================

install_homebrew_packages() {
    info "Installing Homebrew packages..."
    run_script "$SCRIPTS_DIR/brew.sh"
}

configure_shell() {
    info "Configuring shell..."
    run_script "$SCRIPTS_DIR/shell.sh"
}

configure_git() {
    info "Configuring Git..."
    run_script "$SCRIPTS_DIR/git.sh"
}

configure_macos() {
    info "Configuring macOS defaults..."
    run_script "$SCRIPTS_DIR/macos.sh"
}

setup_node() {
    info "Setting up Node.js..."
    run_script "$SCRIPTS_DIR/node.sh"
}

install_optional_apps() {
    info "Installing optional applications..."
    run_script "$SCRIPTS_DIR/apps.sh"
}

configure_claude_code() {
    info "Configuring Claude Code..."
    run_script "$SCRIPTS_DIR/claude-code.sh"
}

configure_cursor() {
    info "Configuring Cursor editor..."
    run_script "$SCRIPTS_DIR/cursor.sh"
}

configure_iterm2() {
    info "Configuring iTerm2..."
    run_script "$SCRIPTS_DIR/iterm2.sh"
}

configure_extras() {
    info "Configuring extras (GitHub CLI, Espanso)..."
    run_script "$SCRIPTS_DIR/extras.sh"
}

# =============================================================================
# Interactive Mode
# =============================================================================

run_interactive() {
    echo ""
    echo "=============================================="
    echo "  Interactive Installation"
    echo "=============================================="
    echo ""
    echo "You will be prompted for each installation step."
    echo "Press Enter to accept defaults shown in [brackets]."
    echo ""

    # Homebrew packages (always yes)
    if ask_yes_no "Install Homebrew CLI packages?" "y"; then
        install_homebrew_packages
    fi

    # Shell configuration
    if ask_yes_no "Configure Zsh shell with Powerlevel10k?" "y"; then
        configure_shell
    fi

    # Git configuration
    if ask_yes_no "Configure Git?" "y"; then
        configure_git
    fi

    # macOS defaults
    if ask_yes_no "Apply macOS system defaults?" "y"; then
        configure_macos
    fi

    # Node.js setup
    if ask_yes_no "Set up Node.js via fnm?" "y"; then
        setup_node
    fi

    # Optional apps
    if ask_yes_no "Install optional GUI applications?" "n"; then
        install_optional_apps
    fi

    # Claude Code
    if ask_yes_no "Configure Claude Code?" "y"; then
        configure_claude_code
    fi

    # Cursor
    if ask_yes_no "Configure Cursor editor?" "y"; then
        configure_cursor
    fi

    # iTerm2
    if ask_yes_no "Configure iTerm2 profile?" "y"; then
        configure_iterm2
    fi

    # Extras (GH CLI, Espanso)
    if ask_yes_no "Configure extras (GitHub CLI, Espanso)?" "y"; then
        configure_extras
    fi
}

# =============================================================================
# Minimal Mode
# =============================================================================

run_minimal() {
    echo ""
    echo "=============================================="
    echo "  Minimal Installation"
    echo "=============================================="
    echo ""

    install_homebrew_packages
    configure_shell
    configure_git
    setup_node
    configure_claude_code
}

# =============================================================================
# Full Mode
# =============================================================================

run_full() {
    echo ""
    echo "=============================================="
    echo "  Full Installation"
    echo "=============================================="
    echo ""

    install_homebrew_packages
    configure_shell
    configure_git
    configure_macos
    setup_node
    install_optional_apps
    configure_claude_code
    configure_cursor
    configure_iterm2
    configure_extras
}

# =============================================================================
# Post-Install Summary
# =============================================================================

print_summary() {
    echo ""
    echo "=============================================="
    success "Installation Complete!"
    echo "=============================================="
    echo ""

    if [[ -d "$BACKUP_DIR" ]]; then
        info "Backups stored in: $BACKUP_DIR"
    fi

    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Restart your terminal or run:"
    echo "     source ~/.zshrc"
    echo ""
    echo "  2. Configure Powerlevel10k (if not already done):"
    echo "     p10k configure"
    echo ""
    echo "  3. Set up SSH keys for Git:"
    echo "     ./scripts/ssh.sh"
    echo ""
    echo "  4. Configure iTerm2 font:"
    echo "     - Open iTerm2 Preferences (Cmd+,)"
    echo "     - Go to Profiles > Text"
    echo "     - Set Font to 'MesloLGS NF'"
    echo ""

    if [[ "$INSTALL_MODE" != "full" ]]; then
        echo "  5. Install optional apps later with:"
        echo "     ./scripts/apps.sh"
        echo ""
    fi

    echo "  5. Configure additional tools (if not done):"
    echo "     ./scripts/claude-code.sh    # Claude Code config"
    echo "     ./scripts/cursor.sh         # Cursor editor"
    echo "     ./scripts/iterm2.sh         # iTerm2 profile"
    echo "     ./scripts/extras.sh         # GH CLI, Espanso"
    echo ""

    echo "  For verification, run:"
    echo "     ./test.sh"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    echo ""
    echo "=============================================="
    echo "  macOS Dotfiles Installer"
    echo "=============================================="
    echo ""
    echo "  Mode: $INSTALL_MODE"
    echo "  Dry Run: $DRY_RUN"
    echo "  Verbose: $VERBOSE"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        warning "Running in dry-run mode - no changes will be made"
        echo ""
    fi

    check_prerequisites

    case $INSTALL_MODE in
        minimal)
            run_minimal
            ;;
        full)
            run_full
            ;;
        interactive)
            run_interactive
            ;;
    esac

    print_summary
}

main "$@"
