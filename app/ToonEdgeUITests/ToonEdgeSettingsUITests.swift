import XCTest

@MainActor
final class ToonEdgeSettingsUITests: XCTestCase {
    func testReaderSettingsControlsAndDoneRemainReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-browserFixture", "medium",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let cleanMode = app.buttons["browser.cleanModeAction"]
        XCTAssertTrue(cleanMode.waitForExistence(timeout: 5))
        cleanMode.tap()

        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let settings = app.buttons["reader.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.tap()

        XCTAssertTrue(app.buttons["reader-settings.done"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.segmentedControls["reader-settings.fit"].exists)
        XCTAssertTrue(app.switches["reader-settings.pageSpacing"].exists)

        let canvas = app.buttons["reader-settings.canvas.paper"]
        for _ in 0..<4 where !canvas.isHittable {
            app.scrollViews["reader-settings.scroll"].swipeUp()
        }
        XCTAssertTrue(canvas.isHittable)
        XCTAssertTrue(app.sliders["reader-settings.brightness"].exists)
        app.buttons["reader-settings.done"].tap()
        XCTAssertFalse(app.navigationBars["Reader Settings"].exists)
    }

    func testUpdateCheckDisablesDuplicateSubmissionAndShowsDistinctUsableResults() {
        verifyUpdateResult(
            launchArgument: "-seedUpdateSuccess",
            expected: "Found updates for 1 series."
        )
        verifyUpdateResult(
            launchArgument: "-seedUpdateNoChange",
            expected: "No new chapters found."
        )
        verifyUpdateResult(
            launchArgument: "-seedUpdateFailure",
            expected: "No updates found; 2 series could not be refreshed."
        )
        verifyUpdateResult(
            launchArgument: "-seedUpdateTotalFailure",
            expected: "Could not refresh 3 series."
        )
    }

    func testAccessibilityTextUsesAdaptivePickersAndKeepsUtilitiesReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        app.tabBars.buttons["tab.settings"].tap()

        let readerFit = app.descendants(matching: .any)["settings.readerFit"]
        XCTAssertTrue(readerFit.waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["settings.readerFit"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.canvas"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.pageSpacing"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.brightness"].exists)

        let manageDownloads = app.buttons["settings.manageDownloads"]
        for _ in 0..<8 where !manageDownloads.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(manageDownloads.isHittable)
    }

    func testReaderFitPersistsAcrossRelaunchAndStorageOpensDownloads() {
        var app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSettings"]
        app.launch()

        app.tabBars.buttons["tab.settings"].tap()
        XCTAssertTrue(app.segmentedControls["settings.readerFit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["Enter Full Screen"].exists)
        app.segmentedControls["settings.readerFit"].buttons["Fit Screen"].tap()
        XCTAssertTrue(app.segmentedControls["settings.readerFit"].buttons["Fit Screen"].isSelected)

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.tabBars.buttons["tab.settings"].tap()

        let fitScreen = app.segmentedControls["settings.readerFit"].buttons["Fit Screen"]
        XCTAssertTrue(fitScreen.waitForExistence(timeout: 5))
        XCTAssertTrue(fitScreen.isSelected)

        let manageDownloads = app.buttons["settings.manageDownloads"]
        for _ in 0..<5 where !manageDownloads.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(manageDownloads.isHittable)
        manageDownloads.tap()
        XCTAssertTrue(app.navigationBars["Downloads"].waitForExistence(timeout: 5))
    }

    func testHapticFeedbackDefaultsEnabledAndPersistsAcrossRelaunch() {
        var app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetSettings"]
        app.launch()
        app.tabBars.buttons["tab.settings"].tap()

        let hapticFeedback = app.switches["settings.hapticFeedback"]
        XCTAssertTrue(hapticFeedback.waitForExistence(timeout: 5))
        XCTAssertEqual(hapticFeedback.value as? String, "1")
        hapticFeedback.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(hapticFeedback.value as? String, "0")

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.tabBars.buttons["tab.settings"].tap()

        let persistedHapticFeedback = app.switches["settings.hapticFeedback"]
        XCTAssertTrue(persistedHapticFeedback.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedHapticFeedback.value as? String, "0")
        persistedHapticFeedback.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    private func verifyUpdateResult(launchArgument: String, expected: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", launchArgument]
        app.launch()
        app.tabBars.buttons["tab.settings"].tap()

        let checkUpdates = app.buttons["settings.checkUpdates"]
        for _ in 0..<6 where !checkUpdates.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(checkUpdates.isHittable)
        checkUpdates.tap()

        let loading = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == false", "Checking…"),
            object: checkUpdates
        )
        XCTAssertEqual(XCTWaiter.wait(for: [loading], timeout: 2), .completed)

        let result = app.staticTexts["settings.updateResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertEqual(result.label, expected)
        XCTAssertTrue(checkUpdates.isEnabled, "Update checking must remain retryable after a final result")
        XCTAssertEqual(checkUpdates.label, "Check for New Chapters")
        XCTAssertTrue(app.tabBars.buttons["tab.home"].isHittable, "Settings must remain navigable after checking")
        app.terminate()
    }
}
