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
