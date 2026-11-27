import SwiftUI
import TippyWander

/// Where everything on the trail map goes, for a given width: the start at
/// the pond, then each area's banner with its landmarks zig-zagging down
/// across it and the ground below. A fork (spec 07) takes a row of its own in
/// the middle, with its side path looping out beside it. The path is a smooth
/// curve through the node centres and forks, and the pet's place for any
/// (fractional) main-trail step lies on it.
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

    /// A side path: a winding route out from its fork through its habitat and
    /// back (spec 07), its landmarks on it. The route's shape comes from its
    /// habitat, in a unit space (x 0...1 outward from the main path, y -1...1
    /// up and down), smoothed and measured so steps are evenly spaced along it.
    struct ForkLoop: Identifiable {
        let fork: Fork
        /// The fork, on the main path.
        let origin: CGPoint
        /// +1 winds out to the right, -1 to the left.
        let direction: CGFloat
        /// How far out it reaches, and how far up and down.
        let reach: CGFloat
        let halfHeight: CGFloat
        /// Where its signpost stands: beside the fork, on the other side of the
        /// main path, so the route and its stones stay clear.
        let signpost: CGPoint
        let habitat: SidePathHabitat
        private let samples: [CGPoint]
        private let distances: [CGFloat]
        var id: String { fork.id }

        init(fork: Fork, origin: CGPoint, direction: CGFloat, reach: CGFloat, halfHeight: CGFloat, signpost: CGPoint) {
            self.fork = fork
            self.origin = origin
            self.direction = direction
            self.reach = reach
            self.halfHeight = halfHeight
            self.signpost = signpost
            let habitat = SidePathHabitat(forkID: fork.id)
            self.habitat = habitat
            let control = habitat.route.map { CGPoint(x: origin.x + direction * $0.x * reach, y: origin.y + $0.y * halfHeight) }
            let samples = ForkLoop.smooth(control)
            var distances: [CGFloat] = [0]
            for index in 1..<max(samples.count, 1) {
                let a = samples[index - 1]
                let b = samples[index]
                distances.append(distances[index - 1] + hypot(b.x - a.x, b.y - a.y))
            }
            self.samples = samples
            self.distances = distances
        }

        /// A habitat-space point on the map.
        func map(_ unit: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + direction * unit.x * reach, y: origin.y + unit.y * halfHeight)
        }

        /// The map rectangle the habitat's scenery fills.
        var bounds: CGRect {
            let a = map(CGPoint(x: -0.04, y: -1.1))
            let b = map(CGPoint(x: 1.08, y: 1.1))
            return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        }

        /// A point along the route: 0 and 1 at the fork, by distance walked.
        func point(at t: CGFloat) -> CGPoint {
            guard let total = distances.last, total > 0, samples.count > 1 else { return origin }
            let target = min(max(t, 0), 1) * total
            var index = 1
            while index < distances.count - 1 && distances[index] < target { index += 1 }
            let span = max(distances[index] - distances[index - 1], 0.0001)
            let f = (target - distances[index - 1]) / span
            let a = samples[index - 1]
            let b = samples[index]
            return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
        }

        func point(ofStep step: Int) -> CGPoint {
            point(at: CGFloat(step) / CGFloat(max(fork.sidePath.length, 1)))
        }

        /// A landmark on the side path and where it's drawn.
        struct SideStop: Identifiable {
            let landmark: Landmark
            let point: CGPoint
            var id: String { landmark.id }
        }

        var nodes: [SideStop] {
            fork.sidePath.landmarks.map { SideStop(landmark: $0, point: point(ofStep: $0.step)) }
        }

        var path: Path {
            var path = Path()
            guard let first = samples.first else { return path }
            path.move(to: first)
            for point in samples.dropFirst() { path.addLine(to: point) }
            return path
        }

        /// A Catmull-Rom curve through the control points, densely sampled.
        private static func smooth(_ points: [CGPoint]) -> [CGPoint] {
            guard points.count > 2 else { return points }
            var result: [CGPoint] = []
            for index in 0..<(points.count - 1) {
                let p0 = points[max(index - 1, 0)]
                let p1 = points[index]
                let p2 = points[index + 1]
                let p3 = points[min(index + 2, points.count - 1)]
                for k in 0..<12 {
                    let t = CGFloat(k) / 12
                    let t2 = t * t
                    let t3 = t2 * t
                    func blend(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                        0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                    }
                    result.append(CGPoint(x: blend(p0.x, p1.x, p2.x, p3.x), y: blend(p0.y, p1.y, p2.y, p3.y)))
                }
            }
            result.append(points[points.count - 1])
            return result
        }
    }

    static let startHeight: CGFloat = 120
    static let rowHeight: CGFloat = 118
    static let bottomPadding: CGFloat = 120

    let width: CGFloat
    let sections: [Section]
    let nodes: [Node]
    let loops: [ForkLoop]
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
        var loops: [ForkLoop] = []
        var top = TrailLayout.startHeight
        var index = 0
        for area in Trail.areas {
            // Landmarks and forks in step order, a row each.
            let forks = Trail.forks.filter { $0.areaID == area.id }
            var rows: [(step: Int, landmark: Landmark?, fork: Fork?)] = []
            for landmark in area.landmarks { rows.append((step: landmark.step, landmark: landmark, fork: nil)) }
            for fork in forks { rows.append((step: fork.mainStep, landmark: nil, fork: fork)) }
            rows.sort { $0.step < $1.step }
            // A fork takes two rows, so its side path has room to wind.
            let units = rows.reduce(CGFloat(0)) { $0 + ($1.fork == nil ? 1 : 2) }
            let height = firstOffset + units * TrailLayout.rowHeight
            sections.append(Section(area: area, top: top, height: height))
            var cursor: CGFloat = 0
            for item in rows {
                if let landmark = item.landmark {
                    let y = top + firstOffset + cursor * TrailLayout.rowHeight
                    let onLeft = index % 2 == 0
                    let x = mapWidth * (onLeft ? 0.3 : 0.7)
                    nodes.append(Node(landmark: landmark, point: CGPoint(x: x, y: y), captionOnRight: onLeft))
                    index += 1
                    cursor += 1
                } else if let fork = item.fork {
                    let y = top + firstOffset + (cursor + 0.5) * TrailLayout.rowHeight
                    let direction: CGFloat = loops.count % 2 == 0 ? 1 : -1
                    loops.append(ForkLoop(
                        fork: fork,
                        origin: CGPoint(x: mapWidth * 0.5, y: y),
                        direction: direction,
                        reach: mapWidth * 0.42,
                        halfHeight: 100,
                        signpost: CGPoint(x: mapWidth * (0.5 - 0.27 * direction), y: y)
                    ))
                    cursor += 2
                }
            }
            top += height
        }
        self.sections = sections
        self.nodes = nodes
        self.loops = loops
        self.start = CGPoint(x: mapWidth * 0.5, y: TrailLayout.startHeight * 0.45)
        self.height = top + TrailLayout.bottomPadding
    }

    /// The path's points with the step each one stands for: the pond at 0,
    /// then every landmark and fork at its step.
    private var stops: [Stop] {
        let points = nodes.map { Stop(step: $0.landmark.step, point: $0.point) }
            + loops.map { Stop(step: $0.fork.mainStep, point: $0.origin) }
        return [Stop(step: 0, point: start)] + points.sorted { $0.step < $1.step }
    }

    func loop(_ forkID: String) -> ForkLoop? { loops.first { $0.id == forkID } }

    /// Where a spot on the walk is drawn.
    func point(of spot: TrailSpot) -> CGPoint {
        switch spot {
        case .main(let step):
            return point(atStep: Double(step))
        case .side(let forkID, let step):
            return loop(forkID)?.point(ofStep: step) ?? start
        }
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

/// The pet's walk on the map (spec 07): the spots it stood on after each
/// step, from the pond, so the replay can follow the route through side paths
/// by a fractional index. The last place is the walk's own spot, which can
/// differ from the last step's when a revisit has just sent the pet to a fork.
struct TrailRoute {
    let layout: TrailLayout
    /// The pond, then one spot per step walked.
    let track: [TrailSpot]
    let final: TrailSpot

    init(layout: TrailLayout, path: [TrailSpot], walk: Walk) {
        self.layout = layout
        self.track = [.main(step: 0)] + path
        self.final = walk.spot
    }

    /// The index of the walk's end.
    var end: Int { track.count - 1 }

    func spot(at index: Int) -> TrailSpot {
        index >= end ? final : track[max(index, 0)]
    }

    /// The pet's place at a fractional index along the walk: on the main
    /// curve between main-trail steps, around the loop on a side path, and
    /// a straight hop where a revisit jumps to a fork or back.
    func point(at index: Double) -> CGPoint {
        if index >= Double(end) { return layout.point(of: final) }
        if index <= 0 { return layout.start }
        let lower = Int(index.rounded(.down))
        let fraction = index - Double(lower)
        let from = track[lower]
        let to = track[lower + 1]
        if case .main(let a) = from, case .main(let b) = to {
            return layout.point(atStep: Double(a) + Double(b - a) * fraction)
        }
        if let loop = sharedLoop(from, to),
           let ta = parameter(from, on: loop, leaving: true),
           let tb = parameter(to, on: loop, leaving: false) {
            return loop.point(at: ta + (tb - ta) * CGFloat(fraction))
        }
        let a = layout.point(of: from)
        let b = layout.point(of: to)
        let t = CGFloat(fraction)
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func sharedLoop(_ a: TrailSpot, _ b: TrailSpot) -> TrailLayout.ForkLoop? {
        for spot in [a, b] {
            if case .side(let id, _) = spot { return layout.loop(id) }
        }
        return nil
    }

    /// A spot's place around a loop: a side step's share of the path, or the
    /// fork itself (0 setting off, 1 coming back).
    private func parameter(_ spot: TrailSpot, on loop: TrailLayout.ForkLoop, leaving: Bool) -> CGFloat? {
        switch spot {
        case .side(let id, let step):
            guard id == loop.id else { return nil }
            return CGFloat(step) / CGFloat(max(loop.fork.sidePath.length, 1))
        case .main(let step):
            guard step == loop.fork.mainStep else { return nil }
            return leaving ? 0 : 1
        }
    }
}
