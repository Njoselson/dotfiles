#!/usr/bin/env bash
# Read-only health check for the dotfiles/vault/Claude Code sync setup.
# Run manually on any machine:
#   symlink layout: bash ~/dotfiles/.claude/hooks/sync-doctor.sh
#   bare-repo layout: bash ~/.claude/hooks/sync-doctor.sh
# Makes no changes — only reports what sync-repos.sh and install.sh would do.
set -uo pipefail

ok()   { printf "  OK   %s\n" "$1"; }
warn() { printf "  WARN %s\n" "$1"; }
fail() { printf "  FAIL %s\n" "$1"; }

# Same git dispatch as sync-repos.sh, duplicated rather than sourced so this
# script works standalone even if copied somewhere else.
git_cmd() {
    local repo="$1"; shift
    if [ "$repo" = "bare" ]; then
        git --git-dir="$HOME/.cfg" --work-tree="$HOME" "$@"
    else
        git -C "$repo" "$@"
    fi
}

echo "=== Layout ==="
LAYOUT=none
INSTALL_CMD=""
if [ -d "$HOME/.cfg" ] && [ -d "$HOME/dotfiles/.git" ]; then
    fail "Both ~/.cfg and ~/dotfiles/.git exist — two systems tracking \$HOME (see dotfiles.md: 'Never run both')"
elif [ -d "$HOME/.cfg" ]; then
    ok "bare-repo layout (~/.cfg)"
    LAYOUT=bare
    INSTALL_CMD="bash ~/install.sh --claude-only"
elif [ -d "$HOME/dotfiles/.git" ]; then
    ok "symlink layout (~/dotfiles)"
    LAYOUT=symlink
    INSTALL_CMD="bash ~/dotfiles/install.sh --claude-only"
else
    fail "Neither ~/.cfg nor ~/dotfiles/.git found — dotfiles not installed"
fi

echo "=== Dotfiles freshness ==="
if [ "$LAYOUT" != none ]; then
    repo=$([ "$LAYOUT" = bare ] && echo bare || echo "$HOME/dotfiles")
    git_cmd "$repo" fetch --quiet origin main 2>/dev/null
    behind=$(git_cmd "$repo" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
    if [ "$behind" = "0" ]; then
        ok "dotfiles up to date"
    else
        warn "dotfiles $behind commit(s) behind origin/main"
    fi
fi

echo "=== Vault freshness ==="
VAULT=""
for v in "$HOME/obsidian" "$HOME/Documents/obsidian"; do
    [ -d "$v/.git" ] && VAULT="$v" && break
done
if [ -n "$VAULT" ]; then
    git -C "$VAULT" fetch --quiet origin main 2>/dev/null
    behind=$(git -C "$VAULT" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
    if [ "$behind" = "0" ]; then
        ok "vault up to date ($VAULT)"
    else
        warn "vault $behind commit(s) behind origin/main"
    fi
else
    fail "vault not found at ~/obsidian or ~/Documents/obsidian"
fi

CFG="$HOME/.claude/settings.json"
DOTFILES_HOOKS=(
    "SessionStart:sync-repos.sh"
    "PermissionRequest:log-permission-request.sh"
)
for entry in "${DOTFILES_HOOKS[@]}"; do
    hook_type="${entry%%:*}"
    script_name="${entry#*:}"
    echo "=== $hook_type hook ==="
    if [ ! -f "$CFG" ]; then
        fail "$CFG does not exist"
        continue
    fi
    hook_cmd=$(python3 -c "
import json
try:
    cfg = json.load(open('$CFG'))
    for e in cfg.get('hooks', {}).get('$hook_type', []):
        for h in e.get('hooks', []):
            if '$script_name' in h.get('command', ''):
                print(h['command'])
                raise SystemExit
except Exception:
    pass
")
    if [ -n "$hook_cmd" ]; then
        resolved="${hook_cmd/#\~/$HOME}"
        if [ -f "$resolved" ]; then
            ok "$hook_type hook registered: $hook_cmd (target exists)"
        else
            fail "$hook_type hook registered but target missing: $hook_cmd"
        fi
    else
        fail "no $hook_type hook for $script_name in $CFG — run: $INSTALL_CMD"
    fi
done

echo "=== Permissions merge ==="
if [ -n "$VAULT" ] && [ -f "$VAULT/system/claude-permissions.json" ] && [ -f "$CFG" ]; then
    missing=$(python3 -c "
import json
want = json.load(open('$VAULT/system/claude-permissions.json'))['allow']
have = json.load(open('$CFG')).get('permissions', {}).get('allow', [])
print(len([p for p in want if p not in have]))
")
    if [ "$missing" = "0" ]; then
        ok "all shared permissions merged"
    else
        warn "$missing shared permission(s) not yet merged into $CFG — a new shell or session will pick them up"
    fi
fi

echo "=== Memory symlink ==="
if [ -n "$VAULT" ]; then
    VAULT_ENCODED=$(echo "$VAULT" | sed 's|^/||; s|/|-|g')
    MEM_DIR="$HOME/.claude/projects/-${VAULT_ENCODED}/memory"
    if [ -L "$MEM_DIR" ]; then
        target=$(readlink "$MEM_DIR")
        if [ "$target" = "$VAULT/_claude/memory" ]; then
            ok "memory symlinked to vault"
        else
            warn "memory symlinked, but to $target, not $VAULT/_claude/memory"
        fi
    elif [ -d "$MEM_DIR" ]; then
        fail "memory is a REAL directory, not a symlink — diverged content risk"
        echo "    files here but not in vault (would be backed up to memory.bak, not merged, by $INSTALL_CMD):"
        comm -23 <(ls "$MEM_DIR" | sort) <(ls "$VAULT/_claude/memory" 2>/dev/null | sort) | sed 's/^/      /'
    else
        warn "no memory dir yet at $MEM_DIR (first session will create it)"
    fi
fi
