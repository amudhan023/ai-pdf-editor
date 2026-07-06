// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaultManagerUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultManagerUI", targets: ["VaultManagerUI"])
    ],
    dependencies: [
        .package(path: "../VaultAPI"),
        .package(path: "../PolicyKit")
    ],
    targets: [
        .target(
            name: "VaultManagerUI",
            dependencies: [
                .product(name: "VaultAPI", package: "VaultAPI"),
                .product(name: "PolicyKit", package: "PolicyKit")
            ]
        ),
        .testTarget(name: "VaultManagerUITests", dependencies: ["VaultManagerUI"])
    ]
)
