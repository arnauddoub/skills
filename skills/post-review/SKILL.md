---
name: post-review
description: Submit the findings of a review already made in this conversation as a GitHub review — Approve when the review found no blocking points, Comment otherwise. Invoked as /post-review [blocking|all] [PR]. Use when the user asks to post review findings, blocking points, a verdict on the PR, or to validate/approve it.
---

Submits findings the conversation already holds as a GitHub review. It never reviews anything
itself — if there is no review in context, say so and stop.

## Process

1. Resolve the PR: the argument if given, else `gh pr view --json number,url,state,isDraft` on the
   current branch. No PR, no post.
2. Take the findings from the review already in context. Default scope is the **Blocking** group;
   `all` posts every group, keeping the severity headings.
3. **No blocking points** → approve, bare: `gh pr review <number> --approve`, no `--body`, no
   comment. Non-blocking findings stay in the conversation. Done — skip the template.
4. Otherwise write the body to a file in the scratchpad directory, in the **repo's** language — read
   it off the PR title and the recent commit subjects, not off the conversation — and submit it with
   the **Comment** action: `gh pr review <number> --comment --body-file <file>`. Then report the
   PR's URL. Never `--request-changes`: a negative verdict belongs to a human.

## Comment template

```
## <N> blocking points

### 1. <one-line claim naming the defect, not its category>

`path/to/file.ts:lines`

<What the code does, with the identifiers that prove it.>

<The AC, documented decision or code comment it contradicts, quoted.>

Suggested fix: <one concrete change.>

---

<One line naming the groups left out, when the scope is `blocking`.>

By Claude
```

## Rules

- Post only findings verified against the code. A claim that could not be reproduced is dropped, never hedged.
- Every finding cites what it contradicts — an AC, a `docs/decisions` entry, an ADR, or the code's own comment. A finding with nothing to cite stays in the conversation.
- `By Claude` is the last line, on its own. No other attribution, no generated-with trailer.
- A review cannot be edited once submitted. Before posting a second one on the same PR, say what the
  previous review already covers and post only what is new.
- Never touch PR state: no ready/draft switch, no reviewers, no resolving threads, no merge.
