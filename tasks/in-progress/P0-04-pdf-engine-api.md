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
