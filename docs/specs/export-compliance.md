# Export Compliance — Vault Cryptography

Confirms `Packages/VaultStore`'s crypto backend for Apple export-compliance classification. See PRD Risk R8; task `tasks/done/P3-13-export-compliance.md`.

## Backend confirmation

`Packages/VaultStore` depends on `ThirdParty/GRDB` (`docs`: `ThirdParty/GRDB/Package.swift`), which depends on the **official** `sqlcipher/SQLCipher.swift` SPM distribution, pinned exact:

- Source: `https://github.com/sqlcipher/SQLCipher.swift.git`
- Resolved: version `4.16.0`, revision `07bf6bc2191a063d6f1e7c3b5f276a3fadfe36b7` (`Packages/VaultStore/Package.resolved`)
- Delivered as a checksum-verified prebuilt `.xcframework` binary target (not source built against a bundled crypto library) — SwiftPM manifest pins the release asset checksum.

Linked-library evidence (`otool -L` on the built macOS slice of `SQLCipher.framework`):

```
SQLCipher.framework/Versions/A/SQLCipher (x86_64 and arm64):
    /usr/lib/libSystem.B.dylib
    /System/Library/Frameworks/CoreFoundation.framework/.../CoreFoundation
    /System/Library/Frameworks/Security.framework/.../Security
```

No `libcrypto`/`libssl` (OpenSSL) or any other bundled crypto library appears in the link table. The binary links only `Security.framework` — this is the "SQLCipher for Apple platforms" build that backs its cipher provider with `CommonCrypto`/`Security.framework`, not the community OpenSSL-backed distribution.

## Classification

Because the app's only cryptographic use is:
- authentication of the user to their local vault, and
- encryption of data at rest via the OS-provided `Security.framework`/`CommonCrypto` APIs (via SQLCipher),

this falls within Apple's **standard, exempt** encryption category (App Store Connect: "Does your app use encryption?" → Yes, but qualifies for the exemption for standard OS-supplied cryptography used only for authentication/data protection — no proprietary or non-standard algorithm, no encryption of data in transit to a server per Constitution/§7.1 no-network rule).

**Recommendation:** `App/Info.plist` → `ITSAppUsesNonExemptEncryption` = `NO` (the standard-exemption path means no separate self-classification submission is required at all under Apple's rules; `NO` is the correct declaration when the only encryption present is exempt per se, distinct from `YES` + self-classification which is for encryption that requires annual self-classification reporting but is still exempt from a CCATS/export license).

## What this doc does NOT do

Per root `CLAUDE.md` §7.7 (new entitlements/Info.plist changes need an ADR + human sign-off) and the fact that the App Store Connect compliance questionnaire is submitted through an external account this session has no access to:

- **Not done:** editing `App/Info.plist` to set `ITSAppUsesNonExemptEncryption`. The recommended value is documented above for a human (or a follow-up task with sign-off) to apply.
- **Not done:** completing the actual App Store Connect export-compliance questionnaire — requires the App Store Connect account holder.
- **Not done:** the PRD Risk R8 pre-GA legal review sign-off — this doc is evidence for that review, not a substitute for it.

## Re-verification trigger

Re-run this check (`Packages/VaultStore/Package.resolved` pin + `otool -L` on the resolved `SQLCipher.xcframework` macOS slice) whenever the SQLCipher.swift pin is bumped (`ThirdParty/GRDB/Package.swift`) — a future release could change the crypto backend without changing the package name.
