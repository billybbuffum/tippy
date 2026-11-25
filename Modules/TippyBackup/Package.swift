// swift-tools-version: 6.0

import PackageDescription

// Integration, not a bounded context: the backup bundle that holds every
// context's data in one file (spec 04), and the preview shown before a restore.
// It composes the three contexts' own codecs and owns no rules of its own.
// Foundation only, Swift 6 language mode. See docs/architecture.md.
let package = Package(
    name: "TippyBackup",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TippyBackup", targets: ["TippyBackup"]),
    ],
    dependencies: [
        .package(path: "../TippyModeration"),
        .package(path: "../TippyRewards"),
        .package(path: "../TippyWander"),
    ],
    targets: [
        .target(
            name: "TippyBackup",
            dependencies: [
                .product(name: "TippyModeration", package: "TippyModeration"),
                .product(name: "TippyRewards", package: "TippyRewards"),
                .product(name: "TippyWander", package: "TippyWander"),
            ]
        ),
        .testTarget(
            name: "TippyBackupTests",
            dependencies: [
                "TippyBackup",
                .product(name: "TippyModeration", package: "TippyModeration"),
                .product(name: "TippyRewards", package: "TippyRewards"),
                .product(name: "TippyWander", package: "TippyWander"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
