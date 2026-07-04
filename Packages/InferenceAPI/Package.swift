// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InferenceAPI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "InferenceAPI", targets: ["InferenceAPI"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "InferenceAPI",
            dependencies: [
            ]
        ),
        .testTarget(name: "InferenceAPITests", dependencies: ["InferenceAPI"])
    ]
)
