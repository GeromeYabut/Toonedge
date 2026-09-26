import XCTest

@MainActor
final class ToonEdgeSettingsUITests: XCTestCase {
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
}
