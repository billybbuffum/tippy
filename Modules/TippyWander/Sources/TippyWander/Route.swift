import Foundation

/// One choice she made on the Wander (spec 07). The route is the list of
/// them, append-only, in the order she made them.
public enum RouteChoice: Hashable, Sendable {
    /// At the fork, she sent the pet down the side path.
    case explore(forkID: String)
    /// At the fork, she kept to the main trail. The side path stays open.
    case pass(forkID: String)
    /// Later, from the map, she sent the pet down a passed side path. It
    /// starts once `afterSteps` steps have been walked, and the pet comes
    /// back to where it was.
    case revisit(forkID: String, afterSteps: Int)

    public var forkID: String {
        switch self {
        case .explore(let id), .pass(let id), .revisit(let id, _): return id
        }
    }
}

/// A place on the Wander.
public enum TrailSpot: Hashable, Sendable {
    /// On the main trail, `step` steps from the pond.
    case main(step: Int)
    /// On a side path, `step` steps in (0 is at the fork, setting off).
    case side(forkID: String, step: Int)
}

/// Where the pet is: the replay of her steps along her route. Derived, never
/// stored, like the trail position.
public struct Walk: Hashable, Sendable {
    public let spot: TrailSpot
    /// The furthest main-trail step reached (where the pet returns after a side path).
    public let mainStep: Int
    /// Steps walked so far.
    public let stepsUsed: Int
    /// Steps earned but not walked yet: kept while the pet waits at a fork
    /// (or stands at the trail's end) for whichever way she picks.
    public let savedSteps: Int
    /// The fork the pet is waiting at for her choice.
    public let waitingAt: Fork?
    /// The side path being walked.
    public let excursion: Fork?
    /// Passed forks whose side path hasn't been walked: she can send the pet
    /// down any of them from the map.
    public let openForks: [Fork]
}

/// The replay rules. Pure: the same steps and route always give the same
/// walk, and saved steps are just steps not walked yet, so choosing a day
/// later gives exactly the same result as choosing at once.
public enum RoutePolicy {
    public static func walk(steps: Int, route: [RouteChoice]) -> Walk {
        replay(steps: steps, route: route).walk
    }

    /// Where the pet stood after each step walked, in order (`stepsUsed`
    /// entries), for marking finds and for the map's replay.
    public static func path(steps: Int, route: [RouteChoice]) -> [TrailSpot] {
        replay(steps: steps, route: route).path
    }

    /// One step at a time:
    /// - a revisit starts as soon as `afterSteps` steps are walked and no
    ///   side path is under way;
    /// - at a fork not decided yet, stop: every remaining step is saved;
    /// - at a fork decided `explore`, set off down its side path; at `pass`,
    ///   carry on;
    /// - on a side path, its last step brings the pet back where it left from;
    /// - at the trail's end, stop.
    static func replay(steps total: Int, route: [RouteChoice]) -> (walk: Walk, path: [TrailSpot]) {
        var decisions: [String: Bool] = [:]
        var revisits: [(forkID: String, after: Int)] = []
        for choice in route {
            switch choice {
            case .explore(let id):
                if decisions[id] == nil { decisions[id] = true }
            case .pass(let id):
                if decisions[id] == nil { decisions[id] = false }
            case .revisit(let id, let after):
                revisits.append((id, after))
            }
        }

        let steps = max(total, 0)
        var main = 0
        var used = 0
        var path: [TrailSpot] = []
        var arrived = Set<String>()
        var walked = Set<String>()
        var excursion: (fork: Fork, at: Int, returnTo: Int)?
        var nextRevisit = 0

        while true {
            if excursion == nil, nextRevisit < revisits.count, revisits[nextRevisit].after <= used {
                let pending = revisits[nextRevisit]
                nextRevisit += 1
                if let fork = Trail.fork(id: pending.forkID), arrived.contains(fork.id),
                   decisions[fork.id] == false, !walked.contains(fork.id) {
                    walked.insert(fork.id)
                    excursion = (fork, 0, main)
                }
                continue
            }
            if excursion == nil, let fork = Trail.fork(atMainStep: main), !arrived.contains(fork.id) {
                guard let explore = decisions[fork.id] else { break }
                arrived.insert(fork.id)
                if explore {
                    walked.insert(fork.id)
                    excursion = (fork, 0, main)
                }
                continue
            }
            guard used < steps else { break }
            if var current = excursion {
                current.at += 1
                used += 1
                if current.at >= current.fork.sidePath.length {
                    path.append(.main(step: current.returnTo))
                    excursion = nil
                } else {
                    path.append(.side(forkID: current.fork.id, step: current.at))
                    excursion = current
                }
                continue
            }
            guard main < Trail.length else { break }
            main += 1
            used += 1
            path.append(.main(step: main))
        }

        var waiting: Fork?
        if excursion == nil, let fork = Trail.fork(atMainStep: main), !arrived.contains(fork.id) {
            waiting = fork
        }
        let spot: TrailSpot = excursion.map { .side(forkID: $0.fork.id, step: $0.at) } ?? .main(step: main)
        let open = Trail.forks.filter { arrived.contains($0.id) && decisions[$0.id] == false && !walked.contains($0.id) }
        let walk = Walk(
            spot: spot,
            mainStep: main,
            stepsUsed: used,
            savedSteps: steps - used,
            waitingAt: waiting,
            excursion: excursion?.fork,
            openForks: open
        )
        return (walk, path)
    }
}

extension RouteChoice: Codable {
    enum CodingKeys: String, CodingKey {
        case kind, fork, afterSteps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let fork = try c.decode(String.self, forKey: .fork)
        switch kind {
        case "explore": self = .explore(forkID: fork)
        case "pass": self = .pass(forkID: fork)
        case "revisit": self = .revisit(forkID: fork, afterSteps: try c.decode(Int.self, forKey: .afterSteps))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unknown route choice \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .explore(let id):
            try c.encode("explore", forKey: .kind)
            try c.encode(id, forKey: .fork)
        case .pass(let id):
            try c.encode("pass", forKey: .kind)
            try c.encode(id, forKey: .fork)
        case .revisit(let id, let after):
            try c.encode("revisit", forKey: .kind)
            try c.encode(id, forKey: .fork)
            try c.encode(after, forKey: .afterSteps)
        }
    }
}
