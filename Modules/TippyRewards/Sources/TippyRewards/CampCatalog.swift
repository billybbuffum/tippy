import Foundation

/// What kind of spot a decoration sits in.
public enum SlotKind: String, Codable, CaseIterable, Sendable {
    case ground
    case water
    case light
}

/// A spot in the camp scene a decoration can be placed in. IDs are stable:
/// saved placements refer to them.
public struct CampSlot: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: SlotKind

    public init(id: String, kind: SlotKind) {
        self.id = id
        self.kind = kind
    }
}

/// A decoration: bought in the shop, or found on the Wander. IDs are stable:
/// purchases, grants and placements refer to them. Never rename or reuse one.
public struct CatalogItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Coins in the shop; 0 for items that are only ever found.
    public let price: Int
    public let kind: SlotKind
    /// Relative to the sprite folder, without extension: "Camp/lantern".
    public let spritePath: String
    /// False for items only found on the Wander.
    public let inShop: Bool

    public init(id: String, name: String, price: Int, kind: SlotKind, spritePath: String, inShop: Bool) {
        self.id = id
        self.name = name
        self.price = price
        self.kind = kind
        self.spritePath = spritePath
        self.inShop = inShop
    }
}

/// The bundled camp content: its spots and every decoration, in shop order
/// (cheapest first). Three starters cost 10–12 so the first check-ins buy a
/// real choice; the middle band is 25–60; showpieces 90–150.
public enum CampCatalog {
    public static let slots: [CampSlot] = [
        CampSlot(id: "light-1", kind: .light),
        CampSlot(id: "light-2", kind: .light),
        CampSlot(id: "water-1", kind: .water),
        CampSlot(id: "water-2", kind: .water),
        CampSlot(id: "ground-1", kind: .ground),
        CampSlot(id: "ground-2", kind: .ground),
        CampSlot(id: "ground-3", kind: .ground),
        CampSlot(id: "ground-4", kind: .ground),
        CampSlot(id: "ground-5", kind: .ground),
    ]

    public static let items: [CatalogItem] = [
        item("lantern", "Paper lantern", 10, .light),
        item("sprout", "Little sprout", 12, .ground),
        item("seashell", "Seashell", 12, .ground),
        item("mushroom", "Spotted mushroom", 25, .ground),
        item("watering-can", "Watering can", 30, .ground),
        item("lily-planter", "Lily pad planter", 35, .water),
        item("flower-pot", "Flower pot", 40, .ground),
        item("stepping-stones", "Stepping stones", 45, .ground),
        item("reed-cluster", "Reed cluster", 50, .water),
        item("bench", "Log bench", 60, .ground),
        item("string-lights", "String lights", 90, .light),
        item("willow-arch", "Willow arch", 150, .ground),
        item("firefly-jar", "Firefly jar", 0, .light, inShop: false),
    ]

    public static func item(_ id: String) -> CatalogItem? { items.first { $0.id == id } }

    public static func slot(_ id: String) -> CampSlot? { slots.first { $0.id == id } }

    public static var shopItems: [CatalogItem] { items.filter(\.inShop) }

    private static func item(_ id: String, _ name: String, _ price: Int, _ kind: SlotKind, inShop: Bool = true) -> CatalogItem {
        CatalogItem(id: id, name: name, price: price, kind: kind, spritePath: "Camp/\(id)", inShop: inShop)
    }
}

/// One shop purchase, kept as history.
public struct Purchase: Hashable, Codable, Sendable {
    public let itemID: String
    public let price: Int
    public let at: Date

    public init(itemID: String, price: Int, at: Date) {
        self.itemID = itemID
        self.price = price
        self.at = at
    }
}
