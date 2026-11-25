import SwiftUI
import TippyWander

/// Where everything on the trail map goes, for a given width: the start at
/// the pond, then each area's banner with its landmarks zig-zagging down
/// across it and the ground below. The path is a smooth curve through the
/// node centres, and the pet's place for any (fractional) step lies on it.
struct TrailLayout {
    struct Section: Identifiable {
        let area: Area
        let top: CGFloat
        let height: CGFloat
        var id: String { area.id }
    }

    struct Node: Identifiable {
        let landmark: Landmark
        let point: CGPoint
        /// Captions go on the side away from the path's swing.
        let captionOnRight: Bool
        var id: String { landmark.id }
    }

    /// A point the path passes through and the step it stands for.
    struct Stop {
        let step: Int
        let point: CGPoint
    }

    static let startHeight: CGFloat = 120
    static let rowHeight: CGFloat = 118
    static let bottomPadding: CGFloat = 120

    let width: CGFloat
    let sections: [Section]
    let nodes: [Node]
    let start: CGPoint
    let height: CGFloat

    var bannerHeight: CGFloat { width / 2 }

    init(width: CGFloat) {
        let mapWidth = max(width, 1)
        self.width = mapWidth
        let banner = mapWidth / 2
        let firstOffset = banner * 0.55
        var sections: [Section] = []
        var nodes: [Node] = []
        var top = TrailLayout.startHeight
        var index = 0
        for area in Trail.areas {
            let height = firstOffset + CGFloat(area.landmarks.count) * TrailLayout.rowHeight
            sections.append(Section(area: area, top: top, height: height))
            for (row, landmark) in area.landmarks.enumerated() {
                let onLeft = index % 2 == 0
                let x = mapWidth * (onLeft ? 0.3 : 0.7)
                let point = CGPoint(x: x, y: top + firstOffset + CGFloat(row) * TrailLayout.rowHeight)
                nodes.append(Node(landmark: landmark, point: point, captionOnRight: onLeft))
                index += 1
            }
            top += height
        }
        self.sections = sections
        self.nodes = nodes
        self.start = CGPoint(x: mapWidth * 0.5, y: TrailLayout.startHeight * 0.45)
        self.height = top + TrailLayout.bottomPadding
    }

    /// The path's points with the step each one stands for: the pond at 0,
    /// then every landmark at its step.
    private var stops: [Stop] {
        [Stop(step: 0, point: start)] + nodes.map { Stop(step: $0.landmark.step, point: $0.point) }
    }

    /// The pet's place at `step` (fractional while it moves): along the
    /// curve between the stops either side.
    func point(atStep step: Double) -> CGPoint {
        let stops = self.stops
        guard let last = stops.last else { return start }
        if step <= 0 { return start }
        if step >= Double(last.step) { return last.point }
        for index in 0..<(stops.count - 1) {
            let from = stops[index]
            let to = stops[index + 1]
            if step <= Double(to.step) {
                let span = Double(max(to.step - from.step, 1))
                let t = CGFloat((step - Double(from.step)) / span)
                return TrailLayout.curve(from.point, to.point, t)
            }
        }
        return last.point
    }

    /// The smooth curve through every stop.
    var path: Path {
        var path = Path()
        let stops = self.stops
        guard let first = stops.first else { return path }
        path.move(to: first.point)
        for index in 1..<stops.count {
            let from = stops[index - 1].point
            let to = stops[index].point
            let middle = (from.y + to.y) / 2
            path.addCurve(to: to, control1: CGPoint(x: from.x, y: middle), control2: CGPoint(x: to.x, y: middle))
        }
        return path
    }

    /// A point on the cubic between two stops, with the same control points as `path`.
    private static func curve(_ from: CGPoint, _ to: CGPoint, _ t: CGFloat) -> CGPoint {
        let middle = (from.y + to.y) / 2
        let c1 = CGPoint(x: from.x, y: middle)
        let c2 = CGPoint(x: to.x, y: middle)
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return CGPoint(
            x: a * from.x + b * c1.x + c * c2.x + d * to.x,
            y: a * from.y + b * c1.y + c * c2.y + d * to.y
        )
    }
}
