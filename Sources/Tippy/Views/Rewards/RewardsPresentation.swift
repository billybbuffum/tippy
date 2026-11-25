import SwiftUI
import TippyModeration

/// What Rewards shows on Home, kept out of `HomeView` so its edits stay small:
/// - the weekly recap sheet, presented when a recap is due and no other sheet is up;
/// - the "+N coins" toast at the top, once Home is in front with no sheet over it,
///   so it isn't missed behind the reflection sheet or a pushed History.
///
/// Dismissing the recap any way marks it seen, so a week's recap shows exactly once.
struct RewardsPresentation: ViewModifier {
    /// Whether Home has one of its own sheets up.
    let otherSheetShowing: Bool

    @Environment(RewardsModel.self) private var rewards
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recap: WeekItem?
    /// Retained after SwiftUI clears the sheet binding, until onDismiss runs.
    @State private var presentedRecapWeek: Week?
    @State private var toast: EarnedToast?
    @State private var isInFront = false

    /// How long the toast stays: about 2 s, a little longer in demo mode so the
    /// UI smoke recording catches it.
    private var toastSeconds: Double { UISmokeMode.isActive ? 4 : 2 }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    CoinsEarnedToast(coins: toast.coins)
                        .padding(.top, 8)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(item: $recap, onDismiss: recapDismissed) { item in
                WeeklyRecapView(week: item.week)
            }
            .onAppear {
                isInFront = true
                update(inFront: true)
            }
            .onDisappear { isInFront = false }
            .onChange(of: rewards.pendingRecap) { update() }
            .onChange(of: rewards.lastEarned) { update() }
            .onChange(of: otherSheetShowing) { update() }
            .task(id: toast?.id) {
                guard toast != nil else { return }
                try? await Task.sleep(for: .seconds(toastSeconds))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? Animation.easeOut(duration: 0.3) : Animation.spring(duration: 0.4)) { toast = nil }
                update()
            }
    }

    /// Presents what is due, recap first, when Home is in front and nothing covers it.
    private func update(inFront: Bool? = nil) {
        guard inFront ?? isInFront, !otherSheetShowing, recap == nil, presentedRecapWeek == nil else { return }
        if let week = rewards.pendingRecap {
            presentedRecapWeek = week
            recap = WeekItem(week: week)
            return
        }
        guard toast == nil, let coins = rewards.lastEarned else { return }
        rewards.acknowledgeEarned()
        withAnimation(reduceMotion ? Animation.easeIn(duration: 0.3) : Animation.spring(duration: 0.4)) {
            toast = EarnedToast(coins: coins)
        }
        let announcement: String = "You earned \(coins.coinsText)"
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func recapDismissed() {
        // Only consume the week actually shown. A refresh while the sheet was
        // open may have made a different week pending. Done already saved its idea.
        if let week = presentedRecapWeek, !rewards.hasSeenRecap(for: week) {
            rewards.markRecapSeen(week, nextWeekIdea: nil)
        }
        presentedRecapWeek = nil
        update()
    }
}

/// One showing of the toast.
private struct EarnedToast: Equatable {
    let id = UUID()
    let coins: Int
}
