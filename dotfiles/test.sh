#!/bin/bash
#
# Test script for dotfiles installation
#
# Verifies that all expected commands and configurations are in place.
#

set -u

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
            fail "$description symlink points to $actual_target (expected $expected_target)"
        fi
    else
        fail "$description is not a symlink"
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

# =============================================================================
# Tests
# =============================================================================

run_tests() {
    echo ""
    echo "=============================================="
    echo "  Dotfiles Installation Test"
    echo "=============================================="
    echo ""

    # -------------------------------------------------------------------------
    info "Testing Homebrew..."
    # -------------------------------------------------------------------------

    test_command "brew" "Homebrew"

    # -------------------------------------------------------------------------
    info "Testing CLI tools..."
    # -------------------------------------------------------------------------

    test_command "git" "Git"
    test_command "nano" "Nano"
    test_command "delta" "Delta (git-delta)"
    test_command "eza" "Eza"
    test_command "zoxide" "Zoxide"
    test_command "fzf" "Fzf"
    test_command "fnm" "Fnm"

    # -------------------------------------------------------------------------
    info "Testing Shell..."
    # -------------------------------------------------------------------------

    test_command "zsh" "Zsh"

    # Check if zsh is the default shell
    if [[ "$SHELL" == *"zsh"* ]]; then
        pass "Zsh is the default shell"
    else
        warn "Zsh is NOT the default shell (current: $SHELL)"
    fi

    # -------------------------------------------------------------------------
    info "Testing Configuration files..."
    # -------------------------------------------------------------------------

    local dotfiles_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"

    # Test symlinks
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

    # -------------------------------------------------------------------------
    info "Testing zsh-snap..."
    # -------------------------------------------------------------------------

    test_directory "$HOME/.zsh-plugins/zsh-snap" "zsh-snap plugin manager"

    # -------------------------------------------------------------------------
    info "Testing Git configuration..."
    # -------------------------------------------------------------------------

    local git_user
    git_user=$(git config --global user.name 2>/dev/null)
    if [[ -n "$git_user" ]]; then
        pass "Git user.name is configured: $git_user"
    else
        fail "Git user.name is NOT configured"
    fi

    local git_email
    git_email=$(git config --global user.email 2>/dev/null)
    if [[ -n "$git_email" ]]; then
        pass "Git user.email is configured: $git_email"
    else
        fail "Git user.email is NOT configured"
    fi

    local git_pager
    git_pager=$(git config --global core.pager 2>/dev/null)
    if [[ "$git_pager" == "delta" ]]; then
        pass "Git pager is configured to use delta"
    else
        warn "Git pager is not delta (current: ${git_pager:-default})"
    fi

    # -------------------------------------------------------------------------
    info "Testing Node.js..."
    # -------------------------------------------------------------------------

    if command -v fnm &>/dev/null; then
        # Source fnm for this test
        eval "$(fnm env --shell bash 2>/dev/null)"

        if command -v node &>/dev/null; then
            local node_version
            node_version=$(node --version 2>/dev/null)
            pass "Node.js is installed: $node_version"
        else
            warn "Node.js is NOT installed via fnm"
        fi

        if command -v npm &>/dev/null; then
            local npm_version
            npm_version=$(npm --version 2>/dev/null)
            pass "npm is installed: $npm_version"
        else
            warn "npm is NOT installed"
        fi
    else
        warn "fnm not available, skipping Node.js tests"
    fi

    # -------------------------------------------------------------------------
    info "Testing SSH directory..."
    # -------------------------------------------------------------------------

    test_directory "$HOME/.ssh" "SSH directory"

    if [[ -f "$HOME/.ssh/config" ]]; then
        pass "SSH config exists"
    else
        warn "SSH config does not exist (run ./scripts/ssh.sh to create)"
    fi

    # -------------------------------------------------------------------------
    info "Testing Directories..."
    # -------------------------------------------------------------------------

    test_directory "$HOME/Screenshots" "Screenshots directory"
    test_directory "$HOME/Developer" "Developer directory"
    test_directory "$HOME/Work" "Work directory"

    # -------------------------------------------------------------------------
    info "Testing Applications..."
    # -------------------------------------------------------------------------

    # iTerm2
    if [[ -d "/Applications/iTerm.app" ]]; then
        pass "iTerm2 is installed"
    else
        warn "iTerm2 is NOT installed"
    fi

    # Check for Nerd Font
    if ls ~/Library/Fonts/*MesloLGS* &>/dev/null || ls /Library/Fonts/*MesloLGS* &>/dev/null; then
        pass "MesloLGS Nerd Font is installed"
    else
        warn "MesloLGS Nerd Font may not be installed (check Font Book)"
    fi
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
