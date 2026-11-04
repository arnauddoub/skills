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
3. Dirty check: `git -C <path> status --porcelain`. Uncommitted changes → show them and ask before `remove --force`.
4. **Its own stack**: a worktree may run its own Docker stack (containers whose `com.docker.compose.project.working_dir` label is `<path>`). Tear it down before removing the directory — the repo's teardown command (e.g. `bun run down`), run **from `<path>` and nowhere else**: `cd <path> && pwd` must print `<path>` in the same command, because the working directory picks the stack, and a teardown usually wipes that stack's data directories too. Never read a teardown command's `--help` by running it; read its source. No stack → skip.
5. `git -C <root> worktree remove <path>` (`--force` only after the step 3 confirmation).
6. Branch: delete without asking when nothing is unpushed — `git -C <path> rev-list --count @{u}..HEAD` is `0`, or the PR is merged. Use `-D`: a squash-merged or review branch never passes `-d`. Say that the remote branch remains. No upstream, or an unpushed commit → ask.

## Without arguments: sweep

1. `git -C <root> worktree prune`, then list the directories under `<root>/.claude/worktrees/` that are no longer registered: prune drops the entry, never the files. Report each with its size.
2. For each worktree except the main checkout, report: branch, dirty?, unpushed commits (`rev-list --count @{u}..HEAD`), PR state, session alive?
3. **Session alive** = a live `claude` whose cwd is the worktree: `lsof -c claude -a -d cwd -Fn`. Not `pgrep -f claude`, which silently misses processes.
4. Auto-remove, and list as done: clean + nothing unpushed + dead session. Tear its stack down first (step 4 of *With a name*), then delete the local branch with it (`-D`), saying the remote branch remains.
5. Propose and wait: anything dirty, carrying an unpushed commit, with no upstream, or with a live session — and the leftover directories from step 1, which git no longer knows and may hold uncommitted work.
6. **Orphaned stacks**: compose projects whose `com.docker.compose.project.working_dir` is under `<root>/.claude/worktrees/` but no longer exists (`docker ps -a --format '{{.Label "com.docker.compose.project"}} {{.Label "com.docker.compose.project.working_dir"}}'`). Report each with its containers and images; on approval remove them with `docker rm -fv` and `docker rmi`, selected by project label — the directory is gone, so there is nothing to `cd` into and no teardown command to run.

**Why not "no own commits":** `/wt-review` and `/wt-open` create worktrees on branches that carry commits by definition, so that condition never fires and every sweep asks for confirmation. Pushed is what makes a worktree disposable.
