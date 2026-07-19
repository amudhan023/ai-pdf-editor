# E-009 — P1-04 (annotations) blocked from file-persisted round-trip by missing engine-side save

**Raised by:** P1-04 · **Severity:** Medium — scopes down P1-04's acceptance criteria, does not block engine/session-layer work · **Status:** partially resolved by P1-21 (2026-07-19) — see "After repair" update below

## Evidence

- `Packages/DocEngineHost/Sources/DocEngineHost/PDFiumEngine.swift`'s `save(_:mode:to:)` throws `PDFEngineError.unsupportedFeature("engineSaveNotYetImplemented")` unconditionally — confirmed by reading the source, not stale docs.
- `tasks/done/P1-16-atomic-save-backups.md` (moved to `done/` after PR #48 and follow-ups) explicitly lists "`DocEngineHost` engine-side save modes (full-rewrite/incremental)" under "Still not done" in its final status update, and no other backlog/in-progress task file claims that scope — `grep -rl "FPDF_SaveAsCopy\|engine save" tasks/` only matches P1-16's own file.
- P1-16's `AtomicSaver` (`Packages/DocumentSession/Sources/DocumentSession/Save/AtomicSave.swift`) handles the *file-level* write-temp → validate → atomic-replace mechanics, but needs serialized PDF bytes with the mutation baked in to write — that serialization step is PDFium's `FPDF_SaveAsCopy` (`fpdf_save.h`), which `PDFiumEngine` doesn't call anywhere yet.
- P1-04's task file (`tasks/in-progress/P1-04-annotations-markup.md`) lists `Dependencies: P1-03` only; it does not name this gap, and its acceptance criteria ("Round-trip fixture suite... passes both directions", "spec-compliant storage") implicitly assume a working save path exists.

## Conclusion

`AnnotationStore` CRUD against an *open* `PDFiumEngine` document (add/read/update/remove via `FPDFPage_CreateAnnot`/`FPDFAnnot_*`) is fully implementable and testable today — that scope does not touch `save()`. But demonstrating that an annotation *written by this product* survives to a file Acrobat/Preview can open (the "write direction" of the round-trip acceptance criterion) is not achievable until `PDFiumEngine.save()` actually calls `FPDF_SaveAsCopy` and `AtomicSaver` is wired to it. This is the same class of task-graph gap as E-007/E-008 (a task closed with a deferred sub-scope that no follow-up task tracks), not a new architectural question — no ADR needed, just a backlog entry.

Separately, `tasks/escalations/E-005-corpus-acquisition-gap.md` already covers the fact that no fixture corpus of real Acrobat/Preview-*annotated* PDFs exists in `Fixtures/` — acquiring one needs the same human-in-the-loop data-acquisition step E-005 describes, compounding this gap for the "read direction" comparison-against-real-files part of the criterion (reading our own PDFium-parsed annotations against a real Acrobat-authored file's annotation objects is possible in principle once such a fixture exists; today there is nothing to read).

## Decision needed (human)

Option A: file a new backlog task ("DocEngineHost: engine-side save modes, `FPDF_SaveAsCopy`") as a Critical/High-priority dependency for every Phase-2 mutation task (annotations, page ops, form fill, text edit) — all of them share this same blocker, not just P1-04. This is a repo-wide unblock, not a one-off.

Option B: accept P1-04 landing with engine/session CRUD complete and tested in-memory (PDFium's own read-back of what it just wrote — a real, if partial, spec-conformance signal), file-persisted round-trip and the Acrobat/Preview fixture comparison explicitly out of scope and re-opened once Option A's task lands.

## Interim decision (made now, so P1-04 isn't fully blocked)

Proceeding with Option B: P1-04 delivers `AnnotationStore` engine CRUD (real PDFium-backed, spec-shaped quad points/color/opacity/author/dates) plus `DocumentSession`-level session/undo/UI wiring, verified via in-memory add→read-back→update→remove tests (including PDFium's own `FPDFAnnot_Get*` after `FPDFAnnot_Set*`) and the existing `PDFEngineConformanceSuite`. The file-persisted round-trip and Acrobat/Preview fixture-suite acceptance criteria are marked not-met in the PR, with this escalation linked as the reason, and Option A's task is filed in the same PR (see backlog addition referenced from the task's Journal).

## After repair

Once engine-side save lands: revisit P1-04 (or a follow-up task) to add the file-persisted round-trip test and, once E-005-class fixture acquisition produces real Acrobat/Preview-annotated PDFs, the actual interop comparison.

**Update (P1-21, 2026-07-19):** `PDFiumEngine.save(_:mode:to:)` now actually serializes via `FPDF_SaveAsCopy` (both `.fullRewrite`/`.incremental`) instead of throwing `.unsupportedFeature` — see `tasks/done/P1-21-docengine-save-modes.md`. `DocEngineHostTests.testSaveFullRewriteRoundTripsMutatedAnnotationToDisk` / `testSaveIncrementalRoundTripsMutatedAnnotationToDisk` now cover the file-persisted open→mutate→save→reopen round-trip this escalation flagged as missing, closing the first half of "After repair." Still open: the Acrobat/Preview interop-fixture comparison, which remains blocked on `E-005-corpus-acquisition-gap.md`'s human-in-the-loop fixture acquisition — unchanged by this task. `DocumentSession`'s `AtomicSaver` wiring to the now-real `save()` is also still open (P1-16/P1-04 follow-up scope, not this task's primary package).
