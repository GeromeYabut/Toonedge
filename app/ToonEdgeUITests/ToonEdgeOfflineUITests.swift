import XCTest

@MainActor
final class ToonEdgeOfflineUITests: XCTestCase {
    func testRetainedChapterReopensOfflineInOrderAndUncachedChapterExplainsFailure() {
        var app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedOfflineReader", "-resetOfflineFixture"]
        app.launch()

        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let retain = app.buttons["Retain Chapter Offline"]
        XCTAssertTrue(retain.waitForExistence(timeout: 5))
        retain.tap()
        XCTAssertTrue(app.staticTexts["Chapter retained offline."].waitForExistence(timeout: 5))

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedOfflineReader"]
        app.launch()

        let reader = app.scrollViews.firstMatch
        for page in 1...3 {
            let image = app.images["Reader image \(page)"]
            for _ in 0..<4 where !image.exists {
                reader.swipeUp()
            }
            XCTAssertTrue(image.exists, "Retained page \(page) did not reopen in order")
        }

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedOfflineReader", "-uncachedOfflineFixture"]
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Page 1 unavailable. Connect to the internet and retry."].waitForExistence(timeout: 8)
        )
    }
}
