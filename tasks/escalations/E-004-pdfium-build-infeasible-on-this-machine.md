# E-004 — PDFium standard build is infeasible on this machine (P0-03 blocked)

**Raised by:** P0-03 · **Severity:** blocks P0-03 (and its dependents P0-06, P0-07) — environment/resource limit, not a code defect

## Evidence
- Installed `git-lfs` and `ninja` via Homebrew (both succeeded, small).
- `gn` (Google's meta-build tool) is not available via Homebrew at all — it's normally obtained through `depot_tools` tooling itself.
- Ran the standard PDFium acquisition path: cloned `depot_tools` (~10MB, fine), then `fetch pdfium` (the documented, standard way to check out PDFium for building).
- `fetch pdfium`'s `gclient sync` started pulling dependencies and was still "Still working on" these at the point it was safety-killed: `pdfium/testing/corpus`, `pdfium/third_party/icu`, `pdfium/third_party/rust-toolchain` (a full Rust toolchain tarball), `pdfium/third_party/skia` (Chromium's graphics library), `pdfium/v8` (the V8 JavaScript engine).
- This machine had ~7.4GB free disk at the start of the attempt; free space dropped to ~2GB within 3 minutes, still mid-sync with several large third-party trees not yet even fully fetched. A safety monitor (self-imposed, not part of any script in this repo) killed the process at the 2GB-free threshold to avoid filling the disk. Reclaimed to ~6.1GB after deleting the partial checkout.
- **Conclusion: this is not a fixable code bug or a missing-package issue.** PDFium's standard build, via Google's own tooling, checks out the same dependency scale as building a slice of Chromium itself (V8, Skia, ICU, a pinned Rust toolchain) — realistically tens of GB and likely hours of build time even with a full toolchain installed. No number of retries against the current environment changes this.

## Decision needed (human)
Option A (matches the task's original intent — build from source, maximum reproducibility/auditability): run this on a machine with substantially more free disk (100GB+ recommended) and be prepared for a long build. `gn` still needs sourcing (available as a `depot_tools`-managed CIPD package, fetched automatically once `gclient sync` completes far enough to reach the `gn` DEPS entry — never independently verified here since sync was aborted first).
Option B (practical, common in the iOS/macOS open-source ecosystem, but changes the supply-chain trust model): consume a reputable prebuilt PDFium distribution instead of building from Google's source directly — e.g. `bblanchon/pdfium-binaries` on GitHub, which publishes prebuilt static libraries for macOS (arm64 + x86_64) built from pinned PDFium revisions via public, auditable CI. This is a **new third-party dependency decision** requiring an ADR per CLAUDE.md §17 (license, supply-chain posture, binary size, build-vs-buy) and Constitution Article 7 (human approval) — not something to substitute silently even though it's technically easy.
Option C: defer P0-03 (and its dependents P0-06 render pipeline, P0-07 shell viewer app) until Option A or B is decided; continue with backlog tasks that don't depend on it (P0-04, P0-08, P0-09, P0-10 are all pure-Swift / no PDFium dependency).

## After repair
Whichever option: update `docs/adr/ADR-001` (already referenced by P0-03) with the actual acquisition method used and its reproducibility/verification story, per the task's Definition of Done.

## Interim decision (made now, so the backlog isn't blocked entirely)
Proceeding with Option C: P0-03/P0-06/P0-07 stay in `tasks/backlog/`, unclaimed, pending a human decision on Option A vs B above. Continuing with P0-04, P0-08, P0-09, P0-10.
