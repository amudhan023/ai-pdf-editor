# Phase 1 — Lessons

## P1-02 — Thumbnails/outline
- No approved snapshot-testing dependency exists (CLAUDE.md §17 is default-no) — adding one is its own ADR, not a UI-task drive-by. Substitute view-model unit tests over the sync/selection/navigation contracts instead.

## P1-03 — Text extraction/search
- An engine's extracted text won't byte-match a different authoring tool's reference text (segmentation/whitespace conventions differ) — pin known-content containment + geometry bounds in tests, not exact hash/string equality against a manifest built with another tool.

## P1-04 — Annotations/markup
- When implementing a feature surfaces a hard cross-cutting infra gap (here: engine-side save didn't exist at all, so nothing could reach disk) that no existing task tracks: don't silently expand this task's scope to fix it. File an escalation (E-009) *and* a new, appropriately-prioritized backlog task for the missing infra, ship what's honestly achievable now, and state plainly in the PR which acceptance criteria remain unmet and why. Same pattern for a missing fixture class (real Acrobat/Preview-authored annotations, E-005/E-010) — don't fabricate a substitute fixture that doesn't actually exercise the real gap.

## P1-07 — Tabs/windows/shortcuts
- AppKit menu/window wiring isn't exercisable under plain `XCTest` (no run loop). Keep AppKit glue thin, unit-test the non-AppKit logic directly, assert structurally on the built `NSMenu`/state tree, and cover the rest with a manual `swift run` smoke test.

## P1-08 — Vault service storage
- Secure Enclave key generation fails in this sandbox (`errSecInteractionNotAllowed` — no interactive Security Server session), the same class of environment gap as Xcode-only XCTest. Design the SE dependency behind a protocol seam (`KeyWrappingProvider`) so the rest of the system is testable via a mock; real-hardware verification of that one path stays a documented, not a blocking, gap.
- A previously-merged, unrelated PR (here: a supervisor-tooling fix) can land on `origin/main` squashed under a different SHA than the commit your branch already carries — rebase onto fresh `origin/main` (dropping the now-redundant duplicate) before continuing, rather than assuming your branch and `main` agree.

## P1-09 — Vault lock/auth
- An `AsyncStream` handle exposed on an actor can be `nonisolated` safely — the stream itself provides the safety guarantee; only its production/consumption needs isolation, not the property that hands out the handle.

## P1-10 — Vault CRUD/history
- Extending a frozen `*API` package's shared conformance suite needs an ADR + `[INTEGRATION]` PR. When a task isn't scoped for that, test the new capability directly in the implementing package's own test suite instead of reaching into the frozen seam.

## P1-12 — Inference service registry
- A task file can cite a specific ADR number that's already taken by the time you actually run the task (another task landed first and claimed it) — check `docs/adr/` for the real next-free number rather than trusting the task text, and note the drift in the new ADR itself.
- A phase's backlog can be fully blocked while a later phase's independent track is not — Dependencies-satisfied-in-`done/` is the real gate, not folder order; pick the next unblocked task by that rule and record why in the Journal.

## P1-13 — OCR endpoint
- A frozen conformance-suite fixture can turn out to be structurally impossible for a real (non-fake) implementation to satisfy honestly. Fix it via a scoped ADR to the fixture literal specifically — never fabricate a passing result to match a fixture that was only ever exercised against a stub.

## P1-14 — Embedding/alias matcher
- When a task specifies a vendored ML model or a dependency with no approved parser in CLAUDE.md's allowed set, and an on-device Apple framework already covers the need (e.g. `NLEmbedding` for embeddings, `Foundation`-native JSON instead of an unapproved YAML parser) — substitute it and document the substitution plainly, rather than blocking on a new-dependency ADR or silently shrinking scope. Same-or-fewer moving parts than what the task asked for doesn't need an escalation; more moving parts would.

## P1-15 — Audit log
- A closed enum case that wraps a validated payload (e.g. `.sha256(SHA256Hex)`) only actually enforces that validation if the wrapper type's *only* initializer validates — a first draft that instead carried a raw `String`/`Int` let a caller construct an "invalid" case directly, silently defeating the "type system rejects a bad value" invariant. Check that there is no non-validating construction path, not just that a validating one exists.

## P1-19 — Viewer memory-pressure wiring
- A `DispatchSourceMemoryPressure` (or any GCD dispatch source) crashes on release if it's never been activated. Call `.activate()` in `init`, not in a separate `start()` that a caller might forget to invoke.

## P1-21 — DocEngineHost save modes
- `FPDF_FILEWRITE`-style C callback structs with no user-data field can be threaded through by widening the struct (real fields the C side reads/writes first, an `Unmanaged<T>` context appended after, recovered via `withMemoryRebound` in the trampoline) — do not add a real context field to a vendored/frozen third-party header itself.
- When an acceptance criterion's bullet reaches outside your task's own Primary package (here: wiring a cross-package consumer) and the task isn't marked `[INTEGRATION]`, treat that bullet as out-of-scope-as-written and file a separate follow-up task rather than expanding the diff across packages.
