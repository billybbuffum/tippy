import SwiftUI
import UIKit

/// The time of day the sky shows, from the model's clock (never `Date()`).
enum SkyTime: Equatable {
    case day
    case dusk
    case night

    init(hour: Int) {
        switch hour {
        case 6..<17: self = .day
        case 17..<20: self = .dusk
        default: self = .night
        }
    }

    /// Top to bottom.
    var bands: [Color] {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
        switch self {
        case .day: return [c(120, 190, 226), c(146, 206, 232), c(176, 222, 238), c(206, 234, 240), c(226, 240, 236), c(240, 244, 228)]
        case .dusk: return [c(52, 44, 92), c(78, 58, 112), c(120, 76, 126), c(178, 104, 120), c(226, 150, 118), c(246, 196, 140)]
        case .night: return [c(18, 18, 44), c(26, 26, 58), c(34, 32, 72), c(44, 40, 86), c(56, 50, 98), c(72, 62, 112)]
        }
    }

    var pondBackground: String { self == .day ? "Camp/pond-background" : "Camp/pond-background-dusk" }

    /// Dims the borrowed daylight treeline to match the sky.
    var treelineTint: Color {
        switch self {
        case .day: return .white
        case .dusk: return Color(red: 0.78, green: 0.72, blue: 0.86)
        case .night: return Color(red: 0.42, green: 0.44, blue: 0.64)
        }
    }
}

/// Where the world sits on this screen (spec 06): one art pixel is width / 132,
/// and the 128 px pond camp is centred a little above the middle, which keeps it
/// clear of the HUD on top and the dock below on every phone size.
struct WorldLayout {
    let size: CGSize

    var unit: CGFloat { PixelGrid.worldUnit(forWidth: size.width) }
    var pondSide: CGFloat { 128 * unit }
    var pondOrigin: CGPoint {
        CGPoint(x: 2 * unit, y: (size.height * 0.49 - pondSide / 2).rounded())
    }

    /// A point given as a fraction of the pond square (the spec 02 coordinates).
    func point(_ fraction: CGPoint) -> CGPoint {
        CGPoint(x: pondOrigin.x + fraction.x * pondSide, y: pondOrigin.y + fraction.y * pondSide)
    }
}

/// Everything behind the camp: the sky with its stars and sun or moon, a
/// treeline on the horizon, and ground running down under the dock. Until
/// spec 05 §7's tall camp scene lands, the treeline is borrowed from the
/// willow-grove banner and the ground from the pond background's bottom band.
struct WorldBackdrop: View {
    let layout: WorldLayout
    let time: SkyTime

    var body: some View {
        let u = layout.unit
        ZStack(alignment: .topLeading) {
            SkyCanvas(time: time, unit: u)
                .frame(width: layout.size.width, height: layout.pondOrigin.y + 8 * u)
            ground
                .offset(y: layout.pondOrigin.y - 2 * u)
            treeline
                .offset(y: layout.pondOrigin.y - 30 * u)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .clipped()
        .accessibilityHidden(true)
    }

    /// Three copies side by side, so the 128 px art covers the 132 px width.
    private func band(_ image: UIImage?, height: CGFloat, fallback: Color) -> some View {
        let u = layout.unit
        return HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                if let image {
                    Image(uiImage: image).interpolation(.none).resizable()
                        .frame(width: 128 * u, height: height)
                } else {
                    fallback.frame(width: 128 * u, height: height)
                }
            }
        }
        .offset(x: 2 * u - 128 * u)
    }

    private var treeline: some View {
        band(
            SpriteLibrary.image("Wander/area-willow-grove", crop: CGRect(x: 0, y: 32, width: 512, height: 128)),
            height: 32 * layout.unit,
            fallback: PixelPalette.leafDark
        )
        .colorMultiply(time.treelineTint)
    }

    private var ground: some View {
        let u = layout.unit
        let rowHeight = 28 * u
        let rows = Int((layout.size.height - layout.pondOrigin.y) / rowHeight) + 2
        let tile = SpriteLibrary.image(time.pondBackground, crop: CGRect(x: 0, y: 400, width: 512, height: 112))
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { _ in
                band(tile, height: rowHeight, fallback: Color(red: 0.36, green: 0.42, blue: 0.40))
            }
        }
    }
}

/// The sky in bands of colour on the world grid, with stars at dusk and night
/// and a pixel sun or moon.
private struct SkyCanvas: View {
    let time: SkyTime
    let unit: CGFloat

    var body: some View {
        Canvas { context, size in
            let u = unit
            let bands = time.bands
            let rows = (size.height / u).rounded(.up)
            let bandRows = (rows / CGFloat(bands.count)).rounded(.up)
            for (index, color) in bands.enumerated() {
                let y = CGFloat(index) * bandRows * u
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: bandRows * u + u)), with: .color(color))
            }
            if time != .day {
                // The same stars every night: a fixed pseudo-random scatter.
                var seed: UInt32 = 7
                for _ in 0..<(time == .night ? 40 : 24) {
                    seed = seed &* 1_664_525 &+ 1_013_904_223
                    let x = CGFloat(seed % 132)
                    seed = seed &* 1_664_525 &+ 1_013_904_223
                    let y = CGFloat(seed % UInt32(max(rows * 0.45, 1)))
                    context.fill(Path(CGRect(x: x * u, y: y * u, width: u, height: u)), with: .color(Color(red: 1, green: 0.96, blue: 0.84)))
                }
            }
            let center = CGPoint(x: 104, y: 16)
            disc(context, center: center, radius: 6, color: time == .day ? Color(red: 1, green: 0.95, blue: 0.75) : Color(red: 1, green: 0.93, blue: 0.75))
            if time != .day {
                // A crescent: the moon with a sky-coloured disc over it.
                disc(context, center: CGPoint(x: center.x + 3, y: center.y - 1), radius: 6, color: bands[1])
            }
        }
    }

    private func disc(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let u = unit
        for dy in stride(from: -radius, through: radius, by: 1) {
            let half = (radius * radius - dy * dy).squareRoot().rounded(.down)
            context.fill(Path(CGRect(x: (center.x - half) * u, y: (center.y + dy) * u, width: (2 * half + 1) * u, height: u)), with: .color(color))
        }
    }
}
