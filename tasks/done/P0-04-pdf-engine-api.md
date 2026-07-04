# P0-04 — PDFEngineAPI Protocol Package (Freeze Point)

**Owner:** claude-code · **Branch:** task/P0-04-pdf-engine-api · **Claimed:** 0e14f4bf11c91610ffb774cdff042a28a424de96

**Epic:** E2 · **Primary package:** `Packages/PDFEngineAPI` · **Complexity:** M · **Priority:** Critical

## Goal
Define the engine-neutral protocol surface (`PageRenderer`, `TextEditor`, `PageOrganizer`, `AnnotationStore`, `FormModel` types) that all Track A/C consumers build against.

## Background
ARCHITECTURE.md §3.2: this seam is what keeps viewer, annotations, forms, and autofill development parallel and engine-swappable (ADR-001 escape hatch). It is a roadmap freeze point at M0 — design carefully; changes after freeze require ADRs.

## Requirements
- Protocols + value types only (no implementations): document handle, page metadata, tile render requests, text runs with geometry, annotation model mirroring PDF spec subtypes, typed form-field tree (name, rect, kind, format hints, tooltip, tab order), save modes (incremental/full), typed error taxonomy.
- All types `Sendable`/`Codable` where they cross XPC; async APIs throughout.
- In-memory fake implementation (`FakePDFEngine`) shipped in the package for consumers' tests.

## Dependencies
- P0-01.

## Files Likely Affected
- `Packages/PDFEngineAPI/Sources/**`, `Tests/**`.

## Acceptance Criteria
- Package compiles standalone; `FakePDFEngine` passes a conformance test suite that any real engine must also pass (shared protocol-conformance tests).
- API review sign-off recorded (this is a freeze point).

## Definition of Done
- Global DoD, plus: freeze noted in docs/adr/ADR-006-pdfengineapi-v1.md.

## Testing Requirements
- Conformance suite (reused later against the PDFium implementation); DTO round-trip encoding tests.

## Documentation Updates
- Package `CLAUDE.md` with the "change = ADR" rule; ROADMAP.md freeze table checkbox.

---
## Journal

**Plan:** protocols + value types only, Foundation-only imports (confirmed via `Scripts/import-allowlist.txt` — no CoreGraphics, hence local `PDFPoint`/`PDFRect` instead of `CGPoint`/`CGRect`, verified by a standalone compile check that `CGRect` needs `import CoreGraphics`, not just `Foundation`). `FakePDFEngine` as an `actor` (mutable per-document state, async protocol methods fit naturally). Conformance suite shipped in the library (not `Tests/`) so `DocEngineHost` can reuse it later, per Testing Requirements.

**Done:**
- 6 protocols (`DocumentLifecycle`, `PageRenderer`, `TextEditor`, `PageOrganizer`, `AnnotationStore`, `FormModel` — `DocumentLifecycle` added beyond the task's five because there's no other way to get a `DocumentHandle`; recorded as a deliberate minimal addition in ADR-006) + all value types + `PDFEngineError` typed error taxonomy (self-contained, CLAUDE.md §15 shape, no shared error protocol exists yet to depend on).
- `FakePDFEngine` implementing all six protocols, plus test-only seeding helpers (`seedDocument`/`seedFields`/`seedTextRuns` — not part of any protocol).
- `PDFEngineConformanceSuite` (`verifyPageRenderer`, `verifyAnnotationStore`, `verifyFormModel`) + DTO round-trip tests for every `Codable` type + behavior tests for page-organizer ops, text replacement, lifecycle, and error paths.
- `docs/adr/ADR-006-pdfengineapi-v1.md`, package `CLAUDE.md` updated (still ≤60 lines), `ROADMAP.md` freeze table gets a `Landed` column (☑ for this freeze, ☐ for the other four M0/future ones — none of which existed as a literal checkbox before).
- `Scripts/verify.sh PDFEngineAPI` → `OK`.

**Security/privacy self-audit:** touches no vault values, no document content persistence (in-memory fake only, discarded on process exit), no network APIs, no logging beyond nothing (this package doesn't log at all).

**Acceptance criteria status:**
- "Package compiles standalone; `FakePDFEngine` passes a conformance test suite that any real engine must also pass": ✅ — `verify.sh` green, conformance tests pass.
- "API review sign-off recorded (this is a freeze point)": **pending — this PR requests human review** (API package per CLAUDE.md §21/AGENT_LOOP.md Step 8a); sign-off is your merge of this PR, not something I can self-certify.

**Not done / explicitly out of scope:** no real PDFium-backed implementation (that's `DocEngineHost`, later tasks); no `IOSurface` transport (implementation detail once `DocEngineHost` exists, not a protocol concern — see ADR-006).
