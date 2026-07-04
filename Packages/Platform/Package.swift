// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Platform",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Platform", targets: ["Platform"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Platform",
            dependencies: [
            ]
        ),
        .testTarget(name: "PlatformTests", dependencies: ["Platform"])
    ]
)
