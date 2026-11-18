#!/bin/bash
# install.sh: copy statusline.sh to ~/.claude and point Claude Code at it.
# Keeps everything else in ~/.claude/settings.json and saves a backup first.
# Usage: ./install.sh        (from a clone)
set -euo pipefail
cd "$(dirname "$0")"

command -v jq >/dev/null || { echo "jq is required (macOS 15+ ships it; else: brew install jq / apt install jq)" >&2; exit 1; }

dest="$HOME/.claude/statusline.sh"
settings="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

install -m 0755 statusline.sh "$dest"
echo "installed $dest"

[ -s "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$settings.bak.$(date +%Y%m%d%H%M%S)"
tmp=$(mktemp)
jq '.statusLine = {type: "command", command: "~/.claude/statusline.sh", padding: 0}' "$settings" > "$tmp"
cat "$tmp" > "$settings" && rm -f "$tmp"
echo "updated $settings (backup saved next to it)"
echo "Done. The status line appears after your next message in Claude Code."
