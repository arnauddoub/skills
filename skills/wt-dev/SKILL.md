---
name: wt-dev
description: Run a worktree's dev stack or dev server in a Rex pane labelled <slug>-dev, in the background window "Stacks", instead of a hidden background task — the user sees its logs, the agent reads them with rex capture. Use whenever a session needs to start, read or stop its dev stack ("lance la stack", "démarre le dev", "regarde les logs du dev").
argument-hint: "[--stop]"
---

# /wt-dev

Needs a Rex terminal (`$REX_SESSION` set).

- **Start**: `~/.claude/scripts/wt-dev.sh <worktree> <slug> -- <command…>`. `<slug>` = the worktree's directory name. The command is the repo's own dev command, chosen by its instructions — if they say to ask before starting a stack, ask first. Chain a setup step through a shell: `-- sh -c 'bun run up && bun run dev --apps okeiro,api --plain'`.
- **Plain logs**: pass the dev command's non-dashboard flag (`--plain` in monokeiro). The pane is a TTY, so a dashboard would draw full-screen, and `rex capture` returns only its current frame.
- **Read**: `rex capture -b <slug>-dev --trim | tail -n 100`. Never `rex send` into it without the user asking.
- **Stop**: `~/.claude/scripts/wt-dev.sh --stop <slug>` closes the pane and kills what runs in it. It does not take the stack's containers down: that stays the repo's teardown command, run from the worktree.

The script never starts a second `<slug>-dev`: if one exists it says so, and the existing pane is the one to read.

## Output

```
started <slug>-dev in window Stacks — read it with: rex capture -b <slug>-dev
```
