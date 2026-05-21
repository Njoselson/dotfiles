#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

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

echo "Installing dotfiles from $DOTFILES"

link "$DOTFILES/.tmux.conf"       "$HOME/.tmux.conf"
link "$DOTFILES/nvim"             "$HOME/.config/nvim"
link "$DOTFILES/lazygit"          "$HOME/.config/lazygit"

echo ""
echo "Done. Reload tmux config with: tmux source-file ~/.tmux.conf"
echo "First nvim launch will auto-install plugins (~30s)."
