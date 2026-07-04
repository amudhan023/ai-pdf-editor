// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuditLog",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AuditLog", targets: ["AuditLog"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "AuditLog",
            dependencies: [
            ]
        ),
        .testTarget(name: "AuditLogTests", dependencies: ["AuditLog"])
    ]
)
