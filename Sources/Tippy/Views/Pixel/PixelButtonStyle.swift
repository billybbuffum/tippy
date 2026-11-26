import SwiftUI

/// A pixel button: a `PixelPanel` that presses down one pixel into its shadow.
/// Disabled buttons are desaturated.
struct PixelButtonStyle: ButtonStyle {
    var kind: PixelPanelStyle = .teal
    /// Text size in UI pixels.
    var size: CGFloat = 12
    var font: PixelTextStyle.Kind = .body
    /// Whether the button stretches to the width it's offered.
    var fill = true

    func makeBody(configuration: Configuration) -> some View {
        PixelButtonBody(configuration: configuration, kind: kind, size: size, font: font, fill: fill)
    }
}

private struct PixelButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: PixelPanelStyle
    let size: CGFloat
    let font: PixelTextStyle.Kind
    let fill: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let u = PixelGrid.uiPoint
        configuration.label
            .pixelFont(font, size)
            .foregroundStyle(kind.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, (fill ? 5 : 3) * u)
            .padding(.vertical, (fill ? 4 : 3) * u)
            .frame(maxWidth: fill ? .infinity : nil)
            .padding(.trailing, u)
            .padding(.bottom, u)
            .background(PixelPanel(style: kind, shadow: !configuration.isPressed))
            .offset(x: configuration.isPressed ? u : 0, y: configuration.isPressed ? u : 0)
            .saturation(isEnabled ? 1 : 0.15)
            .opacity(isEnabled ? 1 : 0.75)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PixelButtonStyle {
    static func pixel(_ kind: PixelPanelStyle = .teal, size: CGFloat = 12, font: PixelTextStyle.Kind = .body, fill: Bool = true) -> PixelButtonStyle {
        PixelButtonStyle(kind: kind, size: size, font: font, fill: fill)
    }
}
