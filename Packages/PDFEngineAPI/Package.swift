// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PDFEngineAPI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PDFEngineAPI", targets: ["PDFEngineAPI"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "PDFEngineAPI",
            dependencies: [
            ]
        ),
        .testTarget(name: "PDFEngineAPITests", dependencies: ["PDFEngineAPI"])
    ]
)
