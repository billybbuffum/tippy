import SwiftUI
import TippyRewards

/// Where things sit in the camp scene, as fractions of its width (the scene is
/// square, origin top-left). The background art (spec 05) is painted to match,
/// so change these only together with it.
enum CampLayout {
    static let pondCenter = CGPoint(x: 0.50, y: 0.42)
    static let pondSize = CGSize(width: 0.62, height: 0.26)
    static let pet = CGPoint(x: 0.50, y: 0.70)
    static let petSize: CGFloat = 0.34
    static let nest = CGPoint(x: 0.26, y: 0.74)
    static let nestSize: CGFloat = 0.20
    /// The outlined target for a spot in decorate mode.
    static let slotTargetSize: CGFloat = 0.17

    static func point(for slotID: String) -> CGPoint {
        switch slotID {
        case "water-1": return CGPoint(x: 0.38, y: 0.40)
        case "water-2": return CGPoint(x: 0.64, y: 0.44)
        case "light-1": return CGPoint(x: 0.14, y: 0.18)
        case "light-2": return CGPoint(x: 0.86, y: 0.18)
        case "ground-1": return CGPoint(x: 0.10, y: 0.62)
        case "ground-2": return CGPoint(x: 0.20, y: 0.88)
        case "ground-3": return CGPoint(x: 0.50, y: 0.92)
        case "ground-4": return CGPoint(x: 0.80, y: 0.88)
        case "ground-5": return CGPoint(x: 0.90, y: 0.62)
        default: return CGPoint(x: 0.50, y: 0.50)
        }
    }

    /// A decoration's drawn size; the willow arch is the one showpiece drawn larger.
    static func size(for itemID: String) -> CGFloat { itemID == "willow-arch" ? 0.26 : 0.16 }

    /// The quiet loop a decoration plays when motion is allowed (Assets/Sprites/README.md).
    static func animation(for itemID: String) -> SpriteAnimation? {
        let strips = [
            "lantern": "lantern-glow", "sprout": "sprout-sway", "mushroom": "mushroom-bob",
            "watering-can": "watering-can-tilt", "seashell": "seashell-glint", "string-lights": "string-lights-twinkle",
            "firefly-jar": "firefly-jar-glow", "reed-cluster": "reed-cluster-sway", "lily-planter": "lily-planter-bob",
        ]
        guard let strip = strips[itemID] else { return nil }
        return SpriteAnimation(strip: strip, durations: [0.65, 0.14, 0.14, 0.17])
    }

    /// "Ground spot 2", for VoiceOver and the spot's sheet.
    static func label(for slot: CampSlot) -> String {
        let number = slot.id.split(separator: "-").last.map(String.init) ?? ""
        switch slot.kind {
        case .ground: return "Ground spot \(number)"
        case .water: return "Pond spot \(number)"
        case .light: return "Light spot \(number)"
        }
    }

    /// Spots behind the pet (drawn first) and in front of it, each back to front.
    static var slotsBehindPet: [CampSlot] { CampCatalog.slots.filter { point(for: $0.id).y < pet.y }.sorted { point(for: $0.id).y < point(for: $1.id).y } }
    static var slotsInFrontOfPet: [CampSlot] { CampCatalog.slots.filter { point(for: $0.id).y >= pet.y }.sorted { point(for: $0.id).y < point(for: $1.id).y } }
}

/// A decoration's sprite, looping when allowed, or a simple placeholder when
/// its art isn't in the bundle.
struct DecorationSprite: View {
    let item: CatalogItem
    var animates = false

    var body: some View {
        if animates, let animation = CampLayout.animation(for: item.id), !SpriteLibrary.frames(of: animation).isEmpty {
            AnimatedSprite(animation: animation)
        } else if SpriteLibrary.image(item.spritePath) != nil {
            SpriteImage(path: item.spritePath)
        } else {
            Image(systemName: item.kind.placeholderSymbol)
                .resizable()
                .scaledToFit()
                .padding(8)
                .foregroundStyle(.secondary)
        }
    }
}

extension SlotKind {
    var placeholderSymbol: String {
        switch self {
        case .ground: return "leaf.fill"
        case .water: return "drop.fill"
        case .light: return "lightbulb.fill"
        }
    }
}
