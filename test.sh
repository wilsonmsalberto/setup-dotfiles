#!/bin/bash
#
# Test script for dotfiles installation
#
# Verifies that all expected commands and configurations are in place.
#

set -u

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Logging
# =============================================================================

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[PASS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }

# =============================================================================
# Test Counters
# =============================================================================

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

pass() {
    success "$1"
    ((TESTS_PASSED++))
}

fail() {
    error "$1"
    ((TESTS_FAILED++))
}

warn() {
    warning "$1"
    ((TESTS_WARNED++))
}

# =============================================================================
# Test Functions
# =============================================================================

test_command() {
    local cmd=$1
    local description=${2:-$cmd}

    if command -v "$cmd" &>/dev/null; then
        pass "$description is installed"
    else
        fail "$description is NOT installed"
    fi
}

test_file() {
    local file=$1
    local description=${2:-$file}

    if [[ -f "$file" ]]; then
        pass "$description exists"
    else
        fail "$description does NOT exist"
    fi
}

test_symlink() {
    local link=$1
    local expected_target=$2
    local description=${3:-$link}

    if [[ -L "$link" ]]; then
        local actual_target
        actual_target=$(readlink "$link")
        if [[ "$actual_target" == "$expected_target" ]]; then
            pass "$description symlink is correct"
        else
            warn "$description symlink points to $actual_target (expected $expected_target)"
        fi
    elif [[ -f "$link" ]]; then
        warn "$description exists but is not a symlink"
    else
        fail "$description does not exist"
    fi
}

test_directory() {
    local dir=$1
    local description=${2:-$dir}

    if [[ -d "$dir" ]]; then
        pass "$description directory exists"
    else
        fail "$description directory does NOT exist"
    fi
}

test_git_config() {
    local key=$1
    local description=${2:-$key}

    local value
    value=$(git config --global "$key" 2>/dev/null)
    if [[ -n "$value" ]]; then
        pass "Git $description is configured: $value"
    else
        fail "Git $description is NOT configured"
    fi
}

# =============================================================================
# Repository Structure Tests
# =============================================================================

test_repository_structure() {
    echo ""
    info "Testing repository structure..."

    test_file "$SCRIPT_DIR/bootstrap.sh" "bootstrap.sh"
    test_file "$SCRIPT_DIR/install.sh" "install.sh"
    test_file "$SCRIPT_DIR/setup.sh" "setup.sh"
    test_file "$SCRIPT_DIR/uninstall.sh" "uninstall.sh"
    test_file "$SCRIPT_DIR/update.sh" "update.sh"
    test_file "$SCRIPT_DIR/Brewfile" "Brewfile"
    test_file "$SCRIPT_DIR/.env.example" ".env.example"
    test_file "$SCRIPT_DIR/lib/common.sh" "lib/common.sh"

    test_directory "$SCRIPT_DIR/scripts" "scripts directory"
    test_directory "$SCRIPT_DIR/config" "config directory"
    test_directory "$SCRIPT_DIR/lib" "lib directory"
}

# =============================================================================
# Homebrew Tests
# =============================================================================

test_homebrew() {
    echo ""
    info "Testing Homebrew..."

    test_command "brew" "Homebrew"

    if command -v brew &>/dev/null; then
        # Check Homebrew health
        if brew doctor &>/dev/null; then
            pass "Homebrew is healthy"
        else
            warn "Homebrew has issues (run 'brew doctor' for details)"
        fi
    fi
}

# =============================================================================
# CLI Tools Tests
# =============================================================================

test_cli_tools() {
    echo ""
    info "Testing CLI tools..."

    test_command "git" "Git"
    test_command "nano" "Nano"
    test_command "delta" "Delta (git-delta)"
    test_command "eza" "Eza"
    test_command "zoxide" "Zoxide"
    test_command "fzf" "Fzf"
    test_command "fnm" "Fnm"
}

# =============================================================================
# Shell Tests
# =============================================================================

test_shell() {
    echo ""
    info "Testing Shell..."

    test_command "zsh" "Zsh"

    # Check if zsh is the default shell
    if [[ "$SHELL" == *"zsh"* ]]; then
        pass "Zsh is the default shell"
    else
        warn "Zsh is NOT the default shell (current: $SHELL)"
    fi

    # Check zsh-snap
    test_directory "$HOME/.zsh-plugins/zsh-snap" "zsh-snap plugin manager"

    # Validate zshrc syntax
    if [[ -f "$HOME/.zshrc" ]]; then
        if zsh -n "$HOME/.zshrc" 2>/dev/null; then
            pass ".zshrc has valid syntax"
        else
            fail ".zshrc has syntax errors"
        fi
    fi
}

# =============================================================================
# Configuration Files Tests
# =============================================================================

test_config_files() {
    echo ""
    info "Testing configuration files..."

    # Test symlinks or files exist
    if [[ -L "$HOME/.zshrc" ]]; then
        pass ".zshrc symlink exists"
    elif [[ -f "$HOME/.zshrc" ]]; then
        warn ".zshrc exists but is not a symlink"
    else
        fail ".zshrc does not exist"
    fi

    if [[ -L "$HOME/.gitconfig" ]]; then
        pass ".gitconfig symlink exists"
    elif [[ -f "$HOME/.gitconfig" ]]; then
        warn ".gitconfig exists but is not a symlink"
    else
        fail ".gitconfig does not exist"
    fi

    test_file "$HOME/.gitignore_global" "Global gitignore"
    test_file "$HOME/.p10k.zsh" "Powerlevel10k config"
    test_file "$HOME/.zsh-functions" "Zsh functions"
}

# =============================================================================
# Git Configuration Tests
# =============================================================================

test_git_configuration() {
    echo ""
    info "Testing Git configuration..."

    test_git_config "user.name" "user.name"
    test_git_config "user.email" "user.email"

    local git_pager
    git_pager=$(git config --global core.pager 2>/dev/null)
    if [[ "$git_pager" == "delta" ]]; then
        pass "Git pager is configured to use delta"
    else
        warn "Git pager is not delta (current: ${git_pager:-default})"
    fi

    # Check for excludesfile
    local excludes
    excludes=$(git config --global core.excludesfile 2>/dev/null)
    if [[ -n "$excludes" ]]; then
        pass "Git excludesfile is configured: $excludes"
        if [[ -f "${excludes/#\~/$HOME}" ]]; then
            pass "Git excludesfile exists"
        else
            warn "Git excludesfile does not exist at $excludes"
        fi
    else
        warn "Git excludesfile is not configured"
    fi
}

# =============================================================================
# Node.js Tests
# =============================================================================

test_nodejs() {
    echo ""
    info "Testing Node.js..."

    if command -v fnm &>/dev/null; then
        # Source fnm for this test
        eval "$(fnm env --shell bash 2>/dev/null)" || true

        if command -v node &>/dev/null; then
            local node_version
            node_version=$(node --version 2>/dev/null)
            pass "Node.js is installed: $node_version"
        else
            warn "Node.js is NOT installed via fnm (run 'fnm install --lts')"
        fi

        if command -v npm &>/dev/null; then
            local npm_version
            npm_version=$(npm --version 2>/dev/null)
            pass "npm is installed: $npm_version"
        else
            warn "npm is NOT installed"
        fi

        if command -v pnpm &>/dev/null; then
            local pnpm_version
            pnpm_version=$(pnpm --version 2>/dev/null)
            pass "pnpm is installed: $pnpm_version"
        else
            warn "pnpm is NOT installed (run 'npm install -g pnpm')"
        fi
    else
        warn "fnm not available, skipping Node.js tests"
    fi
}

# =============================================================================
# SSH Tests
# =============================================================================

test_ssh() {
    echo ""
    info "Testing SSH..."

    test_directory "$HOME/.ssh" "SSH directory"

    if [[ -f "$HOME/.ssh/config" ]]; then
        pass "SSH config exists"
    else
        warn "SSH config does not exist (run './scripts/ssh.sh' to create)"
    fi

    # Check for SSH keys
    if ls "$HOME/.ssh/"*.pub &>/dev/null 2>&1; then
        local key_count
        key_count=$(ls "$HOME/.ssh/"*.pub 2>/dev/null | wc -l | tr -d ' ')
        pass "Found $key_count SSH public key(s)"
    else
        warn "No SSH public keys found"
    fi
}

# =============================================================================
# Directory Tests
# =============================================================================

test_directories() {
    echo ""
    info "Testing directories..."

    test_directory "$HOME/Screenshots" "Screenshots directory"

    # These are optional
    if [[ -d "$HOME/Developer" ]]; then
        pass "Developer directory exists"
    fi

    if [[ -d "$HOME/Work" ]]; then
        pass "Work directory exists"
    fi
}

# =============================================================================
# Application Tests
# =============================================================================

test_applications() {
    echo ""
    info "Testing applications..."

    # iTerm2
    if [[ -d "/Applications/iTerm.app" ]]; then
        pass "iTerm2 is installed"
    else
        warn "iTerm2 is NOT installed"
    fi

    # Check for Nerd Font
    if ls ~/Library/Fonts/*MesloLGS* &>/dev/null 2>&1 || ls /Library/Fonts/*MesloLGS* &>/dev/null 2>&1; then
        pass "MesloLGS Nerd Font is installed"
    else
        warn "MesloLGS Nerd Font may not be installed (check Font Book)"
    fi
}

# =============================================================================
# Claude Code Tests
# =============================================================================

test_claude_code() {
    echo ""
    info "Testing Claude Code..."

    test_command "claude" "Claude Code CLI"
    test_file "$HOME/.claude/CLAUDE.md" "Claude Code CLAUDE.md"
    test_file "$HOME/.claude/settings.json" "Claude Code settings"
    test_directory "$HOME/.claude/hooks" "Claude Code hooks"
    test_directory "$HOME/.claude/rules" "Claude Code rules"

    # Test hooks are executable
    if [[ -d "$HOME/.claude/hooks" ]]; then
        local hook_count=0
        local exec_count=0
        for hook in "$HOME/.claude/hooks/"*; do
            [[ -f "$hook" ]] || continue
            ((hook_count++))
            [[ -x "$hook" ]] && ((exec_count++))
        done
        if [[ $hook_count -gt 0 ]]; then
            if [[ $exec_count -eq $hook_count ]]; then
                pass "All $hook_count hook(s) are executable"
            else
                warn "$exec_count/$hook_count hooks are executable"
            fi
        fi
    fi

    # Test Work tier
    if [[ -d "$HOME/Work" ]]; then
        test_directory "$HOME/Work/.claude" "Work-tier Claude config"
    fi
}

# =============================================================================
# Cursor Tests
# =============================================================================

test_cursor() {
    echo ""
    info "Testing Cursor..."

    if [[ -d "/Applications/Cursor.app" ]]; then
        pass "Cursor is installed"
    else
        warn "Cursor is NOT installed"
        return 0
    fi

    local cursor_user_dir="$HOME/Library/Application Support/Cursor/User"
    test_file "$cursor_user_dir/settings.json" "Cursor settings"
    test_file "$cursor_user_dir/keybindings.json" "Cursor keybindings"

    # Count extensions
    if command -v cursor &>/dev/null; then
        local ext_count
        ext_count=$(cursor --list-extensions 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$ext_count" -gt 0 ]]; then
            pass "Cursor has $ext_count extension(s) installed"
        else
            warn "No Cursor extensions found"
        fi
    else
        warn "Cursor CLI not in PATH (install Shell Command from Command Palette)"
    fi
}

# =============================================================================
# iTerm2 Config Tests
# =============================================================================

test_iterm2_config() {
    echo ""
    info "Testing iTerm2 configuration..."

    local dyn_profiles="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    if [[ -d "$dyn_profiles" ]]; then
        if ls "$dyn_profiles"/*.json &>/dev/null 2>&1; then
            pass "iTerm2 Dynamic Profile(s) found"
        else
            warn "No iTerm2 Dynamic Profiles found"
        fi
    else
        warn "iTerm2 DynamicProfiles directory not found"
    fi
}

# =============================================================================
# Environment File Tests
# =============================================================================

test_env_file() {
    echo ""
    info "Testing environment configuration..."

    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        pass ".env file exists"

        # Check for required variables
        if grep -q "GIT_USER_NAME" "$SCRIPT_DIR/.env"; then
            pass ".env contains GIT_USER_NAME"
        else
            warn ".env is missing GIT_USER_NAME"
        fi

        if grep -q "GIT_USER_EMAIL" "$SCRIPT_DIR/.env"; then
            pass ".env contains GIT_USER_EMAIL"
        else
            warn ".env is missing GIT_USER_EMAIL"
        fi
    else
        warn ".env file does not exist (run './setup.sh' to create)"
    fi
}

# =============================================================================
# Security Tests
# =============================================================================

test_security() {
    echo ""
    info "Testing security..."

    # Check .env is not committed
    if [[ -f "$SCRIPT_DIR/.gitignore" ]]; then
        if grep -q "^\.env$" "$SCRIPT_DIR/.gitignore"; then
            pass ".env is in .gitignore"
        else
            warn ".env should be in .gitignore"
        fi
    fi

    # Check for exposed secrets in config files
    if [[ -f "$HOME/.zshrc" ]]; then
        if grep -qE "(API_KEY|SECRET|PASSWORD|TOKEN)=" "$HOME/.zshrc" 2>/dev/null; then
            warn ".zshrc may contain exposed secrets"
        else
            pass "No obvious secrets in .zshrc"
        fi
    fi
}

# =============================================================================
# Run All Tests
# =============================================================================

run_tests() {
    echo ""
    echo "=============================================="
    echo "  Dotfiles Installation Test"
    echo "=============================================="

    test_repository_structure
    test_homebrew
    test_cli_tools
    test_shell
    test_config_files
    test_git_configuration
    test_nodejs
    test_ssh
    test_directories
    test_applications
    test_claude_code
    test_cursor
    test_iterm2_config
    test_env_file
    test_security
}

# =============================================================================
# Summary
# =============================================================================

print_summary() {
    echo ""
    echo "=============================================="
    echo "  Test Summary"
    echo "=============================================="
    echo ""
    echo "  Passed:   $TESTS_PASSED"
    echo "  Failed:   $TESTS_FAILED"
    echo "  Warnings: $TESTS_WARNED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        if [[ $TESTS_WARNED -eq 0 ]]; then
            success "All tests passed!"
        else
            success "All tests passed (with $TESTS_WARNED warnings)"
        fi
        return 0
    else
        error "$TESTS_FAILED test(s) failed"
        echo ""
        echo "To fix failed tests, try running:"
        echo "  ./install.sh"
        echo ""
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    run_tests
    echo ""
    print_summary
}

main "$@"
