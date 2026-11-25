import SwiftUI

/// The coin balance in Home's toolbar. VoiceOver reads it as "120 coins".
/// Tapping it does nothing yet: spec 02 opens the shop from here.
///
/// It's a container rather than a `Button`, so that both identifiers reach the
/// UI tests: a button merges its label into one element and drops the inner
/// `coin-balance-label`.
struct CoinBadge: View {
    let balance: Int

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coin-badge-button")
    }
}
