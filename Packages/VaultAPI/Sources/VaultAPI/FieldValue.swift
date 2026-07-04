import Foundation

/// The wire/type discriminator for `FieldValue` (PRD FR-2.2: "type
/// (string/date/number/enum/list)"). `.enumeration`'s raw value is `"enum"`
/// to match the PRD's own vocabulary on the wire while avoiding the Swift
/// keyword collision in source.
public enum FieldValueKind: String, Sendable, Codable, CaseIterable, Equatable {
    case string
    case date
    case number
    case enumeration = "enum"
    case list
}

/// A vault field's value. Deliberately does not carry `type` as a separate
/// stored property alongside `value` (unlike the conceptual DB row in
/// ARCHITECTURE.md §8.2) — the case *is* the type, so there is no way for
/// the two to desync. `.kind` derives it when the DB-row shape is needed.
///
/// `.string` carries `SecureBytes`, not `String` — it is the freeform-text
/// vector for names, SSNs, passport/license numbers, and addresses, i.e.
/// exactly the "decrypted secrets" Constitution Art. 11 / CLAUDE.md §7.3
/// require to travel as `SecureBytes` end-to-end. `.number`/`.date` stay
/// plain Foundation types: they're structured, not freeform text, and this
/// codebase has no `SecureNumber`/`SecureDate` precedent to build one from.
public enum FieldValue: Sendable, Equatable {
    case string(SecureBytes)
    case date(Date)
    case number(Double)
    case enumeration(String)
    case list([FieldValue])

    public var kind: FieldValueKind {
        switch self {
        case .string: .string
        case .date: .date
        case .number: .number
        case .enumeration: .enumeration
        case .list: .list
        }
    }

    /// A deterministic, non-cryptographic fingerprint for the value —
    /// used by `compareRead` (ARCHITECTURE.md §5.1's "compare-only grant")
    /// so ingestion can detect a conflict without disclosing the existing
    /// sensitive value itself. Not a security control: collision-resistance
    /// is not a goal, only stability (same value -> same fingerprint) and
    /// practical distinctness (different value -> different fingerprint).
    public func stableFingerprint() -> String {
        FNV1a.hex(of: canonicalString)
    }

    private var canonicalString: String {
        switch self {
        case .string(let value): "string:\(value.exposeAsPlaintext())"
        case .date(let value): "date:\(value.timeIntervalSince1970)"
        case .number(let value): "number:\(value)"
        case .enumeration(let value): "enumeration:\(value)"
        case .list(let values): "list:[" + values.map { $0.canonicalString }.joined(separator: ",") + "]"
        }
    }
}

extension FieldValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(FieldValueKind.self, forKey: .kind) {
        case .string: self = .string(try container.decode(SecureBytes.self, forKey: .value))
        case .date: self = .date(try container.decode(Date.self, forKey: .value))
        case .number: self = .number(try container.decode(Double.self, forKey: .value))
        case .enumeration: self = .enumeration(try container.decode(String.self, forKey: .value))
        case .list: self = .list(try container.decode([FieldValue].self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .string(let value): try container.encode(value, forKey: .value)
        case .date(let value): try container.encode(value, forKey: .value)
        case .number(let value): try container.encode(value, forKey: .value)
        case .enumeration(let value): try container.encode(value, forKey: .value)
        case .list(let values): try container.encode(values, forKey: .value)
        }
    }
}

/// Minimal, dependency-free 64-bit FNV-1a — `FieldValue.stableFingerprint()`'s
/// only consumer. Not for anything security-sensitive (CLAUDE.md §17 forbids
/// new dependencies here, so this deliberately isn't CryptoKit-backed; a real
/// Vault.xpc implementation is free to use a stronger hash internally, since
/// `stableFingerprint()` is a documented contract on the value, not on bytes).
private enum FNV1a {
    static func hex(of string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}
