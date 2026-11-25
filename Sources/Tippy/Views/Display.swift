import SwiftUI
import TippyModeration

extension Double {
    /// Standard drinks with one decimal: "1.0".
    var drinksText: String { String(format: "%.1f", self) }
}

enum Units {
    static let millilitersPerFluidOunce = 29.5735
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
