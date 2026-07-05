import Foundation

/// Wire shape for a bundled model pack's identity + integrity proof
/// (docs/specs/model-pack-format.md is the canonical format doc). Minting
/// and verifying `signature`/`sha256Checksum` is `InferenceHost`'s job
/// (`ModelRegistry`) — identical split to `VaultAPI.PolicyTicket`, whose
/// signature PolicyKit mints/verifies while VaultAPI only carries the
/// shape. This package never loads or executes a model; it only describes
/// one.
public struct ModelManifest: Codable, Sendable, Equatable {
    public let modelID: String
    public let capability: InferenceCapability
    public let version: String
    public let hardwareTier: HardwareTier
    /// Lowercase hex-encoded SHA-256 of the model pack file.
    public let sha256Checksum: String
    /// Detached Ed25519 signature over `modelID|version|sha256Checksum`,
    /// verified against a trusted key baked into `InferenceHost` — this
    /// package carries the opaque bytes only.
    public let signature: Data
    /// Declared resident-memory footprint once loaded — the memory
    /// governor's caps (ARCHITECTURE.md §7.2) are sized against this, not a
    /// measured runtime value, since the governor must decide whether to
    /// evict *before* loading.
    public let estimatedMemoryBytes: Int

    public init(
        modelID: String,
        capability: InferenceCapability,
        version: String,
        hardwareTier: HardwareTier,
        sha256Checksum: String,
        signature: Data,
        estimatedMemoryBytes: Int
    ) {
        self.modelID = modelID
        self.capability = capability
        self.version = version
        self.hardwareTier = hardwareTier
        self.sha256Checksum = sha256Checksum
        self.signature = signature
        self.estimatedMemoryBytes = estimatedMemoryBytes
    }

    /// The canonical byte sequence the signature is computed over — shared
    /// here so registry (verify) and any signing tooling (mint) agree on
    /// the exact framing without duplicating it.
    public var signingPayload: Data {
        Data("\(modelID)|\(version)|\(sha256Checksum)".utf8)
    }
}
