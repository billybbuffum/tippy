import SwiftUI
import TippyRewards

/// One spot in decorate mode: what's there (move it or put it away) and what
/// from storage fits it. Placing into an occupied spot swaps: the previous
/// item goes back to storage. Nothing here costs coins.
struct SlotSheet: View {
    let slot: CampSlot
    /// She chose to move the item here to another spot.
    let move: (String) -> Void
    /// She wants the shop (opened by the caller once this sheet is gone).
    let wantsShop: () -> Void

    @Environment(RewardsModel.self) private var rewards
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let current = rewards.item(in: slot.id)
        let options = rewards.storedItems(fitting: slot.kind)
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: CampLayout.label(for: slot), identifier: "slot-sheet") {
            Button("Close") { dismiss() }
                .buttonStyle(.pixel(.paper, size: 10, fill: false))
                .accessibilityIdentifier("slot-close-button")
        } trailing: {
            EmptyView()
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 6 * u) {
                    if let current {
                        PixelSection(title: "Here now") {
                            itemRow(current)
                            HStack(spacing: 3 * u) {
                                Button("Move it") {
                                    move(current.id)
                                    dismiss()
                                }
                                .buttonStyle(.pixel(.teal, size: 10))
                                .accessibilityLabel("Move to another spot")
                                .accessibilityIdentifier("move-item-button")
                                Button("Put away") {
                                    rewards.store(slotID: slot.id)
                                    dismiss()
                                }
                                .buttonStyle(.pixel(.wood, size: 10))
                                .accessibilityIdentifier("store-item-button")
                            }
                        }
                    }
                    PixelSection(title: current == nil ? "Place here" : "Swap with") {
                        if options.isEmpty {
                            Text("Nothing in storage fits this spot yet.")
                                .pixelFont(.body, 10)
                            Button("Visit the shop") {
                                wantsShop()
                                dismiss()
                            }
                            .buttonStyle(.pixel(.teal, size: 10, fill: false))
                            .accessibilityIdentifier("slot-shop-button")
                        }
                        ForEach(options) { item in
                            Button {
                                if rewards.place(item.id, in: slot.id) { dismiss() }
                            } label: {
                                itemRow(item)
                            }
                            .buttonStyle(.pixel(.parchment, size: 11))
                            .accessibilityLabel(item.name)
                            .accessibilityIdentifier("place-\(item.id)-button")
                        }
                    }
                }
                .padding(.horizontal, 6 * u)
                .padding(.bottom, 8 * u)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func itemRow(_ item: CatalogItem) -> some View {
        HStack(spacing: 3 * PixelGrid.uiPoint) {
            DecorationSprite(item: item)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            Text(item.name)
                .pixelFont(.body, 11)
            Spacer(minLength: 0)
        }
    }
}
