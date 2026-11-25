import SwiftUI
import TippyModeration
import TippyWander

/// The pet: the active pet's species (the teal pondling by default) in the
/// pose for its mood, on a soft mood-coloured disc. Happy breathes and
/// thriving hops; the other moods hold still, as does everything under
/// Reduce Motion. It never looks sick or sad.
struct PetView: View {
    let mood: PetMood
    var species: Species = .pondling

    var body: some View {
        PetSprite(pose: mood, species: species)
            .background(Circle().fill(mood.color.opacity(0.18)).padding(8))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your pet is \(mood.rawValue)")
    }
}

/// A species in a pose, with no background: `Pet/<prefix><pose>`, falling
/// back to the species' happy pose, then the pondling's, then the drawn pet.
/// Looping poses play only when motion is allowed.
struct PetSprite: View {
    let pose: PetMood
    let species: Species
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let animation = species.animation(for: pose), MotionAllowed(reduceMotion: reduceMotion).value {
                AnimatedSprite(animation: animation)
            } else if let path = species.posePath(pose) {
                SpriteImage(path: path)
            } else {
                DrawnPet(mood: pose)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// An egg of a species, wiggling unless motion is reduced (or it's told to
/// hold still: the nest wiggles it only when it's about to hatch).
struct EggView: View {
    var species: Species = .pondling
    var wiggles = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if wiggles, let wiggle = species.eggWiggle, MotionAllowed(reduceMotion: reduceMotion).value {
                AnimatedSprite(animation: wiggle)
            } else {
                SpriteImage(path: species.eggPath)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An egg")
    }
}

/// The drawn stand-in for the pet, used only if a sprite is missing from the
/// bundle: an original round critter whose face follows its mood.
struct DrawnPet: View {
    let mood: PetMood
    @State private var bobbing = false

    private let cream = Color(red: 0.99, green: 0.93, blue: 0.81)
    private let ink = Color(red: 0.16, green: 0.16, blue: 0.19)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            critter(size)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .offset(y: bobbing ? -3 : 3)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bobbing)
        .animation(.spring, value: mood)
        .onAppear {
            // A never-ending animation would keep XCUITest waiting for the
            // app to go idle; the pet holds still in demo mode.
            if !UISmokeMode.isActive { bobbing = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your pet is \(mood.rawValue)")
    }

    private func critter(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(mood.color.opacity(0.22)).frame(width: s * 0.95, height: s * 0.95)
            // Sprout
            Capsule().fill(Color.green.opacity(0.85)).frame(width: s * 0.025, height: s * 0.12).offset(y: -s * 0.31)
            Ellipse().fill(Color.green).frame(width: s * 0.14, height: s * 0.07)
                .rotationEffect(.degrees(-20)).offset(x: s * 0.06, y: -s * 0.38)
            // Ears, behind the body
            Triangle().fill(cream).frame(width: s * 0.17, height: s * 0.2)
                .rotationEffect(.degrees(-18)).offset(x: -s * 0.2, y: -s * 0.2)
            Triangle().fill(cream).frame(width: s * 0.17, height: s * 0.2)
                .rotationEffect(.degrees(18)).offset(x: s * 0.2, y: -s * 0.2)
            Circle().fill(cream).frame(width: s * 0.62, height: s * 0.62).offset(y: s * 0.06)
            eyes(s)
            Ellipse().fill(Color.pink.opacity(0.35)).frame(width: s * 0.08, height: s * 0.045).offset(x: -s * 0.17, y: s * 0.12)
            Ellipse().fill(Color.pink.opacity(0.35)).frame(width: s * 0.08, height: s * 0.045).offset(x: s * 0.17, y: s * 0.12)
            mouth(s)
            extra(s)
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder
    private func eyes(_ s: CGFloat) -> some View {
        switch mood {
        case .concerned:
            HStack(spacing: s * 0.14) {
                Capsule().fill(ink).frame(width: s * 0.07, height: s * 0.018)
                Capsule().fill(ink).frame(width: s * 0.07, height: s * 0.018)
            }
            .offset(y: s * 0.04)
        default:
            HStack(spacing: s * 0.13) {
                eye(s)
                eye(s)
            }
            .offset(y: mood == .waiting ? 0 : s * 0.02)
        }
    }

    private func eye(_ s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Ellipse().fill(ink).frame(width: s * 0.065, height: s * 0.085)
            Circle().fill(Color.white).frame(width: s * 0.022, height: s * 0.022)
                .offset(x: s * 0.012, y: s * 0.012)
        }
    }

    @ViewBuilder
    private func mouth(_ s: CGFloat) -> some View {
        let line = StrokeStyle(lineWidth: s * 0.018, lineCap: .round)
        switch mood {
        case .thriving:
            Smile(curve: 1).stroke(ink, style: line).frame(width: s * 0.14, height: s * 0.06).offset(y: s * 0.15)
        case .happy:
            Smile(curve: 0.7).stroke(ink, style: line).frame(width: s * 0.11, height: s * 0.05).offset(y: s * 0.15)
        case .okay:
            Capsule().fill(ink).frame(width: s * 0.08, height: s * 0.016).offset(y: s * 0.16)
        case .concerned:
            Smile(curve: -0.5).stroke(ink, style: line).frame(width: s * 0.08, height: s * 0.04).offset(y: s * 0.16)
        case .waiting:
            Circle().stroke(ink, lineWidth: s * 0.014).frame(width: s * 0.04, height: s * 0.04).offset(y: s * 0.16)
        }
    }

    @ViewBuilder
    private func extra(_ s: CGFloat) -> some View {
        switch mood {
        case .thriving:
            Image(systemName: "sparkles").font(.system(size: s * 0.12)).foregroundStyle(.yellow)
                .offset(x: s * 0.33, y: -s * 0.28)
        case .concerned:
            Image(systemName: "moon.zzz.fill").font(.system(size: s * 0.11)).foregroundStyle(.indigo)
                .offset(x: s * 0.33, y: -s * 0.28)
        case .waiting:
            Image(systemName: "questionmark.bubble.fill").font(.system(size: s * 0.12)).foregroundStyle(.gray)
                .offset(x: s * 0.33, y: -s * 0.28)
        case .happy, .okay:
            EmptyView()
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A curved mouth: positive `curve` smiles, negative frowns.
struct Smile: Shape {
    var curve: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = curve >= 0 ? rect.minY : rect.maxY
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y),
            control: CGPoint(x: rect.midX, y: y + curve * rect.height * 2)
        )
        return path
    }
}
