// swift-tools-version: 6.0
import PackageDescription

// A standalone SwiftPM package rather than a Packages/* module — App/ hosts
// the composition-root executable target (REPO_STRUCTURE.md), same
// packaging pattern Services/* already uses for the XPC skeletons. Real
// `.app` bundle assembly (Info.plist, UTType/document-type registration,
// entitlements, code signing) is a separate, scriptable packaging step
// (`Scripts/build-app-bundle.sh`) layered on top of this executable rather
// than a hand-authored `.xcodeproj` — `swift package generate-xcodeproj`
// was removed from this SwiftPM toolchain (empirically confirmed: "Unknown
// subcommand"), so there is no supported path to a real Xcode project
// without hand-writing a `.pbxproj`, which this task's Journal flags as
// out of scope, not silently skipped.
let package = Package(
    name: "Vaultform",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Packages/PDFEngineAPI"),
        .package(path: "../Packages/Platform"),
        .package(path: "../Packages/DocEngineHost"),
        .package(path: "../Packages/DocumentSession")
    ],
    targets: [
        .executableTarget(
            name: "Vaultform",
            dependencies: [
                .product(name: "PDFEngineAPI", package: "PDFEngineAPI"),
                .product(name: "Platform", package: "Platform"),
                .product(name: "DocEngineHost", package: "DocEngineHost"),
                .product(name: "DocumentSession", package: "DocumentSession")
            ]
        ),
        .testTarget(
            name: "VaultformTests",
            dependencies: ["Vaultform"]
        )
    ]
)
