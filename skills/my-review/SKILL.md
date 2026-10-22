---
name: my-review
description: Wrapper around the code-review skill — same two-axis process (Standards + Spec in parallel sub-agents), but the final report is a short verdict-first decision document grouped by severity. Invoked as /my-review [fixed-point]. Use when the user asks for a concise, actionable review since a fixed point.
---

Wrapper around the `code-review` skill. Same process, different report.

## Process

1. Read `~/.claude/skills/code-review/SKILL.md` and follow its steps 1–4 (fixed point, spec source, standards sources, parallel sub-agents). Skip its step 5 (Aggregate).
   In step 1, keep generated files out of the diff the sub-agents read — lockfiles, ORM migration snapshots (`**/drizzle/meta/*_snapshot.json`), codegen output — with `:(exclude)` pathspecs. They are reviewed by regenerating them, not by reading them.
2. Verify the sub-agent claims yourself. A finding has two halves — the **mechanism** (what the
   code does) and the **contradiction** (the rule, decision or comment it breaks) — and the
   severity comes only from the second. Check them separately, and check the contradiction by
   re-reading it at its `file:line`: not from a sub-agent's paraphrase, not from output already in
   this conversation. A finding whose mechanism holds but whose contradiction you cannot paste
   verbatim drops a severity group, or drops.
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
