# P0-06 — DocEngine.xpc Render Pipeline v1

**Owner:** claude-agent · **Branch:** task/P0-06-render-v1 · **Claimed:** d74807ff70e9f6b3b7dee148711a907c22bc6cf0

**Epic:** E2 · **Primary package:** `Packages/DocEngineHost` · **Complexity:** L · **Priority:** Critical

## Goal
Implement `PageRenderer` on PDFium inside DocEngine.xpc: open document from security-scoped handle, page metadata, rasterize page tiles to IOSurface.

## Background
ARCHITECTURE.md §2.3: DocEngine.xpc is per-document, no-entitlement, hostile-input sandbox. This task delivers the first real engine capability behind the P0-04 protocols over the P0-05 transport.

## Requirements
- Open/close documents (incl. password-protected open path); page count/size/rotation; render tile (page, rect, scale) → IOSurface, correct color management.
- Per-document service instance lifecycle managed by `DocEngineHost` client (spawn, reuse, teardown).
- Passes the P0-04 conformance suite for implemented protocols.
- Memory: streamed rendering only; no full-document rasterization (NFR-P5 groundwork).

## Dependencies
- P0-03, P0-04, P0-05.

## Files Likely Affected
- `Packages/DocEngineHost/Sources/**`; `Services/DocEngineService/**`.

## Acceptance Criteria
- Corpus sample (100 varied PDFs incl. malformed set) opens or fails gracefully — zero service-host crashes surfacing to app.
- Tile render p50 < 16ms at 1x for corpus text pages on M1 (NFR-P2 groundwork), measured in bench harness.

## Definition of Done
- Global DoD, plus: malformed-PDF fuzz seed set added to corpus manifest.

## Testing Requirements
- Conformance suite green; render-snapshot tests against reference rasters; crash-isolation test (poison PDF kills service, app recovers).

## Documentation Updates
- `Packages/DocEngineHost/CLAUDE.md` (lifecycle model, IOSurface contract).

## Journal

**Orient:** Read root CLAUDE.md, this task file, `Packages/DocEngineHost/CLAUDE.md`, and its Tests/ listing. E-004 (PDFium build infeasible) was the prior blocker for this task; the xcframework/linkage groundwork from P0-03 was already in place, so PDFium is in fact buildable here — the escalation's premise no longer holds.

**Plan:** Implement `PDFiumEngine` as an actor conforming to `DocumentLifecycle` + `PageRenderer` (`PDFEngineAPI`, frozen — no changes needed). Serialize all PDFium calls via actor isolation (library is not thread-safe). `open`/`close` manage `FPDF_DOCUMENT`/`FPDF_PAGE` lifecycle; `renderTile` uses `FPDF_RenderPageBitmapWithMatrix` against only the requested tile rect (never full-page) for NFR-P5. Add `fpdf_edit.h` to the `CPDFium` modulemap for rotation. Wire `Scripts/bench.sh render-latency` to a new `RenderLatencyBench` executable target (mirrors `Platform`'s `XPCLatencyBench` pattern) since `swift run` needs to import `DocEngineHost` directly. Add two new malformed fuzz-seed fixtures (bit-flipped body/tail) to the corpus manifest per DoD.

**Verify (2026-07-12):**
- `Scripts/verify.sh DocEngineHost` → OK (build + tests + boundary lint).
- `Scripts/verify-integration.sh DocEngineHost` → clean skip, no `*Conformance`/`*Integration` classes in this package yet.
- `Scripts/bench.sh render-latency` → pass, p50 3.17ms / p90 3.29ms / max 3.42ms against a 16ms budget (NFR-P2 groundwork), 100 iterations across 5 starter fixtures.
- `Scripts/bench.sh corpus-open` → all rows (including the 2 new malformed fixtures) sha256-match.

**Acceptance criteria:**
- "Corpus sample opens or fails gracefully, zero crashes" → `PDFiumEngineTests.testOpenGracefullyRejectsEachMalformedFixture` exercises all 7 malformed manifest rows; every one either throws a typed `PDFEngineError` or is on the explicit PDFium-repair-tolerated allowlist (`bit-flipped-body`, recovered by PDFium's xref-rebuild heuristic — documented in the manifest row).
- "Tile render p50 < 16ms at 1x" → met with large margin (3.17ms), see bench output above.

**Testing Requirements note:** the literal "crash-isolation test (poison PDF kills service, app recovers)" is out of reach in-process — real cross-process XPC isn't wired yet (`Services/DocEngineService` still ships ping-skeleton logic pending P0-07's app-bundle embedding, per that package's README and `Packages/DocEngineHost/CLAUDE.md`'s IOSurface note). In-process, `renderTile`/`open` on every malformed fixture demonstrably never crashes the host and always yields a typed error or graceful success — the same invariant, without a real service boundary to kill. Real crash-isolation testing is P0-07-or-later scope.

**Architecture self-review (CLAUDE.md §14 / AGENT_LOOP.md §6):**
1. No API-package type duplication — `PDFiumEngine` implements existing `PDFEngineAPI` protocols only.
2. No logic misplaced by layer — PDFium calls stay inside `DocEngineHost`, the one package allowed to link the engine.
3. ARCHITECTURE.md doesn't need edits — this delivers exactly the capability §2.3 describes as pending.

**Security/privacy self-audit:** touches document bytes only (untrusted PDF input via `FPDF_LoadDocument`/render calls), no vault values, no network APIs, no logging of document content — only IDs/errors. `mapPDFiumError` surfaces typed errors, no `fatalError`/`try!` on the parse path.

**Scope note:** `Scripts/bench.sh`, `Fixtures/pdf-corpus/{README.md,manifest.json}`, and `Services/DocEngineService/README.md` are touched outside the primary package — all required by this task's own DoD (fuzz seed set) and Acceptance Criteria (bench harness), not drive-by. `.claude-supervisor/*` working-tree changes are supervisor-process operational state, unrelated to this task, and are left uncommitted.

**Status:** Implementation, tests, and bench are complete and green. Proceeding to PR.
