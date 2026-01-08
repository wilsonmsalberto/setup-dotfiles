#!/bin/bash
#
# Git configuration script
#
# Sets up Git with sensible defaults, delta pager, and useful aliases.
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

# Load environment variables if available
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/.env"
fi

# Default values (can be overridden by .env)
GIT_USER_NAME="${GIT_USER_NAME:-Wilson Alberto}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
GIT_WORK_EMAIL="${GIT_WORK_EMAIL:-wilson.alberto@olx.com}"
GIT_HOME_EMAIL="${GIT_HOME_EMAIL:-wilsonalberto@gmail.com}"

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

git_config_set() {
    local key=$1
    local value=$2
    local scope=${3:---global}

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] git config $scope $key \"$value\""
        return 0
    fi

    git config "$scope" "$key" "$value"
}

# =============================================================================
# Configuration Functions
# =============================================================================

setup_gitconfig() {
    info "Setting up Git configuration..."

    # Create symlink to gitconfig
    create_symlink "$CONFIG_DIR/gitconfig" "$HOME/.gitconfig"

    # Create symlink to global gitignore
    create_symlink "$CONFIG_DIR/gitignore_global" "$HOME/.gitignore_global"

    success "Git configuration files linked"
}

configure_git_user() {
    info "Configuring Git user..."

    # Set user name
    git_config_set "user.name" "$GIT_USER_NAME"

    # Determine which email to use
    local email="$GIT_USER_EMAIL"
    if [[ -z "$email" ]]; then
        # If no email specified, prompt user
        echo ""
        echo "Which email would you like to use as default?"
        echo "  1) Work: $GIT_WORK_EMAIL"
        echo "  2) Home: $GIT_HOME_EMAIL"
        echo "  3) Enter a different email"
        echo ""

        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would prompt for email selection"
            email="$GIT_HOME_EMAIL"
        else
            read -r -p "Select [1/2/3]: " choice
            case $choice in
                1) email="$GIT_WORK_EMAIL" ;;
                2) email="$GIT_HOME_EMAIL" ;;
                3)
                    read -r -p "Enter email: " email
                    ;;
                *) email="$GIT_HOME_EMAIL" ;;
            esac
        fi
    fi

    git_config_set "user.email" "$email"

    success "Git user configured: $GIT_USER_NAME <$email>"
}

configure_git_core() {
    info "Configuring Git core settings..."

    git_config_set "init.defaultBranch" "main"
    git_config_set "core.editor" "nano"
    git_config_set "core.excludesfile" "$HOME/.gitignore_global"

    # Configure delta as pager if available
    if command -v delta >/dev/null 2>&1; then
        git_config_set "core.pager" "delta"
        git_config_set "interactive.diffFilter" "delta --color-only"
        git_config_set "delta.navigate" "true"
        git_config_set "delta.light" "false"
        git_config_set "delta.line-numbers" "true"
        git_config_set "merge.conflictstyle" "diff3"
        git_config_set "diff.colorMoved" "default"
        info "Delta pager configured"
    else
        warning "Delta not found, using default pager"
    fi

    success "Git core settings configured"
}

configure_git_aliases() {
    info "Configuring Git aliases..."

    # User switching aliases
    git_config_set "alias.user" "config user.email"
    git_config_set "alias.workuser" "!git config user.email '$GIT_WORK_EMAIL' && echo 'Switched to work user: $GIT_WORK_EMAIL'"
    git_config_set "alias.homeuser" "!git config user.email '$GIT_HOME_EMAIL' && echo 'Switched to home user: $GIT_HOME_EMAIL'"

    # Common shortcuts
    git_config_set "alias.st" "status"
    git_config_set "alias.co" "checkout"
    git_config_set "alias.br" "branch"
    git_config_set "alias.ci" "commit"
    git_config_set "alias.df" "diff"
    git_config_set "alias.lg" "log --oneline --graph --decorate"
    git_config_set "alias.last" "log -1 HEAD --stat"
    git_config_set "alias.unstage" "reset HEAD --"
    git_config_set "alias.amend" "commit --amend --no-edit"

    success "Git aliases configured"
}

configure_git_misc() {
    info "Configuring additional Git settings..."

    # Pull settings
    git_config_set "pull.rebase" "false"

    # Push settings
    git_config_set "push.default" "current"
    git_config_set "push.autoSetupRemote" "true"

    # Color settings
    git_config_set "color.ui" "auto"

    # Credential helper (macOS Keychain)
    git_config_set "credential.helper" "osxkeychain"

    success "Additional Git settings configured"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up Git configuration..."
    echo ""

    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        error "Git is not installed. Please run brew.sh first."
        exit 1
    fi

    # Setup steps
    setup_gitconfig
    configure_git_user
    configure_git_core
    configure_git_aliases
    configure_git_misc

    echo ""
    success "Git configuration complete!"
    echo ""
    info "You can switch between work and home Git users with:"
    info "  git workuser   # Switch to work email"
    info "  git homeuser   # Switch to home email"
    info "  git user       # Show current email"
    echo ""
}

main "$@"
