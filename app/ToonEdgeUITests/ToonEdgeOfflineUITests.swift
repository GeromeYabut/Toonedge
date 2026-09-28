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

@MainActor
final class ToonEdgeAdjacentFailureUITests: XCTestCase {
    func testChallengeFailureOffersExplicitRetryAndRecoversAfterUserAction() {
        let app = launchFixture()
        revealReaderChrome(in: app)

        app.buttons["Next"].tap()

        XCTAssertTrue(app.staticTexts["This site may be rate limiting Reader Mode. Try again in a moment or open the original page."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reader.adjacent.retry"].exists)
        XCTAssertTrue(app.buttons["reader.adjacent.openOriginal"].exists)
        let retry = app.buttons["reader.adjacent.retry"]
        retry.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 6))
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        XCTAssertFalse(retry.exists)
        XCTAssertTrue(app.scrollViews.firstMatch.exists)
        if !app.staticTexts["reader.chapter.label"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let chapterLabel = app.staticTexts["reader.chapter.label"]
        XCTAssertTrue(chapterLabel.waitForExistence(timeout: 5))
        XCTAssertTrue(chapterLabel.label.contains("Chapter 2"))
    }

    func testChallengeFailureCanOpenKnownOriginalTarget() {
        let app = launchFixture()
        revealReaderChrome(in: app)

        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["reader.adjacent.openOriginal"].waitForExistence(timeout: 5))
        app.buttons["reader.adjacent.openOriginal"].tap()

        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].exists)
    }

    private func launchFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedAdjacentFailureReader"]
        app.launch()
        return app
    }

    private func revealReaderChrome(in app: XCUIApplication) {
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
    }
}
