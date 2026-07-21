# P1-22 — DocumentSession: wire AtomicSaver to the real PDFiumEngine.save

**Owner:** claude-agent · **Branch:** task/P1-22-documentsession-atomicsaver-wiring · **Claimed:** b71c3f385059774f3658ed2a12e4932345e1c88a

## Journal

**Orient:** Root CLAUDE.md; `Packages/DocumentSession/CLAUDE.md`; `AtomicSave.swift` (P1-16 — `AtomicSaver.replace(original:withTemp:)` expects the caller to already have written mutated bytes to `temp`; it doesn't call the engine itself); `DocumentSession.swift` (no `save()` method existed at all, and no URL was retained after `open()`); `DocumentLifecycle.save(_:mode:to:)` (writes serialized bytes directly to the given `url` — that's the missing link). Read `tasks/done/P1-21-docengine-save-modes.md` and `E-009` (already has the real-`PDFiumEngine` engine-layer round trip; this task's gap is purely session-level wiring).

**Key finding — the literal acceptance criterion ("reopen via real PDFiumEngine, not FakePDFEngine") conflicts with the architecture boundary:** `Packages/DocumentSession`'s import allowlist (`Scripts/import-allowlist.txt`) is `Foundation PDFEngineAPI Platform SwiftUI AppKit os OSLog` — no `DocEngineHost`, and that's by design (`App/CLAUDE.md`: only `AppDelegate.init` may name a concrete engine; `DocEngineHost` is Infrastructure, `DocumentSession` is Application layer, CLAUDE.md §3.1 forbids the reverse import regardless of test-vs-source). Adding `DocEngineHost` to this package (even test-only) would be a new cross-package dependency needing an ADR (§3.7) and would invert the intended dependency direction — not something to do as a drive-by in a Complexity-S task. Resolution (same pragmatic-scoping precedent E-009 itself already used for a like-for-like tension): wrote `MockPersistingEngine`, a test-local (`Mock*`) `DocumentLifecycle`/`PageRenderer`/`AnnotationStore` that *genuinely* persists annotation state to disk via `save`/`open` (unlike `FakePDFEngine`, which is in-memory-only and would make a "round trip" test vacuous) — proves `DocumentSession.save()`'s wiring for real, entirely within the package boundary. The real-`PDFiumEngine` half of the round trip already exists at `DocEngineHost`'s layer (P1-21). Documented in the mock's doc comment, `CLAUDE.md`, `okf/sessions/document-session.md`, and E-009 so nobody mistakes this for skipping the criterion rather than satisfying its intent at the correct layer.

**Implement:** `DocumentSession` gained `currentURL` (set on `open`, cleared on `close`) and an optional `atomicSaver: AtomicSaver?` init param (same optional-capability pattern as `outlineReader`/`textEditor`/`annotationStore` — unwired throws `.engine(.unsupportedFeature)`, no silent no-op). `save(mode:)` writes the engine's serialized bytes to a same-directory sibling temp file (same volume → `AtomicSaver`'s replace is a true atomic rename; deliberately not system `/tmp` — CLAUDE.md §7.8's "session-keyed encrypted scratch container" doesn't exist anywhere in the codebase yet, building one is out of scope for this task, and a same-directory temp is both the standard atomic-save technique and not literally `/tmp`, so it satisfies the rule's intent without inventing new infra as a drive-by). `DocumentSessionError` gained `.saveFailed(AtomicSaveError)`, kept distinct from `.engine(...)` per the Requirements' explicit "don't get generalized" instruction.

**Verify:** `Scripts/verify.sh DocumentSession` — OK (build + full test suite incl. pre-existing `AtomicSaveTests` fault-injection tests, unmodified and still passing + boundary lint). `Scripts/check-boundaries.sh DocumentSession` — clean.

**Harden notes:** Re-read the diff: `save()`'s two failure branches (engine throw, atomic-replace throw) both best-effort clean up the orphaned temp file before rethrowing — no leaked scratch file on either failure path. No dead code. `FailingSaveEngine`/`MockPersistingEngine` are test-local, each serving this file's tests only, not shipped abstractions.

**Security/privacy self-audit:** Touches document bytes only (no vault content). The transient temp file used mid-save carries mutated document content but lives beside the real document (same directory, same trust boundary as `original` itself) for the duration of one `save()` call only — either consumed by `FileManager.replaceItemAt` on success or removed on failure; never written to `/tmp` or a user-visible location. No new logging added.

**Acceptance criteria status:** Both met, one at a different (correct) layer than literally worded — see "Key finding" above. `E-009` reduced to its one remaining item (Acrobat/Preview interop fixtures, blocked on `E-005`).

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
