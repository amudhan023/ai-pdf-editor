import XCTest
import Foundation

/// Spawns the real, compiled `DocEngineService` binary as a genuine
/// separate OS process (not a `@testable import` in-process call) and
/// proves it: starts, links Platform's XPC transport correctly (its
/// stdout self-check), and can be killed like any other process.
///
/// This is *not* a test of cross-process XPC connectivity into the
/// service - see the P0-05 task Journal for why that specifically isn't
/// achievable yet without a real `.xpc` app-bundle target (P0-07).
/// `XPCCrashRecoveryIntegrationTests` (Platform package) covers the
/// crash+reconnect contract for real via `NSXPCConnection` invalidation.
final class DocEngineServiceIntegrationTests: XCTestCase {
    /// SwiftPM builds this test bundle and the `DocEngineService`
    /// executable target into the same products directory - locate the
    /// sibling binary relative to the test bundle rather than hardcoding
    /// a `.build/debug` path (which varies by configuration/architecture).
    private func executableURL() throws -> URL {
        let productsDir = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let candidate = productsDir.appendingPathComponent("DocEngineService")
        guard FileManager.default.isExecutableFile(atPath: candidate.path) else {
            throw XCTSkip("DocEngineService binary not found at \(candidate.path) - build products layout may have changed")
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

        // The self-check runs concurrently with RunLoop.main.run() starting
        // (see main.swift) - poll briefly rather than assuming a fixed delay.
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

        XCTAssertTrue(output.contains("DocEngineService self-check: OK"), "unexpected output: \(output)")
        XCTAssertTrue(process.isRunning, "service should still be running after printing its self-check (RunLoop.main.run() blocks)")

        // Prove it's a genuine, independently killable process - the
        // literal mechanism the P0-05 acceptance criterion names, even
        // though the connection-level crash-recovery contract is proven
        // elsewhere (see this file's header comment).
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
        XCTAssertFalse(process.isRunning)
        XCTAssertEqual(process.terminationReason, .uncaughtSignal)
    }
}
