---
name: wt-status
description: Summarize every Claude Code pane of the current Rex session — which one waits for the user and on what, which is still working, which has ended — from their reported state and the tail of their screen. Invoked as /wt-status. Also use when the user asks where the sessions stand ("où en sont les panes ?", "qui m'attend ?", "fais le point sur les sessions").
---

# /wt-status

Run `~/.claude/scripts/wt-status.sh` (needs a Rex terminal). It prints one `■` line per pane of the session except this one — label, window, state and age, program, branch, status message — and, for a pane not working, the tail of its screen above Claude's input box. Read-only: never `rex send` into a pane from here.

Turn it into the report below, sorted: **blocked** (waits on a permission), then **idle Claude** (waits on the user), then **working**, then panes with no Claude running (`shell`, a dev stack, another program).

- One line per pane: what it waits for, or what it is doing, in the user's words — a question it asked, a plan awaiting a go, a PR opened, an error. Read it from the screen tail; never guess beyond it.
- An idle pane whose last message asks nothing has finished: say what it delivered.
- Name a pane by its label; an unlabelled one by its checkout and short id, as the script prints it.
- An API error, a rate limit or a failed agent in a tail is worth its own mention.

## Output

```
t'attend
  <label>   <branche>   depuis <âge>   <ce qu'elle demande>
en cours
  <label>   <branche>   <ce qu'elle fait>
terminé / sans Claude
  <label>   <état>
```
