// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaultAPI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultAPI", targets: ["VaultAPI"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "VaultAPI",
            dependencies: [
            ]
        ),
        .testTarget(name: "VaultAPITests", dependencies: ["VaultAPI"])
    ]
)
