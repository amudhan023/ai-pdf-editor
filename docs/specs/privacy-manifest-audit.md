# Privacy Manifest Audit (P3-11)

**Owner of this fact:** this document. Every `PrivacyInfo.xcprivacy` in the repo must be traceable to a row here; a declaration with no row is speculative and must be removed (CLAUDE.md §8, Constitution Article 13 — evidence over assertion). **Adding a new required-reason API call requires updating both the manifest and this doc in the same PR** (cross-referenced from `App/CLAUDE.md` and each `Services/*/README.md`).

Audited against `origin/main` @ `fa47934` by walking every non-test `.swift` file reachable from each bundle's actual SwiftPM target graph (not just the file's own directory) for required-reason API usage: `UserDefaults`, file-timestamp accessors (`creationDate`/`contentModificationDate`/`resourceValues(forKeys:)`/`attributesOfItem`), disk-space APIs (`volumeAvailableCapacity*`, `statfs`), and system-boot-time APIs (`systemUptime`, `mach_absolute_time`).

## App/PrivacyInfo.xcprivacy

Target graph: `Vaultform` executable ← `PDFEngineAPI`, `Platform`, `DocEngineHost`, `DocumentSession` (`App/Package.swift`).

| Category | Reason | Call sites | Why |
|---|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | `App/Sources/Vaultform/WindowStateStore.swift`, `RecentDocumentsStore.swift`, `DefaultAppOnboarding.swift`; `Packages/DocumentSession/Sources/DocumentSession/UI/DocumentViewModel.swift`, `Viewer/ScrollPosition.swift` | App-local preferences (window/tab restoration, recents, scroll position, onboarding flag) — never another app's or an app-group's defaults, so `CA92.1` ("information only accessible to the app itself"). |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | `Packages/DocumentSession/Sources/DocumentSession/Save/AtomicSave.swift` (`resourceValues(forKeys: [.contentModificationDateKey])`) | Compares modification timestamps of files inside the app's own document/backup container to pick the newer atomic-save candidate — never displayed or transmitted. |

No disk-space or boot-time API usage found — not declared.

## Services/DocEngineService, Services/InferenceService, Services/VaultService — PrivacyInfo.xcprivacy

Target graph: each service executable depends only on `Packages/Platform` (own `Package.swift`). `Platform` has no required-reason API usage. `Packages/VaultStore/Sources/VaultStore/Backup/BackupManager.swift` does use file timestamps, but `VaultStore` is not yet a dependency of `Services/VaultService`'s target — nothing to declare today. **If a future task wires `VaultStore` (or any other required-reason-API-using package) into a service target, add its declaration here and to that service's manifest in the same PR.**

All three manifests: empty `NSPrivacyAccessedAPITypes`, empty `NSPrivacyCollectedDataTypes`, `NSPrivacyTracking: false` — matches "zero network, zero data collection" (CLAUDE.md §8.1).

## Data collection

`NSPrivacyCollectedDataTypes` is empty in all four manifests. Telemetry/crash reporting (opt-in, structurally content-free per CLAUDE.md §8.2/§8.4) are P3-09 scope and not yet wired into any of these targets; this doc must gain a row the moment they are.
