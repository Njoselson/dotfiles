#!/usr/bin/env bash
# Pulls dotfiles and the Obsidian vault on Claude Code session start.
# Silent on success. Skips any repo with real uncommitted work rather than
# risking a clobber or a merge conflict mid-session.
set -euo pipefail

# Auto-commit append-only log/registry files (listed in the vault's
# .gitattributes as merge=union) so they never count as "uncommitted" and
# block a pull. Other dirty files still correctly block the pull below.
autocommit_union_paths() {
    local dir="$1"
    local attrs="$dir/.gitattributes"
    [ -f "$attrs" ] || return 0
    local dirty=()
    local path
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -f "$dir/$path" ] || continue
        git -C "$dir" diff --quiet -- "$path" 2>/dev/null || dirty+=("$path")
    done < <(grep -E 'merge=union' "$attrs" | awk '{print $1}')
    [ ${#dirty[@]} -eq 0 ] && return 0
    git -C "$dir" add -- "${dirty[@]}" 2>/dev/null || return 0
    git -C "$dir" commit --quiet -m "chore: sync local observation logs" -- "${dirty[@]}" 2>/dev/null || true
}

pull_if_clean() {
    local dir="$1"
    [ -d "$dir/.git" ] || return 0
    autocommit_union_paths "$dir"
    # Skip if there are still uncommitted changes (real work in progress)
    git -C "$dir" diff --quiet 2>/dev/null || return 0
    git -C "$dir" diff --cached --quiet 2>/dev/null || return 0
    # Plain pull (not --ff-only): fast-forwards when possible, and falls back
    # to a real merge — using the union driver for the paths above — when
    # another machine committed to the same log files.
    git -C "$dir" pull --no-rebase --quiet 2>/dev/null || true
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
