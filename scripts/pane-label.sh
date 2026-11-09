#!/bin/zsh
# Re-set the iTerm2 badge of the pane a Claude Code session runs in, from inside that session.
# The badge is the conversation's title (its last `custom-title` entry), else the name of the git
# checkout or worktree the session runs in, or <label> when given. Run it from inside a Claude session.
# Usage: pane-label.sh [label]
pid="${CLAUDE_PID:-}"; sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$pid" ] || { echo "pane-label.sh: CLAUDE_PID not set — run it from inside a Claude Code session" >&2; exit 1; }
tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
[ -n "$tty" ] && [ "$tty" != "??" ] && [ -w "/dev/$tty" ] || { echo "pane-label.sh: no terminal found for Claude pid $pid" >&2; exit 1; }
label="$1"
if [ -z "$label" ] && [ -n "$sid" ]; then
  log=$(ls ~/.claude/projects/*/"$sid".jsonl 2>/dev/null | head -1)
  [ -n "$log" ] && label=$(grep '"type":"custom-title"' "$log" | tail -1 | jq -r '.customTitle // empty' 2>/dev/null)
fi
if [ -z "$label" ]; then
  dir=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'); [ -n "$dir" ] || dir=$PWD
  label=$(basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")")
fi
printf '\e]1337;SetBadgeFormat=%s\a' "$(printf %s "$label" | base64)" > "/dev/$tty"
echo "badge « $label » posé sur /dev/$tty"
