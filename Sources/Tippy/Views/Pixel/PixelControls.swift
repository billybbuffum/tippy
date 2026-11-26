import SwiftUI

/// A stepper on the UI grid: the value as text, then − and + pixel buttons.
/// Each part stays its own accessibility element, so VoiceOver and Voice
/// Control can reach the buttons.
struct PixelStepper: View {
    /// What it adjusts, for the buttons' labels ("Amount").
    let name: String
    /// The value as she reads it ("12.0 oz").
    let text: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        let u = PixelGrid.uiPoint
        HStack(spacing: 3 * u) {
            Text(text)
                .pixelFont(.body, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                PixelIcon.minus.frame(height: 7 * u)
            }
            .buttonStyle(.pixel(.paper, fill: false))
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("Less \(name.lowercased())")
            Button {
                value = min(range.upperBound, value + step)
            } label: {
                PixelIcon.plus.frame(height: 7 * u)
            }
            .buttonStyle(.pixel(.paper, fill: false))
            .disabled(value >= range.upperBound)
            .accessibilityLabel("More \(name.lowercased())")
        }
        .accessibilityElement(children: .contain)
    }
}

/// A toggle drawn as a pixel switch after its label.
struct PixelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() }
        } label: {
            HStack {
                configuration.label
                    .pixelFont(.body, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PixelSwitch(isOn: configuration.isOn)
                    .frame(width: 26 * PixelGrid.uiPoint, height: 14 * PixelGrid.uiPoint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

extension ToggleStyle where Self == PixelToggleStyle {
    static var pixel: PixelToggleStyle { PixelToggleStyle() }
}

private struct PixelSwitch: View {
    let isOn: Bool

    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            let w = (size.width / u).rounded(.down)
            let h = (size.height / u).rounded(.down)
            func rect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x * u, y: y * u, width: rw * u, height: rh * u)), with: .color(color))
            }
            rect(1, 0, w - 2, h, PixelPalette.plum)
            rect(0, 1, w, h - 2, PixelPalette.plum)
            rect(1, 1, w - 2, h - 2, isOn ? PixelPalette.teal : PixelPalette.parchmentShade)
            let knob = h - 4
            let x = isOn ? w - 2 - knob : 2
            rect(x, 2, knob, knob, PixelPalette.plum)
            rect(x + 1, 3, knob - 2, knob - 2, PixelPalette.parchmentLight)
        }
        .accessibilityHidden(true)
    }
}

/// A row of pixel buttons choosing one option, like a segmented picker.
struct PixelSegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 2 * PixelGrid.uiPoint) {
            ForEach(options, id: \.self) { option in
                Button(title(option)) { selection = option }
                    .buttonStyle(.pixel(option == selection ? .chosen : .paper, size: 10))
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension View {
    /// A text field on the UI grid: pixel text on a paper panel.
    func pixelField() -> some View {
        self
            .pixelFont(.body, 11)
            .foregroundStyle(PixelPalette.plum)
            .tint(PixelPalette.tealDark)
            .padding(.vertical, PixelGrid.uiPoint)
            .pixelPanel(.paper, shadow: false)
    }
}
