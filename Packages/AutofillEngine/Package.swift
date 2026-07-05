// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutofillEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AutofillEngine", targets: ["AutofillEngine"])
    ],
    dependencies: [
        .package(path: "../PDFEngineAPI"),
        .package(path: "../VaultAPI"),
        .package(path: "../InferenceAPI"),
        .package(path: "../PolicyKit"),
        .package(path: "../FormKnowledge"),    ],
    targets: [
        .target(
            name: "AutofillEngine",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "VaultAPI", package: "VaultAPI"),
                .product(name: "InferenceAPI", package: "InferenceAPI"),
                .product(name: "PolicyKit", package: "PolicyKit"),
                .product(name: "FormKnowledge", package: "FormKnowledge"),            ],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "AutofillEngineTests", dependencies: ["AutofillEngine"])
    ]
)
