---
name: wt-open
description: Open a git worktree as a Claude Code session in a split pane (Rex) — creates it (branch named per repo conventions), or resumes the previous session if the worktree already exists. Invoked as /wt-open <name> [task description]. Also use when the user asks to start a new worktree ("nouveau worktree X") or to reopen/resume one ("rouvre fix-auth").
argument-hint: <name> [tâche]
---

# /wt-open

Helper scripts (allowlisted — always invoke them instead of raw rex/cp/ln):
- `~/.claude/scripts/wt-pane.sh <dir> <name> [claude args...] [--label <text>] [--prompt-file <path>] [--tint <#RRGGBB>] [--horizontal]` — split pane running `claude -n <name>` in a Rex pane beside this session, labelled `--label` (what the user reads; `<name>` stays the session's name). Pass a long initial prompt with `--prompt-file`. It refuses to open a second session on a worktree whose `claude` still runs, then replaces any stale pane with that label.
- `~/.claude/scripts/wt-setup.sh <repo_root> <worktree>` — symlinks (`worktree.symlinkDirectories`), user permissions, `.worktreeinclude` files

Rules: literal absolute paths everywhere; `git -C <path>`, never `cd && git`. Repo root: `git rev-parse --show-toplevel` (ask which project if not in a repo). Worktrees live in `<REPO_ROOT>/.claude/worktrees/<SLUG>`.

**Pane label** `<LABEL>`: what the work is about, readable at a glance — the identifier first, so the Rex actions that open a pane's ticket or PR still find it, then the name without a generic prefix (`Patient panel:`, `Backend —`), the whole kept under 45 characters (clip with `…`). A ticket: `<ID> · <ticket title>` (`PRO-1787 · Transplant specific block`). No ticket: the task in a few words, else `<SLUG>`.

## Steps

1. **Worktree `<SLUG>` already exists** (`git -C <root> worktree list`) → resume it:
   `wt-pane.sh '<worktree>' '<SLUG>' --label '<LABEL>' [--tint '#33181C'] --continue`
   Tell the user their previous session resumes with full history. No session to resume → rerun without `--continue` (also for an explicit fresh-session request).
2. **Branch name**: if the repo's CLAUDE.md has a branch convention (e.g. `fix/ABC-123` | `feat/ABC-123`), build `<type>/<TICKET>` — infer fix|feat from the task/ticket (reading Linear is allowed without asking); ask if unclear. A full branch name given by the user is used as-is. No convention → branch = name. `<SLUG>` = branch with `/` → `-`.
3. **Create**:
   - Branch already exists on origin (`git -C <root> fetch origin` then `git -C <root> branch -r --list 'origin/<BRANCH>'` non-empty) → check it out instead of branching: `git -C <root> worktree add <root>/.claude/worktrees/<SLUG> '<BRANCH>'` (tracks the remote branch automatically).
   - New work → `git -C <root> fetch origin && git -C <root> worktree add <root>/.claude/worktrees/<SLUG> -b <BRANCH> origin/main`
4. `wt-setup.sh <root> <worktree>`
5. `wt-pane.sh '<worktree>' '<SLUG>' --label '<LABEL>' [--tint '#33181C'] ['<task prompt>']` — pass the task (plus useful ticket context) as the initial prompt when known. `--tint '#33181C'` (red) only for a `fix/` or `hotfix/` branch, on resume too; any other branch keeps the theme's background.
6. Confirm: branch, base, pane open. Note: the branch initially tracks `origin/main`; first push should be `git push -u origin <BRANCH>`.
