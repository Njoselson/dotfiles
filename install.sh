#!/usr/bin/env bash
set -euo pipefail

# Cross-platform bootstrap script
#
# Full setup (Mac):   bash install.sh
# VM setup (Linux):   bash install.sh
# Claude-only:        bash install.sh --claude-only
#
# On Mac: installs packages, dotfiles, vault, Claude Code config
# On Linux: installs Claude Code, vault, Claude Code config (skips Homebrew/Obsidian)

DOTFILES_DIR="$HOME/dotfiles"
VAULT_DIR="$HOME/obsidian"
VAULT_REPO="git@github.com:Njoselson/obsidian-vault.git"
DEV_STANDARDS="$HOME/code/eiq/development-standards"
PLATFORM="$(uname -s)"
CLAUDE_ONLY=false

if [[ "${1:-}" == "--claude-only" ]]; then
    CLAUDE_ONLY=true
fi

link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        echo "    backing up $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "    $dst -> $src"
}

# --- Mac-only setup ---
if [[ "$PLATFORM" == "Darwin" && "$CLAUDE_ONLY" == false ]]; then
    echo "==> Checking for Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true

    echo "==> Installing Homebrew..."
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    echo "==> Installing Homebrew packages..."
    brew install \
        git \
        gh \
        tmux \
        neovim \
        pyenv \
        poetry \
        node \
        docker \
        fzf \
        fd \
        ripgrep \
        delta

fi

# --- oh-my-zsh + plugins (cross-platform) ---
if [[ "$CLAUDE_ONLY" == false ]]; then
    echo "==> Installing oh-my-zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    echo "==> Installing zsh plugins..."
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    [ ! -d "$ZSH_CUSTOM/plugins/zsh-vi-mode" ] && \
        git clone https://github.com/jeffreytse/zsh-vi-mode "$ZSH_CUSTOM/plugins/zsh-vi-mode"
fi

# --- Neovim (Linux: appimage, Mac: already via Homebrew) ---
if [[ "$PLATFORM" == "Linux" && "$CLAUDE_ONLY" == false ]]; then
    echo "==> Installing/upgrading Neovim..."
    NVIM_MIN="0.10.0"
    needs_install=false
    if ! command -v nvim &>/dev/null; then
        needs_install=true
    elif [[ "$(nvim --version | head -1 | grep -oP '\d+\.\d+\.\d+')" < "$NVIM_MIN" ]]; then
        needs_install=true
    fi
    if $needs_install; then
        curl -Lo /tmp/nvim-linux-x86_64.appimage https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
        chmod u+x /tmp/nvim-linux-x86_64.appimage
        sudo mv /tmp/nvim-linux-x86_64.appimage /usr/local/bin/nvim
        echo "    Installed $(nvim --version | head -1)"
    else
        echo "    Already $(nvim --version | head -1)"
    fi
fi

# --- Cross-platform tools ---
if [[ "$CLAUDE_ONLY" == false ]]; then
    echo "==> Installing uv..."
    if ! command -v uv &>/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

    echo "==> Installing Claude Code..."
    if ! command -v claude &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
    fi
fi

# --- Dotfiles (symlinks) ---
if [[ "$CLAUDE_ONLY" == false ]]; then
    echo ""
    echo "=== Dotfiles (symlinks) ==="

    # Clone dotfiles repo if needed
    if [ ! -d "$DOTFILES_DIR/.git" ]; then
        echo "  Cloning dotfiles repo..."
        git clone git@github.com:njoselson/dotfiles.git "$DOTFILES_DIR"
    fi

    # Core dotfiles
    link "$DOTFILES_DIR/.zshrc"      "$HOME/.zshrc"
    link "$DOTFILES_DIR/.tmux.conf"  "$HOME/.tmux.conf"
    link "$DOTFILES_DIR/.vimrc"      "$HOME/.vimrc"
    link "$DOTFILES_DIR/.gitconfig"  "$HOME/.gitconfig"
    link "$DOTFILES_DIR/.bashrc"     "$HOME/.bashrc"
    link "$DOTFILES_DIR/.pdbrc.py"   "$HOME/.pdbrc.py"

    # Config dirs
    if [ -d "$DOTFILES_DIR/nvim" ]; then
        link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
    fi
    if [ -d "$DOTFILES_DIR/lazygit" ]; then
        link "$DOTFILES_DIR/lazygit" "$HOME/.config/lazygit"
    fi
    if [ -d "$DOTFILES_DIR/Obsidian" ]; then
        link "$DOTFILES_DIR/Obsidian" "$HOME/.config/obsidian"
    fi

    # Create .zshrc.local template if it doesn't exist
    if [ ! -f "$HOME/.zshrc.local" ]; then
        echo "  Creating ~/.zshrc.local template (fill in your secrets)"
        cat > "$HOME/.zshrc.local" <<'LOCALEOF'
# Machine-local secrets — NOT committed to dotfiles
# Fill in values for this machine.

# Claude Code (Vertex)
# export CLAUDE_CODE_USE_VERTEX=1
# export CLOUD_ML_REGION=us-east5
# export ANTHROPIC_VERTEX_PROJECT_ID=eiq-dev-dte

# W&B
# export WANDB_BASE_URL="https://wandb.evolutioniq.com"
# export WANDB_API_KEY="your-key-here"

# gws (Google Workspace CLI)
# export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="$HOME/.config/gws/credentials.json"
LOCALEOF
    else
        echo "  ~/.zshrc.local already exists — skipping"
    fi
fi

# --- Obsidian vault ---
echo ""
echo "=== Obsidian vault ==="
if [ -d "$VAULT_DIR/.git" ]; then
    echo "  Already cloned at $VAULT_DIR — pulling latest"
    git -C "$VAULT_DIR" pull --ff-only
elif [ -d "$VAULT_DIR" ]; then
    echo "  $VAULT_DIR exists but is not a git repo — skipping vault clone"
    echo "  (init it manually or remove the directory first)"
else
    echo "  Cloning vault to $VAULT_DIR"
    mkdir -p "$(dirname "$VAULT_DIR")"
    git clone "$VAULT_REPO" "$VAULT_DIR"
fi

# --- Claude Code config ---
echo ""
echo "=== Claude Code config ==="
mkdir -p "$HOME/.claude/commands" "$HOME/.claude/skills" "$HOME/.claude/rules"

# Project-level .claude symlink: vault tracks config in _claude/ (git-friendly name)
# but Claude Code reads .claude/ — symlink bridges the two
if [ -d "$VAULT_DIR/_claude" ]; then
    echo "  Project config:"
    link "$VAULT_DIR/_claude" "$VAULT_DIR/.claude"
fi

# Vault skills (morning, checkin, session-close, obsidian-cli, etc.)
if [ -d "$VAULT_DIR/_claude/skills" ]; then
    echo "  Skills (vault):"
    for skill_dir in "$VAULT_DIR/_claude/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        name=$(basename "$skill_dir")
        link "$skill_dir" "$HOME/.claude/skills/$name"
    done
fi

# Dev-standards rules (PR format, Jira workflow, validation, etc.)
if [ -d "$DEV_STANDARDS/.claude/rules" ]; then
    echo "  Rules (dev-standards):"
    for rule in "$DEV_STANDARDS/.claude/rules"/*.md; do
        [ -f "$rule" ] || continue
        link "$rule" "$HOME/.claude/rules/$(basename "$rule")"
    done
else
    echo "  SKIP: dev-standards not found at $DEV_STANDARDS"
    echo "  (clone it or update DEV_STANDARDS path in install.sh)"
fi

# Dev-standards skills
if [ -d "$DEV_STANDARDS" ]; then
    echo "  Skills (dev-standards):"
    for dir in "$DEV_STANDARDS"/community/wc/skills/*/ "$DEV_STANDARDS"/ai/skills/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        [ -f "$dir/SKILL.md" ] || continue
        # Don't overwrite vault skills
        [ -L "$HOME/.claude/skills/$name" ] && continue
        link "$dir" "$HOME/.claude/skills/$name"
    done
fi

# Memory: symlink Claude's auto-memory path to vault memory
if [ -d "$VAULT_DIR/_claude/memory" ]; then
    VAULT_ENCODED=$(echo "$VAULT_DIR" | sed 's|^/||; s|/|-|g')
    CLAUDE_MEM_DIR="$HOME/.claude/projects/-${VAULT_ENCODED}/memory"
    echo "  Memory:"
    mkdir -p "$(dirname "$CLAUDE_MEM_DIR")"
    link "$VAULT_DIR/_claude/memory" "$CLAUDE_MEM_DIR"
fi

echo ""
echo "Done."
if [[ "$PLATFORM" == "Darwin" && "$CLAUDE_ONLY" == false ]]; then
    echo "  Reload tmux:        tmux source-file ~/.tmux.conf"
    echo "  First nvim launch:  auto-installs plugins (~30s)"
fi
echo "  Run 'claude' from $VAULT_DIR for planning/check-ins."
echo "  See SETUP.md in the vault for MCP auth (Jira, Google Calendar, etc.)"
echo "  Edit ~/.zshrc.local for machine-specific secrets."
echo "  Restart shell:      exec zsh"
