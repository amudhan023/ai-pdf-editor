# E-001 — Swift toolchain cannot compile any SPM manifest (blocks P0-01 verification)

**Raised by:** P0-01 · **Severity:** blocks all build/test work on this machine

## Evidence
- `swift build` fails for every package AND for a freshly generated `swift package init` library — this is environment-level, not our code.
- Failure: manifest link error `Undefined symbols: PackageDescription.Package.__allocating_init(...)`.
- `nm -gU /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI/libPackageDescription.dylib` shows 0 matching Package-init symbols: the CLT's ManifestAPI dylib does not match swiftc 6.0.3 — a broken/partially updated Command Line Tools install.
- No full Xcode present (`xcode-select -p` → CommandLineTools).

## Decision needed (human — requires sudo/App Store)
Option A (recommended, needed for P0-07 anyway): install full Xcode 16+, then `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
Option B (faster): reinstall CLT: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.

## After repair
`Scripts/verify.sh --all` → if green, merge `task/P0-01-repo-scaffold`, move task to done/.
