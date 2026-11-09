---
name: pane-label
description: Re-set the iTerm2 badge of the pane this Claude Code session runs in — the conversation's title, or a given label. Invoked as /pane-label [label]. Also use when the user asks to relabel, rename or re-badge the current pane ("remets le label", "relance le badge").
argument-hint: "[label]"
---

# /pane-label

Run `~/.claude/scripts/pane-label.sh [label]` (allowlisted) and report the line it prints.

- No argument: the badge is the conversation's title (its last `custom-title`, found through `CLAUDE_CODE_SESSION_ID`); with no title yet, the name of the git checkout or worktree the session runs in.
- With an argument: that text, as given.
- It writes the iTerm2 badge escape to the session's terminal, so it needs iTerm2 and `dangerouslyDisableSandbox` (the sandbox blocks `/dev/tty*`). It changes nothing else: no shell config, no profile setting.

## Output

```
badge « <label> » posé sur /dev/<tty>
```
