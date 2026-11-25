import SwiftUI

@main
struct TippyApp: App {
    @State private var week = WeekModel(seed: UISmokeMode.isActive ? UISmokeMode.seed : nil)

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(week)
    }
}
