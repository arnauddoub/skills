#!/bin/zsh
# Rex pane in <dir>, beside this session, running `claude -n <name>` and labelled --label (default <name>).
# wt-pane.sh --close <dir>: closes every pane whose program runs in <dir>, this one excepted. The Rex side is wt-pane.lua.
# zsh, not bash: bash 3.2's printf %q turns multibyte text into invalid UTF-8.
[ -n "$REX_SESSION" ] && command -v rex >/dev/null || { echo "wt-pane.sh: needs a Rex terminal (REX_SESSION unset)" >&2; exit 1; }
LUA="${0:A:h}/wt-pane.lua"
if [ "$1" = "--close" ]; then
  D="${2%/}"; exec rex do "$LUA" close="${D:A}"
fi
DIR="${1%/}"; NAME="$2"; shift 2 || exit 1
[ -d "$DIR" ] || { echo "usage: wt-pane.sh <dir> <name> [claude args...] [--label <text>] [--prompt-file <path>] [--tint <#RRGGBB>] [--horizontal] | wt-pane.sh --close <dir>" >&2; exit 1; }
SPLIT="vertically"; ARGS=(); PROMPT_FILE=""; TINT=""; LABEL="$NAME"
while [ $# -gt 0 ]; do
  case "$1" in
    --horizontal) SPLIT="horizontally" ;;
    --prompt-file) PROMPT_FILE="$2"; shift ;;
    --tint) TINT="${2#\#}"; shift ;;
    --label) LABEL="$2"; shift ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
[ -z "$PROMPT_FILE" ] || [ -f "$PROMPT_FILE" ] || { echo "wt-pane.sh: prompt file not found: $PROMPT_FILE" >&2; exit 1; }
[ -z "$TINT" ] || [[ "$TINT" =~ ^[0-9A-Fa-f]{6}$ ]] || { echo "wt-pane.sh: --tint takes #RRGGBB, got $TINT" >&2; exit 1; }
CMD="claude -n $(printf %q "$NAME")"
for a in "${ARGS[@]}"; do CMD+=" $(printf %q "$a")"; done
[ -z "$PROMPT_FILE" ] || CMD+=" \"\$(cat $(printf %q "$PROMPT_FILE"))\""
[ -z "$TINT" ] || CMD="printf '\\033]11;#$TINT\\007'; $CMD"
DIR="${DIR:A}"
[ -n "$(lsof -a -p $$ -d cwd -Fn 2>/dev/null)" ] || { echo "wt-pane.sh: cannot read process cwds — run it with the sandbox off" >&2; exit 1; }
for p in $(ps -axo pid=,comm= | awk '$2=="claude"{print $1}'); do
  case "$(lsof -a -p "$p" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" in
    "$DIR"|"$DIR"/*) echo "wt-pane.sh: a Claude session already runs in $DIR (pid $p) — quit it before opening another" >&2; exit 1 ;;
  esac
done
[ "$SPLIT" = "horizontally" ] && WHERE=below || WHERE=right
exec rex do "$LUA" dir="$DIR" label="$LABEL" split="$WHERE" cmd="$CMD"
