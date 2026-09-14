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
VAULT_REPO="git@github.com:Njoselson/obsidian-vault.git"

# --- Locate the Obsidian vault ---
# Checked in order; first one that looks like a real vault wins.
# NOTE: a bare [ -d ] test is not enough — on macOS the filesystem is
# case-insensitive, so "$HOME/obsidian" can match a ~/Obsidian dotfiles dir
# that only holds .obsidian.vimrc. Require a vault marker instead.
VAULT_CANDIDATES=(
    "$HOME/obsidian"
    "$HOME/Documents/obsidian"
)
VAULT_DIR=""
for _candidate in "${VAULT_CANDIDATES[@]}"; do
    if [ -d "$_candidate/_claude" ] || [ -d "$_candidate/.obsidian" ] || [ -d "$_candidate/.git" ]; then
        VAULT_DIR="$_candidate"
        break
    fi
done
# No existing vault — use the first candidate as the clone target
VAULT_DIR="${VAULT_DIR:-${VAULT_CANDIDATES[0]}}"
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
    # Installed one at a time on purpose: a single bad formula name under
    # `set -e` would otherwise abort the whole script, silently skipping the
    # dotfiles, vault, and Claude Code setup below.
    BREW_PACKAGES=(
        git gh tmux neovim pyenv pyenv-virtualenv poetry node docker
        fzf fd ripgrep delta lazygit autossh hunk googleworkspace-cli
    )
    for pkg in "${BREW_PACKAGES[@]}"; do
        if brew list --versions "$pkg" &>/dev/null; then
            echo "    already installed: $pkg"
        elif brew install "$pkg" &>/dev/null; then
            echo "    installed: $pkg"
        else
            echo "    WARNING: failed to install $pkg — continuing"
        fi
    done

fi

# --- Linux dev tools (fzf, fd, ripgrep, tree-sitter) ---
if [[ "$PLATFORM" == "Linux" && "$CLAUDE_ONLY" == false ]]; then
    echo "==> Installing Linux dev tools..."
    sudo apt-get install -y fzf fd-find ripgrep > /dev/null 2>&1
    # fd is installed as fdfind on Debian — alias it
    [ ! -L /usr/local/bin/fd ] && [ -x /usr/bin/fdfind ] && sudo ln -s /usr/bin/fdfind /usr/local/bin/fd

    # tree-sitter CLI for nvim-treesitter parser compilation (v0.24.x works with glibc 2.36)
    if ! command -v tree-sitter &>/dev/null; then
        curl -sL https://github.com/tree-sitter/tree-sitter/releases/download/v0.24.7/tree-sitter-linux-x64.gz | gunzip > /tmp/tree-sitter
        chmod +x /tmp/tree-sitter
        sudo mv /tmp/tree-sitter /usr/local/bin/tree-sitter
        echo "    Installed tree-sitter $(/usr/local/bin/tree-sitter --version | awk '{print $2}')"
    fi
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

# --- tmux (Linux: build from source if <3.4, Mac: already via Homebrew) ---
if [[ "$PLATFORM" == "Linux" && "$CLAUDE_ONLY" == false ]]; then
    echo "==> Checking tmux..."
    TMUX_MIN="3.4"
    TMUX_VER="$(tmux -V 2>/dev/null | grep -oP '[\d.]+')"
    if [[ -z "$TMUX_VER" || "$(printf '%s\n' "$TMUX_MIN" "$TMUX_VER" | sort -V | head -1)" != "$TMUX_MIN" ]]; then
        echo "    tmux $TMUX_VER < $TMUX_MIN — building from source..."
        sudo apt-get install -y libevent-dev ncurses-dev build-essential bison pkg-config > /dev/null 2>&1
        TMUX_TAG="$(curl -s https://api.github.com/repos/tmux/tmux/releases/latest | grep -oP '"tag_name": "\K[^"]+')"
        cd /tmp
        curl -Lo tmux.tar.gz "https://github.com/tmux/tmux/releases/download/${TMUX_TAG}/tmux-${TMUX_TAG#v}.tar.gz"
        tar xzf tmux.tar.gz
        cd "tmux-${TMUX_TAG#v}"
        ./configure > /dev/null 2>&1 && make -j"$(nproc)" > /dev/null 2>&1 && sudo make install > /dev/null 2>&1
        cd /tmp && rm -rf tmux.tar.gz "tmux-${TMUX_TAG#v}"
        echo "    Installed $(tmux -V)"
    else
        echo "    Already tmux $TMUX_VER"
    fi
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
        curl -Lo /tmp/nvim.appimage https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
        chmod u+x /tmp/nvim.appimage
        if /tmp/nvim.appimage --version &>/dev/null; then
            sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
        else
            # No FUSE — extract appimage
            cd /tmp && ./nvim.appimage --appimage-extract > /dev/null 2>&1
            sudo rm -rf /opt/nvim-appimage
            sudo mv squashfs-root /opt/nvim-appimage
            sudo ln -sf /opt/nvim-appimage/usr/bin/nvim /usr/local/bin/nvim
            rm /tmp/nvim.appimage
        fi
        echo "    Installed $(/usr/local/bin/nvim --version | head -1)"
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

    echo "==> Installing Operon CLI..."
    if ! command -v operon &>/dev/null; then
        npm install --global @stratejya/operon-cli
    fi
fi

# --- Dotfiles (symlinks) ---
if [[ "$CLAUDE_ONLY" == false && -d "$HOME/.cfg" ]]; then
    echo ""
    echo "=== Dotfiles: SKIPPED ==="
    echo "  This machine uses the older bare-repo layout (~/.cfg), which checks"
    echo "  real files into \$HOME. Symlinking them to $DOTFILES_DIR would leave two"
    echo "  systems both tracking \$HOME, and the next 'config checkout' would fight them."
    echo "  Update dotfiles with:  config pull"
    echo "  To migrate to symlinks: remove ~/.cfg first, then re-run."
elif [[ "$CLAUDE_ONLY" == false ]]; then
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
    if [ -f "$DOTFILES_DIR/ssh_config" ]; then
        mkdir -p "$HOME/.ssh/cm"
        chmod 700 "$HOME/.ssh"
        link "$DOTFILES_DIR/ssh_config" "$HOME/.ssh/config"
    fi

    # Config dirs
    if [ -d "$DOTFILES_DIR/nvim" ]; then
        link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
    fi
    if [ -d "$DOTFILES_DIR/lazygit" ]; then
        link "$DOTFILES_DIR/lazygit" "$HOME/.config/lazygit"
    fi
    if [ -f "$DOTFILES_DIR/hunk/config.toml" ]; then
        mkdir -p "$HOME/.config/hunk"
        link "$DOTFILES_DIR/hunk/config.toml" "$HOME/.config/hunk/config.toml"
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

# --- Operon CLI setup ---
if command -v operon &>/dev/null && [ -d "$VAULT_DIR" ]; then
    echo ""
    echo "=== Operon CLI ==="
    if ! operon health --json &>/dev/null 2>&1; then
        echo "  Setting up Operon profile for vault..."
        # Non-fatal: --live needs Obsidian running with the Operon plugin loaded.
        # Under `set -e` a transport failure here would abort the whole script
        # before the Claude Code config below ever runs.
        if ! operon setup --vault "$VAULT_DIR" --name main --default --live; then
            echo "  WARNING: Operon live setup incomplete (is Obsidian running?)"
            echo "  Retry later with: operon doctor --live"
        fi
    else
        echo "  Already configured"
    fi
fi

# --- Claude Code config ---
echo ""
echo "=== Claude Code config ==="
# Older installs symlinked ~/.claude/skills and ~/.claude/commands as whole
# directories into the vault. Both must go before the mkdir below:
#   - skills: the per-skill loop needs a REAL directory, or it would write
#     self-referential links inside the vault's own _claude/skills/.
#   - commands: the vault no longer ships _claude/commands, so that symlink
#     dangles — and `mkdir -p` on a dangling symlink fails outright with
#     ENOENT, aborting the rest of this section under `set -e`.
for legacy in "$HOME/.claude/skills" "$HOME/.claude/commands"; do
    if [ -L "$legacy" ]; then
        if [ -d "$legacy" ]; then
            echo "  Replacing legacy whole-dir symlink: $legacy"
        else
            echo "  Removing dangling symlink: $legacy"
        fi
        rm "$legacy"
    fi
done

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

# Vault rules (cross-cutting agent behavior — loaded in every session, every repo;
# the vault's own CLAUDE.md only loads in sessions started inside the vault)
if [ -d "$VAULT_DIR/_claude/rules" ]; then
    echo "  Rules (vault):"
    for rule in "$VAULT_DIR/_claude/rules"/*.md; do
        [ -f "$rule" ] || continue
        link "$rule" "$HOME/.claude/rules/$(basename "$rule")"
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
