// swift-tools-version: 6.0

import PackageDescription

// The Rewards bounded context: the coin ledger, the rules that earn coins
// from the journal, and weekly recaps (later the shop, purchases and the
// camp's placements). It reads the journal through TippyModeration's
// public API, never the other way round. Foundation only, Swift 6
// language mode, like TippyModeration. See docs/architecture.md.
let package = Package(
    name: "TippyRewards",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TippyRewards", targets: ["TippyRewards"]),
    ],
    dependencies: [
        .package(path: "../TippyModeration"),
    ],
    targets: [
        .target(
            name: "TippyRewards",
            dependencies: [
                .product(name: "TippyModeration", package: "TippyModeration"),
            ]
        ),
        .testTarget(
            name: "TippyRewardsTests",
            dependencies: [
                "TippyRewards",
                .product(name: "TippyModeration", package: "TippyModeration"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
