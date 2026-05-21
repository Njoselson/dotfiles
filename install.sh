#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
VAULT_DIR="$HOME/Documents/obsidian"
VAULT_REPO="git@github.com:njoselson/obsidian-vault.git"

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

echo "=== Dotfiles ==="
link "$DOTFILES/.tmux.conf"       "$HOME/.tmux.conf"
link "$DOTFILES/nvim"             "$HOME/.config/nvim"
link "$DOTFILES/lazygit"          "$HOME/.config/lazygit"

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
echo "Done."
echo "  Reload tmux: tmux source-file ~/.tmux.conf"
echo "  First nvim launch will auto-install plugins (~30s)."
