// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutofillSession",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AutofillSession", targets: ["AutofillSession"])
    ],
    dependencies: [
        .package(path: "../AutofillEngine"),
        .package(path: "../VaultAPI"),
        .package(path: "../PolicyKit"),
        .package(path: "../PDFEngineAPI"),    ],
    targets: [
        .target(
            name: "AutofillSession",
            dependencies: [
                .product(name: "AutofillEngine", package: "AutofillEngine"),
                .product(name: "VaultAPI", package: "VaultAPI"),
                .product(name: "PolicyKit", package: "PolicyKit"),
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),            ]
        ),
        .testTarget(name: "AutofillSessionTests", dependencies: ["AutofillSession"])
    ]
)
