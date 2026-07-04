// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IngestionSession",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IngestionSession", targets: ["IngestionSession"])
    ],
    dependencies: [
        .package(path: "../IngestionPipeline"),
        .package(path: "../VaultAPI"),
        .package(path: "../PolicyKit"),    ],
    targets: [
        .target(
            name: "IngestionSession",
            dependencies: [
                .product(name: "IngestionPipeline", package: "IngestionPipeline"),
                .product(name: "VaultAPI", package: "VaultAPI"),
                .product(name: "PolicyKit", package: "PolicyKit"),            ]
        ),
        .testTarget(name: "IngestionSessionTests", dependencies: ["IngestionSession"])
    ]
)
