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
        .binaryTarget(name: "PDFium", path: "../ThirdParty/pdfium/PDFium.xcframework"),
        .target(
            name: "DocEngineHost",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "Platform", package: "Platform"),
                "PDFium",
            ]
        ),
        .testTarget(name: "DocEngineHostTests", dependencies: ["DocEngineHost"])
    ]
)
