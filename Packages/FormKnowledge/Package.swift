// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormKnowledge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FormKnowledge", targets: ["FormKnowledge"])
    ],
    dependencies: [
        .package(path: "../PDFEngineAPI"),
        .package(path: "../VaultAPI"),    ],
    targets: [
        .target(
            name: "FormKnowledge",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "VaultAPI", package: "VaultAPI"),            ]
        ),
        .testTarget(name: "FormKnowledgeTests", dependencies: ["FormKnowledge"])
    ]
)
