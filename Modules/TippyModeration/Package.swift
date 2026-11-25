// swift-tools-version: 6.0

import PackageDescription

// The Moderation bounded context: the journal of drinks and drink-free
// days, weeks and their summaries, the pet's mood, and the reminder plan.
// Foundation only, so it builds and tests on any Mac (or Linux) with Swift,
// and the app depends on it rather than the other way round. It compiles
// in the Swift 6 language mode: full data-race checking. See
// docs/architecture.md.
let package = Package(
    name: "TippyModeration",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "TippyModeration", targets: ["TippyModeration"]),
    ],
    targets: [
        .target(name: "TippyModeration"),
        .testTarget(
            name: "TippyModerationTests",
            dependencies: ["TippyModeration"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
