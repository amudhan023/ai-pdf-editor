import Foundation

/// A decrypted vault value's byte representation. Constitution Art. 11 /
/// CLAUDE.md §7.3: "decrypted secrets live in `SecureBytes`... bridge to
/// `String` only at the final UI/engine write" — `FieldValue.string` (the
/// freeform-text vector: names, SSNs, passport numbers, addresses) carries
/// this instead of a bare `String` so every hop between `Vault.xpc` and the
/// eventual UI display or document write goes through the one, greppable
/// `exposeAsPlaintext()` seam, never an accidental `String` interpolation
/// or log call.
///
/// This type only enforces that structural boundary. It does **not** by
/// itself provide `mlock`ed memory or guaranteed zero-on-deallocate — Swift
/// value types have no deinit, and once a `String`/`Data` copy exists via
/// `exposeAsPlaintext()` its lifetime is the caller's problem. The actual
/// hardened, mlock'd master-key handling lives in `VaultStore`/`Platform`
/// (P1-08), which may hold considerably stronger guarantees for the key
/// material itself; claiming that here would be exactly the "marketing
/// embellishment of security properties" CLAUDE.md §10 forbids.
public struct SecureBytes: Sendable, Equatable {
    private var bytes: [UInt8]

    public init(utf8 string: String) {
        self.bytes = Array(string.utf8)
    }

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var count: Int { bytes.count }

    /// The single sanctioned bridge back to `String`. Call sites doing this
    /// are asserting they are at the final UI/engine write, not an
    /// intermediate hop (CLAUDE.md §7.3) — that assertion is on the caller;
    /// this type cannot verify it.
    public func exposeAsPlaintext() -> String {
        // `String(decoding:as:)` is total (never nil, replaces invalid
        // sequences rather than failing) - the right choice for a decrypted
        // vault value, where `String(bytes:encoding:)`'s optional would push
        // callers toward `?? ""` and silently drop malformed content instead.
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: bytes, as: UTF8.self)
    }

    /// Best-effort overwrite of this instance's backing storage. Does not
    /// affect any `String`/`Data`/array copy already produced by
    /// `exposeAsPlaintext()` or `init` — see the type's doc comment.
    public mutating func zeroize() {
        for index in bytes.indices { bytes[index] = 0 }
    }
}

extension SecureBytes: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let base64 = try container.decode(String.self)
        guard let data = Data(base64Encoded: base64) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "SecureBytes: invalid base64 payload")
        }
        self.bytes = Array(data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Data(bytes).base64EncodedString())
    }
}

/// Redacted by construction — no `description`/`debugDescription` ever
/// exposes the plaintext, so an accidental `print(field.value)` or string
/// interpolation in a log statement can't leak a vault value.
extension SecureBytes: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { "SecureBytes(\(bytes.count) bytes, redacted)" }
    public var debugDescription: String { description }
}
