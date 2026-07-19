# Phase 0 — Lessons

## P0-01 — Repo scaffold
- Shell: pipelines without `pipefail` lie about exit codes (e.g. piping through `tail`) — `verify.sh` had to be rewritten exit-code-strict, output-on-failure-only. Trust exit codes, never infer success from log absence.
- Environment: on macOS, XCTest/Testing frameworks ship only inside Xcode.app, never inside standalone Command Line Tools, on any version — a permanent packaging boundary, not a broken install (E-002). This surfaced as a stale blocker again in later tasks (P1-08, P1-12, P1-16) after Xcode got installed partway through the project — cheaply re-verify (`xcode-select -p`, `swift test`) before trusting an old escalation's environment claim instead of assuming it still holds.

## P0-02 — CI pipeline
- CI: `set -euo pipefail` + a `grep` stage that legitimately finds zero matches fails the whole pipeline even though "no matches" is the correct result — isolate that stage with `|| true` rather than letting pipefail propagate an empty-but-correct result as failure.
- Infra: GitHub Free blocks branch protection rules on private repos (403) — a plan/hosting constraint, not fixable in code; recorded as an explicit human decision (E-003), later resolved when the repo went public for an unrelated billing reason (E-006).
- CI can fail an entire job matrix at random — including jobs on packages the PR never touched — with an identical "billing/spending limit" annotation. That's an account-billing block, not a real test/build failure; don't burn fix-loop attempts retrying it (see also P0-09).

## P0-03 — PDFium build / task-tracking hygiene
- Process: a merged PR's task file can be left stranded in `tasks/in-progress/` if Step 8d (move to `done/`) is skipped — this incorrectly blocks every backlog task that lists it as a dependency, since the dependency check reads folder location, not merge status. Verify the merge actually landed on `main` before treating a stale claim as still open.

## P0-05 — XPC transport (Platform)
- `NSXPCListener.delegate` is `weak` — if the host object holding it falls out of scope after `resume()`, every subsequent connection silently gets no delegate (looks like `.serviceCrashed`). Retain hosts explicitly.
- Encode a host-detected error (e.g. version mismatch) from the *receiver's* frame of reference before sending it back — relaying it verbatim reads backwards once the client receives it.
- Blocking the main thread with `DispatchSemaphore.wait()` before an unstructured `Task {}` has been scheduled deadlocks the process (the Task never gets to run) — pump `RunLoop.main.run()` instead of blocking first.
- Genuine cross-process XPC between two ad-hoc, non-app-bundled, non-launchd-registered processes does not work on this platform (`NSXPCListenerEndpoint` archiving throws; a bare `machServiceName` connection just hangs). Real cross-process XPC needs either launchd registration or a proper `.xpc` bundle embedded in an app target (P0-07's job) — `NSXPCListener.anonymous()` in the same process is the fallback for testing the transport contract until then.

## P0-07 — Shell/viewer app
- Toolchain: `swift package generate-xcodeproj` no longer exists on this toolchain — there is no way to get a real `.xcodeproj` without hand-authoring a `.pbxproj`. This blocks real `.xpc` bundle embedding, XCUITest, and notarization; substitute unit tests + a manual `swift run` smoke test until a real Xcode project exists.
- Gatekeeper rejecting `open -a` on an ad-hoc-signed `.app` is expected for an unnotarized local build, not a defect — direct execution / debugger attach aren't subject to that check.

## P0-08 — Fixtures/bench harness
- When an acceptance criterion can only be partially met (e.g. corpus-size targets, no engine yet to validate against), say so explicitly in the tool's own output and the PR rather than declaring it met — this repo's convention is honest partial completion over a silently-green check.

## P0-09 — VaultAPI
- A task's own Requirements text can omit a Constitution/CLAUDE.md-mandated type (e.g. `SecureBytes`). When the two conflict, the higher-precedence document wins and the fix belongs in the same PR — especially on a frozen `*API` seam, where retrofitting later needs a breaking, superseding ADR.

## P0-10 — PolicyKit
- Dead code written "for future hygiene" with no caller and no test gets deleted at Harden, not kept "just in case" — record the underlying concern in the package `CLAUDE.md`/a spec instead, for whoever actually has a real consumer to design against.

## P0-12 / P0-13 — Process-tooling tasks
- A task whose Primary package is "none" (pure `AGENT_LOOP.md`/CI-policy edits) has no `Scripts/verify.sh` target — demonstrate acceptance via a manual/scripted verification note in the PR instead of forcing a package to attach it to.

## P0-14 — Branch protection live
- `gh api` PUT bodies with nested booleans don't coerce correctly through `-f`/`-F` flags — pass `--input` with a real JSON file instead.

## P0-16 — Supervisor effort selection
- `claude_supervisor.py` (process tooling, not a product package) has no package `CLAUDE.md` and no `verify.sh` target — verify via `python3 -m unittest` plus a scripted dry run pasted into the PR.
