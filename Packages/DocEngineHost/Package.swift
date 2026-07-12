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
        .package(path: "../Platform"),    ],
    targets: [
        .target(
            name: "DocEngineHost",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "Platform", package: "Platform"),            ]
        ),
        .testTarget(name: "DocEngineHostTests", dependencies: ["DocEngineHost"])
    ]
)
