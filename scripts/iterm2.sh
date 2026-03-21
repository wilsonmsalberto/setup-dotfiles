#!/bin/bash
#
# iTerm2 configuration script
#
# Sets up iTerm2 Dynamic Profile for consistent terminal settings.
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

ITERM_APP="/Applications/iTerm.app"
ITERM_DYNAMIC_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ITERM_CONFIG_DIR="$CONFIG_DIR/iterm2"
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

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

check_iterm_installed() {
    info "Checking for iTerm2 installation..."

    if [[ ! -d "$ITERM_APP" ]]; then
        warning "iTerm.app not found at $ITERM_APP"
        warning "Please install iTerm2 from https://iterm2.com"
        return 1
    fi

    info "iTerm2 found"
    return 0
}

setup_dynamic_profile() {
    info "Setting up iTerm2 Dynamic Profile..."

    local profile_source="$ITERM_CONFIG_DIR/profile.json"

    if [[ ! -f "$profile_source" ]]; then
        warning "Profile config not found: $profile_source"
        warning "Run export_iterm_profile first to generate it"
        return 1
    fi

    # Create DynamicProfiles directory if it doesn't exist
    if [[ "$DRY_RUN" == true ]]; then
        if [[ ! -d "$ITERM_DYNAMIC_PROFILES_DIR" ]]; then
            info "[DRY-RUN] Would create $ITERM_DYNAMIC_PROFILES_DIR"
        fi
    else
        mkdir -p "$ITERM_DYNAMIC_PROFILES_DIR"
    fi

    # Symlink profile into DynamicProfiles
    # Dynamic Profiles are additive - they won't overwrite existing iTerm settings
    create_symlink "$profile_source" "$ITERM_DYNAMIC_PROFILES_DIR/dotfiles-profile.json"

    success "iTerm2 Dynamic Profile linked"
}

export_iterm_profile() {
    local profile_output="$ITERM_CONFIG_DIR/profile.json"

    if [[ ! -f "$ITERM_PLIST" ]]; then
        error "iTerm2 preferences not found at $ITERM_PLIST"
        error "Please run iTerm2 at least once before exporting"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would export iTerm2 profile to $profile_output"
        return 0
    fi

    info "Exporting iTerm2 profile..."

    mkdir -p "$(dirname "$profile_output")"

    python3 -c "
import plistlib, json, sys, os

plist_path = os.path.expanduser('$ITERM_PLIST')
with open(plist_path, 'rb') as f:
    data = plistlib.load(f)

profiles = data.get('New Bookmarks', [])
if not profiles:
    print('No profiles found in iTerm2 preferences', file=sys.stderr)
    sys.exit(1)

profile = profiles[0]
profile['Guid'] = 'dotfiles-default'
profile['Name'] = 'Dotfiles Default'
result = {'Profiles': [profile]}
print(json.dumps(result, indent=2, default=str))
" > "$profile_output"

    success "iTerm2 profile exported to $profile_output"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up iTerm2 configuration..."
    echo ""

    # Check for iTerm2
    if ! check_iterm_installed; then
        error "iTerm2 is not installed. Please install it first."
        exit 1
    fi

    # Setup steps
    setup_dynamic_profile

    echo ""
    success "iTerm2 configuration complete!"
    echo ""
    info "iTerm2 will pick up the Dynamic Profile automatically on next launch."
    info "The profile appears under Profiles > Dotfiles Default in iTerm2 preferences."
    echo ""
}

main "$@"
