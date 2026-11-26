import SwiftUI
import TippyModeration
import TippyWander

extension Double {
    /// Standard drinks with one decimal: "1.0".
    var drinksText: String { String(format: "%.1f", self) }
}

extension VolumeUnit {
    var shortName: String {
        switch self {
        case .fluidOunce: return "fl oz"
        case .milliliter: return "ml"
        }
    }

    var step: Double { self == .fluidOunce ? 0.5 : 5 }

    var amountRange: ClosedRange<Double> { self == .fluidOunce ? 0.5...64 : 5...2000 }

    func rounded(_ amount: Double) -> Double {
        let snapped = (amount / step).rounded() * step
        return min(max(snapped, amountRange.lowerBound), amountRange.upperBound)
    }
}

/// A day, usable as a sheet's item.
struct DayItem: Identifiable {
    let day: LocalDate
    var id: LocalDate { day }
}

extension DrinkKind {
    var displayName: String {
        switch self {
        case .beer: return "Beer"
        case .wine: return "Wine"
        case .cocktail: return "Cocktail"
        case .spirit: return "Shot"
        case .seltzer: return "Seltzer"
        case .other: return "Other"
        }
    }

    /// The sprite for this kind, when the sprite pack has one.
    var spritePath: String? {
        switch self {
        case .beer, .seltzer: return "Drinks/beer"
        case .wine: return "Drinks/wine"
        case .cocktail: return "Drinks/cocktail"
        case .spirit, .other: return nil
        }
    }

    var symbol: String {
        switch self {
        case .beer: return "mug.fill"
        case .wine: return "wineglass.fill"
        case .cocktail: return "wineglass"
        case .spirit: return "drop.fill"
        case .seltzer: return "bubbles.and.sparkles"
        case .other: return "cup.and.saucer.fill"
        }
    }
}

extension PetMood {
    func caption(petName: String) -> String {
        switch self {
        case .thriving: return "\(petName) is feeling fantastic. Keep it up!"
        case .happy: return "\(petName) is happy. You're right on track this week."
        case .okay: return "\(petName) is doing okay. A drink-free day would help."
        case .concerned: return "\(petName) is a bit sleepy. Tomorrow is a fresh start."
        case .waiting: return "\(petName) is wondering how today went."
        }
    }

    var color: Color {
        switch self {
        case .thriving: return .green
        case .happy: return .teal
        case .okay: return .orange
        case .concerned: return .indigo
        case .waiting: return .gray
        }
    }
}

/// A drink kind's sprite, or its symbol when there is no sprite.
struct DrinkIcon: View {
    let kind: DrinkKind

    var body: some View {
        if let path = kind.spritePath, SpriteLibrary.image(path) != nil {
            SpriteImage(path: path)
        } else {
            Image(systemName: kind.symbol).font(.title2)
        }
    }
}

/// A week, usable as a sheet's item.
struct WeekItem: Identifiable {
    let week: Week
    var id: LocalDate { week.start }
}

extension Week {
    /// "Nov 9–15", or "Nov 30–Dec 6" across a month, with month names in the user's
    /// language (a calendar without a locale would say "M11").
    func rangeText(in calendar: Calendar) -> String {
        var named = calendar
        if (named.locale?.identifier ?? "").isEmpty { named.locale = .autoupdatingCurrent }
        let months = named.shortMonthSymbols
        func month(_ day: LocalDate) -> String { months.indices.contains(day.month - 1) ? months[day.month - 1] : "" }
        if start.month == end.month { return "\(month(start)) \(start.day)–\(end.day)" }
        return "\(month(start)) \(start.day)–\(month(end)) \(end.day)"
    }
}

extension Int {
    /// "1 coin", "8 coins".
    var coinsText: String { self == 1 ? "1 coin" : "\(self) coins" }
}

extension WanderState {
    /// The signpost on Home: "4 steps to the Reed Bed" when the next
    /// landmark is in a new area, else "2 steps to the next landmark"; at a
    /// fork, "At a fork: which way?"; on a side path, "Exploring Heron's
    /// Inlet"; and "3 steps to a fork" when one comes first (spec 07).
    var nextLandmarkCaption: String {
        let walk = self.walk
        if walk.waitingAt != nil { return "At a fork: which way?" }
        if let fork = walk.excursion { return "Exploring \(fork.sidePath.name)" }
        if let ahead = nextFork {
            return ahead.steps == 1 ? "1 step to a fork" : "\(ahead.steps) steps to a fork"
        }
        guard let next = nextLandmark, let steps = stepsToNextLandmark else { return "More of the Wander opens soon" }
        let count = steps == 1 ? "1 step" : "\(steps) steps"
        if let area = Trail.area(of: next.id), area.id != currentArea?.id {
            return "\(count) to the \(area.name)"
        }
        return "\(count) to the next landmark"
    }
}

extension Landmark {
    /// The find card's line: "Sprout found a speckled egg in the reeds!"
    func findSentence(petName: String) -> String {
        let what = name.prefix(1).lowercased() + name.dropFirst()
        switch content {
        // Say what she got and where it went: a pouch's coins were added
        // with the check-in that reached it, long before the map shows it.
        case .pouch(let coins):
            return "\(petName) found \(what), with \(coins.coinsText) inside! They're in your coins."
        case .decoration:
            return "\(petName) found \(what)! It's in storage: place it with Decor."
        case .egg:
            return "\(petName) found \(what)! It's waiting under Pets."
        case .visitor:
            return "\(petName) met \(what)!"
        case .scenery:
            if step == Trail.length { return "\(petName) reached the meadow. More of the Wander opens soon." }
            return "\(petName) reached \(what)."
        }
    }

    /// Eggs and visitors make the pet thrill; everything else makes it happy.
    var isThrilling: Bool {
        switch content {
        case .egg, .visitor: return true
        case .decoration, .pouch, .scenery: return false
        }
    }
}

extension LandmarkContent {
    /// The find icon in Wander/.
    var iconPath: String {
        switch self {
        case .egg: return "Wander/find-egg"
        case .decoration: return "Wander/find-gift"
        case .pouch: return "Wander/find-pouch"
        case .visitor: return "Wander/find-visitor"
        case .scenery: return "Wander/find-scenery"
        }
    }

    /// The stand-in when the icon is missing.
    var symbol: String {
        switch self {
        case .egg: return "oval.portrait.fill"
        case .decoration: return "gift.fill"
        case .pouch: return "bag.fill"
        case .visitor: return "pawprint.fill"
        case .scenery: return "leaf.fill"
        }
    }
}

/// A find's icon, or its symbol when the sprite is missing.
struct FindIcon: View {
    let content: LandmarkContent

    var body: some View {
        if SpriteLibrary.image(content.iconPath) != nil {
            SpriteImage(path: content.iconPath)
        } else {
            Image(systemName: content.symbol).font(.title3).foregroundStyle(.secondary)
        }
    }
}

extension NestStatus {
    /// "Hatches in 2 check-ins".
    var countdownText: String {
        checkInsLeft == 1 ? "Hatches in 1 check-in" : "Hatches in \(checkInsLeft) check-ins"
    }
}
