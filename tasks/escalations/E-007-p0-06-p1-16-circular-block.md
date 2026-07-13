# E-007 — P0-06 and P1-16 hold a circular block on `Packages/DocEngineHost`

**Filed:** 2026-07-12 · **Severity:** Medium (blocks phase-0-foundation SELECT, not a security/corruption issue)

## Problem

`tasks/backlog/phase-0-foundation/P0-06-render-v1.md` is the only unblocked
phase-0 task after fixing the P0-03 housekeeping gap (see below), but its
primary package `Packages/DocEngineHost` is held exclusively by
`tasks/in-progress/P1-16-atomic-save-backups.md`, an `[INTEGRATION]` task
whose own `Dependencies` line names **P0-06** as a prerequisite.

- P1-16 cannot finish its `DocEngineHost` scope (engine-side save modes)
  until P0-06 (render pipeline / `PDFEngineAPI` adapter) exists — its own
  Status note says so.
- P0-06 cannot be claimed because AGENT_LOOP.md §2's INTEGRATION-exclusivity
  rule reads "hold blocks others until merge," and P1-16 hasn't fully
  merged (only its `Packages/DocumentSession`-scoped portion has, as PR
  #48/`118131b`; the task file is still in `in-progress/` for the
  remaining `DocEngineHost`, `NSFileCoordinator`, and crash-recovery work).

Neither task can proceed past this point without a human decision. This
isn't a live editing conflict (P1-16 has made zero commits touching
`DocEngineHost` so far) — it's the exclusivity rule applied to a package
neither task can currently touch, which reads as a design gap in the rule
rather than a correct safety hold.

## Also fixed in this session (not an escalation, recorded for context)

`tasks/in-progress/P0-03-pdfium-build.md` had the same shape: its PR (#47,
`862e0a4`) merged to `main`, but Step 8d's move-to-`done/` never happened,
which was itself blocking P0-06's dependency check. Moved to `done/` in
commit `c45b2b3` after verifying the merge is present on `main`
(`ThirdParty/pdfium/*`, `docs/adr/ADR-001-pdfium-source-and-pin.md`).
P1-16 is a live, still-active INTEGRATION claim (unlike P0-03, which was
just an unmoved file), so the same fix does not apply here — closing it
early would hide the fact that its `DocEngineHost`/crash-recovery/
corpus-roundtrip scope is genuinely unstarted.

## Options

1. **Split P1-16.** Move its already-merged `Packages/DocumentSession`
   scope out of the task's active claim: rewrite the in-progress file to
   drop `DocEngineHost` from its `Primary package` line (keep it as a
   forward-looking requirement in Goal/Requirements, re-added as a
   dependency-gated follow-up), so it no longer exclusively holds
   `DocEngineHost` while genuinely blocked on P0-06. P0-06 becomes
   pickable immediately; P1-16 re-claims `DocEngineHost` (or a new task ID)
   once P0-06 lands.
2. **Reorder priority instead.** Treat P0-06 as effectively higher-priority
   than P1-16's remaining scope (it already is: P0-06 is Critical-path,
   Epic E2, and every phase-1 task ultimately depends on it) and have the
   next agent explicitly override the exclusivity hold for P0-06 alone,
   on the reasoning above (no live edits touching the package yet). Lower
   ceremony, but sets a precedent for overriding the exclusivity rule by
   agent judgment rather than a documented exception.
3. **Amend AGENT_LOOP.md §2** to clarify that INTEGRATION-package
   exclusivity does not apply when the holding task's own stated
   dependency is the very task requesting the package (i.e., detect and
   allow this specific ordering pattern automatically), so future agents
   don't hit this same deadlock on other packages.

## Recommendation

Option 1. It resolves the deadlock without weakening the exclusivity rule
(no precedent of "just override it"), and it's an honest reflection of
P1-16's actual state — its `DocEngineHost` portion is not in progress in
any real sense (zero commits) and shouldn't read as claimed.

## What's needed

A human (or the next agent, if this recommendation is pre-approved) to
either split P1-16 per Option 1, or explicitly authorize an exclusivity
override for P0-06. Until then, phase-0-foundation has no pickable task
and the loop should idle rather than guess.
