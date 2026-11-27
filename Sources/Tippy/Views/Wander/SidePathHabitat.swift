import SwiftUI

/// The place a side path winds through (spec 07), drawn on the map until
/// spec 05 §7's trail painting lands: its route's shape, and scenery under
/// it. Shapes are in a unit space: x 0...1 outward from the main path, y
/// -1...1 up and down, starting and ending at the fork (0, 0).
enum SidePathHabitat {
    /// Heron's Inlet: the route skirts a pool with reeds and lily pads.
    case marsh
    /// The Hollow Willow: in along a short path, round the old tree, and back.
    case willow
    /// Fern Hollow: switchbacks down into a gully and across its stream.
    case ferns
    /// The Toadstool Ring: in to a ring of toadstools, round it, and back.
    case toadstools

    init(forkID: String) {
        switch forkID {
        case "reeds-inlet": self = .marsh
        case "willow-hollow": self = .willow
        case "woods-ferns": self = .ferns
        default: self = .toadstools
        }
    }

    /// The route's control points, from the fork round and back.
    var route: [CGPoint] {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        switch self {
        case .marsh:
            return [p(0, 0), p(0.15, -0.3), p(0.35, -0.62), p(0.65, -0.72), p(0.92, -0.45), p(1.0, 0),
                    p(0.9, 0.45), p(0.62, 0.7), p(0.32, 0.56), p(0.14, 0.25), p(0, 0)]
        case .willow:
            return [p(0, 0), p(0.2, 0.08), p(0.3, 0.1), p(0.33, -0.35), p(0.5, -0.76), p(0.8, -0.72),
                    p(0.98, -0.3), p(0.98, 0.25), p(0.8, 0.72), p(0.5, 0.76), p(0.32, 0.45), p(0.3, 0.12),
                    p(0.2, 0.06), p(0, 0)]
        case .ferns:
            return [p(0, 0), p(0.28, 0.12), p(0.1, 0.35), p(0.4, 0.5), p(0.14, 0.72), p(0.55, 0.86),
                    p(0.88, 0.6), p(0.62, 0.3), p(0.95, 0), p(0.65, -0.3), p(0.92, -0.6), p(0.5, -0.82),
                    p(0.2, -0.5), p(0.1, -0.2), p(0, 0)]
        case .toadstools:
            return [p(0, 0), p(0.22, -0.05), p(0.35, -0.1), p(0.4, -0.5), p(0.62, -0.8), p(0.88, -0.62),
                    p(0.98, -0.1), p(0.9, 0.45), p(0.66, 0.76), p(0.42, 0.56), p(0.35, 0.1), p(0.22, 0.05), p(0, 0)]
        }
    }

    /// The ground the scenery sits on.
    var ground: Color {
        switch self {
        case .marsh: return Color(red: 0.47, green: 0.6, blue: 0.43)
        case .willow: return Color(red: 0.5, green: 0.63, blue: 0.4)
        case .ferns: return Color(red: 0.31, green: 0.43, blue: 0.29)
        case .toadstools: return Color(red: 0.63, green: 0.66, blue: 0.42)
        }
    }
}

/// A side path's habitat, drawn under its route: a patch of its own ground
/// and the things that make the place, all in the habitat's unit space.
struct HabitatScenery: View {
    let loop: TrailLayout.ForkLoop

    var body: some View {
        let bounds = loop.bounds
        Canvas { context, _ in
            // Map a unit point to this canvas.
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                let point = loop.map(CGPoint(x: x, y: y))
                return CGPoint(x: point.x - bounds.minX, y: point.y - bounds.minY)
            }
            func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                let center = p(x, y)
                let size = CGSize(width: w * loop.reach, height: h * loop.halfHeight)
                context.fill(Path(ellipseIn: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)), with: .color(color))
            }
            func line(_ points: [CGPoint], _ color: Color, _ width: CGFloat) {
                var path = Path()
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }

            ellipse(0.52, 0, 1.12, 2.05, loop.habitat.ground.opacity(0.9))
            switch loop.habitat {
            case .marsh:
                ellipse(0.56, -0.02, 0.6, 0.9, Color(red: 0.32, green: 0.6, blue: 0.62))
                ellipse(0.56, -0.02, 0.48, 0.7, Color(red: 0.38, green: 0.68, blue: 0.68))
                for (x, y) in [(0.45, -0.15), (0.66, 0.15), (0.58, -0.28)] as [(CGFloat, CGFloat)] {
                    ellipse(x, y, 0.08, 0.1, PixelPalette.leaf)
                }
                for (x, y) in [(0.2, -0.05), (0.78, -0.62), (0.97, 0.3), (0.42, 0.82), (0.08, 0.5)] as [(CGFloat, CGFloat)] {
                    for offset in [-0.02, 0.0, 0.02] as [CGFloat] {
                        line([p(x + offset, y), p(x + offset * 1.5, y - 0.22)], Color(red: 0.4, green: 0.5, blue: 0.25), 2)
                        ellipse(x + offset * 1.5, y - 0.22, 0.018, 0.07, PixelPalette.wood)
                    }
                }
            case .willow:
                ellipse(0.76, 0.42, 0.22, 0.26, Color(red: 0.38, green: 0.66, blue: 0.68))
                let trunk = p(0.64, 0.05)
                context.fill(Path(CGRect(x: trunk.x - 7, y: trunk.y - 18, width: 14, height: 36)), with: .color(PixelPalette.woodDark))
                ellipse(0.64, -0.18, 0.5, 0.8, Color(red: 0.36, green: 0.52, blue: 0.3))
                ellipse(0.64, -0.24, 0.38, 0.6, Color(red: 0.45, green: 0.62, blue: 0.36))
                for x in stride(from: CGFloat(0.44), through: 0.84, by: 0.06) {
                    line([p(x, -0.1), p(x + 0.01, 0.2)], Color(red: 0.4, green: 0.58, blue: 0.32), 2)
                }
            case .ferns:
                line([p(0.02, -0.95), p(0.3, -0.55), p(0.5, -0.1), p(0.72, 0.35), p(1.02, 0.95)], Color(red: 0.36, green: 0.6, blue: 0.66), 6)
                for (x, y) in [(0.3, 0.0), (0.75, 0.75), (0.85, -0.15), (0.35, -0.75), (0.6, 0.55), (0.15, -0.6), (0.78, -0.75)] as [(CGFloat, CGFloat)] {
                    let base = p(x, y)
                    for angle in [-0.9, -0.45, 0.0, 0.45, 0.9] as [CGFloat] {
                        line([base, CGPoint(x: base.x + 12 * sin(angle), y: base.y - 12 * cos(angle))], Color(red: 0.42, green: 0.62, blue: 0.34), 2)
                    }
                }
                for (x, y) in [(0.22, -0.32), (0.27, -0.28), (0.18, -0.26)] as [(CGFloat, CGFloat)] {
                    ellipse(x, y, 0.04, 0.06, Color(red: 0.75, green: 0.95, blue: 0.85))
                }
            case .toadstools:
                for index in 0..<9 {
                    let angle = CGFloat(index) / 9 * 2 * .pi
                    let x = 0.66 + 0.2 * cos(angle)
                    let y = -0.02 + 0.42 * sin(angle)
                    let stem = p(x, y)
                    context.fill(Path(CGRect(x: stem.x - 2, y: stem.y - 2, width: 4, height: 7)), with: .color(PixelPalette.parchmentLight))
                    ellipse(x, y - 0.05, 0.06, 0.09, Color(red: 0.82, green: 0.32, blue: 0.3))
                    ellipse(x - 0.01, y - 0.07, 0.015, 0.025, .white)
                }
                ellipse(0.66, -0.02, 0.18, 0.4, Color(red: 0.7, green: 0.72, blue: 0.48))
            }
        }
        .frame(width: bounds.width, height: bounds.height)
        .position(x: bounds.midX, y: bounds.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
