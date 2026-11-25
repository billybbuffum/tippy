import Foundation

/// What waits at a landmark.
public enum LandmarkContent: Hashable, Sendable {
    /// An egg of this species, which joins the egg queue when found.
    case egg(speciesID: String)
    /// A Rewards catalog item, granted by the app layer (Wander never imports Rewards).
    case decoration(itemID: String)
    /// Coins, awarded by the app layer.
    case pouch(coins: Int)
    /// A one-time visitor ("fox-at-dusk").
    case visitor(id: String)
    /// A named place with nothing to collect; it keeps the path lively.
    case scenery
}

/// A spot on the trail. Reached once the trail position is at least `step`.
public struct Landmark: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let step: Int
    public let content: LandmarkContent
}

/// A stretch of the trail with its own banner and landmarks.
public struct Area: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let landmarks: [Landmark]
}

/// The Wander's trail, version 1: bundled content with stable IDs (saved
/// finds and eggs refer to them; never rename or reuse one). Steps assume
/// about one or two a day, so the first found egg arrives in roughly week
/// one, then about one a week.
public enum Trail {
    public static let areas: [Area] = [
        Area(id: "pond-shore", name: "Pond Shore", landmarks: [
            Landmark(id: "shore-shell", name: "A seashell on the shore", step: 2, content: .decoration(itemID: "seashell")),
            Landmark(id: "shore-pouch", name: "A little pouch by the water", step: 4, content: .pouch(coins: 5)),
            Landmark(id: "shore-bench", name: "An old bench by the pond", step: 6, content: .scenery),
        ]),
        Area(id: "reed-bed", name: "Reed Bed", landmarks: [
            Landmark(id: "reeds-egg-moth", name: "A speckled egg in the reeds", step: 8, content: .egg(speciesID: "moth")),
            Landmark(id: "reeds-fox", name: "A fox at dusk", step: 10, content: .visitor(id: "fox-at-dusk")),
            Landmark(id: "reeds-pouch", name: "A pouch caught in the reeds", step: 13, content: .pouch(coins: 8)),
        ]),
        Area(id: "willow-grove", name: "Willow Grove", landmarks: [
            Landmark(id: "willow-lantern", name: "A firefly jar under the willow", step: 17, content: .decoration(itemID: "firefly-jar")),
            Landmark(id: "willow-egg-turtle", name: "A leafy egg among the roots", step: 21, content: .egg(speciesID: "turtle")),
            Landmark(id: "willow-pouch", name: "A pouch in a hollow trunk", step: 25, content: .pouch(coins: 10)),
        ]),
        Area(id: "mossy-woods", name: "Mossy Woods", landmarks: [
            Landmark(id: "woods-egg-seal", name: "A spotted egg in the moss", step: 30, content: .egg(speciesID: "seal")),
            Landmark(id: "woods-pouch", name: "A pouch on a mossy stump", step: 35, content: .pouch(coins: 10)),
            Landmark(id: "woods-mushrooms", name: "A ring of mushrooms", step: 40, content: .scenery),
        ]),
        Area(id: "mushroom-glade", name: "Mushroom Glade", landmarks: [
            Landmark(id: "glade-egg-fox", name: "A cinnamon egg in the glade", step: 46, content: .egg(speciesID: "fox")),
            Landmark(id: "glade-pouch", name: "A pouch under a toadstool", step: 52, content: .pouch(coins: 10)),
        ]),
        Area(id: "meadow", name: "Meadow", landmarks: [
            Landmark(id: "meadow-end", name: "More of the Wander opens soon", step: 60, content: .scenery),
        ]),
    ]

    /// Every landmark in trail order (by step).
    public static var landmarks: [Landmark] { areas.flatMap(\.landmarks) }

    /// The step of the last landmark: where the trail ends for now.
    public static var length: Int { landmarks.last?.step ?? 0 }

    public static func landmark(id: String) -> Landmark? {
        landmarks.first { $0.id == id }
    }

    /// The area a landmark belongs to.
    public static func area(of landmarkID: String) -> Area? {
        areas.first { area in area.landmarks.contains { $0.id == landmarkID } }
    }
}
