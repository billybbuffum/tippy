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
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: "Shop", identifier: "shop-sheet") {
            HStack(spacing: 2 * u) {
                PixelIcon.coin
                Text(rewards.balance.coinsText)
                    .pixelFont(.body, 11)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("shop-balance-label")
            }
        } trailing: {
            Button("Done") { dismiss() }
                .buttonStyle(.pixel(.teal, size: 10, fill: false))
                .accessibilityIdentifier("shop-done-button")
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 5 * u) {
                    if let item = justBought {
                        bought(item)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 4 * u)], spacing: 4 * u) {
                        ForEach(CampCatalog.shopItems) { item in
                            ShopItemCard(item: item) { confirming = item }
                        }
                    }
                }
                .padding(.horizontal, 6 * u)
                .padding(.bottom, 8 * u)
            }
            .overlay {
                if let item = confirming {
                    confirm(item)
                }
            }
        }
    }

    /// "Buy this decoration?", asked once on a pixel card over the shop.
    private func confirm(_ item: CatalogItem) -> some View {
        let u = PixelGrid.uiPoint
        return ZStack {
            PixelPalette.plum.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { confirming = nil }
                .accessibilityHidden(true)
            VStack(spacing: 4 * u) {
                DecorationSprite(item: item)
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                Text("Buy this decoration?")
                    .pixelFont(.body, 13)
                    .accessibilityAddTraits(.isHeader)
                Text("\(item.name) for \(item.price.coinsText).")
                    .pixelFont(.body, 10)
                HStack(spacing: 3 * u) {
                    Button("Cancel") { confirming = nil }
                        .buttonStyle(.pixel(.paper, size: 10))
                        .accessibilityIdentifier("cancel-buy-button")
                    Button("Buy it") {
                        confirming = nil
                        if rewards.buy(item.id) {
                            withAnimation(.spring(duration: 0.4)) { justBought = item }
                        }
                    }
                    .buttonStyle(.pixel(.teal, size: 10))
                    .accessibilityIdentifier("confirm-buy-button")
                }
            }
            .foregroundStyle(PixelPalette.plum)
            .frame(maxWidth: 280)
            .pixelPanel(.parchment)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("confirm-buy-dialog")
        }
    }

    /// The little celebration after a purchase, with the shortcut to place it.
    private func bought(_ item: CatalogItem) -> some View {
        let u = PixelGrid.uiPoint
        return HStack(spacing: 4 * u) {
            DecorationSprite(item: item)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3 * u) {
                Text("The \(item.name.lowercased()) is yours!")
                    .pixelFont(.body, 12)
                    .accessibilityIdentifier("bought-label")
                Button("Place it now") {
                    placeNow(item.id)
                    dismiss()
                }
                .buttonStyle(.pixel(.teal, size: 10, fill: false))
                .accessibilityIdentifier("place-now-button")
            }
            Spacer(minLength: 0)
        }
        .pixelPanel(.chosen)
    }
}

/// One item in the shop grid: its sprite, name, price and what she can do.
struct ShopItemCard: View {
    let item: CatalogItem
    let buy: () -> Void
    @Environment(RewardsModel.self) private var rewards

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(spacing: 3 * u) {
            DecorationSprite(item: item)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            Text(item.name)
                .pixelFont(.body, 11)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            HStack(spacing: 2 * u) {
                PixelIcon.coin
                Text("\(item.price)")
                    .pixelFont(.body, 10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.price.coinsText)
            Button(buttonTitle, action: buy)
                .buttonStyle(.pixel(owned ? .paper : .teal, size: 10))
                .disabled(owned || !affordable)
                .accessibilityIdentifier("buy-\(item.id)-button")
        }
        .frame(maxWidth: .infinity)
        .pixelPanel(.paper)
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
