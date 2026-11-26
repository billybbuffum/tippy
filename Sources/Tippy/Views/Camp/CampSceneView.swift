import SwiftUI
import TippyRewards

/// The pond camp: the background, her placed decorations, the pet at its
/// spot and the nest at its spot, drawn back to front. In decorate mode every
/// spot shows a tappable outline (only spots that fit `placingKind` while an
/// item waits for a spot). The pet and the nest come from the caller, so the
/// Wander decides what they are.
struct CampSceneView<Pet: View, Nest: View>: View {
    let isDusk: Bool
    let decorating: Bool
    let placingKind: SlotKind?
    let onTapSlot: (CampSlot) -> Void
    var scale: CampLayout.Scale = .framed
    @ViewBuilder let pet: () -> Pet
    @ViewBuilder let nest: () -> Nest

    @Environment(RewardsModel.self) private var rewards
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                background(width)
                ForEach(CampLayout.slotsBehindPet) { slot in decoration(in: slot, width) }
                nest()
                    .frame(width: scale.nest * width, height: scale.nest * width)
                    .position(x: CampLayout.nest.x * width, y: CampLayout.nest.y * width)
                pet()
                    .frame(width: scale.pet * width, height: scale.pet * width)
                    .position(x: CampLayout.pet.x * width, y: CampLayout.pet.y * width)
                ForEach(CampLayout.slotsInFrontOfPet) { slot in decoration(in: slot, width) }
                if decorating {
                    ForEach(CampCatalog.slots) { slot in target(for: slot, width) }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: scale == .framed ? 24 : 0))
    }

    @ViewBuilder
    private func background(_ width: CGFloat) -> some View {
        let path = isDusk && SpriteLibrary.image("Camp/pond-background-dusk") != nil ? "Camp/pond-background-dusk" : "Camp/pond-background"
        if SpriteLibrary.image(path) != nil {
            SpriteImage(path: path)
                .frame(width: width, height: width)
                .accessibilityHidden(true)
        } else {
            ZStack {
                Rectangle().fill(Color.green.opacity(0.35))
                Ellipse()
                    .fill(Color.teal.opacity(0.6))
                    .frame(width: CampLayout.pondSize.width * width, height: CampLayout.pondSize.height * width)
                    .position(x: CampLayout.pondCenter.x * width, y: CampLayout.pondCenter.y * width)
            }
            .frame(width: width, height: width)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func decoration(in slot: CampSlot, _ width: CGFloat) -> some View {
        if let item = rewards.item(in: slot.id) {
            let point = CampLayout.point(for: slot.id)
            let size = scale.size(for: item.id) * width
            DecorationSprite(item: item, animates: MotionAllowed(reduceMotion: reduceMotion).value)
                .frame(width: size, height: size)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.name)
                .accessibilityIdentifier("camp-item-\(item.id)")
                .position(x: point.x * width, y: point.y * width)
        }
    }

    private func target(for slot: CampSlot, _ width: CGFloat) -> some View {
        let point = CampLayout.point(for: slot.id)
        let size = scale.slotTarget * width
        let fits = placingKind == nil || placingKind == slot.kind
        let occupant = rewards.item(in: slot.id)
        return Button {
            onTapSlot(slot)
        } label: {
            Circle()
                .fill(Color.white.opacity(fits ? 0.22 : 0.05))
                .overlay(Circle().strokeBorder(Color.white.opacity(fits ? 0.95 : 0.3), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!fits)
        .accessibilityLabel("\(CampLayout.label(for: slot)), \(occupant?.name ?? "empty")")
        .accessibilityIdentifier("camp-slot-\(slot.id)")
        .position(x: point.x * width, y: point.y * width)
    }
}
