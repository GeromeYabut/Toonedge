import XCTest

@MainActor
final class ToonEdgeLibraryUITests: XCTestCase {
    func testSeriesDetailKeepsOneContinueActionAndVisibleChapterUtilityAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetTestData",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
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
}
