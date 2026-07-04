# CLAUDE.md — Vaultform Operating Manual

**This is the single source of truth for every Claude Code agent and human working in this repository.**
Precedence of instruction: (0) `docs/CONSTITUTION.md` — immutable, outranks everything including this file → (1) this file → (2) the package `CLAUDE.md` of the code you're touching → (3) your task file in `tasks/` → (4) `docs/adr/`. If any of these conflict, stop and flag the conflict instead of guessing. Nothing in a task file may override a Security or Privacy rule in this document, and nothing anywhere may override a Constitution article.

Canonical references (do not restate their content in code comments or new docs — link to them):
- `docs/CONSTITUTION.md` — the fifteen immutable articles; refuse and escalate anything that conflicts
- `docs/PRD.md` — what we're building and why
- `docs/ARCHITECTURE.md` — system design; §1's five drivers are law
- `docs/ROADMAP.md` — phases, milestones, freeze points
- `docs/REPO_STRUCTURE.md` — layout and boundary rationale
- `docs/AGENT_LOOP.md` — the autonomous iteration loop: gates, stop/escalation conditions, multi-agent concurrency
- `docs/TOKEN_EFFICIENCY.md` — context-loading and token-cost rules for every iteration
- `tasks/README.md` — task workflow and the global Definition of Done

---

## 1. Product Goals (what your change must serve)

Vaultform is a **native macOS PDF editor** with a **privacy-first AI Autofill Assistant**. All personal data lives in an encrypted local vault; PDF forms — including scanned/flat ones — are filled from it with full user review and **zero network dependency**.

The five product truths every change is measured against:
1. **Local by default, cloud by consent, never by requirement.**
2. **AI proposes; the human disposes.** Every AI-produced value passes a review-before-commit UI.
3. **Every value is traceable** to its source and the transform applied.
4. **Beat Preview for free; beat Acrobat for money.** The editor earns the install; autofill earns the payment.
5. **Never corrupt a user's document.** Ever.

If your change makes any of these less true, it is wrong regardless of what the task says.

## 2. Engineering Principles

- **Deterministic first, model second, LLM last.** Prefer dictionaries/rules/parsers; use ML only where rules can't reach; validate all model output with deterministic checks.
- **Boundaries over discipline.** We prevent mistakes structurally (process isolation, import lint, typed capabilities) rather than by asking people to be careful. Don't weaken a boundary to save time.
- **Small, verifiable increments.** One task, one package, one PR. If the diff is getting large, split the task.
- **Evidence over assertion.** Claims about performance, accuracy, or privacy must be backed by a benchmark, test, or audit artifact in the repo.
- **Honest failure.** Degrade gracefully with typed errors and clear UX; never silently guess (especially in autofill and text editing).

## 3. Architecture Rules (non-negotiable)

1. **Layering:** Presentation → Application → Domain → Infrastructure. Lower layers never import upper ones. Only `Infra/*` packages may import GRDB, PDFium shims, Core ML, or XPC APIs.
2. **Process boundaries:** PDF parsing/rendering only in `DocEngine.xpc`; ML inference only in `Inference.xpc`; vault data and keys only in `Vault.xpc`. The main app never links the PDF parser and never holds bulk vault plaintext.
3. **Capability tickets:** every privileged vault operation requires a `PolicyTicket` from PolicyKit. There is no bypass path, including in tests of other components (use `FakeVaultClient`).
4. **No model output writes directly** to a document or the vault. All writes flow through a session (AutofillSession/IngestionSession) acting on explicit user confirmation.
5. **All document mutation goes through the atomic save path** (write-temp → validate → atomic replace → versioned backup).
6. **API packages (`Packages/*API/`) and `Schemas/` are frozen seams.** Changing them requires an ADR and an `[INTEGRATION]`-marked PR with human review. Never "just add a field."
7. **New cross-package dependency?** Stop. Write an ADR proposal first.

## 4. Coding Standards

- **Language:** Swift 6, strict concurrency. Obj-C++ only inside the PDFium shim (`ThirdParty/pdfium`, `DocEngineHost` boundary).
- **Concurrency:** `async/await` + actors. No `DispatchQueue` in new code without justification in the PR. Shared mutable state lives in an actor or doesn't exist.
- **Types:** value types by default; `Sendable`/`Codable` for anything crossing XPC. No force-unwraps (`!`) outside tests; no `try!` anywhere in product code.
- **Errors:** typed error enums per module (see §15). No `fatalError` on user-input-reachable paths.
- **File size:** soft cap ~400 lines; split by responsibility.
- **Comments:** only for constraints the code can't express (spec references, PDF-format quirks, security invariants). Never narrate what the next line does, and never write comments addressed to a reviewer.
- **Formatting/lint:** SwiftLint config at repo root is authoritative; `Scripts/verify.sh <Package>` runs it. Don't disable rules inline without a justifying comment naming the rule and reason.
- **Match surrounding style.** When editing a file, adopt its idiom, naming, and comment density rather than imposing your own.

## 5. Naming Conventions

- **Packages:** `UpperCamelCase`, role-suffixed: `*API` (protocols/DTOs only), `*Host` (XPC client + adapter), `*Session` (workflow state machines), `*UI` (views). 
- **Types:** protocols describe capability (`PageRenderer`, `VaultClient`); implementations are concrete (`PDFiumRenderer`, `SQLCipherVaultStore`); test fakes are `Fake*` (shipped in API packages), test-local mocks `Mock*`.
- **XPC interfaces:** versioned suffix (`DocEngineXPCv1`). DTOs end in `Request`/`Response`/`Event`.
- **Vault field paths:** dot-separated lowercase (`identity.passport.number`) — catalog in `docs/specs/vault-schema.md`; never invent paths ad hoc.
- **Files:** one primary type per file, file named after it. Tests mirror source names (`FillPlanner.swift` → `FillPlannerTests.swift`).
- **Branches/commits/PRs:** see §21.
- **Security-sensitive wrappers:** decrypted secrets travel as `SecureBytes`, never `String`/`Data` — if you see a plain type holding a vault value, that's a bug to fix, not a pattern to copy.

## 6. Repository Conventions

- Layout per `docs/REPO_STRUCTURE.md`. Do not create new top-level directories.
- **One task = one package** (the task's `Primary package`). Multi-package work must be an `[INTEGRATION]` task and must not run concurrently with tasks touching the same packages.
- Task workflow: pick from `tasks/backlog/<current-phase>/` (dependencies must be in `done/`) → move file to `in-progress/` with owner+branch header → work → PR links the task file → merge moves it to `done/`.
- Fixtures are data-driven: new regression cases are fixture + manifest-row additions, not bespoke test scaffolding. **Never commit real PII to `Fixtures/`** — synthetic generators only; CI scans and will reject you.
- Generated code (from `Schemas/`) is never hand-edited; run `Scripts/codegen.sh`.
- Package `CLAUDE.md` files stay ≤60 lines and are updated **in the same PR** as any behavior/invariant change.

## 7. Security Rules (violations block merge; no exceptions)

1. **No network calls** anywhere except the enumerated, consented app-level paths (update check, license validation, opt-in telemetry). XPC services have no network entitlement — never add one.
2. Vault master key exists in plaintext only inside `Vault.xpc`, `mlock`ed, zeroized on lock. Never serialize, log, or copy it.
3. Decrypted vault values: `SecureBytes` end-to-end; bridge to `String` only at the final UI/engine write; exclude from undo serialization, state restoration, and Spotlight.
4. Vault values on the pasteboard must use transient pasteboard type + expiry.
5. No JavaScript execution from PDFs. Form format strings are parsed as *hints*, never evaluated.
6. Model packs must pass signature + checksum verification before load; never load a model from an unverified path.
7. New entitlements, Info.plist permission strings, or sandbox exceptions require an ADR + human sign-off.
8. Temp files containing document or vault content go in the session-keyed encrypted scratch container, purged on session end — never `/tmp`, never the user's directories.
9. If you find a security defect, fix or file it immediately as Sev-1; do not note it and move on.

## 8. Privacy Rules (equal rank with §7)

1. **Nothing the user ingests, stores, or fills ever leaves the device.** No feature, test, debug aid, or telemetry event may transmit document content, vault content, filenames, or field values.
2. Telemetry is opt-in, default OFF, and structurally content-free: the event catalog is a closed enum; payloads cannot carry free-form strings. Extending the catalog requires matching a PRD §11 metric.
3. Audit log entries carry IDs, paths, and hashes — never values. The entry type has no value slot; keep it that way.
4. Crash reports are opt-in and scrubbed; never attach documents, vault state, or file paths under the user's home.
5. FormKnowledge stores mappings and fingerprints only — a value column in `forms.db` is an architecture violation.
6. Features must work fully offline. If your feature "needs" the network, the design is wrong — escalate.

## 9. Testing Requirements

- Every behavior change ships with tests in the same PR. `Scripts/verify.sh <Package>` (build + tests + boundary lint) must pass locally before you open the PR — it's exactly what CI runs.
- **Test pyramid by layer:** Domain packages → fast unit + property-based tests (PolicyKit decision table, ValueFormatter losslessness, fingerprint stability are property-test territory). Sessions → state-machine transition tests against `Fake*` clients. Services → conformance suites (API package suites run against fakes *and* real implementations). UI → view-model unit tests + targeted XCUITests + snapshot tests (light/dark).
- **Accuracy-bar code** (matcher, OCR, extractors, detection) must run its bench suite (`Scripts/bench.sh <suite>`); regressions against NFR-A1–A4 baselines block merge.
- **Mutation-path code** (anything that writes PDFs) must extend `Scripts/corpus-roundtrip.sh` coverage.
- Security-relevant changes add negative tests (ticket-less call rejected, tampered pack refused, locked-vault error surfaced).
- Don't test implementation details; test contracts. If you must reach into internals, the design likely needs a seam — say so in the PR.

## 10. Documentation Standards

- Docs live in `docs/`; specs per feature in `docs/specs/`; decisions in `docs/adr/` (immutable once accepted — supersede, don't edit).
- Write for the next agent: state invariants and *why*, link to canonical sources, no duplicated content between docs (one owner per fact).
- Package `CLAUDE.md` = purpose, invariants, forbidden imports, how to verify, gotchas — nothing else.
- User-facing copy touching privacy claims must match ARCHITECTURE.md §6 exactly — no marketing embellishment of security properties.

## 11. Performance Expectations

Budgets from PRD NFR-P1–P5 (baseline: M1/16GB) are enforced by the bench suite; the load-bearing ones:

| Surface | Budget |
|---|---|
| Cold launch / open 100-page PDF | < 1.5s / < 1s |
| Scroll/zoom | 60fps (120 ProMotion), no blank tiles at p95 |
| Autofill plan (6-page AcroForm) | < 3s end-to-end |
| Memory, 1,000-page doc | < 1.5GB working set |
| OCR accuracy | ≥98% @300dpi, ≥93% photos |

Rules: no full-document loads (stream pages); interactive inference preempts background; measure before optimizing (add a bench case, don't guess); a perf regression caught by `bench.yml` trend is a blocker for the PR that caused it.

## 12. Definition of Done (global — task files add to this, never subtract)

- [ ] `Scripts/verify.sh <PrimaryPackage>` green (build + tests + boundary lint)
- [ ] New behavior covered by tests; fixtures added via manifests where applicable
- [ ] Accuracy/perf benches run and non-regressing when the code is on a benched path
- [ ] Package `CLAUDE.md` updated if invariants/usage changed
- [ ] No §7/§8 violations (self-audit against both lists)
- [ ] Conventional commits scoped by package; PR links the task file; task file moved to `done/` on merge
- [ ] Task-specific Acceptance Criteria all demonstrably met (say how in the PR)

## 13. Pull Request Checklist (paste into the PR description and check off)

- [ ] Links task file; scope matches the task (no drive-by changes outside the primary package)
- [ ] Diff stays within the primary package, or PR is marked `[INTEGRATION]` per the task
- [ ] No edits to `Packages/*API/` or `Schemas/` (or: ADR linked and humans requested)
- [ ] Tests: what's covered, what's deliberately not, and why
- [ ] Evidence for acceptance criteria (test names, bench output, screenshots for UI)
- [ ] Security/privacy self-audit: one sentence stating what sensitive data this code touches and how it's protected (write "none" only if true)
- [ ] Failure modes: what happens when inputs are malformed / vault is locked / service crashes mid-call
- [ ] Docs updated (package CLAUDE.md, specs, ADRs) in this PR, not "later"

## 14. Code Review Checklist (for the reviewing agent/human)

1. **Boundary integrity:** imports legal? Layer direction respected? Anything crossing XPC properly typed/versioned?
2. **Ticket discipline:** any vault access without a PolicyTicket? Any model output writing without a session commit?
3. **Secret hygiene:** vault values as `SecureBytes`? Any value reaching logs, telemetry, audit entries, undo state, or `String` bridges prematurely?
4. **Corruption safety:** document writes on the atomic save path? Undo correct?
5. **Error honesty:** failures typed and surfaced, or swallowed? Any silent fallback that could fill a wrong value?
6. **Test quality:** do tests pin the contract (would they catch the bug this change could plausibly introduce)? Property tests where inputs are combinatorial?
7. **Simplicity:** is there an existing utility/fake/fixture this reinvents? Is the abstraction earning its weight?
8. **Docs/DoD:** checklist honest? CLAUDE.md deltas present?
Reviewers verify claims by running, not by trusting the description.

## 15. Error Handling Guidelines

- Typed error enums per module, conforming to a shared `VaultformError` protocol carrying: user-presentable message key, debug description, and recoverability class (`retryable | userAction | fatal`).
- **Never swallow:** `catch { }` with no handling is banned; either handle meaningfully, translate and rethrow, or surface to the session's error state.
- XPC boundaries translate transport failures into domain errors (`serviceCrashed`, `serviceTimeout`) with automatic retry only where idempotent.
- User-input-reachable paths (opening files, ingestion, fills) must be total: every input yields success, a typed error, or a graceful degradation — never a crash, never garbled output.
- Autofill/ingestion specifics: uncertainty is a *low-confidence result*, not an error; wrongness risk is handled by review UX, not exceptions. A validator failure (e.g., digit mutation in formatting) discards the proposal and logs an audit event.
- Vault-locked is a normal state, not an error condition — every vault consumer handles `vaultLocked` with a re-auth affordance.

## 16. Logging Guidelines

- Use the project logger (`os.Logger` wrappers in `Platform`) with subsystem = bundle ID, category = package name. No `print` in product code.
- **Absolute rule: no document content, vault values, filenames under the user's home, or personal data at any log level, including debug.** Log IDs, counts, durations, enum states, hashes.
- Privileged operations log through AuditLog (structured, hash-chained), not the console logger. Console logs are diagnostics; the audit log is the user-facing record — don't conflate them.
- Log at `error` for actionable failures, `notice` for state transitions worth a support trace, `debug` for development (compiled out of release where possible). No log-spam in per-tile/per-frame paths.

## 17. Dependency Management Rules

- **Default answer to new third-party dependencies is no.** The approved set: GRDB, SQLCipher, PDFium (pinned), Sparkle 2 (direct channel), swift-log-style utilities already in `Package.resolved`. Anything else requires an ADR covering: license (must be compatible with commercial distribution), supply-chain posture, binary size, and what it would cost to write ourselves.
- Pin everything: exact versions in `Package.resolved` (committed); PDFium revision pinned in `ThirdParty/pdfium` with its upgrade playbook.
- Upgrades are their own PRs, never bundled with features; PDFium/SQLCipher upgrades additionally run the full corpus + security suites.
- No dependency may be added to `*API` packages (they stay Foundation-only) and none that phones home (verify before proposing — telemetry-bundling SDKs are disqualified by §8).

## 18. Refactoring Guidelines

- Refactors are welcome **inside your primary package** when they serve your task; keep them in separate commits from behavior changes.
- Cross-package refactors, renames of public API, or moving types between packages = `[INTEGRATION]` task + ADR if a frozen seam is touched. Never do these as drive-bys.
- Don't refactor code you don't understand: read its package `CLAUDE.md`, its tests, and its ADRs first. If the "ugly" code encodes a PDF-spec quirk or security constraint, it will say so — and if it doesn't but you discover it does, *add the comment* as part of your change.
- Preserve behavior provably: tests green before and after with no test edits in the refactor commit (test changes belong with behavior changes).
- Delete dead code rather than commenting it out; git is our archive.

## 19. AI Usage Guidelines (for AI features *in the product*)

- Model calls go through `InferenceAPI` typed endpoints only — never name a model file at a call site, never load models outside the registry.
- Prompts to the local LLM contain form labels and candidate vault *paths*; include vault *values* only after a PolicyKit grant and only when the deterministic formatter has already failed.
- LLM output is constrained choice (top-k candidates) wherever possible, and always validated deterministically — hallucinated field paths, mutated digits, or invented values must be structurally impossible, not just unlikely.
- Every model-derived proposal carries: confidence, rung attribution (dictionary/embedding/LLM), and provenance — the review UI depends on this contract.
- Accuracy claims live in the bench suite. A "better" model or prompt without a bench delta is not better.
- Cloud AI is out of scope for MVP. Do not add cloud-model code paths, flags, or stubs — the opt-in tier (if ever) arrives via ADR with its own consent architecture.

## 20. Rules for Modifying Existing Code

1. Read the package `CLAUDE.md`, the file's tests, and any ADR it references *before* editing.
2. Match existing patterns; if you believe a pattern is wrong, flag it in the PR — don't introduce a competing second pattern.
3. Keep public API stable unless the task says otherwise; additive changes preferred; removals need a deprecation note in the package CLAUDE.md.
4. Never weaken a test to make your change pass. If a test blocks you, it's telling you about a contract — resolve the contract question first (task owner or ADR).
5. Don't touch generated code, `Fixtures/` manifests of other features, or another in-progress task's primary package (check `tasks/in-progress/`).
6. When your change alters behavior a downstream consumer might rely on, search the workspace for consumers and update them in the same PR — or split into an `[INTEGRATION]` task if that crosses packages.
7. Migration discipline: vault schema changes ship with a tested migration and a rollback note; there is no "we'll migrate later."

## 21. Branching Strategy & Rules for Updating Documentation

**Git flow (trunk-based):**
- `main` is meant to always be releasable, and merges happen only via PR with green CI (the `ci-status` check: `verify.sh` matrix + repo-wide checks, see P0-02) and one review (human for `[INTEGRATION]`, security-touching, or API/schema PRs). **Branch protection is not currently platform-enforced** — GitHub Free doesn't allow branch protection rules on private repos (`tasks/escalations/E-003-branch-protection-needs-paid-plan.md`); nothing on GitHub's side stops a premature merge. Until that's resolved, the agent itself is the gate: **check `ci-status` before every merge, never GitHub's merge button state.** For ordinary PRs (not `[INTEGRATION]`/security-touching/API-schema), merge autonomously the moment `ci-status` is green — this is standing authorization, not a per-PR ask (see `docs/AGENT_LOOP.md` Step 8a). If `ci-status` is red, never merge: diagnose and fix per the normal fix loop (Step 4 there), then re-check before trying again. `[INTEGRATION]`/security/API-schema PRs still wait for human review regardless of CI status.
- Branches: `task/<ID>-<slug>` (e.g. `task/P2-05-fill-planner`); short-lived (< 1 week — if it's living longer, the task is too big); rebase on main before merge; squash-merge with a conventional-commit title scoped by package (`feat(AutofillEngine): fill planner and session state machine (P2-05)`).
- Release: tags `vX.Y.Z` cut by `release.yml`, gated by the corpus round-trip suite and the network audit. No release-branch stabilization — stabilize on main.
- Never commit directly to `main`; never force-push shared branches; never merge with failing or skipped gates "to unblock."

**Documentation updates:**
- Docs change in the same PR as the code they describe — a doc that can drift is a doc that will lie.
- Each fact has one home: PRD (product intent), ARCHITECTURE (design + invariants), specs (feature detail), ADRs (decisions), package CLAUDE.md (working knowledge). Update the owner; link from elsewhere.
- ADRs are append-only: to change a decision, write a superseding ADR and cross-link both.
- The four root docs (PRD/ARCHITECTURE/ROADMAP/REPO_STRUCTURE) are PM/architect-owned: propose changes via PR with rationale; don't rewrite them unilaterally mid-task.
- This file (root CLAUDE.md) changes only via dedicated PR with human approval — it is the contract everything else assumes.

---

## Quick Reference Card

```
Build/verify one package:   Scripts/verify.sh <PackageName>
Full bootstrap:             Scripts/bootstrap.sh
Benchmarks:                 Scripts/bench.sh <suite>
Corpus integrity suite:     Scripts/corpus-roundtrip.sh
Regenerate DTOs:            Scripts/codegen.sh
PII/secret scan (Fixtures): Scripts/scan-fixtures-pii.sh
CI (every PR, required):    .github/workflows/ci.yml — same verify.sh per
                            changed package + SwiftLint/PII-scan/codegen-
                            drift; full matrix on push to main or any
                            *API/Schemas/ touch. Merge is blocked until
                            the `ci-status` check is green.
Pick work:                  tasks/backlog/<phase>/ (deps must be in done/)
Branch:                     task/<ID>-<slug>
Frozen (ADR to change):     Packages/*API/, Schemas/, this file
Absolute red lines:         network calls · vault values in logs/telemetry ·
                            ticket-less vault access · non-atomic doc writes ·
                            real PII in fixtures · JS execution from PDFs
```
