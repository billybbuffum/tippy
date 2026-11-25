import Foundation

/// An egg: found on the trail (or the starter), waiting in the basket or
/// sitting in the nest.
public struct Egg: Identifiable, Hashable, Codable, Sendable {
    /// The landmark ID it came from, or "starter".
    public let id: String
    public let speciesID: String
    /// The check-in count when it entered the nest; nil while in the basket.
    public internal(set) var nestedAtCheckIn: Int?
    /// The name it hatches with; nil means the species' name. Only the
    /// starter has one: the name she chose in onboarding.
    public internal(set) var name: String?

    public init(id: String, speciesID: String, nestedAtCheckIn: Int? = nil, name: String? = nil) {
        self.id = id
        self.speciesID = speciesID
        self.nestedAtCheckIn = nestedAtCheckIn
        self.name = name
    }

    public var species: Species? { Species.with(id: speciesID) }
}
