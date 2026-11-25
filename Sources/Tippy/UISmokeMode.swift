import Foundation

/// Demo mode for the simulator UI smoke scenarios (`.github/workflows/ui-smoke.yml`,
/// `UISmoke/`), as in ChoreLock. Launched with `-ui-smoke` on the simulator,
/// the app starts from a known state picked by `-ui-smoke-seed <name>` (or
/// the `UI_SMOKE_SEED` environment variable); see `Seed`. Without
/// `-ui-smoke` `isActive` is false and nothing here runs; on a device it is
/// compiled to a constant false, so the production paths are untouched.
enum UISmokeMode {
    static let launchArgument = "-ui-smoke"
    static let seedArgument = "-ui-smoke-seed"

    #if targetEnvironment(simulator)
    static let isActive = ProcessInfo.processInfo.arguments.contains(launchArgument)
    #else
    static let isActive = false
    #endif

    /// The named starting states a scenario can ask for. The names match
    /// `SmokeScenario.Seed` in UISmoke/Tests/SmokeSupport.swift.
    enum Seed: String, CaseIterable {
        /// A fresh week: nothing logged, goal of 14.
        case `default`
        /// Day 4 of the week, 6 drinks logged, checked in today.
        case midWeek = "mid-week"
    }

    /// The seed this launch asked for; `default` when none was named. An
    /// unknown name is logged and treated as `default`.
    static let seed: Seed = {
        let process = ProcessInfo.processInfo
        var name: String?
        if let index = process.arguments.firstIndex(of: seedArgument), index + 1 < process.arguments.endIndex {
            name = process.arguments[index + 1]
        }
        name = name ?? process.environment["UI_SMOKE_SEED"]
        guard let name, !name.isEmpty else { return .default }
        guard let seed = Seed(rawValue: name) else {
            NSLog("Tippy: unknown ui-smoke seed '\(name)'; known: \(Seed.allCases.map(\.rawValue)); using default")
            return .default
        }
        return seed
    }()
}
