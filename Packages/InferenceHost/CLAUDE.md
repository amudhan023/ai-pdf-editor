# InferenceHost

**Purpose:** XPC client + model registry/adapters (Vision, Core ML, FoundationModels) implementing InferenceAPI. Models load only after signature+checksum verification.

**Allowed imports:** Foundation, InferenceAPI, Platform, CryptoKit, NaturalLanguage, Vision, CoreGraphics, CoreImage, CoreText, ImageIO (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh InferenceHost` (build + tests + boundary lint for this package only); `Scripts/verify-integration.sh InferenceHost` (P1-12's `*ConformanceTests`/`*IntegrationTests`).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- `ModelRegistry` never registers a manifest whose pack fails checksum or signature verification (CryptoKit/Curve25519) — see `docs/specs/model-pack-format.md`.
- `embed` (P1-14) is backed by Apple's on-device `NLEmbedding`, not a vendored model pack — `manifest.packData` is deliberately unused in that path.
- `ocr` (P1-13) is backed by Vision's `VNRecognizeTextRequest` (`VisionOCRProvider`), same "OS capability, not packData" shape as `embed`. It never fabricates a region for undecodable `imageData` — throws `InferenceError.adapterFailure` instead (CLAUDE.md §2 honest failure); see ADR-012 for why the shared `InferenceConformanceSuite` OCR fixture had to become a real decodable image once this stopped being a stub. `classify`/`extractEntities` are still stubs pending Phase 2.
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
