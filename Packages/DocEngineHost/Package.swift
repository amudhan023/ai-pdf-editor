// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocEngineHost",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DocEngineHost", targets: ["DocEngineHost"])
    ],
    dependencies: [
        .package(path: "../PDFEngineAPI"),
        .package(path: "../Platform")
    ],
    targets: [
        // Path is relative to this manifest (Packages/DocEngineHost), so it
        // must climb two levels to reach ThirdParty/ — a single "../" here
        // resolves to the nonexistent Packages/ThirdParty/ and fails the
        // build with a cryptic "does not contain a binary artifact" error
        // (see docs/adr/ADR-001-pdfium-source-and-pin.md).
        .binaryTarget(name: "PDFium", path: "../../ThirdParty/pdfium/prebuilt/PDFium.xcframework"),
        // The xcframework ships a raw dylib + headers (not a .framework),
        // so its headers aren't automatically importable by Swift the way
        // a framework's would be. This target vendors the one header this
        // package's linkage-proof needs (fpdfview.h — self-contained; see
        // ADR-001) behind a module map, giving Swift a `CPDFium` module to
        // `import` while `PDFium` (above) supplies the actual symbols at
        // link time.
        .target(name: "CPDFium", path: "Sources/CPDFium"),
        .target(
            name: "DocEngineHost",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "Platform", package: "Platform"),
                "PDFium",
                "CPDFium"
            ]
        ),
        .testTarget(name: "DocEngineHostTests", dependencies: ["DocEngineHost"]),
        // Scripts/bench.sh's render-latency suite (P0-06 acceptance
        // criterion: tile render p50 < 16ms at 1x for corpus text pages) -
        // `swift run` this rather than a bench.sh-only script, since it
        // needs to import DocEngineHost directly (same pattern as
        // Platform's XPCLatencyBench for xpc-latency).
        .executableTarget(
            name: "RenderLatencyBench",
            dependencies: [
                "DocEngineHost",
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI")
            ]
        )
    ]
)
