# skills

Claude Code skills for a frictionless git worktree workflow on macOS + iTerm2: every worktree opens as a Claude Code session in a **split pane** (never a new window or tab), with dependencies symlinked and permissions carried over — you never type a `git worktree` command.

## Commands

| Command | What it does |
|---------|--------------|
| `/wt-open <name> [task]` | Create a worktree (branch named per your repo's conventions, e.g. `fix/ABC-123`) and open a Claude session on it in a split pane. If the worktree already exists, **resumes its previous Claude session** with full history. |
| `/wt-review <branch \| #PR \| TICKET> [base]` | Check out a PR/branch in a disposable worktree and auto-launch a code review against `origin/main` (or a custom base for stacked PRs). Re-running updates the branch and opens a fresh review. |
| `/wt-list` | Readable list of worktrees: branch, dirty state, orphaned locks, merged status. |
| `/wt-clean [name]` | Safe removal. Without arguments, sweeps: auto-removes only trivially safe worktrees (clean + no local-only commits + no running session), asks before touching anything with real work in it. |
| `/my-review [fixed-point]` | Two-axis code review (Standards + Spec, via [mattpocock/skills](https://github.com/mattpocock/skills)' `code-review`) reported as a verdict-first summary grouped by severity. This is what `/wt-review` launches in its pane. |

Each pane gets the worktree name as its title (`claude -n`) and as an iTerm2 **badge** — the watermark survives Claude Code's dynamic titles, so you always know which pane is which worktree.

## Layout

- `skills/` — the skills; copy each directory into `~/.claude/skills/`
- `scripts/` — two helpers the skills call; copy into `~/.claude/scripts/` and `chmod +x` them
  - `wt-pane.sh <dir> <name> [claude args...] [--horizontal]` — iTerm2 split + badge + `claude -n <name>`
  - `wt-setup.sh <repo_root> <worktree>` — symlinks (`worktree.symlinkDirectories` from your project settings), copies `.claude/settings.local.json` (permission allowlist) and `.worktreeinclude` files into the worktree

## Install

```bash
git clone https://github.com/arnauddoub/skills
cp -R skills/skills/* ~/.claude/skills/
mkdir -p ~/.claude/scripts && cp skills/scripts/wt-*.sh ~/.claude/scripts/ && chmod +x ~/.claude/scripts/wt-*.sh
```

Then add these permission rules to `~/.claude/settings.json` so the skills run without confirmation prompts (replace `/Users/you` with your actual home directory — rules don't expand `~`):

```json
{
  "permissions": {
    "allow": [
      "Bash(git -C * worktree *)",
      "Bash(git -C * status *)",
      "Bash(git -C * branch *)",
      "Bash(git -C * fetch *)",
      "Bash(git -C * pull --ff-only*)",
      "Bash(git -C * log *)",
      "Bash(git -C * rev-parse *)",
      "Bash(git rev-parse *)",
      "Bash(gh pr view *)",
      "Bash(gh pr list *)",
      "Bash(pgrep *)",
      "Bash(ps *)",
      "Bash(lsof *)",
      "Bash(/Users/you/.claude/scripts/wt-*)"
    ]
  }
}
```

### Requirements

- macOS + [iTerm2](https://iterm2.com) (split panes via AppleScript — allow the automation prompt on first use)
- `zsh` at `/bin/zsh` (ships with macOS) — `wt-pane.sh` requires it: the `printf %q` of macOS's bash 3.2 mangles multibyte characters (accents, em-dashes) into invalid UTF-8 that AppleScript rejects with error -1700
- [Claude Code](https://code.claude.com)
- `jq`, `gh` (authenticated)
- For `/my-review` (and thus `/wt-review`): the `code-review` skill from [mattpocock/skills](https://github.com/mattpocock/skills) installed at `~/.claude/skills/code-review/`

### Recommended per-project settings

In each repo's `.claude/settings.local.json`:

```json
{
  "worktree": {
    "baseRef": "fresh",
    "symlinkDirectories": ["node_modules"]
  }
}
```

And a `.worktreeinclude` file at the repo root listing gitignored files new worktrees need (e.g. `.env`, `.claude/settings.local.json`).

## Notes

- Worktrees live under `<repo>/.claude/worktrees/<slug>` (add `.claude/worktrees/` to `.git/info/exclude` to keep `git status` clean).
- Closing a pane never deletes the worktree: `/wt-open <name>` resumes the session where it left off; `/wt-clean` is the only thing that deletes.
- Skills honor repo branch conventions (`fix/TICKET` / `feat/TICKET`) and can read your issue tracker to infer the branch type.
