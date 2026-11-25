// swift-tools-version: 6.0

import PackageDescription

// The Wander bounded context: the step ledger, the trail (areas, landmarks,
// finds), eggs and the nest, hatching, the pet collection and the active
// pet. Foundation only, plus the Moderation context it reads check-ins and
// reflections from (never the other way round). Swift 6 language mode: full
// data-race checking. See docs/architecture.md and docs/specs/03-wander-eggs-pets.md.
let package = Package(
    name: "TippyWander",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TippyWander", targets: ["TippyWander"]),
    ],
    dependencies: [
        .package(path: "../TippyModeration"),
    ],
    targets: [
        .target(
            name: "TippyWander",
            dependencies: [
                .product(name: "TippyModeration", package: "TippyModeration"),
            ]
        ),
        .testTarget(
            name: "TippyWanderTests",
            dependencies: [
                "TippyWander",
                .product(name: "TippyModeration", package: "TippyModeration"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
