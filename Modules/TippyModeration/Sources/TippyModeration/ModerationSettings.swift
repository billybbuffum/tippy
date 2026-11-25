import Foundation

/// The user's choices. Every field has a default, and a saved journal that
/// lacks a field (written by an older Tippy) decodes to that default. The
/// weekly goal is not here: it is kept per week in the journal.
public struct ModerationSettings: Hashable, Codable, Sendable {
    public static let defaultPetName = "Sprout"

    public var petName: String = ModerationSettings.defaultPetName
    /// Standard drinks in a typical week before Tippy.
    public var baselinePerWeek: Double = 14
    /// What one drink typically costs, in the user's currency; nil when she
    /// chose not to say.
    public var costPerDrink: Double?
    /// 1 Sunday ... 7 Saturday; 2 is Monday.
    public var firstWeekday: Int = 2
    public var reminderEnabled: Bool = false
    public var reminderHour: Int = 20
    public var reminderMinute: Int = 0
    /// The reminder is offered once, after the first check-in.
    public var reminderOffered: Bool = false
    public var hasOnboarded: Bool = false

    public init() {}

    enum CodingKeys: String, CodingKey {
        case petName, baselinePerWeek, costPerDrink, firstWeekday
        case reminderEnabled, reminderHour, reminderMinute, reminderOffered, hasOnboarded
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ModerationSettings()
        petName = try c.decodeIfPresent(String.self, forKey: .petName) ?? defaults.petName
        baselinePerWeek = try c.decodeIfPresent(Double.self, forKey: .baselinePerWeek) ?? defaults.baselinePerWeek
        costPerDrink = try c.decodeIfPresent(Double.self, forKey: .costPerDrink)
        firstWeekday = try c.decodeIfPresent(Int.self, forKey: .firstWeekday) ?? defaults.firstWeekday
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? defaults.reminderEnabled
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? defaults.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? defaults.reminderMinute
        reminderOffered = try c.decodeIfPresent(Bool.self, forKey: .reminderOffered) ?? defaults.reminderOffered
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? defaults.hasOnboarded
    }
}
