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

extension WanderState {
    /// The next-landmark chip: "4 steps to the Reed Bed" when the next
    /// landmark is in a new area, else "2 steps to the next landmark".
    var nextLandmarkCaption: String {
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
        case .egg, .decoration, .pouch:
            return "\(petName) found \(what)!"
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
