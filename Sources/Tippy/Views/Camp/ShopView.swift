import SwiftUI
import TippyRewards

/// The shop: every decoration for sale, cheapest first, with what she can
/// afford. Buying asks once, then offers to place the new item right away.
struct ShopView: View {
    /// Called with an item's ID when she chooses "Place it now".
    let placeNow: (String) -> Void

    @Environment(RewardsModel.self) private var rewards
    @Environment(\.dismiss) private var dismiss
    @State private var confirming: CatalogItem?
    @State private var justBought: CatalogItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        CoinIcon().frame(width: 24, height: 24)
                        Text(rewards.balance.coinsText)
                            .font(.headline)
                            .monospacedDigit()
                            .accessibilityIdentifier("shop-balance-label")
                    }
                    if let item = justBought {
                        bought(item)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(CampCatalog.shopItems) { item in
                            ShopItemCard(item: item) { confirming = item }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("shop-done-button")
                }
            }
            .alert("Buy this decoration?", isPresented: confirmShown, presenting: confirming) { item in
                Button("Buy it") {
                    if rewards.buy(item.id) {
                        withAnimation(.spring(duration: 0.4)) { justBought = item }
                    }
                }
                .accessibilityIdentifier("confirm-buy-button")
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text("\(item.name) for \(item.price.coinsText).")
            }
        }
    }

    private var confirmShown: Binding<Bool> {
        Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
    }

    /// The little celebration after a purchase, with the shortcut to place it.
    private func bought(_ item: CatalogItem) -> some View {
        HStack(spacing: 12) {
            DecorationSprite(item: item)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("The \(item.name.lowercased()) is yours!")
                    .font(.headline)
                    .accessibilityIdentifier("bought-label")
                Button("Place it now") {
                    placeNow(item.id)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("place-now-button")
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// One item in the shop grid: its sprite, name, price and what she can do.
struct ShopItemCard: View {
    let item: CatalogItem
    let buy: () -> Void
    @Environment(RewardsModel.self) private var rewards

    var body: some View {
        VStack(spacing: 8) {
            DecorationSprite(item: item)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            HStack(spacing: 4) {
                CoinIcon().frame(width: 16, height: 16)
                Text("\(item.price)").monospacedDigit()
            }
            .font(.footnote)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.price.coinsText)
            Button(action: buy) {
                Text(buttonTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(owned || !affordable)
            .accessibilityIdentifier("buy-\(item.id)-button")
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shop-item-\(item.id)")
    }

    private var owned: Bool { rewards.owns(item.id) }
    private var affordable: Bool { rewards.canAfford(item) }

    private var buttonTitle: String {
        if owned { return "Owned" }
        return affordable ? "Buy" : "Not enough coins"
    }
}
