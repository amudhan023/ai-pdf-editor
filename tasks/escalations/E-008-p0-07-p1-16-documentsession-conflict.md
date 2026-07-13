# E-008 — P0-07 blocked by P1-16's exclusive hold on `Packages/DocumentSession`

**Filed:** 2026-07-12 · **Severity:** Medium (blocks phase-0-foundation SELECT, not a security/corruption issue)

## Problem

`tasks/backlog/phase-0-foundation/P0-07-shell-viewer-app.md` is the only
phase-0 task left in the backlog. Its dependency (P0-06) is satisfied
(`tasks/done/P0-06-render-v1.md`), but its primary package line names
`App/` + `Packages/DocumentSession` `[INTEGRATION]`, and `DocumentSession`
is exclusively held by `tasks/in-progress/P1-16-atomic-save-backups.md`
(also `[INTEGRATION]`, primary package `Packages/DocumentSession` (save
path) + `DocEngineHost`).

This is a live conflict, not a stale claim: P1-16's Status note lists real
unmerged `Packages/DocumentSession/Sources/Save/**` scope still open —
`NSFileCoordinator` iCloud coordination and the crash-recovery journal —
so AGENT_LOOP.md §2's exclusivity rule correctly applies here (unlike the
now-resolved `DocEngineHost` deadlock in E-007, where P1-16 had made zero
commits against the package it was blocking).

A prior iteration this session already claimed P0-07
(`615ef5b`) then released it back to `backlog/` for this exact reason
(`989fc3b`, "release P0-07 claim, package conflict with in-progress
P1-16"). This escalation is filed because the conflict is structural
(P1-16 must keep `DocumentSession` until its remaining save-path work
lands) rather than something a retry would resolve, and the loop should
idle on phase-0-foundation rather than repeatedly reclaim-and-release.

## Why this isn't E-007 reused

E-007 covered a *circular* dependency (P1-16 blocked on P0-06, which was
blocked on P1-16 holding its package) — that resolved cleanly once P0-06
merged. This is a plain resource conflict: two tasks legitimately want the
same package at the same time, with no ordering cycle to break. E-007's
Option 1 (split P1-16's claim) doesn't directly transfer, because unlike
the `DocEngineHost` portion (zero commits), the `DocumentSession` portion
has genuine in-flight scope P1-16 cannot give up without abandoning
unfinished work.

## Options

1. **Scope P0-07 down to `App/` only for this pass**, deferring the page-view
   wiring that touches `Packages/DocumentSession` until P1-16 merges (task
   would need to be rewritten/split — a scope change beyond what an agent
   should decide unilaterally, since Acceptance Criteria assume a working
   page view).
2. **Prioritize P1-16 to completion first.** It's Critical priority, already
   has an owner and Journal, and every phase-1 mutation task depends on it
   landing anyway. An idle agent could pick up P1-16's remaining scope
   (`NSFileCoordinator`, crash-recovery journal) instead of idling, if
   ownership rules permit a different agent to continue another's
   in-progress claim (AGENT_LOOP.md §2 doesn't clearly authorize this without
   a stale-claim condition, which isn't met here).
3. **Wait.** Leave both tasks as-is; the next agent that picks up P1-16 and
   finishes it unblocks P0-07 naturally. Simplest, no rule changes, costs
   idle cycles until someone works P1-16.

## Recommendation

Option 3, with Option 2 as the human-approved fast path: if a human wants
faster phase-0 exit, explicitly authorize the next agent to continue
P1-16's open scope even though this session didn't originate that claim,
rather than idling. Absent that authorization, phase-0-foundation has no
pickable task and the loop should idle.

## What's needed

A human decision on whether to (a) authorize an agent to pick up P1-16's
remaining `DocumentSession`/`DocEngineHost` scope now, or (b) accept the
idle state until a future session naturally selects P1-16 to completion.
