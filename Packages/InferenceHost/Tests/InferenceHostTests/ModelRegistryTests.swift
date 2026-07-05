import XCTest
import CryptoKit
import InferenceAPI
@testable import InferenceHost

final class ModelRegistryTests: XCTestCase {
    func testValidManifestRegistersAndIsSelectable() async throws {
        let (privateKey, publicKey) = TestSupport.makeSigningKeyPair()
        let registry = ModelRegistry(trustedPublicKeys: [publicKey])
        let (manifest, packData) = try TestSupport.signedManifest(
            modelID: "ocr-v1", capability: .ocr, tier: .appleSilicon, privateKey: privateKey
        )

        try await registry.register(manifest: manifest, packData: packData)

        let best = await registry.bestModel(for: .ocr, tier: .appleSilicon)
        XCTAssertEqual(best?.modelID, "ocr-v1")
    }

    func testTamperedChecksumIsRefused() async throws {
        let (privateKey, publicKey) = TestSupport.makeSigningKeyPair()
        let registry = ModelRegistry(trustedPublicKeys: [publicKey])
        let (manifest, _) = try TestSupport.signedManifest(
            modelID: "ocr-v1", capability: .ocr, tier: .appleSilicon, privateKey: privateKey
        )
        let tamperedPackData = Data("a-different-pack-than-what-was-signed".utf8)

        do {
            try await registry.register(manifest: manifest, packData: tamperedPackData)
            XCTFail("expected modelPackUnverified for a checksum mismatch")
        } catch InferenceError.modelPackUnverified(let reason) {
            XCTAssertTrue(reason.contains("checksum"))
        }

        let best = await registry.bestModel(for: .ocr, tier: .appleSilicon)
        XCTAssertNil(best, "a manifest that fails verification must not be registered")
    }

    func testTamperedSignatureIsRefused() async throws {
        let (privateKey, _) = TestSupport.makeSigningKeyPair()
        let (_, untrustedPublicKey) = TestSupport.makeSigningKeyPair()
        // Registry trusts a *different* key than the one that signed this manifest.
        let registry = ModelRegistry(trustedPublicKeys: [untrustedPublicKey])
        let (manifest, packData) = try TestSupport.signedManifest(
            modelID: "ocr-v1", capability: .ocr, tier: .appleSilicon, privateKey: privateKey
        )

        do {
            try await registry.register(manifest: manifest, packData: packData)
            XCTFail("expected modelPackUnverified for an untrusted signature")
        } catch InferenceError.modelPackUnverified(let reason) {
            XCTAssertTrue(reason.contains("signature"))
        }
    }

    func testWrongHardwareTierIsNotSelected() async throws {
        let (privateKey, publicKey) = TestSupport.makeSigningKeyPair()
        let registry = ModelRegistry(trustedPublicKeys: [publicKey])
        let (manifest, packData) = try TestSupport.signedManifest(
            modelID: "ocr-intel-v1", capability: .ocr, tier: .intel, privateKey: privateKey
        )
        try await registry.register(manifest: manifest, packData: packData)

        let best = await registry.bestModel(for: .ocr, tier: .appleSilicon)
        XCTAssertNil(best, "a manifest registered for a different hardware tier must not be selected")
    }
}
