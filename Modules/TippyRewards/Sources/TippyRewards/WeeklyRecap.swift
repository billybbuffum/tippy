import Foundation
import TippyModeration

/// A finished week's recap, once she has seen it, with her optional idea for
/// the week after. There is at most one per week.
public struct WeeklyRecap: Hashable, Codable, Sendable {
    public let weekStart: LocalDate
    public let seenAt: Date
    /// Her optional "one thing to try next week"; never empty (blank is nil).
    public var nextWeekIdea: String?

    public init(weekStart: LocalDate, seenAt: Date, nextWeekIdea: String?) {
        self.weekStart = weekStart
        self.seenAt = seenAt
        self.nextWeekIdea = WeeklyRecap.cleaned(nextWeekIdea)
    }

    /// Trims the idea; a blank one is no idea.
    static func cleaned(_ idea: String?) -> String? {
        guard let text = idea?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
