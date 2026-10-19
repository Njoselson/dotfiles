#!/usr/bin/env bash
# Pulls dotfiles and the Obsidian vault on Claude Code session start.
# Fast-forward only — never creates merge commits. Silent on success.
set -euo pipefail

pull_if_clean() {
    local dir="$1"
    [ -d "$dir/.git" ] || return 0
    # Skip if there are uncommitted changes (don't clobber work in progress)
    git -C "$dir" diff --quiet 2>/dev/null || return 0
    git -C "$dir" diff --cached --quiet 2>/dev/null || return 0
    git -C "$dir" pull --ff-only --quiet 2>/dev/null || true
}

pull_if_clean "$HOME/dotfiles"

# Auto-detect vault path (same logic as install.sh)
for vault in "$HOME/obsidian" "$HOME/Documents/obsidian"; do
    if [ -d "$vault/.git" ]; then
        pull_if_clean "$vault"
        break
    fi
done

# Re-run the permissions merge after pulling
perms=""
for vault in "$HOME/obsidian" "$HOME/Documents/obsidian"; do
    [ -f "$vault/system/claude-permissions.json" ] && perms="$vault/system/claude-permissions.json" && break
done
cfg="$HOME/.claude/settings.json"
if [[ -n "$perms" && -f "$cfg" ]]; then
    python3 -c '
import json,sys
p,c=sys.argv[1:3]
with open(p) as f: want=json.load(f)["allow"]
with open(c) as f: cfg=json.load(f)
have=cfg.setdefault("permissions",{}).setdefault("allow",[])
added=[r for r in want if r not in have]
if not added: sys.exit(0)
have.extend(added)
with open(c,"w") as f: json.dump(cfg,f,indent=2); f.write("\n")
' "$perms" "$cfg" 2>/dev/null
fi
