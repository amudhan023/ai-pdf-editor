import XCTest
@testable import InferenceHost
import InferenceAPI

final class MemoryGovernorTests: XCTestCase {
    func testLoadWithinCapSucceeds() async throws {
        let governor = MemoryGovernor(capBytes: 1_000)
        try await governor.ensureLoaded(modelID: "a", estimatedBytes: 500)
        let usage = await governor.currentUsageBytes
        XCTAssertEqual(usage, 500)
    }

    func testSingleModelBiggerThanCapThrows() async throws {
        let governor = MemoryGovernor(capBytes: 1_000)
        do {
            try await governor.ensureLoaded(modelID: "a", estimatedBytes: 2_000)
            XCTFail("expected memoryCapExceeded")
        } catch InferenceError.memoryCapExceeded {
            // expected
        }
    }

    func testEvictsLeastRecentlyUsedToMakeRoom() async throws {
        let governor = MemoryGovernor(capBytes: 1_000)
        try await governor.ensureLoaded(modelID: "a", estimatedBytes: 600)
        try await governor.ensureLoaded(modelID: "b", estimatedBytes: 600)
        // "a" should have been evicted to make room for "b" (a+b > cap).
        let loaded = await governor.loadedModelIDs
        XCTAssertEqual(loaded, ["b"])
    }

    func testReloadingAnAlreadyLoadedModelRefreshesRecency() async throws {
        let governor = MemoryGovernor(capBytes: 1_000)
        try await governor.ensureLoaded(modelID: "a", estimatedBytes: 400)
        try await governor.ensureLoaded(modelID: "b", estimatedBytes: 400)
        try await governor.ensureLoaded(modelID: "a", estimatedBytes: 400) // touch "a" again
        try await governor.ensureLoaded(modelID: "c", estimatedBytes: 400) // must evict "b", not "a"

        let loaded = await governor.loadedModelIDs
        XCTAssertEqual(loaded, ["a", "c"])
    }
}
