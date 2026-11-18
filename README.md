# claude-statusline

A two-line status line for [Claude Code](https://code.claude.com) that shows where you are and how much of your usage you have left, at a glance.

```
Opus 5.5 · my-repo (main*) · context █░░░░░░░░░ 12%
session ░░░░░░░░░░ 3% resets 21:30 (in 4h54m) · week █████░░░░░ 53% resets Sun 13:00 (in 3d20h) on pace
```

In the terminal the bars are coloured: green under 50%, yellow from 50%, red from 80%.

## What it shows

| Part | Meaning |
|---|---|
| `Opus 5.5` | The model this session is using |
| `my-repo (main*)` | Git repo and branch of the session's folder; `*` means uncommitted changes. Outside git, just the folder name |
| `context █░░░ 12%` | How full the context window is |
| `session … resets 21:30 (in 4h54m)` | Your 5-hour usage limit, when it resets, and how long until then |
| `week … resets Sun 13:00 (in 3d20h)` | Your 7-day usage limit, the same way |
| `on pace` | Weekly use compared with how much of the week has gone by. **ahead of pace (+N%)** (red) means you'll hit the limit before it resets at this rate; **under pace** (green) means room to spare; within 10 points is **on pace** |

The `session` and `week` line appears only on plans that report usage limits (Claude Pro, Max and similar), and only after the first reply in a session. Before that you see just the first line.

## Install

You need `bash` and `jq`. macOS 15 and later ship `jq`; otherwise `brew install jq` or `apt install jq`.

```bash
git clone https://github.com/baldwinsung/claude-statusline.git
cd claude-statusline
./install.sh
```

`install.sh` copies the script to `~/.claude/statusline.sh` and sets `statusLine` in `~/.claude/settings.json`, keeping your other settings and saving a timestamped backup first. Send a message in Claude Code and the status line appears.

### Or by hand

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and `chmod +x` it.
2. Add this to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "padding": 0
     }
   }
   ```

## Test it

```bash
./test.sh
```

Feeds the script sample input and checks the output, without Claude Code. CI runs it on Linux and macOS (bash 3.2, BSD `date`) along with `shellcheck`.

To see what Claude Code actually sends, run with `CLAUDE_STATUSLINE_DEBUG=1` set in your environment; the script then saves its last input to `~/.claude/statusline-input.json`. The fields are documented at [code.claude.com/docs/en/statusline](https://code.claude.com/docs/en/statusline).

## FAQ: not working?

**I only see one line, like `Opus 5.5 · repos`.**
That's normal in a new session before the first reply: Claude Code doesn't send context or usage numbers until then. Send any message and the context bar and the `session` / `week` line appear.

**Still one line after a reply.**
Claude Code isn't sending those fields. Usually one of:

- **Signed in with an API key, not a Claude subscription.** Usage limits are only reported for Claude Pro, Max and similar plans. Run `/status` in Claude Code to see how you're logged in.
- **An older Claude Code.** Check with `claude --version`; update with `claude update`.

To see exactly what Claude Code sends, start it with debug saving on, send one message, then look at the saved input:

```bash
CLAUDE_STATUSLINE_DEBUG=1 claude
# in another terminal, after a reply:
jq '{model, context_window, rate_limits}' ~/.claude/statusline-input.json
```

If `rate_limits` is missing or `null`, your account or version isn't sending usage limits; the script has nothing to show.

**No repo or branch, just a folder name.**
The session's folder isn't inside a git repo (for example `~/repos` holding several repos). Start Claude Code inside a repo to see `repo (branch)`.

**No status line at all.**

- Check `~/.claude/settings.json` has the `statusLine` block (see [Install](#install)).
- Check the script runs by hand: `echo '{"model":{"display_name":"Opus"}}' | ~/.claude/statusline.sh` should print `Opus`.
- `jq: command not found`: install jq (`brew install jq` or `apt install jq`).
- `Permission denied`: `chmod +x ~/.claude/statusline.sh`.

**Garbled characters instead of bars or colours.**
Your terminal font or locale doesn't support Unicode block characters, or the terminal doesn't support ANSI colours. Use a UTF-8 locale and a modern terminal font.

## How it works

Claude Code runs the command after each reply and pipes it a JSON object on stdin. The script reads `model.display_name`, `workspace.current_dir`, `context_window.used_percentage`, and `rate_limits.five_hour` / `rate_limits.seven_day` (`used_percentage`, and `resets_at` in Unix seconds) with a single `jq` call, then asks `git` for the repo, branch and dirty state. Git is called with `--no-optional-locks` so it never fights your own git commands for the index lock.

## Uninstall

Delete `~/.claude/statusline.sh` and remove the `statusLine` block from `~/.claude/settings.json`.

## License

MIT
