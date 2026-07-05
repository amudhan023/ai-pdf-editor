import XCTest
import Foundation

/// Spawns the real, compiled `VaultService` binary as a genuine separate OS
/// process (not a `@testable import` in-process call) and proves it: starts,
/// links Platform's XPC transport correctly (its stdout self-check), and can
/// be killed like any other process. Identical pattern/rationale to
/// `DocEngineServiceIntegrationTests` (P0-05) / `InferenceServiceIntegrationTests`
/// (P1-12) — see those files' header comments for why genuine cross-process
/// connectivity isn't covered here (needs P0-07's app bundle).
final class VaultServiceIntegrationTests: XCTestCase {
    private func executableURL() throws -> URL {
        let productsDir = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let candidate = productsDir.appendingPathComponent("VaultService")
        guard FileManager.default.isExecutableFile(atPath: candidate.path) else {
            throw XCTSkip("VaultService binary not found at \(candidate.path) - build products layout may have changed")
        }
        return candidate
    }

    func testServiceStartsSelfChecksAndIsKillable() throws {
        let process = Process()
        process.executableURL = try executableURL()
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        defer {
            if process.isRunning { process.terminate() }
        }

        var output = ""
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let data = stdout.fileHandleForReading.availableData
            if !data.isEmpty {
                output += String(data: data, encoding: .utf8) ?? ""
            }
            if output.contains("self-check:") { break }
            usleep(50_000)
        }

        XCTAssertTrue(output.contains("VaultService self-check: OK"), "unexpected output: \(output)")
        XCTAssertTrue(process.isRunning, "service should still be running after printing its self-check (RunLoop.main.run() blocks)")

        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(process.terminationReason, .uncaughtSignal)
    }
}
