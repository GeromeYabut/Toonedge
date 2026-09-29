import XCTest

@MainActor
final class ToonEdgeLibraryUITests: XCTestCase {
    func testSeriesDetailKeepsOneContinueActionAndVisibleChapterUtilityAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetTestData",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let identifiedLibraryTab = app.tabBars.buttons["tab.library"]
        let libraryTab = identifiedLibraryTab.exists ? identifiedLibraryTab : app.tabBars.buttons["Library"]
        libraryTab.tap()
        let series = app.staticTexts["Moonlit Edge"]
        XCTAssertTrue(series.waitForExistence(timeout: 5))
        series.tap()

        let progressActions = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Continue Chapter' OR label BEGINSWITH 'Start Chapter'")
        )
        XCTAssertTrue(progressActions.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(progressActions.count, 1)

        let chapterUtilities = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'series-detail.chapter-actions.'")
        )
        let firstUtility = chapterUtilities.firstMatch
        XCTAssertTrue(firstUtility.waitForExistence(timeout: 5))
        XCTAssertEqual(firstUtility.frame.width, 44, accuracy: 0.01)
        XCTAssertEqual(firstUtility.frame.height, 44, accuracy: 0.01)
    }

    func testLibraryFilterSelectionNarrowsVisibleCollection() {
        let app = launchLibrary()

        let plannedFilter = app.buttons["Planned"]
        XCTAssertTrue(plannedFilter.waitForExistence(timeout: 5))
        plannedFilter.tap()

        XCTAssertEqual(plannedFilter.value as? String, "Selected")
        XCTAssertTrue(app.staticTexts["Glass Harbor"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Moonlit Edge"].exists)
    }

    func testLibraryDensitySelectionPersistsAcrossRelaunch() {
        let app = launchLibrary()
        let listMode = app.buttons["List library view"]
        let compactMode = app.buttons["Compact library view"]
        XCTAssertTrue(listMode.waitForExistence(timeout: 5))
        XCTAssertTrue(compactMode.exists)

        listMode.tap()
        XCTAssertEqual(listMode.value as? String, "Selected")
        compactMode.tap()
        XCTAssertEqual(compactMode.value as? String, "Selected")

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openLibrary(in: app)

        let relaunchedCompactMode = app.buttons["Compact library view"]
        XCTAssertTrue(relaunchedCompactMode.waitForExistence(timeout: 5))
        XCTAssertEqual(relaunchedCompactMode.value as? String, "Selected")
    }

    func testSeriesDetailMutationFailureOffersRetryAndRecovers() {
        let app = launchLibrary(extraArguments: ["-seedSeriesMutationRetry"])
        let series = app.staticTexts["Moonlit Edge"]
        XCTAssertTrue(series.waitForExistence(timeout: 5))
        series.tap()

        let savedSeries = app.buttons["Saved series"]
        XCTAssertTrue(savedSeries.waitForExistence(timeout: 5))
        XCTAssertEqual(savedSeries.value as? String, "Reading")
        savedSeries.tap()
        let markPlanned = app.buttons["Mark Planned"]
        XCTAssertTrue(markPlanned.waitForExistence(timeout: 5))
        markPlanned.tap()

        let failureTitle = app.staticTexts["Library update failed"]
        XCTAssertTrue(failureTitle.waitForExistence(timeout: 5))
        let retry = app.buttons["series-detail.mutation-retry"]
        XCTAssertTrue(retry.exists)
        retry.tap()

        XCTAssertTrue(failureTitle.waitForNonExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(app.buttons["Saved series"].value as? String, "Planned")
    }

    private func launchLibrary(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extraArguments
        app.launch()
        openLibrary(in: app)
        return app
    }

    private func openLibrary(in app: XCUIApplication) {
        let identifiedLibraryTab = app.tabBars.buttons["tab.library"]
        let libraryTab = identifiedLibraryTab.exists ? identifiedLibraryTab : app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()
        XCTAssertTrue(app.staticTexts["Moonlit Edge"].waitForExistence(timeout: 5))
    }
}
