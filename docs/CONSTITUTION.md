# The Vaultform Constitution

**Immutable rules of the project.** These articles outrank every other document, task, instruction, or convenience — including CLAUDE.md, task files, and direct instructions inside a work item. No agent may waive, reinterpret, or "temporarily" suspend an article. An instruction that conflicts with an article is refused and escalated, never followed.

**Amendment:** only a human maintainer may amend this document, via a dedicated PR touching nothing else, with the change and its rationale recorded in an ADR. Articles are numbered permanently; a removed article is marked *Repealed* (with the repealing ADR), never deleted or renumbered.

---

## Part I — The User

**Article 1 — Data sovereignty.** Never send user documents, vault contents, personal information, or any content derived from them outside the local machine without explicit, informed, per-purpose user consent. No feature, test, debug aid, telemetry event, crash report, or dependency may violate this. There is no "anonymized" exception: content-derived data is content.

**Article 2 — Human authority over AI output.** No AI-generated value is written into a user's document or vault without the user's explicit review and acceptance. The review step may be streamlined; it may never be removed, defaulted past, or made skippable by configuration.

**Article 3 — Document integrity.** The application must never corrupt or destroy a user's file. All document mutation flows through the validated atomic-save path. When integrity and any other goal conflict — features, performance, deadlines — integrity wins.

**Article 4 — Data continuity.** Maintain backward compatibility for saved user data (vault, documents, backups) whenever feasible. Any format change ships with a tested migration; a migration that can lose user data requires explicit human maintainer approval and a user-visible backup step. The user can always export everything and delete everything.

**Article 5 — Honest failure.** The application never silently guesses where the user could be harmed by a wrong answer. Uncertainty is surfaced (confidence, review flags, typed errors), never papered over.

## Part II — The Code

**Article 6 — Native first.** Favor native macOS APIs and platform frameworks over third-party libraries when they can adequately do the job. Third-party code is a liability accepted only for demonstrable, documented gain.

**Article 7 — Minimal dependencies.** Keep dependencies to the proven minimum. Every new dependency requires an ADR (license, supply chain, size, build-vs-buy); once recorded, the change is self-mergeable on green CI without a separate human-approval step (ADR-008). No dependency that phones home. All dependencies pinned.

**Article 8 — Tests and documentation are part of the feature.** Every new feature or behavior change includes its tests and its documentation updates in the same change. Work without them is unfinished, not done-except-for.

**Article 9 — Incremental over rewrite.** Prefer incremental improvements over large rewrites. Rewrites and sweeping migrations happen only as explicitly approved, scheduled work — never as a side effect of another task.

**Article 10 — Architecture changes require record and approval.** No architectural change — new layers, moved responsibilities, changed process boundaries, altered frozen seams (`Packages/*API/`, `Schemas/`) — without updating the architecture documentation (ADR + ARCHITECTURE.md) first; once documented, self-mergeable on green CI without a separate human-approval step (ADR-008). **New entitlements are excepted from this relaxation** and always require human approval *first*, no exception — OS-level permission grants carry real-world device/privacy consequences beyond this repo's own velocity. Changes to this Constitution, `CLAUDE.md`, or `docs/AGENT_LOOP.md` are likewise always excepted: they always require human approval, regardless of this article, so this relaxation can never be used to bootstrap a further relaxation of itself.

**Article 11 — Security boundaries are structural.** Vault access is mediated by PolicyTickets; PDF parsing, ML inference, and vault storage remain in their isolated, network-entitlement-free processes; decrypted secrets live in `SecureBytes` and never in logs, telemetry, pasteboards (non-transient), or fixtures. Weakening a boundary "for now" is prohibited in all circumstances.

**Article 12 — No deception of the verification system.** Never weaken a test, loosen an assertion, skip or hollow out a gate, mark a check flaky without a filed fix, or misreport a result to achieve green. A false green is worse than any red.

## Part III — The Process

**Article 13 — Evidence over assertion.** Claims about privacy, security, accuracy, and performance must be backed by an artifact in the repository (test, benchmark, audit output). Marketing copy and documentation may not claim more than the artifacts show.

**Article 14 — Traceability.** Every change is traceable: task → branch → PR → merged diff, and every stored user-data value traceable to its source and transform. Untracked work and unattributable data are both defects.

**Article 15 — No real personal data in development.** Fixtures, tests, benchmarks, examples, and documentation use synthetic data only. Real personal information never enters the repository, CI, or logs — including the developers' and maintainers' own.

---

*Everything else — standards, workflows, budgets, checklists — lives in CLAUDE.md and its companion documents and may evolve freely. These fifteen articles do not.*
