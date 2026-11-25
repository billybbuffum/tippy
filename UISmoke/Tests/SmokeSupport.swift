import XCTest

/// Base class of every UI smoke scenario (see "UI smoke test" in README.md).
/// A scenario is one `test…` method on a subclass: it calls `launch(seed:)`
/// once, taps its way through one feature, and names each screen with
/// `screen(_:_:)`. The method name is the scenario's name in kebab case
/// (`testLogDrink` is `log-drink`); the clip, the GIF, the screenshots and
/// the row in the PR comment all carry it.
///
/// The app runs in `-ui-smoke` demo mode with the seed the scenario asks
/// for (Sources/Tippy/UISmokeMode.swift).
///
/// scripts/ui-smoke.sh records one video per scenario. The handshake is a
/// few files under `UI_SMOKE_SIGNALS_DIR`: the scenario writes
/// `<name>.start` before launching the app, waits for the script's
/// `<name>.recording`, and writes `<name>.done` (a JSON result) when it
/// ends. Without the variable (running from Xcode) none of that happens.
class SmokeScenario: XCTestCase {
    /// The seed presets demo mode offers; the names match `UISmokeMode.Seed`.
    enum Seed: String {
        /// Set up already (pet "Sprout", goal 14), nothing logged. Today is
        /// Thursday 19 November 2026 in every seed.
        case `default`
        /// First launch: onboarding.
        case onboarding
        /// 3 beers Monday, 3 Tuesday, Wednesday drink-free with a reflection,
        /// today not logged; the reminder not offered yet.
        case midWeek = "mid-week"
        /// One beer logged today, nothing else; the reminder already offered.
        case oneDrink = "one-drink"
        /// Last week (Nov 9–15) logged on 6 of 7 days, 10 drinks against 14, one
        /// reflection; its check-in coins (33) already earned, the goal bonus not
        /// yet; its recap not seen. This week empty.
        case lastWeekDone = "last-week-done"
        /// `default` plus 120 coins.
        case coins
    }

    var app: XCUIApplication!
    private(set) var scenarioName = ""
    private(set) var seed: Seed = .default
    private var shotsDir: URL?
    private var signalsDir: URL?
    private var shotNumber = 0
    private var launchedAt: Date?
    private var firstFailure: String?
    /// Pause between steps so the video is watchable.
    let beat: TimeInterval = 0.7

    // MARK: Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        scenarioName = Self.scenarioName(ofTest: name)
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["UI_SMOKE_SHOTS_DIR"], !path.isEmpty {
            let url = URL(fileURLWithPath: path).appendingPathComponent(scenarioName, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            shotsDir = url
        }
        if let path = environment["UI_SMOKE_SIGNALS_DIR"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            signalsDir = url
        }
        app = XCUIApplication()
        // A system permission alert would otherwise stall every tap.
        addUIInterruptionMonitor(withDescription: "System alert") { alert in
            for label in ["Allow", "OK", "Don't Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        let failed = (testRun?.totalFailureCount ?? 0) > 0 || firstFailure != nil
        if failed { snapshot("FAILED-final") }
        let duration = launchedAt.map { Date().timeIntervalSince($0) } ?? 0
        var result: [String: Any] = [
            "scenario": scenarioName,
            "seed": seed.rawValue,
            "status": failed ? "failed" : "passed",
            "duration": (duration * 10).rounded() / 10,
            "screenshots": shotNumber,
        ]
        if let firstFailure { result["failure"] = firstFailure }
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) {
            signal("done", data)
        }
    }

    override func record(_ issue: XCTIssue) {
        if firstFailure == nil {
            var text = issue.compactDescription
            if text.hasPrefix("failed - ") { text.removeFirst("failed - ".count) }
            firstFailure = text
        }
        super.record(issue)
    }

    /// Launches the app in demo mode with `seed`. Every scenario starts
    /// here; the recording starts just before.
    func launch(seed: Seed = .default) {
        self.seed = seed
        // The previous scenario's app goes before the recording starts, so
        // the clip opens on the home screen and then this launch.
        app.terminate()
        signal("start", Data(seed.rawValue.utf8))
        waitForRecording()
        launchedAt = Date()
        app.launchArguments = ["-ui-smoke", "-ui-smoke-seed", seed.rawValue]
        app.launch()
    }

    // MARK: Screens

    /// Any element with this accessibility identifier.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Waits for `marker` (the element that proves the screen is up), then
    /// takes the screenshot. Fails the scenario, naming the screen, otherwise.
    func screen(
        _ name: String,
        _ marker: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard marker.waitForExistence(timeout: timeout) else {
            snapshot("FAILED-\(name)")
            if app.state != .runningForeground {
                XCTFail("The app is no longer running (state \(app.state.rawValue)) before the \(name) screen; it probably crashed", file: file, line: line)
            } else {
                XCTFail("The \(name) screen never appeared: waited \(Int(timeout))s for \(marker)", file: file, line: line)
            }
            return
        }
        // Let the transition finish so the screenshot is not mid-animation.
        Thread.sleep(forTimeInterval: 0.4)
        snapshot(name)
    }

    /// A numbered screenshot of the whole screen, attached to the test and
    /// saved under the scenario's directory.
    func snapshot(_ name: String) {
        shotNumber += 1
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let shotsDir else { return }
        let file = shotsDir.appendingPathComponent(String(format: "%02d-%@.png", shotNumber, name))
        do { try shot.pngRepresentation.write(to: file) } catch { NSLog("ui-smoke: could not save \(file.path): \(error)") }
    }

    // MARK: Gestures

    /// Taps a list row near its leading text, where a finger would land,
    /// rather than at its centre, which can fall on empty space.
    func tapRow(_ identifier: String) {
        element(identifier).coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
    }

    func enter(_ text: String, into field: XCUIElement) {
        field.tap()
        field.typeText(text)
    }

    /// The back button of the navigation bar titled `title`.
    func goBack(from title: String) {
        app.navigationBars[title].buttons.element(boundBy: 0).tap()
    }

    /// Scrolls until `element` can be tapped (a Form row below the fold).
    func reveal(_ element: XCUIElement) {
        var attempts = 0
        while !element.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
    }

    /// Taps a button in a confirmation dialog. SwiftUI doesn't always carry
    /// accessibility identifiers onto the system action sheet's buttons, so
    /// this falls back to the button's title there, and only there.
    func tapDialogButton(_ identifier: String, title: String) {
        let byIdentifier = element(identifier)
        if byIdentifier.waitForExistence(timeout: 3) {
            byIdentifier.tap()
        } else {
            app.buttons[title].firstMatch.tap()
        }
    }

    func pause() {
        Thread.sleep(forTimeInterval: beat)
    }

    // MARK: Layout

    /// `row` is on screen below `header`: in that list section, when the
    /// header is the last one above it.
    func isBelow(_ row: XCUIElement, _ header: XCUIElement) -> Bool {
        row.frame.minY > header.frame.minY
    }

    /// `row` is on screen between the two section headers: in the first
    /// one's section.
    func isBetween(_ row: XCUIElement, _ above: XCUIElement, _ below: XCUIElement) -> Bool {
        isBelow(row, above) && row.frame.minY < below.frame.minY
    }

    // MARK: Naming

    /// `-[HomeScenarios testLogDrink]` is the scenario `log-drink`. The
    /// same rule lives in scripts/smoke-scenarios.py.
    static func scenarioName(ofTest testName: String) -> String {
        var method = testName
        if let space = method.lastIndex(of: " ") { method = String(method[method.index(after: space)...]) }
        method = method.replacingOccurrences(of: "]", with: "").replacingOccurrences(of: "()", with: "")
        if method.hasPrefix("test") { method.removeFirst(4) }
        var kebab = ""
        for (index, character) in method.enumerated() {
            if character.isUppercase && index > 0 { kebab.append("-") }
            kebab.append(contentsOf: character.lowercased())
        }
        return kebab.isEmpty ? "scenario" : kebab
    }

    // MARK: Recording handshake

    private func signal(_ kind: String, _ data: Data) {
        guard let signalsDir else { return }
        let file = signalsDir.appendingPathComponent("\(scenarioName).\(kind)")
        do { try data.write(to: file, options: .atomic) } catch { NSLog("ui-smoke: could not write \(file.path): \(error)") }
    }

    /// Gives the script a few seconds to start the recorder; a scenario
    /// never fails over it.
    private func waitForRecording() {
        guard let signalsDir else { return }
        let ack = signalsDir.appendingPathComponent("\(scenarioName).recording").path
        let deadline = Date().addingTimeInterval(8)
        while !FileManager.default.fileExists(atPath: ack) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if !FileManager.default.fileExists(atPath: ack) {
            NSLog("ui-smoke: no recorder acknowledged \(scenarioName); launching anyway")
        }
    }
}
