import XCTest

/// Backups across every context (spec 04). One scenario per method; see SmokeSupport.swift.
final class BackupScenarios: SmokeScenario {
    /// The preview compares this phone with the backup; Cancel changes nothing.
    func testRestorePreview() {
        launch(seed: .default)
        screen("home", element("camp-scene"))
        element("settings-button").tap()
        screen("settings", app.navigationBars["Settings"])
        reveal(element("restore-demo-button"))
        XCTAssertTrue(element("export-privacy-note").exists)
        element("restore-demo-button").tap()
        screen("preview", element("restore-confirm-button"))
        XCTAssertEqual(element("preview-current-pets").label, "1")
        XCTAssertEqual(element("preview-backup-pets").label, "2")
        XCTAssertEqual(element("preview-backup-decorations").label, "5")
        element("restore-cancel-button").tap()
        screen("settings-again", app.navigationBars["Settings"])
        XCTAssertFalse(element("restore-done-label").exists, "nothing was restored")
        element("settings-done-button").tap()
        screen("home-unchanged", element("camp-scene"))
        XCTAssertEqual(element("coin-balance-label").label, "0 coins")
    }

    /// Confirming replaces everything: Dot is out in a decorated camp.
    func testRestoreApply() {
        launch(seed: .default)
        screen("home", element("camp-scene"))
        element("settings-button").tap()
        screen("settings", app.navigationBars["Settings"])
        reveal(element("restore-demo-button"))
        element("restore-demo-button").tap()
        screen("preview", element("restore-confirm-button"))
        element("restore-confirm-button").tap()
        reveal(element("restore-done-label"))
        screen("restored", element("restore-done-label"))
        element("settings-done-button").tap()
        screen("home-restored", element("camp-item-lantern"))
        XCTAssertEqual(element("pet-name-label").label, "Dot")
    }
}
