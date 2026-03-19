#!/bin/bash
#
# macOS system defaults configuration script
#
# This script applies macOS defaults that match your current setup.
# Run with --dry-run to see what would be changed.
#
# Note: These settings have been verified against your current machine.
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

DRY_RUN="${DRY_RUN:-false}"

# =============================================================================
# Helper Functions
# =============================================================================

apply_default() {
    local domain=$1
    local key=$2
    local type=$3
    local value=$4
    local description=${5:-""}

    if [[ -n "$description" ]]; then
        info "$description"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] defaults write $domain $key -$type $value"
        return 0
    fi

    defaults write "$domain" "$key" "-$type" "$value"
}

apply_global_default() {
    local key=$1
    local type=$2
    local value=$3
    local description=${4:-""}

    if [[ -n "$description" ]]; then
        info "$description"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] defaults write -g $key -$type $value"
        return 0
    fi

    defaults write -g "$key" "-$type" "$value"
}

# =============================================================================
# Keyboard Settings
# =============================================================================

configure_keyboard() {
    info "Configuring keyboard settings..."

    # Fast keyboard repeat rate (matches your current settings)
    apply_global_default "InitialKeyRepeat" "int" "15" \
        "Setting initial key repeat delay (15 = 225ms)"

    apply_global_default "KeyRepeat" "int" "2" \
        "Setting key repeat rate (2 = 30ms)"

    # Disable press-and-hold for keys in favor of key repeat
    apply_global_default "ApplePressAndHoldEnabled" "bool" "false" \
        "Disabling press-and-hold for key repeat"

    success "Keyboard settings configured"
}

# =============================================================================
# Finder Settings
# =============================================================================

configure_finder() {
    info "Configuring Finder settings..."

    # Show hidden files
    apply_default "com.apple.finder" "AppleShowAllFiles" "bool" "true" \
        "Showing hidden files in Finder"

    # Show full POSIX path in Finder title bar
    apply_default "com.apple.finder" "_FXShowPosixPathInTitle" "bool" "true" \
        "Showing full path in Finder title bar"

    # Show all filename extensions
    apply_global_default "AppleShowAllExtensions" "bool" "true" \
        "Showing all filename extensions"

    # Keep folders on top when sorting by name
    apply_default "com.apple.finder" "_FXSortFoldersFirst" "bool" "true" \
        "Keeping folders on top when sorting"

    # Show the ~/Library folder
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would unhide ~/Library folder"
    else
        chflags nohidden ~/Library 2>/dev/null || true
        info "Unhiding ~/Library folder"
    fi

    success "Finder settings configured"
}

# =============================================================================
# Text Input Settings
# =============================================================================

configure_text_input() {
    info "Configuring text input settings..."

    # Disable automatic spelling correction
    apply_global_default "NSAutomaticSpellingCorrectionEnabled" "bool" "false" \
        "Disabling automatic spelling correction"

    # Disable smart quotes
    apply_global_default "NSAutomaticQuoteSubstitutionEnabled" "bool" "false" \
        "Disabling smart quotes"

    # Disable smart dashes
    apply_global_default "NSAutomaticDashSubstitutionEnabled" "bool" "false" \
        "Disabling smart dashes"

    # Note: NOT disabling auto-capitalization (you have it enabled)

    success "Text input settings configured"
}

# =============================================================================
# Screenshot Settings
# =============================================================================

configure_screenshots() {
    info "Configuring screenshot settings..."

    # Create Screenshots folder if it doesn't exist
    local screenshots_dir="$HOME/Screenshots"
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would create $screenshots_dir"
    else
        mkdir -p "$screenshots_dir"
        info "Created $screenshots_dir"
    fi

    # Set screenshot location
    apply_default "com.apple.screencapture" "location" "string" "$screenshots_dir" \
        "Setting screenshot location to ~/Screenshots"

    # Disable shadow in screenshots
    apply_default "com.apple.screencapture" "disable-shadow" "bool" "true" \
        "Disabling shadow in screenshots"

    success "Screenshot settings configured"
}

# =============================================================================
# Dock Settings
# =============================================================================

configure_dock() {
    info "Configuring Dock settings..."

    # Remove the auto-hiding Dock delay
    apply_default "com.apple.dock" "autohide-delay" "float" "0" \
        "Removing Dock auto-hide delay"

    # Remove the animation when hiding/showing the Dock
    apply_default "com.apple.dock" "autohide-time-modifier" "float" "0" \
        "Removing Dock hide/show animation"

    # Speed up Mission Control animations
    apply_default "com.apple.dock" "expose-animation-duration" "float" "0.1" \
        "Speeding up Mission Control animations"

    # Don't show recent applications in Dock
    apply_default "com.apple.dock" "show-recents" "bool" "false" \
        "Hiding recent applications in Dock"

    success "Dock settings configured"
}

# =============================================================================
# Animation Settings
# =============================================================================

configure_animations() {
    info "Configuring animation settings..."

    # Disable window animations
    apply_global_default "NSAutomaticWindowAnimationsEnabled" "bool" "false" \
        "Disabling window animations"

    success "Animation settings configured"
}

# =============================================================================
# Kill Affected Applications
# =============================================================================

restart_affected_apps() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would restart affected applications"
        return 0
    fi

    info "Restarting affected applications..."

    local apps=(
        "Finder"
        "Dock"
        "SystemUIServer"
    )

    for app in "${apps[@]}"; do
        killall "$app" &>/dev/null || true
    done

    success "Affected applications restarted"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Configuring macOS system defaults..."
    echo ""

    # Check if running as expected
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script is intended for macOS only"
        exit 1
    fi

    # Close System Preferences/Settings to prevent conflicts
    if [[ "$DRY_RUN" != true ]]; then
        osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true
        osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
    fi

    # Apply configurations (only settings verified on your machine)
    configure_keyboard
    echo ""
    configure_finder
    echo ""
    configure_text_input
    echo ""
    configure_screenshots
    echo ""
    configure_dock
    echo ""
    configure_animations
    echo ""

    # Restart affected applications
    restart_affected_apps

    echo ""
    success "macOS defaults configured successfully!"
    echo ""
    warning "Note: Some changes may require a logout/restart to take effect."
}

main "$@"
