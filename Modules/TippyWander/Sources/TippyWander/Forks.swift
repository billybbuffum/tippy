import Foundation

/// A winding path off the main trail through a habitat of its own, with its
/// own discoveries (spec 07). Walking it takes `length` steps, the last of
/// which brings the pet back to where it left from, so its landmarks sit at
/// steps 1..<length.
public struct SidePath: Hashable, Sendable {
    /// Shown on the fork's signpost: "Heron's Inlet".
    public let name: String
    /// The kind of place it winds through: "Marsh", "Fern gully".
    public let habitat: String
    /// Steps to walk it, including the step back to the fork.
    public let length: Int
    /// A line for the fork card, hinting at what's down there.
    public let hint: String
    /// `step` counts steps into the path, 1..<length.
    public let landmarks: [Landmark]
}

/// A spot on the main trail where a side path leaves and comes back.
public struct Fork: Identifiable, Hashable, Sendable {
    /// Stable: saved routes refer to it. Never rename or reuse one.
    public let id: String
    /// The area it's in, for the current area while the pet walks its path.
    public let areaID: String
    /// Where it sits on the main trail, always between two landmarks.
    public let mainStep: Int
    public let sidePath: SidePath
}

extension Trail {
    /// The forks, in main-trail order (trail version 2). Each side path is a
    /// small place of its own, with scenery, coins, a decoration to find and
    /// a creature who lives there. Landmark IDs are unique across the main
    /// trail and every side path, because finds share one map.
    public static let forks: [Fork] = [
        Fork(id: "reeds-inlet", areaID: "reed-bed", mainStep: 11, sidePath: SidePath(
            name: "Heron's Inlet", habitat: "Marsh", length: 8,
            hint: "A boardwalk winds out over the water. Something glints there.",
            landmarks: [
                Landmark(id: "inlet-dragonflies", name: "Dragonflies skimming the inlet", step: 2, content: .scenery),
                Landmark(id: "inlet-pouch", name: "A pouch on a heron's perch", step: 3, content: .pouch(coins: 6)),
                Landmark(id: "inlet-heron", name: "A heron fishing in the shallows", step: 5, content: .visitor(id: "heron")),
                Landmark(id: "inlet-cairn", name: "A little stack of pond pebbles", step: 7, content: .decoration(itemID: "pebble-cairn")),
            ]
        )),
        Fork(id: "willow-hollow", areaID: "willow-grove", mainStep: 19, sidePath: SidePath(
            name: "The Hollow Willow", habitat: "Ancient willow", length: 8,
            hint: "A path circles the oldest willow. A rope creaks in its branches.",
            landmarks: [
                Landmark(id: "hollow-swing", name: "A rope swing in the willow", step: 2, content: .scenery),
                Landmark(id: "hollow-owl", name: "An owl in the hollow trunk", step: 4, content: .visitor(id: "owl")),
                Landmark(id: "hollow-bloom", name: "A lily in full bloom", step: 6, content: .decoration(itemID: "lily-bloom")),
                Landmark(id: "hollow-pouch", name: "A pouch tucked in the roots", step: 7, content: .pouch(coins: 10)),
            ]
        )),
        Fork(id: "woods-ferns", areaID: "mossy-woods", mainStep: 33, sidePath: SidePath(
            name: "Fern Hollow", habitat: "Fern gully", length: 9,
            hint: "A narrow path zig-zags down into the ferns. Water trickles somewhere below.",
            landmarks: [
                Landmark(id: "ferns-pouch", name: "A pouch under the ferns", step: 2, content: .pouch(coins: 12)),
                Landmark(id: "ferns-hedgehog", name: "A hedgehog snuffling in the moss", step: 4, content: .visitor(id: "hedgehog")),
                Landmark(id: "ferns-stream", name: "A stream hidden under the ferns", step: 6, content: .scenery),
                Landmark(id: "ferns-glow", name: "Mushrooms glowing softly", step: 8, content: .decoration(itemID: "glow-mushrooms")),
            ]
        )),
        Fork(id: "glade-ring", areaID: "mushroom-glade", mainStep: 49, sidePath: SidePath(
            name: "The Toadstool Ring", habitat: "Fairy ring", length: 8,
            hint: "Music drifts from a ring of toadstools in the long grass.",
            landmarks: [
                Landmark(id: "ring-dance", name: "Mushrooms dancing in a ring", step: 2, content: .scenery),
                Landmark(id: "ring-toad", name: "A toad playing a reed flute", step: 4, content: .visitor(id: "toad")),
                Landmark(id: "ring-pouch", name: "A pouch in the toadstool ring", step: 6, content: .pouch(coins: 15)),
                Landmark(id: "ring-seat", name: "A toadstool just right for sitting", step: 7, content: .decoration(itemID: "toadstool-seat")),
            ]
        )),
    ]

    public static func fork(id: String) -> Fork? {
        forks.first { $0.id == id }
    }

    public static func fork(atMainStep step: Int) -> Fork? {
        forks.first { $0.mainStep == step }
    }

    /// The fork whose side path holds this landmark.
    public static func fork(ofLandmark id: String) -> Fork? {
        forks.first { fork in fork.sidePath.landmarks.contains { $0.id == id } }
    }

    /// Every landmark, main trail and side paths, in trail order: each side
    /// path's landmarks come right after its fork.
    public static var allLandmarks: [Landmark] {
        var result: [Landmark] = []
        var pending = forks
        for landmark in landmarks {
            while let fork = pending.first, fork.mainStep < landmark.step {
                result.append(contentsOf: fork.sidePath.landmarks)
                pending.removeFirst()
            }
            result.append(landmark)
        }
        for fork in pending { result.append(contentsOf: fork.sidePath.landmarks) }
        return result
    }

    /// The landmark at a spot on the walk, if there is one.
    public static func landmark(at spot: TrailSpot) -> Landmark? {
        switch spot {
        case .main(let step):
            return landmarks.first { $0.step == step }
        case .side(let forkID, let step):
            return fork(id: forkID)?.sidePath.landmarks.first { $0.step == step }
        }
    }
}
