// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaultStore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaultStore", targets: ["VaultStore"])
    ],
    dependencies: [
        .package(path: "../VaultAPI"),
        .package(path: "../PolicyKit"),
        .package(path: "../Platform"),
        .package(path: "../AuditLog"),
        .package(path: "../../ThirdParty/GRDB")
    ],
    targets: [
        .target(
            name: "VaultStore",
            dependencies: [
                .product(name: "VaultAPI", package: "VaultAPI"),
                .product(name: "PolicyKit", package: "PolicyKit"),
                .product(name: "Platform", package: "Platform"),
                .product(name: "AuditLog", package: "AuditLog"),
                .product(name: "GRDB", package: "GRDB")
            ]
        ),
        .testTarget(name: "VaultStoreTests", dependencies: ["VaultStore"])
    ]
)
