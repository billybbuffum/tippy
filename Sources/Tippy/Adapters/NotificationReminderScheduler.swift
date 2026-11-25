import Foundation
import UserNotifications
import TippyModeration

/// Local notifications: one non-repeating notification per upcoming day
/// that is not logged yet, so a logged day gets no reminder. Rescheduled
/// on every change and every time the app comes to the front.
final class NotificationReminderScheduler: ReminderScheduling {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "tippy.reminder."

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func schedule(days: [LocalDate], hour: Int, minute: Int, petName: String, calendar: Calendar) {
        center.removeAllPendingNotificationRequests()
        for day in days {
            var parts = DateComponents()
            parts.calendar = calendar
            parts.timeZone = calendar.timeZone
            parts.year = day.year
            parts.month = day.month
            parts.day = day.day
            parts.hour = hour
            parts.minute = minute
            let content = UNMutableNotificationContent()
            content.title = "\(petName) is wondering how today went"
            content.body = "Log today's drinks, or mark it a drink-free day."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: prefix + day.description, content: content, trigger: trigger), withCompletionHandler: nil)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
