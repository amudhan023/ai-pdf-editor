# E-002 — `swift test` cannot run: neither XCTest nor Swift Testing framework present (CLT-only machine)

**Raised by:** P0-01 · **Severity:** blocks the "test" leg of `Scripts/verify.sh` for all 17 packages · **Not a code defect — do not attempt a code fix.**

## Evidence
- After E-001's CLT reinstall, `swift build` succeeds for every package. `swift test` fails for every package with `error: no such module 'XCTest'`.
- Root-cause probe (clean-room package, outside the repo, `import Testing` / Swift Testing instead of XCTest): **also fails** — `error: no such module 'Testing'`. So this is not an XCTest-specific gap; no test framework of any kind is available.
- `find /Library/Developer/CommandLineTools -iname "XCTest*"` finds only a private `XCTestSupport.framework` (unrelated internal support framework, not the public `XCTest.framework` test API).
- `ls /Applications | grep -i xcode` → no match. **No full Xcode.app is installed.**
- Conclusion: on macOS, both `XCTest.framework` and the `Testing.framework` (Swift Testing) ship inside `Xcode.app` (under its `Platforms/MacOSX.platform/.../Frameworks`), not inside standalone Command Line Tools, on any CLT version. This is an Apple packaging boundary, not a broken install — reinstalling CLT again will not fix it.

## Decision needed (human — App Store / large download, ~7-12 GB)
Install full Xcode (the same "Option A" already logged as recommended in E-001, since P0-07's app target needs it regardless):
1. App Store → install Xcode.
2. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. `sudo xcodebuild -license accept` (first-launch license gate)

## After repair
Re-run `Scripts/verify.sh --all`. If green: merge `task/P0-01-repo-scaffold`, move task file to `done/`, P0-02 unblocks.

## Standing note for future agents (avoid re-analysis, per TOKEN_EFFICIENCY §7)
CLT-only environments can build SPM packages but cannot execute their test targets, at all, ever — this is permanent, not a version issue. `Scripts/bootstrap.sh` already warns about CLT-vs-Xcode for the app target; that warning is being broadened in the same PR to cover testing in general so the next agent doesn't re-diagnose this from scratch.
