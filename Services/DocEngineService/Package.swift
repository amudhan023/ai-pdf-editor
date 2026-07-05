// swift-tools-version: 6.0
import PackageDescription

// A standalone SwiftPM package rather than a Packages/* module: Services/
// hosts the three real .xpc bundle targets (REPO_STRUCTURE.md), which is a
// packaging/embedding concern P0-07's Xcode app target owns. This package
// is the "thin main" skeleton P0-05 proves wiring with: a real,
// separately-launchable/killable executable that links and runs Platform's
// XPC transport for real (via an in-process self-check, not a genuine
// cross-process connection - see DocEngineServiceIntegrationTests and the
// P0-05 task Journal for why that's not achievable without P0-07's app
// bundle). P0-06/P0-07 replace/embed this; the ping logic here is
// deliberately trivial (P0-05's own scope: "no functionality yet, just
// linkage/wiring proof").
let package = Package(
    name: "DocEngineService",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/Platform")
    ],
    targets: [
        .executableTarget(
            name: "DocEngineService",
            dependencies: ["Platform"]
        ),
        .testTarget(
            name: "DocEngineServiceTests",
            dependencies: ["DocEngineService", "Platform"]
        )
    ]
)
