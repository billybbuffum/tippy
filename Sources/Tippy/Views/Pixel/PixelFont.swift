import SwiftUI
import CoreText

/// The bundled pixel fonts (SIL Open Font License, see Resources/Fonts):
/// Pixelify Sans for text, Silkscreen for small caps labels.
enum PixelFonts {
    /// PostScript names, which `Font.custom` resolves most reliably.
    static let body = "PixelifySans-Regular"
    static let label = "Silkscreen-Regular"
    static let labelBold = "Silkscreen-Bold"

    @MainActor private static var registered = false

    /// Registers the fonts for this process. The composition root calls it once.
    @MainActor
    static func register() {
        guard !registered else { return }
        registered = true
        for name in ["PixelifySans", "Silkscreen-Regular", "Silkscreen-Bold"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Pixel text, sized in UI pixels (2 pt each). At accessibility text sizes it
/// falls back to the rounded system font so it stays readable (spec 06).
struct PixelTextStyle: ViewModifier {
    enum Kind {
        case body
        case label
        case labelBold
    }

    let kind: Kind
    let uiPixels: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.font(font)
    }

    private var font: Font {
        let points = uiPixels * PixelGrid.uiPoint
        if dynamicTypeSize >= .accessibility1 {
            return .system(size: points * 1.3, weight: kind == .body ? .medium : .bold, design: .rounded)
        }
        switch kind {
        case .body: return .custom(PixelFonts.body, fixedSize: points)
        case .label: return .custom(PixelFonts.label, fixedSize: points)
        case .labelBold: return .custom(PixelFonts.labelBold, fixedSize: points)
        }
    }
}

extension View {
    /// Pixel text: `.pixelFont(.body, 10)` is Pixelify Sans at 10 UI pixels.
    func pixelFont(_ kind: PixelTextStyle.Kind = .body, _ uiPixels: CGFloat = 10) -> some View {
        modifier(PixelTextStyle(kind: kind, uiPixels: uiPixels))
    }
}
