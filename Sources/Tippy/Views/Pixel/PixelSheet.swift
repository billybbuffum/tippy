import SwiftUI

/// A sheet as a parchment card over the dimmed scene (spec 06): a title
/// ribbon between pixel buttons, then the content, on paper with a plum
/// edge. It replaces the navigation bar, so a sheet using it needs no
/// `NavigationStack` of its own. `identifier` names the whole sheet, the
/// marker the smoke scenarios wait for.
struct ParchmentSheet<Leading: View, Trailing: View, Content: View>: View {
    let title: String
    let identifier: String
    var titleIdentifier: String?
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(spacing: 0) {
            HStack(spacing: 2 * u) {
                leading()
                    .frame(maxWidth: .infinity, alignment: .leading)
                TitleRibbon(title: title, identifier: titleIdentifier)
                    .layoutPriority(1)
                trailing()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 6 * u)
            .padding(.top, 10 * u)
            .padding(.bottom, 4 * u)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .foregroundStyle(PixelPalette.plum)
        .tint(PixelPalette.tealDark)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
        .presentationBackground { SheetPaper() }
        .presentationCornerRadius(0)
    }
}

/// The sheet's paper: parchment with a plum edge, a highlight under it, cut
/// top corners and a faint, fixed scatter of fibres.
struct SheetPaper: View {
    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            let w = (size.width / u).rounded(.up)
            let h = (size.height / u).rounded(.up)
            func rect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x * u, y: y * u, width: rw * u, height: rh * u)), with: .color(color))
            }
            rect(0, 1, w, h, PixelPalette.plum)
            rect(1, 0, w - 2, 1, PixelPalette.plum)
            rect(1, 1, w - 2, h, PixelPalette.parchment)
            rect(2, 1, w - 4, 1, PixelPalette.parchmentLight)
            rect(1, 2, w - 2, 1, PixelPalette.parchmentLight)
            var seed: UInt32 = 11
            for _ in 0..<Int(w * h / 90) {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let x = CGFloat(seed % UInt32(max(w - 4, 1))) + 2
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let y = CGFloat(seed % UInt32(max(h - 4, 1))) + 4
                rect(x, y, 1, 1, PixelPalette.parchmentShade.opacity(0.6))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A sheet's title on a teal ribbon with notched tails. It's the screen's
/// header for VoiceOver.
struct TitleRibbon: View {
    let title: String
    var identifier: String?

    var body: some View {
        let u = PixelGrid.uiPoint
        Text(title)
            .pixelFont(.body, 11)
            .foregroundStyle(PixelPalette.parchmentLight)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 9 * u)
            .padding(.top, 3 * u)
            .padding(.bottom, 5 * u)
            .background(RibbonShape())
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(identifier ?? "sheet-title-label")
    }
}

private struct RibbonShape: View {
    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            let w = (size.width / u).rounded(.down)
            let h = (size.height / u).rounded(.down)
            func rect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ color: Color) {
                guard rw > 0, rh > 0 else { return }
                context.fill(Path(CGRect(x: x * u, y: y * u, width: rw * u, height: rh * u)), with: .color(color))
            }
            // Tails, behind the band and two pixels lower, with a notch.
            for x in [CGFloat(0), w - 6] {
                rect(x, 2, 6, h - 2, PixelPalette.plum)
                rect(x + 1, 3, 4, h - 4, PixelPalette.tealDark)
            }
            let mid = ((h + 2) / 2).rounded(.down)
            context.blendMode = .clear
            rect(0, mid - 1, 2, 2, .black)
            rect(w - 2, mid - 1, 2, 2, .black)
            context.blendMode = .normal
            // The band.
            let bandH = h - 2
            rect(3, 0, w - 6, bandH, PixelPalette.plum)
            rect(4, 1, w - 8, bandH - 2, PixelPalette.teal)
            rect(4, 1, w - 8, 1, PixelPalette.tealLight)
            rect(4, bandH - 2, w - 8, 1, PixelPalette.tealDark)
        }
        .accessibilityHidden(true)
    }
}

/// A titled group on a parchment sheet: a small caps heading over a paper card.
struct PixelSection<Content: View>: View {
    let title: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(alignment: .leading, spacing: 2 * u) {
            if let title {
                Text(title.uppercased())
                    .pixelFont(.labelBold, 8)
                    .foregroundStyle(PixelPalette.tealDark)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 4 * u) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(.paper)
            if let footer {
                Text(footer)
                    .pixelFont(.body, 9)
                    .foregroundStyle(PixelPalette.plum.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A full-screen moment (hatching) as a parchment card over the dimmed
/// scene: the cover's own background is clear, so Home shows through.
struct DimmedSceneCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            PixelPalette.plum.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            content()
                .frame(maxWidth: 360)
                .pixelPanel(.parchment)
                .padding(.horizontal, 8 * PixelGrid.uiPoint)
        }
        .presentationBackground(.clear)
    }
}
