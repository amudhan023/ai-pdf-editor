// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrivacyDashboard",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PrivacyDashboard", targets: ["PrivacyDashboard"])
    ],
    dependencies: [
        .package(path: "../AuditLog"),
        .package(path: "../VaultAPI"),    ],
    targets: [
        .target(
            name: "PrivacyDashboard",
            dependencies: [
                .product(name: "AuditLog", package: "AuditLog"),
                .product(name: "VaultAPI", package: "VaultAPI"),            ]
        ),
        .testTarget(name: "PrivacyDashboardTests", dependencies: ["PrivacyDashboard"])
    ]
)
