import Foundation

/// Reference amounts of pure alcohol.
public enum StandardDrink {
    /// One US standard drink: 14 g of pure alcohol.
    public static let usGrams = 14.0
    /// One UK unit: 8 g of pure alcohol.
    public static let ukUnitGrams = 8.0
    /// Density of ethanol, grams per millilitre.
    public static let ethanolDensity = 0.789
}

/// One drink as poured: how much, and how strong. A value object: an
/// invalid serving cannot be made.
public struct DrinkServing: Equatable, Hashable, Sendable {
    public let volumeMilliliters: Double
    public let abvPercent: Double

    /// Nil unless the volume is positive (up to 5 litres) and the ABV is
    /// between 0 and 100 percent.
    public init?(volumeMilliliters: Double, abvPercent: Double) {
        guard volumeMilliliters.isFinite, abvPercent.isFinite,
              volumeMilliliters > 0, volumeMilliliters <= 5000,
              abvPercent >= 0, abvPercent <= 100
        else { return nil }
        self.volumeMilliliters = volumeMilliliters
        self.abvPercent = abvPercent
    }

    public var gramsOfAlcohol: Double {
        volumeMilliliters * (abvPercent / 100) * StandardDrink.ethanolDensity
    }

    /// US standard drinks.
    public var standardDrinks: Double { gramsOfAlcohol / StandardDrink.usGrams }

    /// UK units.
    public var ukUnits: Double { gramsOfAlcohol / StandardDrink.ukUnitGrams }
}

extension DrinkServing {
    /// 12 oz of 5% beer.
    public static let beer = DrinkServing(volumeMilliliters: 355, abvPercent: 5)!
    /// 5 oz of 12% wine.
    public static let wine = DrinkServing(volumeMilliliters: 148, abvPercent: 12)!
    /// 1.5 oz of 40% spirits.
    public static let spirit = DrinkServing(volumeMilliliters: 44, abvPercent: 40)!
}
