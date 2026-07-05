// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Platform",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Platform", targets: ["Platform"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Platform",
            dependencies: [
            ]
        ),
        .testTarget(name: "PlatformTests", dependencies: ["Platform"]),
        // Scripts/bench.sh's xpc-latency suite (P0-05 Definition of Done:
        // ADR-002 measured round-trip latency baseline) - `swift run` this
        // rather than adding a bench.sh-only script, since it needs to
        // import Platform directly.
        .executableTarget(name: "XPCLatencyBench", dependencies: ["Platform"])
    ]
)
