# macOS Dotfiles

Automated setup for a new macOS machine, optimized for Frontend Engineering (React, TypeScript, Next.js).

## Quick Start

Run this single command on a fresh macOS installation:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/USERNAME/dotfiles/main/bootstrap.sh)"
```

Then follow the on-screen instructions.

## What's Included

### CLI Tools
- **git** - Version control
- **nano** - Text editor
- **git-delta** - Beautiful git diffs with syntax highlighting
- **eza** - Modern replacement for `ls`
- **zoxide** - Smarter `cd` command
- **fzf** - Fuzzy finder
- **fnm** - Fast Node Manager

### Shell
- **Zsh** with Powerlevel10k theme
- **zsh-snap** plugin manager
- Plugins: autosuggestions, syntax-highlighting, history-substring-search
- Custom functions for common tasks

### Applications
- **iTerm2** - Terminal emulator
- **MesloLGS NF** - Nerd Font for terminal
- Quick Look plugins (qlcolorcode, qlstephen, qlmarkdown)

### Optional Apps (interactive installation)
- Code editors (VS Code, Cursor)
- Docker, Postman
- Rectangle, Maccy
- Browsers, communication tools, and more

## Prerequisites

- macOS Sequoia 15.5+ (Apple Silicon recommended)
- Admin access for initial setup
- Internet connection

## Installation

### Option 1: Full Bootstrap (Recommended)

For a completely fresh machine:

```bash
# Download and run bootstrap script
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/USERNAME/dotfiles/main/bootstrap.sh)"

# Navigate to dotfiles directory
cd ~/.dotfiles

# Copy and edit environment variables
cp .env.example .env
nano .env

# Run installation
./install.sh
```

### Option 2: Clone and Install

If you already have Git and Homebrew:

```bash
git clone https://github.com/USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
cp .env.example .env
nano .env
./install.sh
```

### Installation Modes

```bash
# Interactive mode (default) - prompts for each category
./install.sh

# Minimal mode - essential CLI tools only
./install.sh --minimal

# Full mode - everything including optional apps
./install.sh --full

# Preview changes without applying
./install.sh --dry-run

# Verbose output for debugging
./install.sh --verbose
```

## Post-Installation

### Manual Steps

These cannot be automated and require manual intervention:

1. **Restart Terminal**
   ```bash
   source ~/.zshrc
   # Or just open a new terminal window
   ```

2. **Configure Powerlevel10k** (if not auto-configured)
   ```bash
   p10k configure
   ```

3. **Set iTerm2 Font**
   - Open iTerm2 → Preferences (Cmd+,)
   - Go to Profiles → Text
   - Set Font to "MesloLGS NF"

4. **Set up SSH Keys**
   ```bash
   ./scripts/ssh.sh
   ```
   Follow prompts to generate keys for GitHub/GitLab.

5. **Sign into Services** (as needed)
   - App Store
   - VS Code / Cursor Settings Sync
   - 1Password, Slack, etc.

### Verification

Run the test script to verify installation:

```bash
./test.sh
```

## Directory Structure

```
dotfiles/
├── README.md                    # This file
├── bootstrap.sh                 # Initial bootstrap script
├── install.sh                   # Main installation script
├── uninstall.sh                 # Revert changes
├── update.sh                    # Update dotfiles
├── test.sh                      # Verification script
├── Brewfile                     # Homebrew packages
├── .env.example                 # Environment variables template
├── scripts/
│   ├── brew.sh                  # Homebrew installation
│   ├── macos.sh                 # macOS defaults
│   ├── shell.sh                 # Zsh configuration
│   ├── git.sh                   # Git setup
│   ├── ssh.sh                   # SSH key helper
│   ├── node.sh                  # Node.js setup
│   └── apps.sh                  # Optional apps
└── config/
    ├── zshrc                    # Zsh configuration
    ├── zsh-functions            # Custom shell functions
    ├── zprofile                 # Login shell config
    ├── p10k.zsh                 # Powerlevel10k theme
    ├── gitconfig                # Git configuration
    ├── gitignore_global         # Global gitignore
    └── editorconfig             # Editor settings
```

## Customization

### Adding Environment Variables

Edit `.env` file:

```bash
# User information
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="your@email.com"
GIT_WORK_EMAIL="work@company.com"
GIT_HOME_EMAIL="personal@email.com"
```

### Adding Homebrew Packages

Edit `Brewfile`:

```ruby
# Add formula
brew "package-name"

# Add cask (GUI app)
cask "app-name"
```

Then run:
```bash
brew bundle
```

### Adding Shell Aliases

Edit `config/zshrc` or create `~/.zshrc.local` for machine-specific aliases:

```bash
# ~/.zshrc.local (not tracked in git)
alias myalias="command"
```

### Adding Functions

Edit `config/zsh-functions`:

```bash
myfunction() {
    echo "Hello, $1!"
}
```

## Useful Commands

### Shell Functions

```bash
# Kill process on port
killport 3000

# Flush DNS cache
flushdns

# Switch Git user
git-workuser
git-homeuser

# Create directory and cd into it
mkcd new-project

# Show IP addresses
myip

# Quick HTTP server
serve 8080

# Create React component
newcomponent MyComponent
```

### Git Aliases

```bash
git st          # status
git lg          # pretty log
git co branch   # checkout
git cob branch  # checkout -b
git amend       # amend last commit
git uncommit    # undo last commit (soft)
git cleanup     # delete merged branches
git workuser    # switch to work email
git homeuser    # switch to home email
```

### Navigation

```bash
z project      # Jump to frequently used directory (zoxide)
ll             # List with details (eza)
lt             # Tree view (eza)
..             # cd ..
...            # cd ../..
```

## Troubleshooting

### Shell not loading correctly

```bash
# Check for syntax errors
zsh -n ~/.zshrc

# Reload configuration
source ~/.zshrc

# Reset zsh-snap plugins
rm -rf ~/.zsh-plugins
source ~/.zshrc
```

### Homebrew issues

```bash
# Update Homebrew
brew update

# Fix permissions
sudo chown -R $(whoami) $(brew --prefix)/*

# Doctor
brew doctor
```

### Git configuration not applied

```bash
# Re-run git setup
./scripts/git.sh

# Check current config
git config --list --show-origin
```

### Fonts not showing correctly

1. Ensure font is installed: `brew list --cask | grep font`
2. Restart iTerm2
3. Manually set font in iTerm2 preferences

### Quick Look plugins not working

```bash
# Reset Quick Look
qlmanage -r
qlmanage -r cache

# Check xattr
xattr -d com.apple.quarantine ~/Library/QuickLook/*.qlgenerator
```

## Updating

Pull latest changes and re-run:

```bash
cd ~/.dotfiles
./update.sh
```

Or manually:

```bash
cd ~/.dotfiles
git pull
./install.sh
```

## Uninstalling

To revert changes:

```bash
./uninstall.sh
```

This will:
- Restore backed-up files
- Remove symlinks
- Keep Homebrew packages (uninstall manually if needed)

## Credits

Inspired by:
- [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles)
- [thoughtbot dotfiles](https://github.com/thoughtbot/dotfiles)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [zsh-snap](https://github.com/marlonrichert/zsh-snap)

## License

MIT License - feel free to use and modify for your own setup.
