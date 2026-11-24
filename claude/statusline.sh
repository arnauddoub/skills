#!/bin/bash
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
[ -n "$sid" ] && mkdir -p ~/.claude/state/statusline && printf '%s' "$input" > ~/.claude/state/statusline/"$sid".json.tmp && mv ~/.claude/state/statusline/"$sid".json.tmp ~/.claude/state/statusline/"$sid".json
IFS=$'\x1f' read -r dir model pct < <(printf '%s' "$input" | jq -r '[(.workspace.project_dir // .workspace.current_dir // .cwd // ""), (.model.display_name // ""), ((.context_window.used_percentage // null) | if type == "number" then (round | tostring) else "" end)] | join("\u001f")')
out=$(printf '\033[38;2;217;119;87m%s\033[0m' "$(basename "$dir")")
if [ -n "$dir" ]; then
  branch=$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    [ "$branch" = "HEAD" ] && branch="detached"
    out="$out · $(printf '\033[2m%s\033[0m' "$branch")"
  fi
fi
[ -n "$model" ] && out="$out · $(printf '\033[2m%s\033[0m' "$model")"
if [ -n "$pct" ]; then
  p=$pct
  if [ "$p" -ge 85 ]; then c='\033[31m'; elif [ "$p" -ge 70 ]; then c='\033[33m'; else c=''; fi
  out="$out · $(printf "${c}contexte %s %%\033[0m" "$p")"
fi
printf '%s\n' "$out"
