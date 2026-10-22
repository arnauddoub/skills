---
name: wt-project
description: Open a parent Claude Code session for a whole tracker project (e.g. a Linear project URL) in a git worktree and an iTerm2 split pane — the scoping session that reads the project's issues, frames the work and breaks it down; each issue is then worked in its own /wt-open worktree. Invoked as /wt-project <project URL | slug | name>. Also use when the user asks to open or start a project in a new pane ("ouvre ce projet dans un pane", "nouveau projet X").
argument-hint: <project URL | slug | name>
---

# /wt-project

A project session is a **parent** session: it holds the scoping and the breakdown, and spawns one `/wt-open` worktree per issue. It never implements an issue itself.

Helper scripts (allowlisted — always invoke them instead of raw osascript/cp/ln):
- `~/.claude/scripts/wt-pane.sh <dir> <name> [claude args...] [--prompt-file <path>] [--horizontal]` — split pane + badge + `claude -n <name>` in it; a long initial prompt goes through `--prompt-file`
- `~/.claude/scripts/wt-setup.sh <repo_root> <worktree>` — symlinks (`worktree.symlinkDirectories`), user permissions, `.worktreeinclude` files

Rules: literal absolute paths everywhere; `git -C <path>`, never `cd && git`. Repo root: `git rev-parse --show-toplevel` (ask which project if not in a repo). Worktrees live in `<REPO_ROOT>/.claude/worktrees/<SLUG>`. Reading the tracker (project, issues) is allowed without asking; writing to it never is.

## Steps

1. **Resolve the project**: Linear → `get_project` (with milestones and resources) on the URL slug or the name, then `list_issues` on the project (title, status, assignee, labels, priority, parent). Ask if several projects match.
2. **Branch name**: `feat/<project-slug>-requirements`, where `<project-slug>` is the tracker's slug without its trailing id (`my-project-ae91a2ba624e` → `my-project`). The repo's ticket-based branch convention does not apply: a project has no ticket. `<SLUG>` = branch with `/` → `-`.
3. **Worktree `<SLUG>` already exists** (`git -C <root> worktree list`) → resume it: `wt-pane.sh '<worktree>' '<SLUG>' --continue`. Tell the user their previous session resumes with full history. No session to resume → rerun without `--continue`.
4. **Create**:
   - Branch already exists on origin (`git -C <root> fetch origin` then `git -C <root> branch -r --list 'origin/<BRANCH>'` non-empty) → `git -C <root> worktree add <root>/.claude/worktrees/<SLUG> '<BRANCH>'`
   - New project → `git -C <root> fetch origin && git -C <root> worktree add <root>/.claude/worktrees/<SLUG> -b <BRANCH> origin/main`
5. `wt-setup.sh <root> <worktree>`
6. **Write the brief** to `~/.claude/briefs/<SLUG>.md` (`mkdir -p` it), then `wt-pane.sh '<worktree>' '<SLUG>' --prompt-file ~/.claude/briefs/<SLUG>.md`. Never pass the brief as a plain argument: the pane's TTY truncates the typed command at 1024 bytes. The brief is the session's initial prompt, written in the conversation language. It carries:
   - the project: name, identifier, URL, lead, priority, start and target dates, labels
   - the issues, numbered as the project orders them (title prefix, milestone, else creation order): `ID — title [status]`, with their parent/child structure
   - the role: scoping and breakdown first — read the issues, the existing code they touch and the relevant decision records, then propose a plan and wait for the user's agreement before any code; each issue is then worked in its own worktree via `/wt-open`, carrying the decisions taken here; never create tickets or commits without an explicit request
7. Confirm with the template below. The branch initially tracks `origin/main`; first push should be `git push -u origin <BRANCH>`.

## Output

```
branch    <BRANCH>  (from origin/main, <sha> | resumed)
worktree  .claude/worktrees/<SLUG>
pane      <SLUG>

<project name> — <identifier>, lead <name>, <priority>, target <date>
<n> issues (<status summary>):
  1. <ID>  <title>
  2. <ID>  <title>
```
