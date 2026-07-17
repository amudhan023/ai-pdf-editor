# P1-20 — Deflake VaultLockController Idle-Timeout Test

**Epic:** E9 · **Primary package:** `Packages/VaultStore` · **Complexity:** S · **Priority:** Medium

## Goal
`VaultLockControllerTests.testIdleTimeoutAutoLocksAndActivityDefersIt` passes deterministically on loaded CI runners, without weakening what it verifies (activity defers auto-lock; idle past timeout locks).

## Background
Observed failing on CI (run 29550572398, 2026-07-17, on an unrelated P1-02 PR): `("locked") is not equal to ("unlocked") — activity inside the window must defer the auto-lock`. The test is structurally racy: it unlocks, sets a 0.2s idle timeout, sleeps ~0.1s, notes activity, sleeps ~0.15s, then asserts still-unlocked. `Task.sleep` guarantees only a *minimum* duration, so the real margin between "check runs" and "deferred deadline fires" is ~50ms — any scheduler delay on a busy runner flips the result. The second assertion (locked after 0.3s more) is safe; only the first is racy.

## Requirements
- Replace wall-clock sleeps with an injected clock/timer seam in `VaultLockController` (e.g. accept a `Clock` or a `now: () -> Date` + schedulable timer), so the test advances time deterministically. This is the fix that matches "boundaries over discipline" — don't just widen the margins.
- If a seam is genuinely disproportionate, the fallback is documented generous margins (≥10× scheduler jitter, e.g. 2s timeout / 0.2s activity offsets) with a comment naming the flake and why margins were chosen — but prefer the seam.
- No behavior change to production lock semantics; all 10 existing `VaultLockControllerTests` keep passing.

## Dependencies
- P1-09 (done — introduced the controller and test).

## Files Likely Affected
- `Packages/VaultStore/Sources/VaultStore/Lock/**`, `Packages/VaultStore/Tests/VaultStoreTests/VaultLockControllerTests.swift`.

## Acceptance Criteria
- The test passes 50/50 consecutive local runs under load (`for i in $(seq 50); do swift test --filter testIdleTimeout ...; done` or equivalent evidence in the PR).
- Auto-lock semantics unchanged: activity inside the window defers; idle past the timeout locks.

## Definition of Done
- Global DoD (tasks/README.md).

## Testing Requirements
- The deflaked test itself, plus (if a clock seam is added) a fast deterministic test for "activity exactly at the deadline boundary."

## Documentation Updates
- `Packages/VaultStore/CLAUDE.md` gotcha note if a clock-injection seam is added.
