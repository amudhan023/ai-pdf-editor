---
name: distill-lessons
description: Distill a just-completed task's Journal into a short entry in its phase's lessons file, so future sessions can reuse the finding without re-reading the full task file. Use during AGENT_LOOP.md Step 7 (DOCUMENT), right before moving the task file to done/.
---

# distill-lessons

Purpose: `docs/TOKEN_EFFICIENCY.md` §3 already tells agents to read
`phase-<n>-lessons.md` instead of `tasks/done/*.md` — this skill is the other
half of that rule: the thing that actually keeps those files populated and
current. Skipping this after a task means the *next* session either re-reads
the full done task file (against the rule) or loses the finding entirely.

Also implements §7 ("Conclusions are artifacts"): analysis worth 30+ minutes
of agent time is worth 5 lines of documentation. This is the mechanical place
that documentation goes for anything not already covered by a package
`CLAUDE.md` gotcha or an ADR.

## When to run

Once per task, in Step 7 (DOCUMENT) — after the package `CLAUDE.md` and okf
updates, before Step 8d moves the task file to `tasks/done/`. Do not run this
mid-task or speculatively; the Journal must be final.

## Steps

1. Resolve the phase file from the task ID prefix (same mapping as
   `orient-history`): `tasks/done/phase-<n>-lessons.md`. Create it with a
   one-line header (`# Phase <n> — Lessons`) if it doesn't exist yet.

2. Read the task file's `## Journal` (and `## Handoff` if present) — nothing
   else; this is a distillation of what you already wrote, not new research.

3. Extract only what's **non-obvious and reusable by a different task**:
   - a gotcha discovered about the package/engine/API that isn't already in
     that package's `CLAUDE.md` (if it is, skip it here — one-fact-one-home,
     CLAUDE.md §21/TOKEN_EFFICIENCY §6)
   - a dead end ruled out, so nobody re-tries it
   - an escalation filed and why (link the `E-0xx` file, don't restate it)
   - a scope decision that could look ambiguous to a future reader (e.g. "the
     acceptance criteria's cross-package bullet was treated as a separate
     follow-up task, not expanded scope")
   Skip anything that's just restating the task's Goal/Requirements, or that's
   already captured verbatim in the package `CLAUDE.md` — a lessons entry that
   duplicates the gotcha section is pure waste, worse than no entry.

4. Append (never rewrite the file — append-only, like an ADR log) a compact
   entry:

   ```
   ## <TASK-ID> — <short title>
   - <package>: <one gotcha/dead-end/decision, one line>
   - <package>: <another, if any — max 3 bullets>
   - Escalations: <E-0xx if filed, else omit this line>
   ```

   Target 3-6 lines per task. If you can't get it under ~8 lines, the finding
   probably belongs in the package `CLAUDE.md` instead (higher-leverage: every
   future agent in that package reads it, not just ones consulting lessons).

5. If nothing in the Journal clears the bar in step 3 — the task was
   straightforward, no surprises — **do not write an entry**. A lessons file
   padded with "nothing unusual happened" entries defeats its own purpose
   (agents would have to read past them to find the ones that matter).

## Non-goals

- Not a changelog — don't record what changed, only what was *learned* that
  isn't already the obvious reading of the diff.
- Not a substitute for package `CLAUDE.md` gotchas, ADRs, or escalation files
  — those remain the source of truth for their respective facts; this file
  only points at them or records what doesn't have a better home yet.
- Don't backfill other tasks' entries while doing this — one task's Journal
  in, one entry out.
