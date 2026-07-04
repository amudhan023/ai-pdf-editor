# ADR-009 — Self-Merge for `CLAUDE.md`/`AGENT_LOOP.md` Changes

**Status:** Accepted · **Task:** none (direct human-maintainer instruction)

## Context
ADR-008 (Constitution Articles 7/10 amendment) relaxed self-merge for `[INTEGRATION]`/security-touching/`*API`/`Schemas/` PRs, but deliberately kept two categories always-human-reviewed regardless of CI: new entitlements/Info.plist permissions, and any change to `CLAUDE.md`, `docs/AGENT_LOOP.md`, or `docs/CONSTITUTION.md` themselves — the latter specifically "to prevent this relaxation from being used to bootstrap a further relaxation of itself" (ADR-008/PR #23).

The human maintainer has now directly instructed a further, narrower relaxation: changes to `CLAUDE.md` and `docs/AGENT_LOOP.md` (not `docs/CONSTITUTION.md`) become self-mergeable once `ci-status` is green, with no separate human-approval click. This is a legitimate exercise of the maintainer's own authority over process documents that, per `docs/CONSTITUTION.md`'s closing line, "may evolve freely" (unlike the fifteen immutable articles) — the maintainer is not asking to bypass their own oversight; they are choosing, explicitly and with the tradeoff stated back to them first, to substitute automated verification for a manual click on these two files specifically.

This PR is itself the bootstrap case: it is a change to `CLAUDE.md`/`AGENT_LOOP.md` submitted under the *old* rule (always-human-reviewed). Per the same anti-bootstrap reasoning ADR-008 applied to itself, **this PR is not self-merged** — it is merged by the human maintainer directly, exactly once, to adopt the new rule. Every subsequent `CLAUDE.md`/`AGENT_LOOP.md` PR is self-mergeable under the rule this PR establishes.

## Decision
- `CLAUDE.md` and `docs/AGENT_LOOP.md` changes are self-mergeable the moment `ci-status` is green — same standing authorization as any other non-carved-out PR, no separate human-approval step.
- `docs/CONSTITUTION.md` is **not** included and cannot be included by this or any ADR: its own Amendment clause ("only a human maintainer may amend this document") is unconditional and does not describe a CI-based exception. Changing that requires a human-merged PR to `docs/CONSTITUTION.md` itself, per its own text.
- New entitlements/Info.plist permissions remain always-human-reviewed, unchanged from ADR-008 — this ADR does not touch that category; the rationale (real device/privacy consequences, "an agent may never self-approve one") is orthogonal to governance-doc review and wasn't reopened here.
- The CI bar this relies on today: `ci-status` (the `verify` job's `swift build`+`swift test`+boundary-lint per touched package, plus `repo-checks`' SwiftLint/PII-scan/codegen-drift check). There is **not yet** a distinct, labeled "integration test" CI stage — see `P0-15` (filed alongside this decision) for adding one. `CLAUDE.md`/`AGENT_LOOP.md` changes are docs-only, so `verify` always shows `skipped` for them regardless; `repo-checks` + `ci-status` green is the actual, real bar for this category today. This ADR does not claim an integration-test gate exists before `P0-15` lands it.

## Consequences
- `CLAUDE.md` §21 and `docs/AGENT_LOOP.md` Step 8a/8b and the §1 intro line drop `CLAUDE.md`/`docs/AGENT_LOOP.md` from their review-required carve-outs, leaving exactly two always-human-reviewed categories: new entitlements/Info.plist permissions, and `docs/CONSTITUTION.md` itself.
- A future agent reading an old cached copy of CLAUDE.md/AGENT_LOOP.md text (pre-dating this ADR) that still says "no exception" for these two files is out of date the moment this merges — this ADR is the record of why the text changed.
- If `P0-15` later lands a real integration-test CI stage, `ci-status` gates on it automatically for any package-touching PR; this ADR's self-merge authorization is unaffected either way since it was never conditioned on that stage existing.
