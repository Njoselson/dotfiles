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

VAULT_DIR="$HOME/Documents/obsidian"
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
        fzf

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

# --- Dotfiles (bare git) — Mac only ---
if [[ "$PLATFORM" == "Darwin" && "$CLAUDE_ONLY" == false ]]; then
    echo ""
    echo "=== Dotfiles (bare git) ==="
    if [ ! -d "$HOME/.cfg" ]; then
        git clone --bare git@github.com:Njoselson/dotfiles.git "$HOME/.cfg"
        /usr/bin/git --git-dir="$HOME/.cfg/" --work-tree="$HOME" checkout
        echo "  Dotfiles checked out to ~"
    else
        echo "  ~/.cfg already exists — skipping"
    fi

    if [ -d "$HOME/nvim" ] && [ ! -e "$HOME/.config/nvim" ]; then
        mkdir -p "$HOME/.config"
        ln -s "$HOME/nvim" "$HOME/.config/nvim"
        echo "  ~/.config/nvim -> ~/nvim"
    fi
    if [ -d "$HOME/lazygit" ] && [ ! -e "$HOME/.config/lazygit" ]; then
        mkdir -p "$HOME/.config"
        ln -s "$HOME/lazygit" "$HOME/.config/lazygit"
        echo "  ~/.config/lazygit -> ~/lazygit"
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

# Vault commands (checkin, capture, session-close, etc.)
if [ -d "$VAULT_DIR/_claude/commands" ]; then
    echo "  Commands:"
    for cmd in "$VAULT_DIR/_claude/commands"/*.md; do
        [ -f "$cmd" ] || continue
        link "$cmd" "$HOME/.claude/commands/$(basename "$cmd")"
    done
fi

# Vault skills (obsidian-cli, commit-push-pr, etc.)
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
echo "  Restart shell:      exec zsh"
