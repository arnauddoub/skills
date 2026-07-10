---
name: wt-list
description: List git worktrees in a readable format. Invoked as /wt-list. Also use when the user asks to list worktrees ("liste les worktrees", "quels worktrees sont ouverts ?") or asks about worktree state. Related commands - /wt-open (create), /wt-review (review a PR/branch), /wt-clean (remove).
---

# /wt-list

Rules: literal absolute paths; `git -C <path>`, never `cd && git`.

1. `git -C <root> worktree list --porcelain` (worktrees live under `<root>/.claude/worktrees/`).
2. Per worktree (main checkout first): branch, dirty? (`git -C <path> status --porcelain | head -1`), locked + session alive? (lock pid via `ps -p`), merged into origin/main?
3. Present a short readable list — name, branch, state, path — never raw git output. Flag stale entries (merged branch, orphaned lock) and suggest `/wt-clean`.
