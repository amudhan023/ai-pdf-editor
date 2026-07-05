import Foundation

/// Wraps/unwraps a symmetric key using a device-bound key the caller never
/// sees directly (ARCHITECTURE.md §6.2: "SE key -> wrapped master key").
/// A protocol seam rather than a hard dependency on `SecureEnclaveKeyBox`
/// for the same reason `VaultClient`/`FakeVaultClient` is a protocol: real
/// Secure Enclave key generation requires an interactive Security Server
/// session and real hardware, neither of which a headless test/CI process
/// has (verified empirically — `SecKeyCreateRandomKey` with
/// `kSecAttrTokenIDSecureEnclave` fails with `errSecInteractionNotAllowed`
/// outside that context). Production wiring uses `SecureEnclaveKeyBox`; key
/// lifecycle tests use a software-only test double.
public protocol KeyWrappingProvider: Sendable {
    func wrap(_ plaintext: Data) throws -> Data
    func unwrap(_ ciphertext: Data) throws -> Data

    /// Irreversibly destroys the wrapping key itself. After this, `wrap`
    /// creates a new key (nothing to relate it to the old one) and `unwrap`
    /// of a ciphertext produced under the destroyed key must fail — this is
    /// the SE-key leg of whole-vault crypto-shred (ARCHITECTURE.md §6.2).
    func destroy() throws
}
