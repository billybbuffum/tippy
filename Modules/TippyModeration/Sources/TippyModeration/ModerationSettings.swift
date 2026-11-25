import Foundation

/// The user's choices. Every field has a default, and a saved journal that
/// lacks a field (written by an older Tippy) decodes to that default.
public struct ModerationSettings: Hashable, Codable, Sendable {
    public static let defaultPetName = "Sprout"

    public var petName: String = ModerationSettings.defaultPetName
    /// Standard drinks allowed per week.
    public var weeklyGoal: Double = 14
    /// Standard drinks in a typical week before Tippy, for the savings figure.
    public var baselinePerWeek: Double = 18
    /// What one drink typically costs, in the user's currency.
    public var costPerDrink: Double = 8
    /// 1 Sunday ... 7 Saturday; 2 is Monday.
    public var firstWeekday: Int = 2
    public var reminderEnabled: Bool = false
    public var reminderHour: Int = 20
    public var reminderMinute: Int = 0
    public var hasOnboarded: Bool = false

    public init() {}

    enum CodingKeys: String, CodingKey {
        case petName, weeklyGoal, baselinePerWeek, costPerDrink, firstWeekday
        case reminderEnabled, reminderHour, reminderMinute, hasOnboarded
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ModerationSettings()
        petName = try c.decodeIfPresent(String.self, forKey: .petName) ?? defaults.petName
        weeklyGoal = try c.decodeIfPresent(Double.self, forKey: .weeklyGoal) ?? defaults.weeklyGoal
        baselinePerWeek = try c.decodeIfPresent(Double.self, forKey: .baselinePerWeek) ?? defaults.baselinePerWeek
        costPerDrink = try c.decodeIfPresent(Double.self, forKey: .costPerDrink) ?? defaults.costPerDrink
        firstWeekday = try c.decodeIfPresent(Int.self, forKey: .firstWeekday) ?? defaults.firstWeekday
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? defaults.reminderEnabled
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? defaults.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? defaults.reminderMinute
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? defaults.hasOnboarded
    }
}
