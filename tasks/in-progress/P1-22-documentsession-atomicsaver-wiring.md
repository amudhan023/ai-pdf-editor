# P1-22 — DocumentSession: wire AtomicSaver to the real PDFiumEngine.save

**Epic:** E2 · **Primary package:** `Packages/DocumentSession` · **Complexity:** S · **Priority:** High

## Goal
`DocumentSession`'s `AtomicSaver` (P1-16) calls the now-real `PDFiumEngine.save(_:mode:to:)` (P1-21) to serialize mutated document bytes into its write-temp → validate → atomic-replace path, instead of whatever placeholder/no-op it currently uses to obtain save bytes.

## Background
P1-16 delivered the file-level atomic-save mechanics (temp file, validation, atomic replace, versioned backup) but had no real engine serialization to call — `PDFiumEngine.save` threw `.unsupportedFeature` unconditionally. P1-21 (`tasks/done/P1-21-docengine-save-modes.md`) implemented real `FPDF_SaveAsCopy`-backed save (both `.fullRewrite`/`.incremental`), verified with engine-level open→mutate→save→reopen round-trip tests in `DocEngineHost`, but did not touch `DocumentSession` (out of primary-package scope for that task). `tasks/escalations/E-009-p1-04-engine-save-missing.md`'s "After repair" note flags this exact wiring gap as the remaining piece before annotation/mutation features get a real end-to-end file-persisted save.

## Requirements
- `AtomicSaver` (or whatever calls it) obtains serialized bytes via `PDFiumEngine.save(_:mode:to:)` (through the `DocumentLifecycle` protocol, not a concrete-type import) rather than a stub/no-op path.
- Session-level save triggers a real open→mutate→save→reopen cycle end-to-end (e.g. add an annotation via `AnnotationStore`, save the session, reopen the resulting file, confirm the mutation persisted) — this is the acceptance criterion P1-04's task file marked "not met" pending this wiring.
- Typed error propagation: a `PDFEngineError.ioFailure` (or other) from `save()` must surface through `AtomicSaver`'s existing typed-error path, not get swallowed or converted to a generic failure.

## Dependencies
- P1-16 (done), P1-21 (done)

## Files Likely Affected
- `Packages/DocumentSession/Sources/DocumentSession/Save/AtomicSave.swift` and whatever currently stubs the save-bytes source.

## Acceptance Criteria
- A `DocumentSession`-level test demonstrates: open a fixture, add an annotation, trigger session save, reopen the saved file (real `PDFiumEngine`, not `FakePDFEngine`), confirm the annotation is present.
- `tasks/escalations/E-009-p1-04-engine-save-missing.md` can be closed (or reduced to only the still-open Acrobat/Preview interop-fixture item, which is separately blocked on E-005).

## Definition of Done
- Global DoD, plus: update `okf/sessions/document-session.md`'s file-persisted-round-trip note (currently "not met") once this lands.

## Testing Requirements
- Session-level round-trip test as above; existing `AtomicSaver` fault-injection tests (mid-write crash, disk-full, etc., if any exist from P1-16) should continue to pass unmodified against the real save path.

## Documentation Updates
- `Packages/DocumentSession/CLAUDE.md`, `okf/sessions/document-session.md`.

---
**Owner:** claude-agent
**Branch:** task/P1-22-documentsession-atomicsaver-wiring
**Claimed:** 2026-07-19
