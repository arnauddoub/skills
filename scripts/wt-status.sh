#!/bin/zsh
# One block per pane of the Rex session: label, what runs in it, its reported state and age, its branch.
# A pane not working (idle, blocked, done, failed) also gets the tail of its screen, above Claude's input box.
[ -n "$REX_SESSION" ] && command -v rex >/dev/null || { echo "wt-status.sh: needs a Rex terminal (REX_SESSION unset)" >&2; exit 1; }
S=(-s "${1:-$REX_SESSION}")
now=$(date +%s)
typeset -A wins
for w in ${(f)"$(rex window ls "${S[@]}" --json | jq -r '.windows[] | "\(.window_id)\t\(.label // "")"')"}; do wins[${w%%$'\t'*}]=${w#*$'\t'}; done

rex block ls "${S[@]}" --json | jq -r '.blocks[] | "\(.block_id)\t\(.label // "")\t\(.window_id)"' | while IFS=$'\t' read -r id label win; do
  [ "$id" = "$REX_BLOCK" ] && continue
  proc=$(rex block call "${S[@]}" -b "$id" process 2>/dev/null)
  prog=$(jq -r '.foreground.argv0 // .child.argv0 // "?" | split("/") | last' <<<"$proc")
  cwd=$(jq -r '.foreground.cwd // .child.cwd // ""' <<<"$proc")
  rec=$(rex block call "${S[@]}" -b "$id" program_status 2>/dev/null | jq -c '[.records[]? | select(.id == null)] | last // empty')
  state=$(jq -r '.state // empty' <<<"$rec"); msg=$(jq -r '.msg // empty' <<<"$rec")
  [ "$(jq -r '.foreground.pid // .child.pid' <<<"$proc")" = "$(jq -r '.child.pid' <<<"$proc")" ] && { state="shell"; msg=""; rec=""; }
  age=""
  ts=$(jq -r '.updated_at // empty' <<<"$rec")
  if [ -n "$ts" ]; then
    s=$(( now - $(date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" +%s 2>/dev/null || echo $now) ))
    if (( s < 60 )); then age="${s}s"; elif (( s < 3600 )); then age="$((s/60))min"; else age="$((s/3600))h$(( (s%3600)/60 ))"; fi
  fi
  branch=$([ -n "$cwd" ] && git -C "$cwd" branch --show-current 2>/dev/null)
  [ -n "$label" ] && [ "$label" != shell ] || label="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-?}")") (…${id: -6})"
  echo "■ ${label}  [${wins[$win]:-?}]  ${state:-${prog}}${age:+ · $age}  ·  $prog${branch:+  ·  $branch}${msg:+  ·  $msg}"
  case "$state" in blocked|done|error|idle)
    rex capture "${S[@]}" -b "$id" --trim --unwrap 2>/dev/null | awk '
      { line[NR] = $0 } /^────────/ { b2 = b1; b1 = NR }
      END { stop = (b2 ? b2 : NR + 1); n = 0
            for (i = stop - 1; i > 0 && n < 15; i--) if (line[i] ~ /[^[:space:]]/) { keep[++n] = line[i] }
            for (i = n; i > 0; i--) print "    " keep[i] }'
  ;; esac
done
