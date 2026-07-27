---
name: wt-review
description: Review a PR or branch in an isolated git worktree, in an iTerm2 split pane running /my-review. Invoked as /wt-review <branch | #PR | ABC-XXXX> [base]. Also use when the user asks to review a PR or branch in a worktree.
argument-hint: <branche | #PR | ABC-XXXX> [base]
---

# /wt-review

Opens the branch in a disposable worktree and launches `/my-review` in an iTerm2 split pane. The main checkout is never touched. Default review base: `origin/main` (second argument overrides, e.g. stacked PRs).

Helper scripts (allowlisted — always invoke them instead of raw osascript/cp/ln):
- `~/.claude/scripts/wt-pane.sh <dir> <name> [claude args...] [--horizontal]`
- `~/.claude/scripts/wt-setup.sh <repo_root> <worktree>`

Rules: literal absolute paths everywhere; `git -C <path>`, never `cd && git`.

## Steps

1. Repo root: `git rev-parse --show-toplevel` (ask which project if not in a repo).
2. Resolve `<BRANCH>`: given directly | PR number → `gh pr view <num> --json headRefName -q .headRefName` | ticket ID → `gh pr list --search "ABC-XXXX" --json number,headRefName,title` (ask if several). `<SLUG>` = branch with `/` → `-`.
3. `git -C <root> fetch origin '<BRANCH>'`
4. `git -C <root> worktree add <root>/.claude/worktrees/<SLUG> '<BRANCH>'`
   - Worktree already exists (re-review) → `git -C <worktree> pull --ff-only` instead; on divergence (force-push), warn and propose `git -C <worktree> reset --hard origin/<BRANCH>` (disposable, but say so first).
   - Branch checked out in another non-review worktree → tell the user where; don't force.
5. `wt-setup.sh <root> <worktree>`
6. `wt-pane.sh '<worktree>' '<SLUG>' --permission-mode acceptEdits '/my-review <BASE>'` — auto-accept mode is enough here (worktree is disposable, review is read-only); never use `--dangerously-skip-permissions`.
7. Confirm: branch, base, pane open. The worktree is disposable — suggest `/wt-clean <SLUG>` once the review is done.
