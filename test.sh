#!/bin/bash
# test.sh: feed statusline.sh sample input and check the output. No Claude Code needed.
# Usage: ./test.sh
cd "$(dirname "$0")" || exit 1
now=$(date +%s)
fail=0

run() { printf '%s' "$1" | ./statusline.sh | sed $'s/\e\\[[0-9;]*m//g'; }

check() { # check <name> <input> <expected substring>...
  local name=$1 input=$2 out; shift 2
  out=$(run "$input")
  for want in "$@"; do
    if [[ "$out" != *"$want"* ]]; then
      echo "FAIL $name: missing '$want'"; printf '     %s\n' "$out"; fail=1; return
    fi
  done
  echo "ok   $name"
}

check "model only" '{"model":{"display_name":"Opus"}}' "Opus"
if [ "$(run '{"model":{"display_name":"Opus"}}' | wc -l | tr -d ' ')" = 1 ]; then
  echo "ok   model only is one line"
else
  echo "FAIL model only is one line"; fail=1
fi

plain=$(mktemp -d); mkdir "$plain/notes"
check "folder outside git" "{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"$plain/notes\"}}" "Opus · notes"
rm -rf "$plain"

check "git repo and branch" "{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"$PWD\"}}" \
  "$(basename "$(git rev-parse --show-toplevel)") ($(git branch --show-current)"

check "context bar" '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":12.4}}' \
  "context █░░░░░░░░░ 12%"

check "session and week" "{\"model\":{\"display_name\":\"Opus\"},\"rate_limits\":{\"five_hour\":{\"used_percentage\":3,\"resets_at\":$((now + 17670))},\"seven_day\":{\"used_percentage\":53,\"resets_at\":$((now + 331230))}}}" \
  "session ░░░░░░░░░░ 3% resets" "(in 4h54m)" "week █████░░░░░ 53% resets" "(in 3d20h)" "on pace"

check "ahead of pace" "{\"model\":{\"display_name\":\"Opus\"},\"rate_limits\":{\"seven_day\":{\"used_percentage\":80,\"resets_at\":$((now + 400000))}}}" \
  "ahead of pace (+"

check "under pace" "{\"model\":{\"display_name\":\"Opus\"},\"rate_limits\":{\"seven_day\":{\"used_percentage\":5,\"resets_at\":$((now + 100000))}}}" \
  "under pace (-"

check "week only (no session)" "{\"model\":{\"display_name\":\"Opus\"},\"rate_limits\":{\"seven_day\":{\"used_percentage\":20,\"resets_at\":$((now + 500000))}}}" \
  "week ██"

exit $fail
