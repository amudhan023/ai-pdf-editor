import Foundation
import CryptoKit
import InferenceAPI
@testable import InferenceHost

/// Shared signing/registration helpers so each test doesn't reinvent a
/// throwaway trusted key + synthetic model pack. Production key
/// provisioning (an actual shipped trusted public key) isn't built yet —
/// see `docs/specs/model-pack-format.md`.
enum TestSupport {
    static func makeSigningKeyPair() -> (privateKey: Curve25519.Signing.PrivateKey, publicKey: Curve25519.Signing.PublicKey) {
        let privateKey = Curve25519.Signing.PrivateKey()
        return (privateKey, privateKey.publicKey)
    }

    /// Builds a manifest + synthetic pack data, signs it with `privateKey`,
    /// and returns both for `ModelRegistry.register(manifest:packData:)`.
    static func signedManifest(
        modelID: String,
        capability: InferenceCapability,
        tier: HardwareTier,
        privateKey: Curve25519.Signing.PrivateKey,
        packData: Data = Data("synthetic-model-pack".utf8)
    ) throws -> (manifest: ModelManifest, packData: Data) {
        let checksum = SHA256.hash(data: packData).map { String(format: "%02x", $0) }.joined()
        let unsigned = ModelManifest(
            modelID: modelID, capability: capability, version: "1.0.0", hardwareTier: tier,
            sha256Checksum: checksum, signature: Data(), estimatedMemoryBytes: 1_000
        )
        let signature = try privateKey.signature(for: unsigned.signingPayload)
        let signed = ModelManifest(
            modelID: modelID, capability: capability, version: "1.0.0", hardwareTier: tier,
            sha256Checksum: checksum, signature: signature, estimatedMemoryBytes: 1_000
        )
        return (signed, packData)
    }

    /// A fully-populated `InferenceHostClient`: one signed, registered
    /// manifest per capability on `tier`, plenty of memory headroom.
    static func makeRealClient(tier: HardwareTier = HardwareTierDetector.current()) async throws -> InferenceHostClient {
        let (privateKey, publicKey) = makeSigningKeyPair()
        let registry = ModelRegistry(trustedPublicKeys: [publicKey])
        for capability in InferenceCapability.allCases {
            let (manifest, packData) = try signedManifest(
                modelID: "\(capability.rawValue)-stub-v1", capability: capability, tier: tier, privateKey: privateKey
            )
            try await registry.register(manifest: manifest, packData: packData)
        }
        let governor = MemoryGovernor(capBytes: 1_000_000)
        return InferenceHostClient(registry: registry, governor: governor, hardwareTier: tier)
    }
}
