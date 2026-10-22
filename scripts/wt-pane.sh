#!/bin/zsh
# zsh required: bash 3.2's printf %q mangles multibyte characters (e.g. em-dash)
# into invalid UTF-8, which osascript rejects with error -1700.
# Open an iTerm2 split pane in <dir>, set its name + badge, start Claude Code there.
# Usage: wt-pane.sh <dir> <name> [claude args...] [--prompt-file <path>] [--horizontal]
#
# The command is typed into the new pane's TTY before the shell's line editor owns it, so the
# kernel's canonical input queue caps it at MAX_INPUT (1024 bytes on macOS) and silently drops
# the rest — newline included, so nothing runs. A long initial prompt therefore goes through
# --prompt-file: the pane's shell expands "$(cat <path>)" itself, and the typed command stays short.
DIR="$1"; NAME="$2"; shift 2 || exit 1
[ -d "$DIR" ] || { echo "usage: wt-pane.sh <dir> <name> [claude args...] [--prompt-file <path>] [--horizontal]" >&2; exit 1; }
SPLIT="vertically"; ARGS=(); PROMPT_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --horizontal) SPLIT="horizontally" ;;
    --prompt-file) PROMPT_FILE="$2"; shift ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
[ -z "$PROMPT_FILE" ] || [ -f "$PROMPT_FILE" ] || { echo "wt-pane.sh: prompt file not found: $PROMPT_FILE" >&2; exit 1; }
CMD="claude -n $(printf %q "$NAME")"
for a in "${ARGS[@]}"; do CMD+=" $(printf %q "$a")"; done
[ -z "$PROMPT_FILE" ] || CMD+=" \"\$(cat $(printf %q "$PROMPT_FILE"))\""
INNER="cd $(printf %q "$DIR") && printf '\033]1337;SetBadgeFormat=%s\007' '$(printf %s "$NAME" | base64)' && $CMD"
BYTES=$(printf %s "$INNER" | wc -c | tr -d ' ')
[ "$BYTES" -le 1000 ] || { echo "wt-pane.sh: command is $BYTES bytes, over the TTY's 1024-byte line limit — pass the prompt with --prompt-file" >&2; exit 1; }
exec osascript - "$SPLIT" "$NAME" "$INNER" <<'APPLESCRIPT'
on run argv
	set theSplit to item 1 of argv
	set theName to item 2 of argv
	set theCmd to item 3 of argv
	tell application "iTerm2"
		tell current session of current window
			if theSplit is equal to "horizontally" then
				set newSession to (split horizontally with default profile)
			else
				set newSession to (split vertically with default profile)
			end if
		end tell
		tell newSession
			set name to theName
			write text theCmd
		end tell
	end tell
end run
APPLESCRIPT
