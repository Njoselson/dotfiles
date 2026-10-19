#!/usr/bin/env bash
# PermissionRequest hook: logs every command that needed a permission
# decision, so session-close/task-close can grep real prompts instead of
# scanning the conversation from memory. Pure logging — emits no `decision`
# field, so the permission flow proceeds unchanged (never auto-allows or
# auto-denies).
input="$(cat)"

for vault in "$HOME/obsidian" "$HOME/Documents/obsidian"; do
    [ -d "$vault/system" ] && LOG="$vault/system/permission-prompts.ndjson" && break
done
[ -n "${LOG:-}" ] || exit 0

python3 -c "
import json, sys, datetime
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
entry = {
    'ts': datetime.datetime.now().astimezone().isoformat(),
    'tool_name': data.get('tool_name'),
    'command': data.get('tool_input', {}).get('command', ''),
    'file_path': data.get('tool_input', {}).get('file_path', ''),
}
entry = {k: v for k, v in entry.items() if v}
with open(sys.argv[2], 'a') as f:
    f.write(json.dumps(entry) + '\n')
" "$input" "$LOG" 2>/dev/null

exit 0
