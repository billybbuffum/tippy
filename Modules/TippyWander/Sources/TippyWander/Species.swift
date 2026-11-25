import Foundation

/// A kind of pet that hatches from an egg. Bundled content with stable IDs:
/// saved eggs and pets refer to them, so an ID is never renamed or reused.
public struct Species: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Prepended to a pose to find its sprite: "" for the pondling
    /// (`Pet/happy`), "moth-" for the moth (`Pet/moth-happy`).
    public let spritePrefix: String
    /// Check-ins after it enters the nest before it hatches.
    public let hatchAfterCheckIns: Int

    public static let pondling = Species(id: "pondling", name: "Pondling", spritePrefix: "", hatchAfterCheckIns: 1)
    public static let moth = Species(id: "moth", name: "Lilac moth", spritePrefix: "moth-", hatchAfterCheckIns: 3)
    public static let turtle = Species(id: "turtle", name: "Leaf-shell turtle", spritePrefix: "turtle-", hatchAfterCheckIns: 3)
    public static let seal = Species(id: "seal", name: "Spotted seal", spritePrefix: "seal-", hatchAfterCheckIns: 3)
    public static let fox = Species(id: "fox", name: "Cinnamon fox", spritePrefix: "fox-", hatchAfterCheckIns: 3)

    /// Every species, the starter first.
    public static let all: [Species] = [pondling, moth, turtle, seal, fox]

    /// The species with this ID; nil for one this version doesn't know.
    public static func with(id: String) -> Species? {
        all.first { $0.id == id }
    }
}
