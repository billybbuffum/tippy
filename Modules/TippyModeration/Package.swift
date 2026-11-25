// swift-tools-version: 5.9

import PackageDescription

// The Moderation bounded context: drink servings and standard drinks, the
// weekly goal and pace, and the pet's mood derived from them. Its own
// package so it builds and tests on a Mac with nothing but Foundation, and
// so the app depends on it rather than the other way round (the same shape
// as ChoreLock's Household module).
let package = Package(
    name: "TippyModeration",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        // Domain: Foundation only.
        .library(name: "TippyModeration", targets: ["TippyModeration"]),
    ],
    targets: [
        .target(name: "TippyModeration"),
        .testTarget(
            name: "TippyModerationTests",
            dependencies: ["TippyModeration"]
        ),
    ]
)
