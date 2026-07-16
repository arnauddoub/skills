---
name: my-review
description: Wrapper around the code-review skill — same two-axis process (Standards + Spec in parallel sub-agents), but the final report is a short verdict-first decision document grouped by severity. Invoked as /my-review [fixed-point]. Use when the user asks for a concise, actionable review since a fixed point.
---

Wrapper around the `code-review` skill. Same process, different report.

## Process

1. Read `~/.claude/skills/code-review/SKILL.md` and follow its steps 1–4 (fixed point, spec source, standards sources, parallel sub-agents). Skip its step 5 (Aggregate).
2. Spot-check the most severe sub-agent claims against the code before reporting; drop or soften anything that doesn't hold up.
3. Write the report from the template below, in the conversation language.

## Report template

```
<Verdict — one sentence: mergeable or not, with finding counts.>

**Blocking**
1. `file.ts:line` — problem → concrete fix

**Fix before review**
2. …

**Cosmetic**
3. …

<Optional closing note — only for interdependencies between findings.>
```

## Rules

- Merge both axes into the severity groups; the axis shows in the phrasing, never as separate sections.
- One line per finding: location → problem → fix. Nothing non-actionable, no tables, no process recap.
- Continue numbering across groups. Omit empty groups; an axis with nothing to report goes in the verdict line.
