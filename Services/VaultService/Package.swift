// swift-tools-version: 6.0
import PackageDescription

// A standalone SwiftPM package rather than a Packages/* module — same
// rationale as Services/DocEngineService (P0-05) and Services/InferenceService
// (P1-12): Services/ hosts the three real .xpc bundle targets
// (REPO_STRUCTURE.md), packaging/embedding is P0-07's Xcode app target job.
// Identical "thin main" skeleton pattern: a real, separately-launchable/
// killable executable proving Platform's XPC transport links and runs
// correctly, via an in-process self-check (genuine cross-process connection
// needs P0-07's app bundle — see DocEngineServiceIntegrationTests/ADR-002).
// The vault store/key-hierarchy logic this service will eventually host
// lives in and is tested by Packages/VaultStore; main.swift here stays
// deliberately trivial, matching P0-05/P1-12's scope.
let package = Package(
    name: "VaultService",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/Platform")
    ],
    targets: [
        .executableTarget(
            name: "VaultService",
            dependencies: ["Platform"]
        ),
        .testTarget(
            name: "VaultServiceTests",
            dependencies: ["VaultService", "Platform"]
        )
    ]
)
