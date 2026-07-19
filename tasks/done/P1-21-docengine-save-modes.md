# P1-21 — DocEngineHost: Engine-Side Save Modes (`FPDF_SaveAsCopy`)

**Epic:** E2 · **Primary package:** `Packages/DocEngineHost` · **Complexity:** M · **Priority:** Critical

**Owner:** claude-agent · **Branch:** task/P1-21-docengine-save-modes · **Claimed:** 1908050d4465fa3ff45b8aeb999bf5074be8c059

## Goal
`PDFiumEngine.save(_:mode:to:)` actually serializes the open document's current state (including any in-memory mutations — annotations, page ops, form values) to bytes instead of throwing `unsupportedFeature("engineSaveNotYetImplemented")`, so `DocumentSession`'s atomic-save path (P1-16) has something real to write.

## Background
P1-16 (`tasks/done/P1-16-atomic-save-backups.md`) delivered the file-level write-temp → validate → atomic-replace mechanics but explicitly left "`DocEngineHost` engine-side save modes" undone, and no task tracked that remaining scope — discovered as a hard blocker by P1-04 (`tasks/escalations/E-009-p1-04-engine-save-missing.md`) when annotation CRUD had no way to reach disk. Every Phase 1/2 mutation feature (annotations P1-04/P1-05, page ops P1-06, form fill, text edit) shares this same blocker: none of their mutations can be persisted until this lands. `fpdf_save.h`'s `FPDF_SaveAsCopy`/`FPDF_SaveWithVersion` are the PDFium entry points; not yet declared in `CPDFium`'s header surface (same incremental-header pattern as `fpdf_annot.h`/`fpdf_doc.h`).

## Requirements
- Add `fpdf_save.h` to `CPDFium`'s module map; implement a `FPDF_FILEWRITE`-conforming Swift shim (callback-based streaming write, per PDFium's C API) so `FPDF_SaveAsCopy` can write into an in-memory buffer or file handle without needing PDFium to know about Swift `Data`/`URL` types directly.
- `PDFiumEngine.save(_:mode:to:)`: `.fullRewrite` via `FPDF_SaveAsCopy` (`FPDF_NO_INCREMENTAL` flag); `.incremental` via the default incremental-append flag — both must round-trip (open → save → reopen → structural check) against the existing PDFium test documents.
- Typed error surfacing on PDFium save failure (mirror `mapPDFiumError()`'s existing pattern) — never silently no-op.

## Dependencies
- P0-06 (done).

## Files Likely Affected
- `Packages/DocEngineHost/Sources/CPDFium/include/**`; `Packages/DocEngineHost/Sources/DocEngineHost/PDFiumEngine.swift`.

## Acceptance Criteria
- `PDFiumEngine.save` round-trips a mutated in-memory document (e.g. an added annotation) to a file that reopens with the mutation intact, for both `.fullRewrite` and `.incremental` modes.
- `DocumentSession`'s `AtomicSaver` can be wired to this instead of throwing, with a regression test proving a full open→mutate→save→reopen cycle through the real (not fake) engine.

## Definition of Done
- Global DoD, plus: unblocks the annotation/page-ops/form-fill file-persistence gaps tracked in `E-009` and equivalent notes in P1-05/P1-06/P2-xx tasks.

## Testing Requirements
- Fault-injection is P1-16's `Scripts/corpus-roundtrip.sh` concern (still separately blocked on fixture corpus per `E-005`); this task's own tests are engine-level open→mutate→save→reopen round-trips against the starter corpus.

## Documentation Updates
- `Packages/DocEngineHost/CLAUDE.md` — update the "save always throws unsupportedFeature" gotcha once this lands.

## Journal

**Orient:** Read root CLAUDE.md, this task file, `Packages/DocEngineHost/CLAUDE.md`, and `Tests/DocEngineHostTests/{DocEngineHostTests,PDFiumAnnotationStoreTests}.swift`. Confirmed `PDFiumEngine.save` (`Sources/DocEngineHost/PDFiumEngine.swift`) unconditionally threw `.unsupportedFeature("engineSaveNotYetImplemented")`. Checked `Packages/PDFEngineAPI/Sources/PDFEngineAPI/DocumentLifecycle.swift` for the frozen `SaveMode`/`save` signature (no change needed, API package untouched) and `PDFEngineError` (`DocumentHandle.swift`) for the right typed-error case (`.ioFailure`). Confirmed the vendored xcframework already ships `fpdf_save.h` (`ThirdParty/pdfium/prebuilt/PDFium.xcframework/macos-arm64_x86_64/Headers/fpdf_save.h`) and that `CPDFium/include/*.h` are verbatim copies of the vendored headers (`diff` against `fpdf_annot.h` was empty) — same copy-in pattern for `fpdf_save.h`.

**Plan:**
1. Copy `fpdf_save.h` into `CPDFium/include/`, add to `module.modulemap`.
2. `FPDF_FILEWRITE` has no user-data/context field — write a small context-threading shim (`PDFiumSaveWriter.swift`) using the "widen the C struct, `withMemoryRebound` in the trampoline" technique, since a plain top-level global var would race across multiple `PDFiumEngine` actor instances (unlike the single `pdfiumLibraryInitialized` global, which is init-once and immutable).
3. Wire `PDFiumEngine.save` to call it with the right `FPDF_INCREMENTAL`/`FPDF_NO_INCREMENTAL` flag per `SaveMode`, then a single `Data.write(to:options:.atomic)`.
4. Tests: engine-level open→add-annotation→save→reopen→verify round-trip for both modes (temp scratch files, never overwriting fixtures), plus a typed-`.ioFailure` test for an unwritable destination. Replace the now-stale `testSaveIsNotYetImplementedButFailsTyped`.
5. Risk: acceptance criterion also asks for `DocumentSession`'s `AtomicSaver` to be wired in a regression test — but this task's own Primary package/Files-Likely-Affected are `DocEngineHost`-only and it isn't marked `[INTEGRATION]`. Per CLAUDE.md §6 ("one task = one package... multi-package work must be an `[INTEGRATION]` task") I'm treating that bullet as aspirational/out-of-scope-as-written rather than expanding this task across packages — filed the wiring as a separate follow-up task (`P1-22-documentsession-atomicsaver-wiring.md`, High priority) instead of doing a drive-by cross-package change. Noting this as an AGENT_LOOP.md §9 "acceptance criteria ambiguous" case rather than silently deviating.

**Implementation:** `Sources/DocEngineHost/PDFiumSaveWriter.swift` (new) holds `PDFiumSaveContext`/`PDFiumSaveBuffer`/the C trampoline/`pdfiumSaveAsCopy`. `PDFiumEngine.save` now calls it and writes the result to `url`. Updated the stale "save always throws" doc comment on `PDFiumEngine` itself.

**Verify:** `Scripts/verify.sh DocEngineHost` → `OK` (build + tests + boundary lint). No `*Conformance`/`*Integration` test classes in this package — `verify-integration.sh` is a legitimate skip (CLAUDE.md §9/P0-15). Not a benched path; `Scripts/corpus-roundtrip.sh` doesn't exist yet (P1-16, still a no-op per AGENT_LOOP.md Step 4.4).

**Harden/security self-audit:** No vault/network/JS-eval surfaces touched. `PDFiumSaveBuffer` holds document *bytes* only (not vault values), scoped to the duration of one `save()` call, never logged. The `Unmanaged`/`withMemoryRebound` pattern is confined to one file with a doc comment explaining why it's safe (PDFium only ever dereferences its own declared struct fields; we never mutate the vendored header). No new entitlements, no new dependencies, no frozen-seam (`PDFEngineAPI`/`Schemas`) changes.

**Docs updated in this PR:** `Packages/DocEngineHost/CLAUDE.md` (save paragraph rewritten, stale "still unimplemented" paragraph removed), `okf/engines/doc-engine-host.md` (description + save bullet + still-absent list), `okf/sessions/document-session.md` (round-trip note now distinguishes "engine save exists" from "AtomicSaver wiring still open"), `tasks/escalations/E-009-p1-04-engine-save-missing.md` (status + "After repair" update), `Tests/DocEngineHostTests/PDFiumAnnotationStoreTests.swift` (stale leading comment). Filed `tasks/backlog/phase-1-core-pillars/P1-22-documentsession-atomicsaver-wiring.md` for the remaining cross-package wiring.
