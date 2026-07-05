import Foundation
import CryptoKit
import InferenceAPI

/// Verifies and holds model-pack manifests: capability → best installed
/// model for a hardware tier. Refuses anything that fails checksum or
/// signature verification (CLAUDE.md §7.6 — "never load a model from an
/// unverified path"); trusted signing keys are injected at init rather
/// than hardcoded, since no real signed model pack ships yet (that's a
/// later task once actual Core ML packs are bundled) — see
/// `docs/specs/model-pack-format.md` for the production key provisioning
/// gap this leaves open.
public actor ModelRegistry {
    private let trustedPublicKeys: [Curve25519.Signing.PublicKey]
    private var manifestsByCapability: [InferenceCapability: [ModelManifest]] = [:]
    private var packDataByModelID: [String: Data] = [:]

    public init(trustedPublicKeys: [Curve25519.Signing.PublicKey]) {
        self.trustedPublicKeys = trustedPublicKeys
    }

    /// Verifies `packData` against `manifest.sha256Checksum` and
    /// `manifest.signature`, then registers it. Throws
    /// `.modelPackUnverified` for either failure — never partially
    /// registers a manifest whose pack doesn't check out.
    @discardableResult
    public func register(manifest: ModelManifest, packData: Data) throws -> ModelManifest {
        let actualChecksum = SHA256.hash(data: packData).map { String(format: "%02x", $0) }.joined()
        guard actualChecksum == manifest.sha256Checksum else {
            throw InferenceError.modelPackUnverified(reason: "checksum mismatch")
        }
        let signatureIsValid = trustedPublicKeys.contains { key in
            key.isValidSignature(manifest.signature, for: manifest.signingPayload)
        }
        guard signatureIsValid else {
            throw InferenceError.modelPackUnverified(reason: "signature verification failed")
        }
        manifestsByCapability[manifest.capability, default: []].append(manifest)
        packDataByModelID[manifest.modelID] = packData
        return manifest
    }

    /// Exact hardware-tier match only — a registry with no model for this
    /// tier reports unavailable rather than silently substituting a
    /// mismatched one (caller sees `.capabilityUnavailable`, a normal
    /// condition per CLAUDE.md §15, not a crash).
    public func bestModel(for capability: InferenceCapability, tier: HardwareTier) -> ModelManifest? {
        (manifestsByCapability[capability] ?? []).first { $0.hardwareTier == tier }
    }

    public func packData(forModelID modelID: String) -> Data? {
        packDataByModelID[modelID]
    }
}
