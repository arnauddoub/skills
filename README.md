# skills

Claude Code skills for a git worktree workflow on macOS + [Rex](https://rex.superlogical.com): every worktree opens as a Claude Code session in a **Rex pane** beside the current one, with dependencies symlinked and permissions carried over — you never type a `git worktree` command.

## Commands

| Command | What it does |
|---------|--------------|
| `/wt-open <name> [task]` | Create a worktree (branch named per your repo's conventions, e.g. `fix/ABC-123`) and open a Claude session on it in a pane. If the worktree already exists, **resumes its previous Claude session** with full history. |
| `/wt-review <branch \| #PR \| TICKET> [base]` | Check out a PR/branch in a disposable worktree and auto-launch a code review against the PR's own base (or a custom one). A PR on a stack is reviewed **layer by layer, bottom-up**, in one worktree and one session — only the layers you are a requested reviewer on, one verdict each. Re-running updates the branch and opens a fresh review. |
| `/wt-project <project URL \| slug \| name>` | Open a **parent** session, on Fable, for a whole tracker project: reads the project and its issues, opens a `feat/<project>-requirements` worktree and a pane whose first prompt is the project brief. Scoping and breakdown happen there; each issue then gets its own `/wt-open` worktree. Re-running resumes the session. |
| `/wt-dev [--stop]` | Run a worktree's dev stack in a pane labelled `<slug>-dev`, in the background window `Stacks`, instead of a hidden background task: you see its logs, the agent reads them with `rex capture`. |
| `/wt-clean [name]` | Safe removal, pane and dev stack included. Without arguments, sweeps: auto-removes only trivially safe worktrees (clean + nothing unpushed + no running session), asks before touching anything with real work in it. |
| `/my-review [fixed-point]` | Two-axis code review (Standards + Spec, via [mattpocock/skills](https://github.com/mattpocock/skills)' `code-review`) reported as a verdict-first summary grouped by severity. This is what `/wt-review` launches in its pane. |
| `/post-review [blocking\|all] [PR]` | Submit the findings of a review already in context as a GitHub review: bare **Approve** when nothing blocks, **Comment** otherwise (never request-changes), blocking points only by default. Cites what each finding contradicts; signs off as Claude. |

Each pane is labelled with what it works on — `PRO-1787 · Transplant specific block`, `#5029 · group the patient's conditions…`, a project's name — while the Claude session keeps the worktree name (`claude -n`). Its background tells the kind of work apart: red for a `fix/` or `hotfix/` branch, blue for a project, green for a review, the theme's own for anything else.

## Layout

- `skills/` — the skills; copy each directory into `~/.claude/skills/`
- `scripts/` — helpers the skills call; copy into `~/.claude/scripts/` and `chmod +x` them
  - `wt-pane.sh <dir> <name> [claude args...] [--label <text>] [--prompt-file <path>] [--tint <#RRGGBB>] [--horizontal]` — Rex pane running `claude -n <name>`, labelled `--label`; `--prompt-file` carries a long initial prompt. Refuses a second session on a worktree whose `claude` still runs, and replaces a stale pane left in it. `wt-pane.sh --close <dir>` closes every pane running in a worktree; the Rex side (listing, closing and splitting panes) is `wt-pane.lua`, run with `rex do` over one server connection
  - `wt-setup.sh <repo_root> <worktree>` — symlinks (`worktree.symlinkDirectories` from your project settings), copies `.claude/settings.local.json` (permission allowlist) and `.worktreeinclude` files into the worktree
  - `wt-dev.sh <worktree> <slug> -- <command…>` / `wt-dev.sh --stop <slug>` — the dev pane of `/wt-dev`
  - `review-board.ts` — `bun review-board.ts --repo <checkout>`: PRs where you are a requested reviewer (Enter sends `/wt-review <n>` to the Claude session running in that checkout) and, below them, your own open PRs by review state
  - `memory-board.ts` — `bun memory-board.ts`: the Mac's memory pressure, swap in use, and the apps holding the most, each counted with all its processes
  - `usage-board.ts` — `bun usage-board.ts`: the account's 5-hour and 7-day limits, then each live Claude session's model, context and cost. Reads `~/.claude/state/statusline/<session>.json`, which your status line script must write (`printf '%s' "$input" > ~/.claude/state/statusline/<session_id>.json`)
  - `pull-main.lua` — `rex do pull-main.lua repo=<path> [minutes=180]`: fast-forwards that checkout's `main` to `origin/main` at that interval, in the pane it runs in. Never merges or resets; skipped when the checkout is not on `main`
- `rex/` — Rex configuration, linked into `~/.config/rex/`
  - `init.lua` — `⇧⌘=` evens the panes out, the boards (Reviews, Memory, Usage) at about half a column; `⇧⌘L` opens the pane's Linear ticket (a project pane lists the project's open tickets), `⇧⌘G` its pull requests, bottom-up for a stack; loads rex-resume. Reads a Linear API key from the keychain (`security add-generic-password -a "$USER" -s linear-api -w`), never from a file
  - `rex-resume-settings.json` — the programs [rex-resume](https://github.com/evgeny-golubev/rex-extensions) brings back after a restart; link it to `~/.config/rex/extensions/rex-resume/settings.json`
- `claude/statusline.sh` — Claude Code status line (folder, branch, model, context), which also saves its input to `~/.claude/state/statusline/` for `usage-board.ts`; link it to `~/.claude/statusline.sh`

## Install

```bash
git clone https://github.com/arnauddoub/skills
cp -R skills/skills/* ~/.claude/skills/
mkdir -p ~/.claude/scripts && cp skills/scripts/* ~/.claude/scripts/ && chmod +x ~/.claude/scripts/wt-*.sh
```

Run Claude Code in auto mode (`"permissions": { "defaultMode": "auto" }`): it approves the skills' `git -C <path> …` commands on its own. Then add these permission rules to `~/.claude/settings.json` for the rest (replace `/Users/you` with your actual home directory — rules don't expand `~`):

```json
{
  "permissions": {
    "allow": [
      "Bash(git rev-parse *)",
      "Bash(gh pr view *)",
      "Bash(gh pr list *)",
      "Bash(ps *)",
      "Bash(lsof *)",
      "Bash(rex block ls *)",
      "Bash(rex block close *)",
      "Bash(rex capture *)",
      "Bash(/Users/you/.claude/scripts/wt-*)"
    ]
  }
}
```

Don't allow `Bash(git -C * …)`: a wildcard before the subcommand also accepts options slipped in there, and `git -c` can run any command.

### Requirements

- macOS + Rex; the skills run from a Rex terminal (`$REX_SESSION` set)
- `zsh` at `/bin/zsh` (ships with macOS) — the scripts require it: the `printf %q` of macOS's bash 3.2 mangles multibyte characters (accents, em-dashes) into invalid UTF-8
- [Claude Code](https://code.claude.com)
- `jq`, `gh` (authenticated)
- For `/wt-project`: an issue-tracker MCP (Linear) whose project/issue read tools are allowed
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
- Panes live in the Rex server, not the app: quitting the app keeps every session running.
- Skills honor repo branch conventions (`fix/TICKET` / `feat/TICKET`) and can read your issue tracker to infer the branch type.
