import Foundation
import TippyModeration

/// A hatched pet in her collection.
public struct Pet: Identifiable, Hashable, Codable, Sendable {
    /// The ID of the egg it hatched from.
    public let id: String
    public let speciesID: String
    public internal(set) var name: String
    public let hatchedOn: LocalDate

    public init(id: String, speciesID: String, name: String, hatchedOn: LocalDate) {
        self.id = id
        self.speciesID = speciesID
        self.name = name
        self.hatchedOn = hatchedOn
    }

    /// Its species, or the pondling for a species this version doesn't know.
    public var species: Species { Species.with(id: speciesID) ?? .pondling }
}
