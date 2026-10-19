#!/usr/bin/env bash
# Pulls dotfiles and the Obsidian vault on Claude Code session start.
# Silent on success. Skips any repo with real uncommitted work rather than
# risking a clobber or a merge conflict mid-session.
set -euo pipefail

# Dispatches git to the right invocation for a repo. "bare" is the special
# case for the ~/.cfg bare-repo dotfiles layout (git-dir ~/.cfg, work-tree
# $HOME — real files checked out straight into $HOME, no ~/dotfiles dir).
git_cmd() {
    local repo="$1"; shift
    if [ "$repo" = "bare" ]; then
        git --git-dir="$HOME/.cfg" --work-tree="$HOME" "$@"
    else
        git -C "$repo" "$@"
    fi
}

# Resolves a repo path to the directory .gitattributes/file-existence checks
# should use — $HOME for the bare layout, the repo dir otherwise.
work_tree_of() {
    [ "$1" = "bare" ] && echo "$HOME" || echo "$1"
}

repo_exists() {
    local repo="$1"
    if [ "$repo" = "bare" ]; then
        [ -d "$HOME/.cfg" ]
    else
        [ -d "$repo/.git" ]
    fi
}

# Auto-commit append-only log/registry files (listed in the vault's
# .gitattributes as merge=union) so they never count as "uncommitted" and
# block a pull. Other dirty files still correctly block the pull below.
autocommit_union_paths() {
    local repo="$1"
    local wt; wt="$(work_tree_of "$repo")"
    local attrs="$wt/.gitattributes"
    [ -f "$attrs" ] || return 0
    local dirty=()
    local path
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        [ -f "$wt/$path" ] || continue
        git_cmd "$repo" diff --quiet -- "$path" 2>/dev/null || dirty+=("$path")
    done < <(grep -E 'merge=union' "$attrs" | awk '{print $1}')
    [ ${#dirty[@]} -eq 0 ] && return 0
    git_cmd "$repo" add -- "${dirty[@]}" 2>/dev/null || return 0
    git_cmd "$repo" commit --quiet -m "chore: sync local observation logs" -- "${dirty[@]}" 2>/dev/null || true
}

pull_if_clean() {
    local repo="$1"
    repo_exists "$repo" || return 0
    autocommit_union_paths "$repo"
    # Skip if there are still uncommitted changes (real work in progress)
    git_cmd "$repo" diff --quiet 2>/dev/null || return 0
    git_cmd "$repo" diff --cached --quiet 2>/dev/null || return 0
    # Plain pull (not --ff-only): fast-forwards when possible, and falls back
    # to a real merge — using the union driver for the paths above — when
    # another machine committed to the same log files.
    git_cmd "$repo" pull --no-rebase --quiet 2>/dev/null || true
}

# Dotfiles: bare-repo layout (~/.cfg) takes precedence if both somehow exist,
# matching install.sh's own detection.
if [ -d "$HOME/.cfg" ]; then
    pull_if_clean bare
else
    pull_if_clean "$HOME/dotfiles"
fi

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
