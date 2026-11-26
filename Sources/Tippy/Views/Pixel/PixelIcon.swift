import SwiftUI

/// A small icon drawn on the UI grid from a string bitmap, one character per
/// pixel ('.' is transparent). Stand-ins until spec 05 §7's drawn icons land.
struct PixelIcon: View {
    let rows: [String]

    var body: some View {
        let u = PixelGrid.uiPoint
        Canvas { context, _ in
            for (y, row) in rows.enumerated() {
                for (x, character) in row.enumerated() {
                    guard let color = PixelIcon.palette[character] else { continue }
                    context.fill(Path(CGRect(x: CGFloat(x) * u, y: CGFloat(y) * u, width: u, height: u)), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(rows.first?.count ?? 0) * u, height: CGFloat(rows.count) * u)
        .accessibilityHidden(true)
    }

    private static let palette: [Character: Color] = [
        "o": PixelPalette.plum, "w": PixelPalette.parchmentLight, "c": PixelPalette.parchment,
        "g": PixelPalette.leaf, "G": PixelPalette.leafDark, "y": PixelPalette.gold,
        "Y": Color(red: 206 / 255, green: 146 / 255, blue: 48 / 255), "f": Color(red: 250 / 255, green: 214 / 255, blue: 120 / 255),
        "b": PixelPalette.wood, "r": Color(red: 214 / 255, green: 92 / 255, blue: 84 / 255), "t": PixelPalette.teal,
    ]

    static let coin = PixelIcon(rows: ["..oooo..", ".oyyyyo.", "oyyffyYo", "oyfyyyYo", "oyyyyyYo", "oyyyyYYo", ".oYYYYo.", "..oooo.."])
    static let leaf = PixelIcon(rows: [".....ooo", "...oogGo", "..ogggGo", ".ogggGo.", ".oggGo..", "oGGoo...", "oo......", "o......."])
    static let mug = PixelIcon(rows: [".ooooo..", "owwwwwo.", "offffooo", "offffo.o", "offffo.o", "offffooo", "offffo..", ".oooo..."])
    static let map = PixelIcon(rows: ["oooooooo", "ocwcwcwo", "owrcwcwo", "ocwrwcwo", "owcwrcwo", "ocwcwcro", "oooooooo"])
    static let paw = PixelIcon(rows: [".o.oo.o.", "oto..oto", ".o.oo.o.", "..otto..", ".otttto.", ".otttto.", "..oooo.."])
    static let brush = PixelIcon(rows: ["......oo", ".....oyo", "....oyo.", "...oyo..", "..obo...", ".obbo...", "obbo....", "ooo....."])
    static let bag = PixelIcon(rows: ["..oooo..", ".o....o.", "oooooooo", "obbbbbbo", "obbyybbo", "obbbbbbo", "oooooooo"])
    static let calendar = PixelIcon(rows: [".o..o..o", "oooooooo", "orrrrrro", "oooooooo", "ocwcwcwo", "owcwcwco", "ocwcwcwo", "oooooooo"])
    static let gear = PixelIcon(rows: ["...oo...", ".o.oo.o.", "..oooo..", "oooccooo", "oooccooo", "..oooo..", ".o.oo.o.", "...oo..."])
    static let flag = PixelIcon(rows: ["oooooo..", "orrrrro.", "orrrro..", "orrrrro.", "oooooo..", "o.......", "o.......", "o......."])
    static let check = PixelIcon(rows: [".......o", "......og", ".....ogo", "o...ogo.", "go.ogo..", ".gogo...", "..go...."])
    static let close = PixelIcon(rows: ["oo...oo", "ooo.ooo", ".ooooo.", "..ooo..", ".ooooo.", "ooo.ooo", "oo...oo"])
    static let bulb = PixelIcon(rows: ["..ooo..", ".offfo.", "offyffo", "offyffo", ".ofyfo.", "..owo..", "..ooo.."])
    static let bell = PixelIcon(rows: ["...o...", "..oyo..", ".oyyyo.", ".oyfyo.", ".oyyyo.", "ooooooo", "...o..."])
    static let sparkle = PixelIcon(rows: ["...y...", "..yfy..", "yyffyyy", "..yfy..", "...y..."])
}
