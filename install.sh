#!/usr/bin/env bash
set -euo pipefail

# New Mac bootstrap script
# From the dotfiles dir: bash install.sh
# Or remotely: bash <(curl -fsSL https://raw.githubusercontent.com/Njoselson/dotfiles/main/install.sh)

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
VAULT_DIR="$HOME/Documents/obsidian"
VAULT_REPO="git@github.com:Njoselson/obsidian-vault.git"

link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        echo "  backing up $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  $dst -> $src"
}

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

echo "==> Installing uv..."
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo "==> Installing Claude Code..."
if ! command -v claude &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
fi

echo ""
echo "=== Dotfiles ==="
link "$DOTFILES/.tmux.conf"   "$HOME/.tmux.conf"
link "$DOTFILES/.zshrc"       "$HOME/.zshrc"
link "$DOTFILES/.bashrc"      "$HOME/.bashrc"
link "$DOTFILES/.gitconfig"   "$HOME/.gitconfig"
link "$DOTFILES/.vimrc"       "$HOME/.vimrc"
link "$DOTFILES/.pdbrc.py"    "$HOME/.pdbrc.py"
if [ -d "$DOTFILES/nvim" ]; then
    link "$DOTFILES/nvim"     "$HOME/.config/nvim"
fi
if [ -d "$DOTFILES/lazygit" ]; then
    link "$DOTFILES/lazygit"  "$HOME/.config/lazygit"
fi

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

echo ""
echo "=== Claude Code skills ==="
if [ -d "$VAULT_DIR/_claude" ]; then
    mkdir -p "$HOME/.claude"
    ln -sf "$VAULT_DIR/_claude/commands" "$HOME/.claude/commands"
    ln -sf "$VAULT_DIR/_claude/skills"   "$HOME/.claude/skills"
    echo "  Symlinked commands + skills from $VAULT_DIR/_claude"
else
    echo "  Vault not found at $VAULT_DIR — re-run after vault clones"
fi

echo ""
echo "Done."
echo "  Reload tmux:        tmux source-file ~/.tmux.conf"
echo "  First nvim launch:  auto-installs plugins (~30s)"
echo "  See SETUP.md in the vault for MCP auth (Jira, Google Calendar, etc.)"
echo "  Restart shell:      exec zsh"
