#!/bin/zsh
# Run a worktree's dev stack in a pane labelled <slug>-dev, in the Rex window "Stacks", without taking focus.
# Usage: wt-dev.sh <dir> <slug> -- <command...>   |   wt-dev.sh --stop <slug>
usage() { echo "usage: wt-dev.sh <dir> <slug> -- <command...> | wt-dev.sh --stop <slug>" >&2; exit 1; }
# A pane rex-resume brings back after a restart has REX_BLOCK but no REX_SESSION: ask Rex which session holds it.
[ -n "$REX_SESSION" ] || export REX_SESSION="$(rex whoami --json 2>/dev/null | jq -r '.session_id // empty')"
[ -n "$REX_SESSION" ] && command -v rex >/dev/null || { echo "wt-dev.sh: needs a Rex terminal (no Rex session found)" >&2; exit 1; }
S=(-s "$REX_SESSION")
blocks() { rex block ls "${S[@]}" --json | jq -r --arg l "$1" '.blocks[] | select(.label == $l) | .block_id'; }

if [ "$1" = "--stop" ]; then
  [ -n "$2" ] || usage
  ids=$(blocks "$2-dev")
  [ -n "$ids" ] || { echo "no pane $2-dev"; exit 0; }
  for b in ${(f)ids}; do rex block close "${S[@]}" "$b" >/dev/null && echo "closed $2-dev ($b)"; done
  exit 0
fi

DIR="${1%/}"; SLUG="$2"; shift 2 2>/dev/null || usage
[ "$1" = "--" ] && shift
[ -d "$DIR" ] && [ -n "$SLUG" ] && [ $# -gt 0 ] || usage
LABEL="$SLUG-dev"
existing=$(blocks "$LABEL")
[ -z "$existing" ] || { echo "already running: $LABEL (${existing//$'\n'/ }) — read it with: rex capture -b $LABEL"; exit 0; }
CMD="${(j: :)${(q)@}}; exec zsh -l"
if rex window inspect "${S[@]}" Stacks >/dev/null 2>&1; then
  rex split "${S[@]}" -w Stacks --split below --focus=false --cwd "$DIR" --label "$LABEL" --shell=none -- zsh -lic "$CMD" >/dev/null || exit 1
else
  win=$(rex run "${S[@]}" --json --focus=false --cwd "$DIR" --label "$LABEL" --shell=none -- zsh -lic "$CMD" | jq -r '.window_id')
  [ -n "$win" ] && [ "$win" != null ] || exit 1
  rex window rename "${S[@]}" "$win" Stacks >/dev/null
fi
echo "started $LABEL in window Stacks — read it with: rex capture -b $LABEL"
