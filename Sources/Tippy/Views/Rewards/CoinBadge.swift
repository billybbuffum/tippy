import SwiftUI

/// The coin balance in Home's toolbar. VoiceOver reads it as "120 coins".
/// Tapping it opens the shop.
///
/// It's a container rather than a `Button`, so that both identifiers reach the
/// UI tests: a button merges its label into one element and drops the inner
/// `coin-balance-label`.
struct CoinBadge: View {
    let balance: Int
    var openShop: () -> Void = {}

    var body: some View {
        HStack(spacing: 4) {
            CoinIcon()
                .frame(width: 22, height: 22)
            Text("\(balance)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityLabel(balance.coinsText)
                .accessibilityIdentifier("coin-balance-label")
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: openShop)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the shop")
        .accessibilityAction(named: "Open the shop", openShop)
        .accessibilityIdentifier("coin-badge-button")
    }
}
