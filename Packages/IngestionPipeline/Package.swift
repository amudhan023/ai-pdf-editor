// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IngestionPipeline",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IngestionPipeline", targets: ["IngestionPipeline"])
    ],
    dependencies: [
        .package(path: "../PDFEngineAPI"),
        .package(path: "../VaultAPI"),
        .package(path: "../InferenceAPI"),    ],
    targets: [
        .target(
            name: "IngestionPipeline",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "VaultAPI", package: "VaultAPI"),
                .product(name: "InferenceAPI", package: "InferenceAPI"),            ]
        ),
        .testTarget(name: "IngestionPipelineTests", dependencies: ["IngestionPipeline"])
    ]
)
