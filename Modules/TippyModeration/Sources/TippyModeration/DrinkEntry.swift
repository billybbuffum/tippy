import Foundation

/// What kind of drink was poured; each has a typical serving to start from.
public enum DrinkKind: String, Codable, CaseIterable, Sendable {
    case beer
    case wine
    case cocktail
    case spirit
    case seltzer
    case other

    public var defaultServing: DrinkServing {
        switch self {
        case .beer: return .beer
        case .wine: return .wine
        case .cocktail: return DrinkServing(volumeMilliliters: 120, abvPercent: 18)!
        case .spirit: return .spirit
        case .seltzer: return DrinkServing(volumeMilliliters: 355, abvPercent: 5)!
        case .other: return .beer
        }
    }
}

/// One logged drink.
public struct DrinkEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// The day it counts towards (can be earlier than `loggedAt`: back-filled).
    public var day: LocalDate
    public var loggedAt: Date
    public var kind: DrinkKind
    public var volumeMilliliters: Double
    public var abvPercent: Double

    public init(id: UUID = UUID(), day: LocalDate, loggedAt: Date, kind: DrinkKind, serving: DrinkServing) {
        self.id = id
        self.day = day
        self.loggedAt = loggedAt
        self.kind = kind
        self.volumeMilliliters = serving.volumeMilliliters
        self.abvPercent = serving.abvPercent
    }

    public var serving: DrinkServing? {
        DrinkServing(volumeMilliliters: volumeMilliliters, abvPercent: abvPercent)
    }

    public var standardDrinks: Double { serving?.standardDrinks ?? 0 }
}
