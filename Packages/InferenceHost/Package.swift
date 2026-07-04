// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InferenceHost",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "InferenceHost", targets: ["InferenceHost"])
    ],
    dependencies: [
        .package(path: "../InferenceAPI"),
        .package(path: "../Platform"),    ],
    targets: [
        .target(
            name: "InferenceHost",
            dependencies: [
                .product(name: "InferenceAPI", package: "InferenceAPI"),
                .product(name: "Platform", package: "Platform"),            ]
        ),
        .testTarget(name: "InferenceHostTests", dependencies: ["InferenceHost"])
    ]
)
