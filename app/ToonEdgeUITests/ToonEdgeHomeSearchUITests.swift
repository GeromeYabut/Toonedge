import XCTest

@MainActor
final class ToonEdgeHomeSearchUITests: XCTestCase {
    func testFirstOpenShowsInputAndCancelAndAcceptsTyping() {
        let app = openSearch()
        let input = app.textFields["search.input"]

        XCTAssertTrue(input.isHittable)
        XCTAssertTrue(app.buttons["search.cancel"].isHittable)
        app.typeText("first open")
        XCTAssertEqual(input.value as? String, "first open")
    }

    func testClearThenRetypeAndSubmitOpensBrowser() {
        let app = openSearch()
        let input = app.textFields["search.input"]
        input.typeText("discard this")
        let clear = app.buttons["search.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        clear.tap()
        XCTAssertEqual(input.value as? String, "")
        input.typeText("https://example.com/\n")

        assertBrowserOpened(app)
    }

    func testInvalidAddressKeepsInputAndShowsRecoverableValidation() {
        let app = openSearch()
        let input = app.textFields["search.input"]
        input.typeText("https://\n")

        let validation = app.staticTexts["search.validation"]
        XCTAssertTrue(validation.waitForExistence(timeout: 3))
        XCTAssertTrue(input.isHittable)
        XCTAssertTrue(app.buttons["search.cancel"].isHittable)
        input.typeText("example.com")
        XCTAssertTrue(validation.waitForNonExistence(timeout: 3))
    }

    func testCancelAndReopenRestoresEmptyFocusedInput() {
        let app = openSearch()
        app.textFields["search.input"].typeText("cancelled query")
        app.buttons["search.cancel"].tap()
        XCTAssertTrue(app.buttons["search.cancel"].waitForNonExistence(timeout: 3))

        app.buttons["home.searchEntry"].tap()
        let input = app.textFields["search.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, "")
        app.typeText("reopened")
        XCTAssertEqual(input.value as? String, "reopened")
    }

    func testSuggestionBlankTrailingEdgeOpensBrowser() {
        let app = openSearch()
        app.textFields["search.input"].typeText("toonedge row tap fixture")
        let row = app.buttons["search.submitSuggestion"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.isHittable)
        // Tap the padded edge, away from the icon, title, and trailing kind text.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()

        assertBrowserOpened(app)
    }

    private func openSearch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData"]
        app.launch()
        let entry = app.buttons["home.searchEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.textFields["search.input"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["search.cancel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        return app
    }

    private func assertBrowserOpened(_ app: XCUIApplication) {
        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        // Browser's existing system Close accessibility label; Search anchors are identifiers.
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
    }
}
