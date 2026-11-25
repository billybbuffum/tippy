import SwiftUI

/// "+8 coins", shown briefly at the top of Home after a check-in earns coins.
/// No sound, no haptic; VoiceOver announces it (see `RewardsPresentation`).
struct CoinsEarnedToast: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 8) {
            CoinIcon()
                .frame(width: 26, height: 26)
            Text("+\(coins.coinsText)")
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coins-earned-toast")
    }
}
