#!/bin/bash
# Open an iTerm2 split pane in <dir>, set its name + badge, start Claude Code there.
# Usage: wt-pane.sh <dir> <name> [claude args...] [--horizontal]
DIR="$1"; NAME="$2"; shift 2 || exit 1
[ -d "$DIR" ] || { echo "usage: wt-pane.sh <dir> <name> [claude args...] [--horizontal]" >&2; exit 1; }
SPLIT="vertically"; ARGS=()
for a in "$@"; do
  if [ "$a" = "--horizontal" ]; then SPLIT="horizontally"; else ARGS+=("$a"); fi
done
CMD="claude -n $(printf %q "$NAME")"
for a in "${ARGS[@]}"; do CMD+=" $(printf %q "$a")"; done
INNER="cd $(printf %q "$DIR") && printf '\033]1337;SetBadgeFormat=%s\007' '$(printf %s "$NAME" | base64)' && $CMD"
exec osascript - "$SPLIT" "$NAME" "$INNER" <<'EOF'
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
EOF
