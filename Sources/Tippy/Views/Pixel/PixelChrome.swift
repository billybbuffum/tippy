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

/// Wooden planks filling a screen: the frame pushed screens (History, Pets)
/// sit in, with their parchment list on top.
struct WoodBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            let plank: CGFloat = 16
            let rows = Int((size.height / u / plank).rounded(.up))
            for row in 0..<rows {
                let y = CGFloat(row) * plank * u
                let fill = row.isMultiple(of: 2) ? PixelPalette.wood : PixelPalette.woodLight.opacity(0.85)
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: plank * u)), with: .color(PixelPalette.woodDark))
                context.fill(Path(CGRect(x: 0, y: y + u, width: size.width, height: (plank - 2) * u)), with: .color(fill))
                // A seam where two boards meet, staggered row to row.
                let seam = (row.isMultiple(of: 2) ? 0.3 : 0.7) * size.width
                let x = (seam / u).rounded(.down) * u
                context.fill(Path(CGRect(x: x, y: y, width: u, height: plank * u)), with: .color(PixelPalette.woodDark))
                for nail in [x - 3 * u, x + 3 * u] {
                    context.fill(Path(CGRect(x: nail, y: y + 3 * u, width: u, height: u)), with: .color(PixelPalette.plum))
                    context.fill(Path(CGRect(x: nail, y: y + (plank - 4) * u, width: u, height: u)), with: .color(PixelPalette.plum))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// A pushed screen in the pixel style (spec 06): the content on wooden
    /// planks, the title on a ribbon. It keeps the system back button, so the
    /// swipe back and VoiceOver's back gesture keep working. `identifier`
    /// names the content, the marker the smoke scenarios wait for.
    func pixelScreen(_ title: String, identifier: String) -> some View {
        self
            .foregroundStyle(PixelPalette.plum)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(WoodBackdrop().ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TitleRibbon(title: title)
                }
            }
            .tint(PixelPalette.parchmentLight)
    }

    /// A parchment panel holding a screen's list, inset in its wooden frame.
    func parchmentFrame() -> some View {
        self
            .background(PixelPanel(style: .parchment))
            .padding(.horizontal, 5 * PixelGrid.uiPoint)
            .padding(.bottom, 4 * PixelGrid.uiPoint)
    }
}
