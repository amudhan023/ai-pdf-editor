// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocumentSession",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DocumentSession", targets: ["DocumentSession"])
    ],
    dependencies: [
        .package(path: "../PDFEngineAPI"),
        .package(path: "../Platform"),    ],
    targets: [
        .target(
            name: "DocumentSession",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "Platform", package: "Platform"),            ]
        ),
        .testTarget(name: "DocumentSessionTests", dependencies: ["DocumentSession"]),
        // Scripts/bench.sh's tile-scroll suite (P1-01): scripted scroll-perf
        // test for TileCache/TileGrid. `swift run` this rather than a
        // bench.sh-only script, since it needs to import DocumentSession
        // directly (same pattern as DocEngineHost's RenderLatencyBench).
        .executableTarget(
            name: "TileScrollBench",
            dependencies: [
                "DocumentSession",
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI")
            ]
        )
    ]
)
