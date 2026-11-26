import SwiftUI

/// How a pixel panel or button is coloured.
enum PixelPanelStyle {
    case parchment
    /// A lighter card that stands out on a parchment sheet.
    case paper
    case wood
    case teal
    case leaf
    /// A parchment tile that is selected.
    case chosen

    var fill: Color {
        switch self {
        case .parchment: return PixelPalette.parchment
        case .paper: return PixelPalette.parchmentLight
        case .wood: return PixelPalette.woodLight
        case .teal: return PixelPalette.teal
        case .leaf: return PixelPalette.leaf
        case .chosen: return Color(red: 214 / 255, green: 240 / 255, blue: 228 / 255)
        }
    }

    var shade: Color {
        switch self {
        case .parchment, .paper: return PixelPalette.parchmentShade
        case .wood: return PixelPalette.wood
        case .teal: return PixelPalette.tealDark
        case .leaf: return PixelPalette.leafDark
        case .chosen: return PixelPalette.tealLight
        }
    }

    var highlight: Color {
        switch self {
        case .parchment, .chosen: return PixelPalette.parchmentLight
        case .paper: return .white
        case .wood: return PixelPalette.woodHighlight
        case .teal: return PixelPalette.tealLight
        case .leaf: return PixelPalette.leafLight
        }
    }

    var outline: Color { self == .chosen ? PixelPalette.tealDark : PixelPalette.plum }

    /// Text and icons drawn on it.
    var ink: Color {
        switch self {
        case .parchment, .paper, .chosen: return PixelPalette.plum
        case .wood, .teal, .leaf: return PixelPalette.parchmentLight
        }
    }
}

/// A pixel panel on the 2 pt UI grid: a 1 px outline with cut corners, a
/// highlight row, a shade row and a 1 px drop shadow (spec 06). The panel
/// fills the space minus one pixel on the right and bottom, kept for the shadow.
struct PixelPanel: View {
    var style: PixelPanelStyle = .parchment
    var shadow = true

    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            let w = max((size.width / u).rounded(.down), 4)
            let h = max((size.height / u).rounded(.down), 4)
            func rect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ color: Color) {
                guard rw > 0, rh > 0 else { return }
                context.fill(Path(CGRect(x: x * u, y: y * u, width: rw * u, height: rh * u)), with: .color(color))
            }
            let pw = w - 1
            let ph = h - 1
            if shadow {
                rect(1, ph, pw, 1, PixelPalette.shadow)
                rect(pw, 2, 1, ph - 1, PixelPalette.shadow)
            }
            rect(1, 0, pw - 2, ph, style.outline)
            rect(0, 1, pw, ph - 2, style.outline)
            rect(1, 1, pw - 2, ph - 2, style.fill)
            rect(2, 1, pw - 4, 1, style.highlight)
            rect(1, ph - 2, pw - 2, 1, style.shade)
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts a pixel panel behind the view, with room inside for its outline.
    func pixelPanel(_ style: PixelPanelStyle = .parchment, shadow: Bool = true) -> some View {
        self
            .padding(.horizontal, 4 * PixelGrid.uiPoint)
            .padding(.vertical, 3 * PixelGrid.uiPoint)
            .padding(.trailing, PixelGrid.uiPoint)
            .padding(.bottom, PixelGrid.uiPoint)
            .background(PixelPanel(style: style, shadow: shadow))
    }
}
