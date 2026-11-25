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
        NavigationStack {
            List {
                if let current {
                    Section("Here now") {
                        Label {
                            Text(current.name)
                        } icon: {
                            DecorationSprite(item: current).frame(width: 36, height: 36)
                        }
                        Button("Move to another spot") {
                            move(current.id)
                            dismiss()
                        }
                        .accessibilityIdentifier("move-item-button")
                        Button("Put away") {
                            rewards.store(slotID: slot.id)
                            dismiss()
                        }
                        .accessibilityIdentifier("store-item-button")
                    }
                }
                Section(current == nil ? "Place here" : "Swap with") {
                    if options.isEmpty {
                        Text("Nothing in storage fits this spot yet.")
                            .foregroundStyle(.secondary)
                        Button("Visit the shop") {
                            wantsShop()
                            dismiss()
                        }
                        .accessibilityIdentifier("slot-shop-button")
                    }
                    ForEach(options) { item in
                        Button {
                            if rewards.place(item.id, in: slot.id) { dismiss() }
                        } label: {
                            Label {
                                Text(item.name)
                            } icon: {
                                DecorationSprite(item: item).frame(width: 36, height: 36)
                            }
                        }
                        .accessibilityIdentifier("place-\(item.id)-button")
                    }
                }
            }
            .navigationTitle(CampLayout.label(for: slot))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("slot-close-button")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
