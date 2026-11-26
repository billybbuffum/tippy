import SwiftUI

/// The grids everything snaps to (spec 06). The world uses one art pixel =
/// screen width / 132; the HUD, buttons and text use a finer UI pixel of 2 pt.
enum PixelGrid {
    static let worldArtWidth: CGFloat = 132
    static let uiPoint: CGFloat = 2

    /// Points per world art pixel for a screen this wide.
    static func worldUnit(forWidth width: CGFloat) -> CGFloat { width / worldArtWidth }
}

/// The pixel UI's palette, matched to the sprite pack: the plum outline every
/// sprite uses, parchment, the pondling's teal, leaf green, wood and gold.
enum PixelPalette {
    static let plum = Color(red: 54 / 255, green: 28 / 255, blue: 48 / 255)
    static let parchment = Color(red: 250 / 255, green: 238 / 255, blue: 210 / 255)
    static let parchmentShade = Color(red: 228 / 255, green: 206 / 255, blue: 170 / 255)
    static let parchmentLight = Color(red: 255 / 255, green: 250 / 255, blue: 236 / 255)
    static let teal = Color(red: 84 / 255, green: 178 / 255, blue: 154 / 255)
    static let tealDark = Color(red: 52 / 255, green: 128 / 255, blue: 110 / 255)
    static let tealLight = Color(red: 140 / 255, green: 214 / 255, blue: 186 / 255)
    static let leaf = Color(red: 118 / 255, green: 176 / 255, blue: 92 / 255)
    static let leafDark = Color(red: 80 / 255, green: 128 / 255, blue: 62 / 255)
    static let leafLight = Color(red: 170 / 255, green: 214 / 255, blue: 140 / 255)
    static let wood = Color(red: 150 / 255, green: 96 / 255, blue: 58 / 255)
    static let woodDark = Color(red: 112 / 255, green: 66 / 255, blue: 40 / 255)
    static let woodLight = Color(red: 186 / 255, green: 128 / 255, blue: 78 / 255)
    static let woodHighlight = Color(red: 214 / 255, green: 160 / 255, blue: 104 / 255)
    static let gold = Color(red: 246 / 255, green: 196 / 255, blue: 82 / 255)
    static let shadow = Color.black.opacity(0.35)
}
