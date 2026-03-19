#!/bin/bash
#
# Common functions shared across all setup scripts
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#

# =============================================================================
# Logging Functions
# =============================================================================

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

debug() {
    if [[ "${VERBOSE:-false}" == true ]]; then
        echo -e "\033[1;35m[DEBUG]\033[0m $1"
    fi
}

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
# Validation Functions
# =============================================================================

validate_email() {
    local email=$1
    if [[ -z "$email" ]]; then
        return 1
    fi
    [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

validate_not_empty() {
    local value=$1
    local name=$2
    if [[ -z "$value" ]]; then
        error "$name cannot be empty"
        return 1
    fi
    return 0
}

# =============================================================================
# File Operations
# =============================================================================

backup_file() {
    local file=$1
    local backup_dir="${BACKUP_DIR:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"

    if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
        mkdir -p "$backup_dir"
        local filename
        filename=$(basename "$file")
        cp -a "$file" "$backup_dir/$filename"
        # Store original location for restore
        echo "$file" >> "$backup_dir/.manifest"
        info "Backed up $file to $backup_dir/$filename"
    fi
}

is_symlink_correct() {
    local source=$1
    local target=$2
    [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]
}

create_symlink() {
    local source=$1
    local target=$2

    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "[DRY-RUN] Would symlink $source -> $target"
        return 0
    fi

    # Check if symlink already correct
    if is_symlink_correct "$source" "$target"; then
        debug "Symlink already correct: $target"
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

# =============================================================================
# System Checks
# =============================================================================

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script is intended for macOS only."
        exit 1
    fi
}

check_macos_version() {
    local min_version="${1:-14.0}"
    local current
    current=$(sw_vers -productVersion)

    if [[ "$(printf '%s\n' "$min_version" "$current" | sort -V | head -n1)" != "$min_version" ]]; then
        warning "macOS $min_version or later recommended (found $current)"
        return 1
    fi
    return 0
}

check_apple_silicon() {
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
        return 0
    else
        HOMEBREW_PREFIX="/usr/local"
        return 1
    fi
}

# =============================================================================
# Error Handling
# =============================================================================

# Trap handler for cleanup on error
setup_error_trap() {
    trap 'handle_error $? $LINENO' ERR
}

handle_error() {
    local exit_code=$1
    local line_number=$2
    error "Script failed at line $line_number with exit code $exit_code"
}

# =============================================================================
# Progress Indicators
# =============================================================================

with_spinner() {
    local pid=$1
    local message=$2
    local spinstr='|/-\'

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] %s\r" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r\033[K"
}

# =============================================================================
# Script Runner
# =============================================================================

run_script() {
    local script=$1
    local script_name
    script_name=$(basename "$script" .sh)

    if [[ ! -f "$script" ]]; then
        warning "Script not found: $script"
        return 1
    fi

    if [[ "${DRY_RUN:-false}" == true ]]; then
        info "[DRY-RUN] Would run: $script_name"
        return 0
    fi

    info "Running $script_name..."

    # Source the script
    if bash "$script"; then
        success "$script_name completed"
    else
        error "$script_name failed"
        return 1
    fi
}

# =============================================================================
# Export Functions (for child scripts)
# =============================================================================

export_common_functions() {
    export -f info success warning error debug
    export -f command_exists retry ask_yes_no
    export -f validate_email validate_not_empty
    export -f backup_file is_symlink_correct create_symlink
    export -f check_macos check_macos_version check_apple_silicon
    export -f run_script
}
