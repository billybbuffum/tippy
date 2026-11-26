import SwiftUI

/// The pet's speech bubble: a parchment panel with a tail pointing down at it.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(spacing: 0) {
            Text(text)
                .pixelFont(.body, 10)
                .foregroundStyle(PixelPalette.plum)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .pixelPanel(.parchment)
            Canvas { context, _ in
                context.fill(Path(CGRect(x: 0, y: 0, width: 3 * u, height: u)), with: .color(PixelPalette.plum))
                context.fill(Path(CGRect(x: u, y: 0, width: u, height: u)), with: .color(PixelPalette.parchment))
                context.fill(Path(CGRect(x: u, y: u, width: u, height: u)), with: .color(PixelPalette.plum))
            }
            .frame(width: 3 * u, height: 2 * u)
            .offset(y: -u)
        }
    }
}

/// The wooden dock along the bottom of Home: planks on the UI grid with a
/// plum top edge, extending under the home indicator.
struct PixelDock: View {
    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(PixelPalette.woodDark))
            var y = 2 * u
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: u)), with: .color(PixelPalette.wood))
                y += 12 * u
            }
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: u)), with: .color(PixelPalette.plum))
            context.fill(Path(CGRect(x: 0, y: u, width: size.width, height: u)), with: .color(PixelPalette.woodLight))
        }
        .accessibilityHidden(true)
    }
}
