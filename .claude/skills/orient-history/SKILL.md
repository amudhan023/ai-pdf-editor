---
name: orient-history
description: Surface prior-session findings for a package/task before starting work — phase lessons, package CLAUDE.md gotchas, open escalations, okf status. Use during AGENT_LOOP.md Step 1 (ORIENT), right after reading the task file, before reading any source.
---

# orient-history

Purpose: stop new sessions from re-deriving conclusions a previous session already
paid for. This does not replace AGENT_LOOP.md §1 Step 1's reading order — it is
the first sub-step of it, run before "the primary package's `CLAUDE.md`."

This skill only aggregates sources already sanctioned by `docs/TOKEN_EFFICIENCY.md`
§7 ("check whether the conclusion already exists" — package CLAUDE.md gotchas →
relevant spec → ADR index) and §3 ("read `phase-<n>-lessons.md` instead" of
`done/` task files). It does not introduce a new knowledge source.

## Inputs

- `primary_package` — the task's `Primary package` field (e.g. `Packages/DocEngineHost`).
- `task_id` — the task file's ID prefix (e.g. `P1-05`), used only to resolve the phase.

## Steps

1. **Resolve the phase from the task ID prefix**: `P0` → `phase-0-foundation`,
   `P1` → `phase-1-core-pillars`, `P2` → `phase-2-intelligence`,
   `P3` → `phase-3-beta-ga`. If the prefix doesn't match one of these, skip
   step 2 rather than guessing.

2. **Read `tasks/done/phase-<n>-lessons.md`** (whole file — it's a curated
   digest, kept short by design; see `distill-lessons`). If it has no entry
   naming `primary_package` or a closely related one, that's fine — say so,
   don't pad the report.

3. **Grep `tasks/escalations/*.md` for the package name** (e.g.
   `grep -l "DocEngineHost" tasks/escalations/*.md`). Read only the matching
   files' `Status`/`Resolution` fields, not the full narrative, unless the
   status is still open.

4. **Check `okf/index.md` → the relevant `okf/<dir>/*.md` concept file** for
   the package's `implementation_status`. Rung 0 per TOKEN_EFFICIENCY §1 —
   already usually done by this point in ORIENT; don't re-read if so.

5. Package `CLAUDE.md`'s own **Gotchas** section is read next as ORIENT's
   normal Step 1.3 — this skill doesn't duplicate that read, just sequences
   before it.

## Output

A short digest (aim for under 15 lines), not a re-narration of the sources:

```
## Prior findings — <primary_package>
- Lessons (phase-<n>): <bullet(s) from the lessons file that apply, or "none recorded">
- Open escalations: <ID + one-line status, or "none">
- okf status: <implementation_status + one caveat if any>
```

Append this digest under the task file's `## Journal` section as the first
entry (before "Orient:"), so it's part of the same handoff record the next
session reads. If nothing relevant turns up in any of the three sources,
still write the digest showing that — a documented "checked, found nothing"
is what stops the *next* session from re-checking too.

## When this doesn't apply

- Tasks with no `Primary package` resolvable to a phase (e.g. malformed
  header) — fall back to plain ORIENT, note the gap.
- Don't widen the search beyond these three sources "to be thorough" —
  that reintroduces the reading cost this skill exists to avoid
  (TOKEN_EFFICIENCY §2: "never read another doc to be safe").
