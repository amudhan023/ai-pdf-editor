// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PolicyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PolicyKit", targets: ["PolicyKit"])
    ],
    dependencies: [
        .package(path: "../VaultAPI"),    ],
    targets: [
        .target(
            name: "PolicyKit",
            dependencies: [
                .product(name: "VaultAPI", package: "VaultAPI"),            ]
        ),
        .testTarget(name: "PolicyKitTests", dependencies: ["PolicyKit"])
    ]
)
