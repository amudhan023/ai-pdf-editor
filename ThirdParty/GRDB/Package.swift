// swift-tools-version: 6.0
import PackageDescription

// Hand-written manifest (not vendored from upstream) implementing GRDB's own
// documented "GRDB+SQLCipher" SPM recipe: upstream's Package.swift ships the
// exact same target graph commented out with instructions to uncomment them,
// because SPM gives consumers no way to parametrize a remote package's build
// settings - the only way to get GRDB linked against SQLCipher instead of
// the system SQLite is to vendor the source and write the manifest yourself.
// See Scripts/vendor-grdb.sh and README.md in this directory for the pin and
// upgrade procedure.
let package = Package(
    name: "GRDB",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GRDB", targets: ["GRDB"])
    ],
    dependencies: [
        // Official SQLCipher project's own SPM distribution (prebuilt
        // xcframework, checksum-verified by SPM) - not a third-party
        // redistribution of someone else's binary. Pinned exact version.
        .package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", exact: "4.16.0")
    ],
    targets: [
        .target(
            name: "GRDBSQLCipher",
            dependencies: [
                .product(name: "SQLCipher", package: "SQLCipher.swift")
            ],
            path: "Sources/GRDBSQLCipher"
        ),
        .target(
            name: "GRDB",
            dependencies: [
                .product(name: "SQLCipher", package: "SQLCipher.swift"),
                "GRDBSQLCipher"
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: [
                .define("SQLITE_HAS_CODEC")
            ],
            swiftSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_SNAPSHOT"),
                .define("SQLITE_HAS_CODEC"),
                .define("SQLCipher")
            ]
        )
    ]
)
