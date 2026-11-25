// swift-tools-version: 6.0

import PackageDescription

// Built with xtool (https://xtool.sh), not Xcode, exactly like ChoreLock. Each
// `.library` product below is either the app itself or one app extension;
// xtool links each into its own executable and assembles the .app / .appex
// bundles from xtool.yml. Tippy has no extensions yet.
let package = Package(
    name: "Tippy",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // The app. Must match `product:` in xtool.yml.
        .library(
            name: "Tippy",
            targets: ["Tippy"]
        ),
    ],
    dependencies: [
        // The Moderation context (standard drinks, weekly pace, the pet's
        // mood) is its own package: Foundation-only domain, tested on a Mac.
        .package(path: "Modules/TippyModeration"),
        // The Rewards context (coins, weekly recaps), downstream of Moderation.
        .package(path: "Modules/TippyRewards"),
        // The Wander context (steps, the trail, eggs, hatching, pets).
        .package(path: "Modules/TippyWander"),
    ],
    targets: [
        .target(
            name: "Tippy",
            dependencies: [
                .product(name: "TippyModeration", package: "TippyModeration"),
                .product(name: "TippyRewards", package: "TippyRewards"),
                .product(name: "TippyWander", package: "TippyWander"),
            ],
            // The sprites the app shows, copied from Assets/Sprites by
            // scripts/sync-sprites.py. SwiftPM bundles them as Tippy_Tippy.bundle,
            // which xtool packs into the app; code reads them via Bundle.module.
            resources: [
                .copy("Resources/Sprites"),
            ]
        ),
    ],
    // Swift 5 language mode keeps strict-concurrency diagnostics as warnings,
    // as in ChoreLock. Flip to .v6 once it builds clean.
    swiftLanguageModes: [.v5]
)
