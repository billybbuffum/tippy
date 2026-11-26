import SwiftUI

/// The coin balance on Home's HUD, as a pixel panel. VoiceOver reads it as "120 coins".
/// Tapping it opens the shop.
///
/// It's a container rather than a `Button`, so that both identifiers reach the
/// UI tests: a button merges its label into one element and drops the inner
/// `coin-balance-label`.
struct CoinBadge: View {
    let balance: Int
    var openShop: () -> Void = {}

    var body: some View {
        HStack(spacing: 3 * PixelGrid.uiPoint) {
            PixelIcon.coin
            Text("\(balance)")
                .pixelFont(.body, 12)
                .foregroundStyle(PixelPalette.plum)
                .accessibilityLabel(balance.coinsText)
                .accessibilityIdentifier("coin-balance-label")
        }
        .pixelPanel(.parchment)
        .contentShape(Rectangle())
        .onTapGesture(perform: openShop)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the shop")
        .accessibilityAction(named: "Open the shop", openShop)
        .accessibilityIdentifier("coin-badge-button")
    }
}
