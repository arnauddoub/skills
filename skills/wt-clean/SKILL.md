---
name: wt-clean
description: Remove git worktrees safely. Invoked as /wt-clean [name] — with a name, removes that worktree; without arguments, sweeps all stale worktrees (merged branches, orphaned locks, prunable entries). Also use when the user asks to clean up or remove worktrees ("nettoie fix-auth", "supprime les worktrees obsolètes").
argument-hint: "[nom]"
---

# /wt-clean

Closing a pane never removes its worktree — cleanup is always explicit, via this skill. Rules: literal absolute paths; `git -C <path>`, never `cd && git`.

## With a name

1. Resolve the path (`git -C <root> worktree list --porcelain`; worktrees live under `<root>/.claude/worktrees/`).
2. `locked`? Verify the recorded pid is dead (`ps -p <pid>`) — if a session still runs, stop and say so. Then `git -C <root> worktree unlock <path>`.
3. Dirty check: `git -C <path> status --porcelain`. Uncommitted changes → show them and ask before `remove --force`. Otherwise `git -C <root> worktree remove <path>`.
4. Branch: delete without asking if it has no own commits (HEAD == origin/main) or is merged (`branch -d`). A review branch tracking an open PR can be `-D`'d safely (the remote branch remains) — say so. Otherwise ask before `-D`.

## Without arguments: sweep

1. `git -C <root> worktree prune`.
2. For each worktree except the main checkout, report: branch, dirty?, merged into origin/main?, session alive? (lock pid via `ps -p`).
3. Auto-remove only the trivially safe ones (clean + no own commits + dead session); list them as done. Anything dirty or with real commits → propose and wait for confirmation.
