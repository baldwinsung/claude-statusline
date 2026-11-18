#!/bin/bash
# claude-statusline: a two-line Claude Code status line.
#
#   Opus 5.5 · my-repo (main*) · context █░░░░░░░░░ 12%
#   session ░░░░░░░░░░ 3% resets 21:30 (in 4h54m) · week █████░░░░░ 53% resets Sun 13:00 (in 3d20h) on pace
#
# Line 1: model, git repo and branch (* = uncommitted changes; plain folder name
#         outside git), and how full the context window is.
# Line 2: 5-hour session and 7-day weekly usage limits, when each resets, and
#         whether this week's use is ahead of or under the pace of time passing.
#         Shown only on plans that report limits, after the session's first reply.
# Bars are green under 50%, yellow from 50%, red from 80%.
#
# Claude Code pipes JSON to this script on stdin. Needs bash and jq.
# Works on Linux (GNU or BusyBox date) and macOS (BSD date, bash 3.2).
# Set CLAUDE_STATUSLINE_DEBUG=1 to save the last input to ~/.claude/statusline-input.json.
# https://github.com/baldwinsung/claude-statusline (MIT)

in=$(cat)
if [ -n "$CLAUDE_STATUSLINE_DEBUG" ]; then
  printf '%s' "$in" > "$HOME/.claude/statusline-input.json" 2>/dev/null
fi

# One jq call. Fields are joined with the ASCII unit separator, not a tab:
# bash collapses consecutive tabs, which would shift every field after an empty one.
IFS=$'\x1f' read -r model cwd ctx s_pct s_at w_pct w_at < <(printf '%s' "$in" | jq -r '
  [ (.model.display_name // "?"),
    (.workspace.current_dir // .cwd // ""),
    (.context_window.used_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
  ] | map(tostring) | join("\u001f")')

now=$(date +%s)
G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' D=$'\e[2m' N=$'\e[0m'
SEP=" ${D}·${N} "

color() { # color <pct>
  local p=${1%.*}
  if ((p >= 80)); then echo "$R"; elif ((p >= 50)); then echo "$Y"; else echo "$G"; fi
}

bar() { # bar <pct>: ten cells plus the number, coloured
  local p=${1%.*} f i s=""
  f=$(((p + 5) / 10)); ((f > 10)) && f=10
  for ((i = 0; i < 10; i++)); do
    if ((i < f)); then s+="█"; else s+="░"; fi
  done
  printf '%s%s %d%%%s' "$(color "$p")" "$s" "$p" "$N"
}

clock() { # clock <epoch> <format>: GNU/BusyBox date -d, BSD date -r
  date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2"
}

left() { # left <epoch>: 3d20h / 4h54m / 12m
  local t=$(($1 - now))
  ((t < 0)) && t=0
  if ((t >= 86400)); then printf '%dd%dh' $((t / 86400)) $((t % 86400 / 3600))
  elif ((t >= 3600)); then printf '%dh%02dm' $((t / 3600)) $((t % 3600 / 60))
  else printf '%dm' $((t / 60)); fi
}

where() { # where <dir>: "repo (branch*)" inside git, else the folder name
  local dir=$1 top branch dirty=""
  [ -n "$dir" ] || return
  if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    [ -n "$branch" ] || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
      dirty="*"
    fi
    printf '%s (%s%s)' "${top##*/}" "${branch:-no commits}" "$dirty"
  else
    printf '%s' "${dir##*/}"
    [ "$dir" = / ] && printf /
  fi
}

line1=$model
loc=$(where "$cwd")
[ -n "$loc" ] && line1+="$SEP$loc"
[ -n "$ctx" ] && line1+="${SEP}context $(bar "$ctx")"

line2=""
if [ -n "$s_pct" ]; then
  line2="session $(bar "$s_pct")"
  [ -n "$s_at" ] && line2+=" ${D}resets $(clock "$s_at" %H:%M) (in $(left "$s_at"))${N}"
fi
if [ -n "$w_pct" ]; then
  w="week $(bar "$w_pct")"
  if [ -n "$w_at" ]; then
    w+=" ${D}resets $(clock "$w_at" '%a %H:%M') (in $(left "$w_at"))${N}"
    # Pace: weekly % used vs % of the 7-day window already gone by.
    elapsed=$(((604800 - (w_at - now)) * 100 / 604800))
    diff=$((${w_pct%.*} - elapsed))
    if ((diff > 10)); then w+=" ${R}ahead of pace (+${diff}%)${N}"
    elif ((diff < -10)); then w+=" ${G}under pace (${diff}%)${N}"
    else w+=" ${D}on pace${N}"; fi
  fi
  if [ -n "$line2" ]; then line2+="$SEP$w"; else line2=$w; fi
fi

printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
