import SwiftUI

/// The coin: shimmering, or the still coin under Reduce Motion and in demo mode,
/// or a drawn stand-in if the sprite is missing. Decorative: the text beside it
/// says how many.
struct CoinIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if MotionAllowed(reduceMotion: reduceMotion).value, !SpriteLibrary.frames(of: .coinShimmer).isEmpty {
                AnimatedSprite(animation: .coinShimmer)
            } else if SpriteLibrary.image("Rewards/coin") != nil {
                SpriteImage(path: "Rewards/coin")
            } else {
                Image(systemName: "circle.circle.fill")
                    .resizable()
                    .foregroundStyle(.yellow)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
