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
        .testTarget(name: "DocumentSessionTests", dependencies: ["DocumentSession"])
    ]
)
