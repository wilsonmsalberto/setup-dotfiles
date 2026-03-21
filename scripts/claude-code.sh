#!/bin/bash
#
# Claude Code configuration script
#
# Sets up Claude Code with:
# - Global tier config (CLAUDE.md, settings, hooks, rules, skills)
# - Plugin installation
# - Work tier template
# - Playground tier template
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

CLAUDE_CONFIG_DIR="$CONFIG_DIR/claude-code"

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
# Claude Code Functions
# =============================================================================

check_claude_installed() {
    info "Checking for Claude Code CLI..."

    if command -v claude &>/dev/null; then
        success "Claude Code CLI found: $(which claude)"
        return 0
    else
        warning "Claude Code CLI not found"
        info "Install with: npm install -g @anthropic-ai/claude-code"
        info "Or visit: https://docs.anthropic.com/en/docs/claude-code"
        return 1
    fi
}

template_settings() {
    local source=$1
    local destination=$2

    if [[ ! -f "$source" ]]; then
        warning "Template not found: $source"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would template $source -> $destination"
        return 0
    fi

    backup_file "$destination"
    mkdir -p "$(dirname "$destination")"

    local content
    content=$(<"$source")
    content="${content//\{\{HOME\}\}/$HOME}"
    printf '%s\n' "$content" > "$destination"
    info "Templated settings: $destination"
}

setup_global_config() {
    info "Setting up global Claude Code configuration..."

    # Create ~/.claude/ directory
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would create $HOME/.claude/"
    else
        mkdir -p "$HOME/.claude"
    fi

    # Symlink CLAUDE.md
    create_symlink "$CLAUDE_CONFIG_DIR/global/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

    # Symlink mcp.json -> .mcp.json (note the dot prefix in destination)
    create_symlink "$CLAUDE_CONFIG_DIR/global/mcp.json" "$HOME/.claude/.mcp.json"

    # Template settings.json
    template_settings "$CLAUDE_CONFIG_DIR/global/settings.json.template" "$HOME/.claude/settings.json"

    success "Global Claude Code configuration set up"
}

setup_global_hooks() {
    info "Setting up global Claude Code hooks..."

    local hooks_source="$CLAUDE_CONFIG_DIR/global/hooks"

    if [[ ! -d "$hooks_source" ]]; then
        warning "Hooks directory not found: $hooks_source"
        return 0
    fi

    # Create ~/.claude/hooks/ directory
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would create $HOME/.claude/hooks/"
    else
        mkdir -p "$HOME/.claude/hooks"
    fi

    # Symlink each hook file
    for hook_file in "$hooks_source"/*; do
        if [[ -f "$hook_file" ]]; then
            local filename
            filename=$(basename "$hook_file")
            create_symlink "$hook_file" "$HOME/.claude/hooks/$filename"

            # Ensure hooks are executable
            if [[ "$DRY_RUN" == true ]]; then
                info "[DRY-RUN] Would chmod +x $HOME/.claude/hooks/$filename"
            else
                chmod +x "$HOME/.claude/hooks/$filename"
            fi
        fi
    done

    success "Global hooks set up"
}

setup_global_rules() {
    info "Setting up global Claude Code rules..."

    local rules_source="$CLAUDE_CONFIG_DIR/global/rules"

    if [[ ! -d "$rules_source" ]]; then
        warning "Rules directory not found: $rules_source"
        return 0
    fi

    # Create ~/.claude/rules/ directory
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would create $HOME/.claude/rules/"
    else
        mkdir -p "$HOME/.claude/rules"
    fi

    # Symlink each rule file
    for rule_file in "$rules_source"/*; do
        if [[ -f "$rule_file" ]]; then
            local filename
            filename=$(basename "$rule_file")
            create_symlink "$rule_file" "$HOME/.claude/rules/$filename"
        fi
    done

    success "Global rules set up"
}

setup_global_skills() {
    info "Setting up global Claude Code skills..."

    local skills_source="$CLAUDE_CONFIG_DIR/global/skills"

    if [[ ! -d "$skills_source" ]]; then
        warning "Skills directory not found: $skills_source"
        return 0
    fi

    # Create ~/.claude/skills/update-docs/ directory
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would create $HOME/.claude/skills/update-docs/"
    else
        mkdir -p "$HOME/.claude/skills/update-docs"
    fi

    # Copy (not symlink) skill files
    local skill_file="$skills_source/update-docs/SKILL.md"
    if [[ -f "$skill_file" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would copy $skill_file -> $HOME/.claude/skills/update-docs/SKILL.md"
        else
            backup_file "$HOME/.claude/skills/update-docs/SKILL.md"
            cp -f "$skill_file" "$HOME/.claude/skills/update-docs/SKILL.md"
            info "Copied skill: $HOME/.claude/skills/update-docs/SKILL.md"
        fi
    else
        warning "Skill file not found: $skill_file"
    fi

    success "Global skills set up"
}

install_plugins() {
    info "Installing Claude Code plugins..."

    local plugins_file="$CLAUDE_CONFIG_DIR/plugins.txt"

    if [[ ! -f "$plugins_file" ]]; then
        warning "Plugins file not found: $plugins_file"
        return 0
    fi

    # Check if claude CLI is available for plugin management
    if ! command -v claude &>/dev/null; then
        warning "Claude CLI not found, skipping plugin installation"
        return 0
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Parse: name@registry status
        local plugin_ref status
        plugin_ref=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')

        if [[ -z "$plugin_ref" ]] || [[ -z "$status" ]]; then
            warning "Skipping malformed plugin line: $line"
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would install plugin: $plugin_ref (status: $status)"
            continue
        fi

        # Install plugin (|| true to handle already-installed)
        info "Installing plugin: $plugin_ref"
        claude plugins install "$plugin_ref" || true

        # Enable or disable based on status
        local plugin_name
        plugin_name=$(echo "$plugin_ref" | cut -d'@' -f1)

        if [[ "$status" == "enabled" ]]; then
            claude plugins enable "$plugin_name" || true
            info "Enabled plugin: $plugin_name"
        elif [[ "$status" == "disabled" ]]; then
            claude plugins disable "$plugin_name" || true
            info "Disabled plugin: $plugin_name"
        fi
    done < "$plugins_file"

    success "Plugins installed"
}

setup_work_tier() {
    info "Setting up Work tier Claude Code configuration..."

    # Skip if ~/Work/ directory doesn't exist
    if [[ ! -d "$HOME/Work" ]]; then
        warning "$HOME/Work directory not found, skipping Work tier setup"
        return 0
    fi

    local work_source="$CLAUDE_CONFIG_DIR/work"

    if [[ ! -d "$work_source" ]]; then
        warning "Work tier config not found: $work_source"
        return 0
    fi

    # Create ~/Work/.claude/ directory structure
    local work_dirs=(
        "$HOME/Work/.claude"
        "$HOME/Work/.claude/hooks"
        "$HOME/Work/.claude/agents"
        "$HOME/Work/.claude/patterns"
        "$HOME/Work/.claude/skills"
    )

    for dir in "${work_dirs[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would create $dir"
        else
            mkdir -p "$dir"
        fi
    done

    # Template settings.json
    template_settings "$work_source/settings.json.template" "$HOME/Work/.claude/settings.json"

    # Copy hooks
    if [[ -d "$work_source/hooks" ]]; then
        for file in "$work_source/hooks"/*; do
            if [[ -f "$file" ]]; then
                local filename
                filename=$(basename "$file")
                if [[ "$DRY_RUN" == true ]]; then
                    info "[DRY-RUN] Would copy $file -> $HOME/Work/.claude/hooks/$filename"
                else
                    cp -f "$file" "$HOME/Work/.claude/hooks/$filename"
                    chmod +x "$HOME/Work/.claude/hooks/$filename"
                    info "Copied hook: $HOME/Work/.claude/hooks/$filename"
                fi
            fi
        done
    fi

    # Copy agents
    if [[ -d "$work_source/agents" ]]; then
        for file in "$work_source/agents"/*; do
            if [[ -f "$file" ]]; then
                local filename
                filename=$(basename "$file")
                if [[ "$DRY_RUN" == true ]]; then
                    info "[DRY-RUN] Would copy $file -> $HOME/Work/.claude/agents/$filename"
                else
                    cp -f "$file" "$HOME/Work/.claude/agents/$filename"
                    info "Copied agent: $HOME/Work/.claude/agents/$filename"
                fi
            fi
        done
    fi

    # Copy patterns
    if [[ -d "$work_source/patterns" ]]; then
        for file in "$work_source/patterns"/*; do
            if [[ -f "$file" ]]; then
                local filename
                filename=$(basename "$file")
                if [[ "$DRY_RUN" == true ]]; then
                    info "[DRY-RUN] Would copy $file -> $HOME/Work/.claude/patterns/$filename"
                else
                    cp -f "$file" "$HOME/Work/.claude/patterns/$filename"
                    info "Copied pattern: $HOME/Work/.claude/patterns/$filename"
                fi
            fi
        done
    fi

    # Copy skills (each skill is a directory with SKILL.md)
    if [[ -d "$work_source/skills" ]]; then
        for skill_dir in "$work_source/skills"/*/; do
            if [[ -d "$skill_dir" ]]; then
                local skill_name
                skill_name=$(basename "$skill_dir")
                if [[ "$DRY_RUN" == true ]]; then
                    info "[DRY-RUN] Would create $HOME/Work/.claude/skills/$skill_name/"
                else
                    mkdir -p "$HOME/Work/.claude/skills/$skill_name"
                fi
                for file in "$skill_dir"*; do
                    if [[ -f "$file" ]]; then
                        local filename
                        filename=$(basename "$file")
                        if [[ "$DRY_RUN" == true ]]; then
                            info "[DRY-RUN] Would copy $file -> $HOME/Work/.claude/skills/$skill_name/$filename"
                        else
                            cp -f "$file" "$HOME/Work/.claude/skills/$skill_name/$filename"
                            info "Copied skill: $HOME/Work/.claude/skills/$skill_name/$filename"
                        fi
                    fi
                done
            fi
        done
    fi

    success "Work tier configuration set up"
}

setup_playground_tier() {
    info "Setting up Playground tier Claude Code configuration..."

    # Skip if ~/Playground/ directory doesn't exist
    if [[ ! -d "$HOME/Playground" ]]; then
        warning "$HOME/Playground directory not found, skipping Playground tier setup"
        return 0
    fi

    local playground_source="$CLAUDE_CONFIG_DIR/playground"

    if [[ ! -d "$playground_source" ]]; then
        warning "Playground tier config not found: $playground_source"
        return 0
    fi

    # Create ~/Playground/.claude/ directory
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would create $HOME/Playground/.claude/"
    else
        mkdir -p "$HOME/Playground/.claude"
    fi

    # Template settings.json
    template_settings "$playground_source/settings.json.template" "$HOME/Playground/.claude/settings.json"

    # Copy CLAUDE.md to ~/Playground/CLAUDE.md
    local claude_md="$playground_source/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            info "[DRY-RUN] Would copy $claude_md -> $HOME/Playground/CLAUDE.md"
        else
            backup_file "$HOME/Playground/CLAUDE.md"
            mkdir -p "$HOME/Playground"
            cp -f "$claude_md" "$HOME/Playground/CLAUDE.md"
            info "Copied: $HOME/Playground/CLAUDE.md"
        fi
    else
        warning "Playground CLAUDE.md not found: $claude_md"
    fi

    success "Playground tier configuration set up"
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    info "Setting up Claude Code configuration..."
    echo ""

    # Check if config directory exists
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        error "Claude Code config directory not found: $CLAUDE_CONFIG_DIR"
        exit 1
    fi

    # Check if Claude CLI is installed (warn but don't abort)
    if ! check_claude_installed; then
        warning "Continuing without Claude CLI — config files will still be deployed"
    fi

    # Setup steps
    setup_global_config
    setup_global_hooks
    setup_global_rules
    setup_global_skills
    install_plugins
    setup_work_tier
    setup_playground_tier

    echo ""
    success "Claude Code configuration complete!"
    echo ""
    info "Global config deployed to: ~/.claude/"
    info "Work tier deployed to: ~/Work/.claude/"
    info "Playground tier deployed to: ~/Playground/.claude/"
    echo ""
}

main "$@"
