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

/// The unit an amount was entered in. Entries keep it, so an edit shows
/// exactly what was typed.
public enum VolumeUnit: String, Codable, CaseIterable, Sendable {
    case fluidOunce
    case milliliter

    public var milliliters: Double {
        switch self {
        case .fluidOunce: return 29.5735
        case .milliliter: return 1
        }
    }
}

/// One logged drink, as entered.
public struct DrinkEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// The day it counts towards (can be earlier than `loggedAt`: back-filled).
    public var day: LocalDate
    public var loggedAt: Date
    public var kind: DrinkKind
    public var amount: Double
    public var unit: VolumeUnit
    public var abvPercent: Double
    /// When set, the drink counts as this many standard drinks instead of the
    /// value computed from amount and strength (a pour she knows better).
    public var standardDrinksOverride: Double?

    public init(
        id: UUID = UUID(),
        day: LocalDate,
        loggedAt: Date,
        kind: DrinkKind,
        amount: Double,
        unit: VolumeUnit,
        abvPercent: Double,
        standardDrinksOverride: Double? = nil
    ) {
        self.id = id
        self.day = day
        self.loggedAt = loggedAt
        self.kind = kind
        self.amount = amount
        self.unit = unit
        self.abvPercent = abvPercent
        self.standardDrinksOverride = standardDrinksOverride
    }

    public var volumeMilliliters: Double { amount * unit.milliliters }

    public var serving: DrinkServing? {
        DrinkServing(volumeMilliliters: volumeMilliliters, abvPercent: abvPercent)
    }

    public var standardDrinks: Double { standardDrinksOverride ?? serving?.standardDrinks ?? 0 }

    /// A real serving, and an override (if any) between 0 and 50.
    public var isValid: Bool {
        guard serving != nil else { return false }
        guard let override = standardDrinksOverride else { return true }
        return override.isFinite && override >= 0 && override <= 50
    }
}
