import SwiftUI
import UIKit

/// Loads the bundled pixel-art sprites (`Resources/Sprites`, kept in step with
/// `Assets/Sprites` by scripts/sync-sprites.py) and slices animation strips.
/// Everything is cached and drawn with nearest-neighbour scaling, so pixel
/// edges stay crisp at any size.
@MainActor
enum SpriteLibrary {
    private static var images: [String: UIImage] = [:]
    private static var strips: [String: [CGImage]] = [:]

    /// `path` is relative to Sprites/, without the extension: "Pet/happy".
    static func image(_ path: String) -> UIImage? {
        if let cached = images[path] { return cached }
        let parts = path.split(separator: "/").map(String.init)
        guard let name = parts.last else { return nil }
        let folder = (["Sprites"] + parts.dropLast()).joined(separator: "/")
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: folder),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        images[path] = image
        return image
    }

    /// The frames of a horizontal strip in Animations/, left to right.
    static func frames(of animation: SpriteAnimation) -> [CGImage] {
        if let cached = strips[animation.strip] { return cached }
        guard let sheet = image("Animations/\(animation.strip)")?.cgImage else { return [] }
        let width = sheet.width / animation.durations.count
        let frames = (0..<animation.durations.count).compactMap {
            sheet.cropping(to: CGRect(x: $0 * width, y: 0, width: width, height: sheet.height))
        }
        strips[animation.strip] = frames
        return frames
    }
}

/// A looping strip and how long each frame shows (from Assets/Sprites/README.md).
struct SpriteAnimation: Equatable {
    let strip: String
    let durations: [TimeInterval]

    static let petIdle = SpriteAnimation(strip: "pet-idle", durations: [0.48, 0.16, 0.25, 0.16])
    static let petHop = SpriteAnimation(strip: "pet-hop", durations: [0.48, 0.10, 0.16, 0.11])
    static let eggWiggle = SpriteAnimation(strip: "egg-wiggle", durations: [0.65, 0.14, 0.14, 0.17])

    func frameIndex(at time: TimeInterval) -> Int {
        let total = durations.reduce(0, +)
        guard total > 0 else { return 0 }
        var t = time.truncatingRemainder(dividingBy: total)
        for (index, duration) in durations.enumerated() {
            if t < duration { return index }
            t -= duration
        }
        return durations.count - 1
    }
}

/// One still sprite, pixel-perfect.
struct SpriteImage: View {
    let path: String

    var body: some View {
        if let image = SpriteLibrary.image(path) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

/// A looping strip. Callers show a still sprite instead under Reduce Motion
/// and in demo mode (a never-ending animation keeps XCUITest waiting).
struct AnimatedSprite: View {
    let animation: SpriteAnimation

    var body: some View {
        let frames = SpriteLibrary.frames(of: animation)
        TimelineView(.animation(minimumInterval: 0.04)) { context in
            if !frames.isEmpty {
                let index = animation.frameIndex(at: context.date.timeIntervalSinceReferenceDate)
                Image(decorative: frames[min(index, frames.count - 1)], scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

/// Whether looping animations may play: not under Reduce Motion, not in demo mode.
struct MotionAllowed {
    let reduceMotion: Bool
    var value: Bool { !reduceMotion && !UISmokeMode.isActive }
}
