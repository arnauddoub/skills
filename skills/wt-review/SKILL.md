---
name: wt-review
description: Review a PR or branch in an isolated git worktree, in an iTerm2 split pane running /my-review. The review base defaults to the PR's own base, and a PR that sits on a stack is reviewed layer by layer, bottom-up, in one worktree. Invoked as /wt-review <branch | #PR | ABC-XXXX> [base]. Also use when the user asks to review a PR, a branch or a stack of PRs in a worktree.
argument-hint: <branche | #PR | ABC-XXXX> [base]
---

# /wt-review

Opens the branch in a disposable worktree and launches `/my-review` in an iTerm2 split pane. The main checkout is never touched.

Helper scripts (allowlisted — always invoke them instead of raw osascript/cp/ln):
- `~/.claude/scripts/wt-pane.sh <dir> <name> [claude args...] [--prompt-file <path>] [--horizontal]`
- `~/.claude/scripts/wt-setup.sh <repo_root> <worktree>`

Rules: literal absolute paths everywhere; `git -C <path>`, never `cd && git`. `<DEFAULT>` is the repo's default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).

## Steps

1. Repo root: `git rev-parse --show-toplevel` (ask which project if not in a repo).
2. Resolve the PR: PR number → that PR | ticket ID → `gh pr list --state open --json number,headRefName,title` filtered on `headRefName` matching the ticket (ask if several) | branch → `gh pr list --head <branch> --json number`. `gh pr view <n> --json number,headRefName,baseRefName,title` gives `<BRANCH>` and `<PR_BASE>`.
3. **Base**: the second argument if given; else `origin/<PR_BASE>`; else (a branch with no PR) `origin/<DEFAULT>`. Never default to `<DEFAULT>` when the PR targets another branch: that reviews every PR below it as well.
4. `<PR_BASE>` is not `<DEFAULT>` and no base was given → **Stack mode** below. Otherwise continue here.
5. `<SLUG>` = `<BRANCH>` with `/` → `-`. `git -C <root> fetch origin '<BRANCH>'`, then `git -C <root> worktree add <root>/.claude/worktrees/<SLUG> '<BRANCH>'`.
   - Worktree already exists (re-review) → `git -C <worktree> pull --ff-only` instead; on divergence (force-push), warn and propose `git -C <worktree> reset --hard origin/<BRANCH>` (disposable, but say so first).
   - Branch checked out in another non-review worktree → tell the user where; don't force.
6. `wt-setup.sh <root> <worktree>`
7. `wt-pane.sh '<worktree>' '<SLUG>' --permission-mode auto '/my-review <BASE>'` — auto mode is enough here (worktree is disposable, review is read-only); never use `--dangerously-skip-permissions`.
8. Confirm: branch, base, pane open. Suggest `/wt-clean <SLUG>` once the review is done.

## Stack mode

One worktree, one session, one verdict per layer. A PR higher in a stack assumes the ones below it, so layers are reviewed bottom-up in the same session.

1. **Walk the chain.** Down: follow `baseRefName` PR by PR until a base that is `<DEFAULT>` or has no open PR. Up: `gh pr list --state open --base <headRefName> --json number,headRefName` from the top until none (several → siblings, ask which one continues the chain).
2. **Pick the layers.** The layers where the user is a requested reviewer (`gh pr view <n> --json reviewRequests`, matched against `gh api user -q .login`); if none, the PR given alone. Layers outside that set are context, never reviewed.
3. **Worktree** on the highest picked layer, `<SLUG>` = its branch with `/` → `-`; fetch every picked branch and its base (`git -C <root> fetch origin <b1> <b2> …`); create, resume or reset it as in step 5; `wt-setup.sh`.
4. **Brief** in `~/.claude/briefs/<SLUG>.md` (`mkdir -p` it), in the conversation language: the chain bottom-up with the picked layers marked; for each picked layer, in order — `git -C <worktree> checkout --detach origin/<head>`, then the `my-review` skill with fixed point `origin/<base>`, then its report under a `#<n> <head>` heading; and the rule that a finding belongs to the lowest layer that introduces it.
5. `wt-pane.sh '<worktree>' '<SLUG>' --permission-mode auto --prompt-file ~/.claude/briefs/<SLUG>.md`
6. Confirm with the template below.

```
stack     <bottom head> → … → <top head>
review    #<n> <head> ← <base>      (one line per picked layer, bottom-up)
context   #<n> <head>               (layers in the chain, not reviewed)
worktree  .claude/worktrees/<SLUG>
pane      <SLUG>
```
