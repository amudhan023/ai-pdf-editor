import XCTest
@testable import InferenceAPI

/// Proves `FakeInferenceClient` passes the shared conformance suite — the
/// same suite a real registry/router-backed `InferenceHost` client must
/// pass later (this task's Acceptance Criteria).
final class FakeInferenceClientConformanceTests: XCTestCase {
    func testConformance() async throws {
        try await InferenceConformanceSuite.runAll(FakeInferenceClient())
    }
}
