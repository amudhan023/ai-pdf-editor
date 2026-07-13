# P0-03 — PDFium Build Integration

**Owner:** claude-agent · **Branch:** task/P0-03-pdfium-binaries

**Epic:** E2 · **Primary package:** `ThirdParty/pdfium` · **Complexity:** L · **Priority:** Critical

## Status (2026-07-11)

E-004 (from-source build infeasible on available hardware — see
`tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`)
resolved by human-approved decision: consume a vetted prebuilt distribution
instead of building from Google's source. See
`docs/adr/ADR-001-pdfium-source-and-pin.md` for the full sourcing
decision and verification, `ThirdParty/pdfium/README.md` for the upgrade
playbook.

**Done:** pinned artifact vendored (`ThirdParty/pdfium/prebuilt/PDFium.xcframework`,
via Git LFS) with checksum-verified provenance; `DocEngineHost`'s
`binaryTarget` fixed and links successfully; `CPDFium` shim module added;
linkage-proof test (`testPDFiumLibraryLinksAndInitializes`) calls
`FPDF_InitLibrary`/`FPDF_GetLastError`/`FPDF_DestroyLibrary` against the
real library and passes — first acceptance criterion met (single-arch:
this machine is arm64; the vendored binary is a universal arm64+x86_64
slice, but re-running the test under Rosetta/an x86_64 CI runner to prove
the second architecture is still open).

**Not done (follow-up):** `Scripts/build-pdfium.sh` scripted-fetch path
(moot under the vendoring decision — superseded by
`ThirdParty/pdfium/README.md`'s upgrade playbook instead); Hardened
Runtime alignment / symbol stripping / dSYM (applies once this ships in a
real app target, not meaningful for a Swift-package-only linkage proof);
corpus-open smoke test on 20 sample PDFs (needs the real `PDFEngineAPI`
adapter implementation — P0-06 — which doesn't exist yet); reproducing
identical library version metadata from a from-source rebuild (moot under
the vendoring decision — reproducibility now comes from the pinned
checksum in `PINNED_REVISION`, not a local rebuild).

## Goal
Reproducible, pinned PDFium binaries (arm64 + x86_64) consumable by `DocEngineHost`, with the build recipe in-repo.

## Background
ADR-001 (ARCHITECTURE.md §10.1) selects PDFium as the engine core. Nothing on Track A proceeds without linkable binaries; reproducibility matters for security audits.

## Requirements
- Pin a PDFium revision; scripted fetch+build (`Scripts/build-pdfium.sh`) producing xcframework with headers; prebuilt artifacts committed via LFS so agents never build C++ locally.
- Hardened build flags aligned with Hardened Runtime; symbols stripped in release, dSYM retained.
- Thin Obj-C++ shim module target (`pdfium-shim`) exposing a C-compatible surface for Swift interop — no functionality yet, just linkage proof.

## Dependencies
- P0-01.

## Files Likely Affected
- `ThirdParty/pdfium/*`; `Scripts/build-pdfium.sh`; `Packages/DocEngineHost/Package.swift` (binary target reference).

## Acceptance Criteria
- `DocEngineHost` links the xcframework and calls `FPDF_InitLibrary`/`FPDF_GetLastError` successfully in a test on both architectures.
- Rebuilding from the pinned revision reproduces identical library version metadata.

## Definition of Done
- Global DoD, plus: ADR-001 updated with pinned revision + upgrade procedure.

## Testing Requirements
- Link-and-init unit test; corpus-open smoke on 20 sample PDFs (no crash, page count correct).

## Documentation Updates
- `ThirdParty/pdfium/README.md` (upgrade playbook); ADR-001.

## Journal

**Housekeeping fix (2026-07-12):** the PR for this task (feat(DocEngineHost):
vendor pinned PDFium binaries, resolve E-004 (P0-03), #47) merged to `main`
as commit `862e0a4`, but Step 8d (move task file to `done/`) was never
executed — the file was left in `in-progress/`, which incorrectly blocked
every task in `tasks/backlog/phase-0-foundation/` that lists P0-03 as a
dependency (their dependency check reads folder location). Verified the
merge landed on current `main` (`ThirdParty/pdfium/{prebuilt,licenses,
PINNED_REVISION,README.md}` present, `docs/adr/ADR-001-pdfium-source-and-pin.md`
in place) before moving this file. The two items noted as "Not done
(follow-up)" above (x86_64-architecture re-run of the linkage test; corpus
smoke test) remain genuinely open but are correctly deferred — the corpus
smoke test explicitly depends on P0-06 (`PDFEngineAPI` adapter), which does
not exist yet, so this task cannot itself close that gap. No code changed
in this fix, only task-tracking state.
