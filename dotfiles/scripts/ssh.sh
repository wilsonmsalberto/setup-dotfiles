#!/bin/bash
#
# SSH key generation helper script
#
# Interactive script to generate SSH keys for various services
# (GitHub, GitLab, etc.) with proper configuration.
#

set -e
set -u
set -o pipefail

# =============================================================================
# Logging
# =============================================================================

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# =============================================================================
# Configuration
# =============================================================================

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"

# =============================================================================
# Helper Functions
# =============================================================================

ensure_ssh_directory() {
    if [[ ! -d "$SSH_DIR" ]]; then
        info "Creating SSH directory..."
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi
}

ensure_ssh_config() {
    if [[ ! -f "$SSH_CONFIG" ]]; then
        info "Creating SSH config file..."
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi
}

start_ssh_agent() {
    # Check if ssh-agent is running
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        info "Starting ssh-agent..."
        eval "$(ssh-agent -s)"
    fi
}

# =============================================================================
# SSH Key Generation
# =============================================================================

generate_ssh_key() {
    local email=$1
    local key_name=$2
    local key_path="$SSH_DIR/$key_name"

    # Check if key already exists
    if [[ -f "$key_path" ]]; then
        warning "SSH key already exists at $key_path"
        echo ""
        read -r -p "Do you want to overwrite it? [y/N] " overwrite
        if [[ ! "$overwrite" =~ ^[Yy] ]]; then
            info "Skipping key generation"
            return 1
        fi
        # Backup existing key
        mv "$key_path" "$key_path.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$key_path.pub" "$key_path.pub.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi

    info "Generating SSH key: $key_name"
    echo ""

    # Generate ed25519 key
    ssh-keygen -t ed25519 -C "$email" -f "$key_path"

    # Set proper permissions
    chmod 600 "$key_path"
    chmod 644 "$key_path.pub"

    success "SSH key generated at $key_path"
    return 0
}

add_to_agent() {
    local key_path=$1

    info "Adding key to ssh-agent..."

    # Add key to agent with macOS Keychain integration
    if [[ "$(uname)" == "Darwin" ]]; then
        ssh-add --apple-use-keychain "$key_path" 2>/dev/null || ssh-add "$key_path"
    else
        ssh-add "$key_path"
    fi

    success "Key added to ssh-agent"
}

add_to_ssh_config() {
    local key_name=$1
    local host=$2
    local hostname=$3
    local user=${4:-git}

    info "Adding entry to SSH config..."

    # Check if entry already exists
    if grep -q "Host $host" "$SSH_CONFIG" 2>/dev/null; then
        warning "SSH config entry for $host already exists"
        return 0
    fi

    # Add entry to config
    cat >> "$SSH_CONFIG" << EOF

# $key_name
Host $host
    HostName $hostname
    User $user
    IdentityFile ~/.ssh/$key_name
    AddKeysToAgent yes
    UseKeychain yes
EOF

    success "SSH config entry added for $host"
}

copy_public_key() {
    local key_path=$1

    if command -v pbcopy >/dev/null 2>&1; then
        cat "$key_path.pub" | pbcopy
        success "Public key copied to clipboard!"
    else
        warning "pbcopy not available, displaying public key:"
        echo ""
        cat "$key_path.pub"
    fi
}

test_ssh_connection() {
    local host=$1
    local expected_user=${2:-}

    info "Testing SSH connection to $host..."
    echo ""

    # Test connection (GitHub/GitLab return exit code 1 even on success)
    if ssh -T "$host" 2>&1 | grep -qi "successfully authenticated\|welcome\|Hi "; then
        success "SSH connection successful!"
    else
        # Show the output anyway
        ssh -T "$host" 2>&1 || true
        echo ""
        warning "Connection test complete (check output above)"
    fi
}

# =============================================================================
# Service-specific Setup
# =============================================================================

setup_github() {
    local email=$1
    local key_name=${2:-github}

    echo ""
    info "Setting up SSH key for GitHub"
    echo "=============================================="
    echo ""

    if generate_ssh_key "$email" "$key_name"; then
        local key_path="$SSH_DIR/$key_name"

        start_ssh_agent
        add_to_agent "$key_path"
        add_to_ssh_config "$key_name" "github.com" "github.com"

        echo ""
        echo "=============================================="
        info "Next steps:"
        echo "=============================================="
        echo ""
        echo "1. Your public key has been copied to clipboard (if pbcopy available)"
        copy_public_key "$key_path"
        echo ""
        echo "2. Add the key to GitHub:"
        echo "   - Go to: https://github.com/settings/keys"
        echo "   - Click 'New SSH key'"
        echo "   - Give it a title (e.g., 'MacBook Pro')"
        echo "   - Paste the key and save"
        echo ""
        read -r -p "Press Enter when you've added the key to GitHub..."

        echo ""
        test_ssh_connection "git@github.com"
    fi
}

setup_gitlab() {
    local email=$1
    local key_name=${2:-gitlab}
    local gitlab_host=${3:-gitlab.com}

    echo ""
    info "Setting up SSH key for GitLab ($gitlab_host)"
    echo "=============================================="
    echo ""

    if generate_ssh_key "$email" "$key_name"; then
        local key_path="$SSH_DIR/$key_name"

        start_ssh_agent
        add_to_agent "$key_path"

        # Determine host alias
        local host_alias="gitlab.com"
        if [[ "$gitlab_host" != "gitlab.com" ]]; then
            host_alias="$gitlab_host"
        fi

        add_to_ssh_config "$key_name" "$host_alias" "$gitlab_host"

        echo ""
        echo "=============================================="
        info "Next steps:"
        echo "=============================================="
        echo ""
        echo "1. Your public key has been copied to clipboard (if pbcopy available)"
        copy_public_key "$key_path"
        echo ""
        echo "2. Add the key to GitLab:"
        echo "   - Go to: https://$gitlab_host/-/profile/keys"
        echo "   - Paste the key in 'Key' field"
        echo "   - Give it a title"
        echo "   - Set expiration date (optional)"
        echo "   - Click 'Add key'"
        echo ""
        read -r -p "Press Enter when you've added the key to GitLab..."

        echo ""
        test_ssh_connection "git@$host_alias"
    fi
}

setup_custom() {
    echo ""
    info "Custom SSH key setup"
    echo "=============================================="
    echo ""

    read -r -p "Email address: " email
    read -r -p "Key name (e.g., work-server): " key_name
    read -r -p "Host alias (for SSH config): " host_alias
    read -r -p "Hostname/IP: " hostname
    read -r -p "Username [git]: " username
    username=${username:-git}

    if generate_ssh_key "$email" "$key_name"; then
        local key_path="$SSH_DIR/$key_name"

        start_ssh_agent
        add_to_agent "$key_path"
        add_to_ssh_config "$key_name" "$host_alias" "$hostname" "$username"

        echo ""
        copy_public_key "$key_path"
        echo ""
        info "Add this public key to your server's authorized_keys"
    fi
}

# =============================================================================
# Interactive Menu
# =============================================================================

show_menu() {
    echo ""
    echo "=============================================="
    echo "  SSH Key Setup Helper"
    echo "=============================================="
    echo ""
    echo "What would you like to set up?"
    echo ""
    echo "  1) GitHub (github.com)"
    echo "  2) GitLab (gitlab.com)"
    echo "  3) GitLab (custom domain, e.g., company GitLab)"
    echo "  4) Custom SSH key"
    echo "  5) List existing keys"
    echo "  6) Test SSH connection"
    echo "  7) Exit"
    echo ""
}

list_existing_keys() {
    echo ""
    info "Existing SSH keys in $SSH_DIR:"
    echo ""

    if ls "$SSH_DIR"/*.pub &>/dev/null; then
        for pub_key in "$SSH_DIR"/*.pub; do
            local key_name
            key_name=$(basename "$pub_key" .pub)
            local key_type
            key_type=$(head -c 20 "$pub_key" | awk '{print $1}')
            echo "  - $key_name ($key_type)"
        done
    else
        warning "No SSH keys found"
    fi

    echo ""
    if [[ -f "$SSH_CONFIG" ]]; then
        info "SSH config entries:"
        echo ""
        grep "^Host " "$SSH_CONFIG" 2>/dev/null | sed 's/Host /  - /' || echo "  (none)"
    fi
    echo ""
}

test_connection_interactive() {
    echo ""
    read -r -p "Enter SSH host to test (e.g., git@github.com): " host
    test_ssh_connection "$host"
}

# =============================================================================
# Main
# =============================================================================

main() {
    ensure_ssh_directory
    ensure_ssh_config

    while true; do
        show_menu
        read -r -p "Select option [1-7]: " choice

        case $choice in
            1)
                read -r -p "Email address: " email
                read -r -p "Key name [github]: " key_name
                key_name=${key_name:-github}
                setup_github "$email" "$key_name"
                ;;
            2)
                read -r -p "Email address: " email
                read -r -p "Key name [gitlab]: " key_name
                key_name=${key_name:-gitlab}
                setup_gitlab "$email" "$key_name"
                ;;
            3)
                read -r -p "Email address: " email
                read -r -p "GitLab domain (e.g., gitlab.company.com): " domain
                read -r -p "Key name [gitlab-work]: " key_name
                key_name=${key_name:-gitlab-work}
                setup_gitlab "$email" "$key_name" "$domain"
                ;;
            4)
                setup_custom
                ;;
            5)
                list_existing_keys
                ;;
            6)
                test_connection_interactive
                ;;
            7)
                echo ""
                info "Goodbye!"
                exit 0
                ;;
            *)
                warning "Invalid option"
                ;;
        esac

        echo ""
        read -r -p "Press Enter to continue..."
    done
}

main "$@"
