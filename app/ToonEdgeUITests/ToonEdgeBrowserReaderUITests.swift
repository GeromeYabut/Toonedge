import XCTest

@MainActor
final class ToonEdgeBrowserReaderUITests: XCTestCase {
    func testMediumConfidenceFixtureShowsWholeCleanModeActionAndOpensReader() {
        let app = launchBrowserFixture("medium")
        let action = app.buttons["browser.cleanModeAction"]

        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertTrue(action.isHittable)
        XCTAssertTrue(app.buttons["browser.close"].isHittable)
        XCTAssertTrue(app.buttons["browser.reload"].isHittable)
        XCTAssertTrue(app.buttons["browser.back"].exists)
        XCTAssertTrue(app.buttons["browser.forward"].exists)

        action.tap()

        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForExistence(timeout: 5))
    }

    func testReaderChromeOnlyTogglesFromReadingSurface() {
        let app = launchBrowserFixture("medium")
        let cleanMode = app.buttons["browser.cleanModeAction"]
        XCTAssertTrue(cleanMode.waitForExistence(timeout: 5))
        cleanMode.tap()

        let reader = app.descendants(matching: .any)["reader.root"]
        let chrome = app.descendants(matching: .any)["reader.chrome"]
        let back = app.buttons["reader.back"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertFalse(chrome.exists)
        XCTAssertFalse(back.exists)

        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(chrome.waitForExistence(timeout: 2))
        XCTAssertTrue(back.waitForExistence(timeout: 2))

        let retain = app.buttons["reader.retainChapter"]
        XCTAssertTrue(retain.isHittable)
        retain.tap()
        XCTAssertTrue(chrome.exists)
        XCTAssertTrue(back.exists)

        reader.swipeUp()
        XCTAssertTrue(chrome.exists)
        XCTAssertTrue(back.exists)
    }

    func testLowConfidenceFixtureDoesNotExposeCleanModeAction() {
        assertCleanModeIsUnavailable(for: "low")
    }

    func testProtectedFixtureDoesNotExposeCleanModeAction() {
        assertCleanModeIsUnavailable(for: "protected")
    }

    func testNonviableFixtureDoesNotExposeCleanModeAction() {
        assertCleanModeIsUnavailable(for: "nonviable")
    }

    private func assertCleanModeIsUnavailable(for fixture: String) {
        let app = launchBrowserFixture(fixture)
        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
    }

    private func launchBrowserFixture(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-browserFixture", fixture]
        app.launch()
        return app
    }
}
