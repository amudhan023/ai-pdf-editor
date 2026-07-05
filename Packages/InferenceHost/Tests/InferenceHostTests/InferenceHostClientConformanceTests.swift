import XCTest
import InferenceAPI
@testable import InferenceHost

/// Proves the real registry/router/governor-backed `InferenceHostClient`
/// passes the identical shared conformance suite `FakeInferenceClient`
/// does (InferenceAPI package) — this task's stated acceptance criterion
/// ("Fake + real service both pass InferenceAPI conformance suite").
final class InferenceHostClientConformanceTests: XCTestCase {
    func testConformance() async throws {
        let client = try await TestSupport.makeRealClient()
        try await InferenceConformanceSuite.runAll(client)
    }

    func testCapabilityUnavailableWhenNoModelRegisteredForTier() async throws {
        // Empty registry: every call must throw .capabilityUnavailable
        // rather than crash or silently return a default.
        let registry = ModelRegistry(trustedPublicKeys: [])
        let governor = MemoryGovernor(capBytes: 1_000_000)
        let client = InferenceHostClient(registry: registry, governor: governor, hardwareTier: .appleSilicon)

        do {
            _ = try await client.ocr(OCRRequest(imageData: Data([0x01])))
            XCTFail("expected capabilityUnavailable")
        } catch InferenceError.capabilityUnavailable(let capability, let tier) {
            XCTAssertEqual(capability, .ocr)
            XCTAssertEqual(tier, .appleSilicon)
        }
    }
}
