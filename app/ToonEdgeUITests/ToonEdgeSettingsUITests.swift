import XCTest

@MainActor
final class ToonEdgeSettingsUITests: XCTestCase {
    func testUpdateCheckShowsSuccessNoUpdateAndFailureResults() {
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

        let result = app.staticTexts["settings.updateResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertEqual(result.label, expected)
        app.terminate()
    }
}
