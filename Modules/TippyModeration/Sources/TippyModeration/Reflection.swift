import Foundation

/// Her answer to the day's optional prompt.
public struct Reflection: Hashable, Codable, Sendable {
    public let day: LocalDate
    public let promptID: String
    public let answer: String
    public let answeredAt: Date

    public init(day: LocalDate, promptID: String, answer: String, answeredAt: Date) {
        self.day = day
        self.promptID = promptID
        self.answer = answer
        self.answeredAt = answeredAt
    }
}

/// One reflection prompt. IDs are stable: saved reflections refer to them.
public struct ReflectionPrompt: Identifiable, Hashable, Sendable {
    public let id: String
    public let text: String
}

/// The bundled prompt sets: one for days with drinks, one for drink-free
/// days. The day picks the prompt, so it varies from day to day but is the
/// same every time that day is opened.
public enum ReflectionPrompts {
    public static let afterDrinks: [ReflectionPrompt] = [
        ReflectionPrompt(id: "enjoyed-most", text: "Which drink did you enjoy most?"),
        ReflectionPrompt(id: "wanted-in-moment", text: "What did you want in that moment?"),
        ReflectionPrompt(id: "could-skip", text: "Was there a drink you could have skipped?"),
        ReflectionPrompt(id: "who-with", text: "Who were you with, and how did it feel?"),
        ReflectionPrompt(id: "feel-now", text: "How do you feel about today's drinks now?"),
    ]

    public static let afterDrinkFree: [ReflectionPrompt] = [
        ReflectionPrompt(id: "what-helped", text: "What helped today?"),
        ReflectionPrompt(id: "noticed-evening", text: "What did you notice about the evening?"),
        ReflectionPrompt(id: "did-instead", text: "What did you do instead?"),
        ReflectionPrompt(id: "proud-of", text: "What are you proud of today?"),
    ]

    public static func prompt(for day: LocalDate, hadDrinks: Bool) -> ReflectionPrompt {
        let prompts = hadDrinks ? afterDrinks : afterDrinkFree
        let ordinal = epoch.days(until: day)
        return prompts[((ordinal % prompts.count) + prompts.count) % prompts.count]
    }

    public static func prompt(id: String) -> ReflectionPrompt? {
        (afterDrinks + afterDrinkFree).first { $0.id == id }
    }

    private static let epoch = LocalDate(year: 2000, month: 1, day: 1)!
}
