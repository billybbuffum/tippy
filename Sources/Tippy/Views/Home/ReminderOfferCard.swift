import SwiftUI

/// The reminder, offered once after the first check-in, as a parchment notice.
struct ReminderOfferCard: View {
    @Environment(JournalModel.self) private var model

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(alignment: .leading, spacing: 3 * u) {
            HStack(alignment: .top, spacing: 3 * u) {
                PixelIcon.bell
                Text("Want a nudge in the evening if the day isn't logged yet?")
                    .pixelFont(.body, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 3 * u) {
                Button("Remind me at \(model.reminderTimeToday.formatted(date: .omitted, time: .shortened))") {
                    Task { await model.answerReminderOffer(accept: true) }
                }
                .buttonStyle(.pixel(.teal, size: 10))
                .accessibilityIdentifier("reminder-offer-accept-button")
                Button("Not now") {
                    Task { await model.answerReminderOffer(accept: false) }
                }
                .buttonStyle(.pixel(.parchment, size: 10, fill: false))
                .accessibilityIdentifier("reminder-offer-dismiss-button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(PixelPalette.plum)
        .pixelPanel(.parchment)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminder-offer-card")
    }
}
