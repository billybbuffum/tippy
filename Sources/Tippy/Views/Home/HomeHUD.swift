import SwiftUI
import TippyModeration
import TippyWander

/// Home's heads-up display, over the sky (spec 06): the pet's nameplate and
/// mood, the coin badge and the History and Settings buttons, then the week
/// meter. Numbers stay neutral; the pet's bubble carries the feelings.
struct HomeHUD: View {
    let openShop: () -> Void
    let openSettings: () -> Void

    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
    @Environment(WanderModel.self) private var wander

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(alignment: .leading, spacing: 3 * u) {
            HStack(alignment: .top, spacing: 3 * u) {
                nameplate
                Spacer(minLength: 0)
                CoinBadge(balance: rewards.balance, openShop: openShop)
                NavigationLink {
                    HistoryView()
                } label: {
                    PixelIcon.calendar
                }
                .buttonStyle(.pixel(.parchment, fill: false))
                .accessibilityLabel("History")
                .accessibilityIdentifier("history-button")
                Button(action: openSettings) {
                    PixelIcon.gear
                }
                .buttonStyle(.pixel(.parchment, fill: false))
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("settings-button")
            }
            WeekMeter(summary: model.summary)
        }
    }

    private var nameplate: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name)
                .pixelFont(.body, 13)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("pet-name-label")
            Text(moodWord)
                .pixelFont(.labelBold, 8)
                .foregroundStyle(PixelPalette.tealDark)
                .accessibilityLabel(caption)
                .accessibilityIdentifier("pet-mood-label")
        }
        .foregroundStyle(PixelPalette.plum)
        .pixelPanel(.parchment)
        .accessibilityElement(children: .contain)
    }

    /// The pet's name: the active pet's, or (before it hatches) the one she
    /// chose in onboarding.
    private var name: String { wander.shownPet?.name ?? model.settings.petName }

    private var moodWord: String {
        if wander.shownPet != nil { return model.mood.rawValue.uppercased() }
        return wander.hatchingPet != nil ? "HATCHING" : "IN THE EGG"
    }

    private var caption: String {
        if wander.shownPet != nil { return model.mood.caption(petName: name) }
        if wander.hatchingPet != nil { return "\(name) is hatching!" }
        return "\(name) is snug in the egg. Check in to help it hatch."
    }
}

/// This week on one panel: a pixel bar of the goal used and `6/14`, with
/// the drink-free days and days logged under it. VoiceOver hears the full
/// sentences ("6.0 of 14 drinks this week").
struct WeekMeter: View {
    let summary: WeekSummary

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(alignment: .leading, spacing: 2 * u) {
            HStack(spacing: 3 * u) {
                Text("THIS WEEK")
                    .pixelFont(.labelBold, 8)
                    .accessibilityHidden(true)
                PixelMeterBar(progress: summary.progress, over: summary.standardDrinks > summary.weeklyGoal)
                    .frame(width: 42 * u, height: 6 * u)
                    .accessibilityHidden(true)
                Text("\(summary.standardDrinks.drinksText)/\(Int(summary.weeklyGoal))")
                    .pixelFont(.body, 11)
                    .accessibilityLabel(String(format: "%.1f of %.0f drinks this week", summary.standardDrinks, summary.weeklyGoal))
                    .accessibilityIdentifier("week-total-label")
            }
            HStack(spacing: 4 * u) {
                Text("\(summary.drinkFreeDays) drink-free \(summary.drinkFreeDays == 1 ? "day" : "days")")
                    .accessibilityIdentifier("drink-free-count-label")
                Text("\(summary.checkedInDays) of \(summary.daysElapsed) days logged")
                    .accessibilityIdentifier("days-logged-label")
            }
            .pixelFont(.body, 9)
            .foregroundStyle(PixelPalette.plum.opacity(0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(PixelPalette.plum)
        .pixelPanel(.parchment)
        .accessibilityElement(children: .contain)
    }
}

/// A segmented pixel bar: ten cells, filled in teal (gold once over the goal).
private struct PixelMeterBar: View {
    let progress: Double
    let over: Bool

    var body: some View {
        Canvas { context, size in
            let u = PixelGrid.uiPoint
            let cells = 10
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(PixelPalette.plum))
            let inner = CGRect(x: u, y: u, width: size.width - 2 * u, height: size.height - 2 * u)
            context.fill(Path(inner), with: .color(PixelPalette.parchmentShade))
            let filled = over ? cells : Int((min(max(progress, 0), 1) * Double(cells)).rounded(.up))
            let cellWidth = ((inner.width - CGFloat(cells - 1) * u) / CGFloat(cells) / u).rounded(.down) * u
            for index in 0..<filled {
                let x = inner.minX + CGFloat(index) * (cellWidth + u)
                context.fill(Path(CGRect(x: x, y: inner.minY, width: cellWidth, height: inner.height)),
                             with: .color(over ? PixelPalette.gold : PixelPalette.teal))
                context.fill(Path(CGRect(x: x, y: inner.minY, width: cellWidth, height: u)),
                             with: .color(over ? PixelPalette.parchmentLight : PixelPalette.tealLight))
            }
        }
    }
}
