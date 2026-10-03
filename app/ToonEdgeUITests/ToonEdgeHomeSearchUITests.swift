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

    func testSavedSuggestionShowsLocalContextAndOpensNativeSeriesDetail() {
        let app = openSearch()
        app.textFields["search.input"].typeText("moonlit")
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Moonlit Edge")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        XCTAssertTrue(saved.label.contains("Saved in Library"))
        XCTAssertEqual(saved.identifier, "search.savedSeries.A4A029B1-778A-46DF-9B92-2E94378C8E11")
        XCTAssertTrue(saved.label.contains("Reading"))
        XCTAssertTrue(saved.label.contains("Chapter 12"))
        XCTAssertTrue(saved.isHittable)
        let layoutScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        layoutScreenshot.name = "synthetic-saved-search-layout"
        layoutScreenshot.lifetime = .keepAlways
        add(layoutScreenshot)
        // The whole 44-point row remains actionable, including its padded edge.
        saved.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()

        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Moonlit Edge"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue Chapter 12"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close"].exists)
        XCTAssertTrue(app.navigationBars.buttons["Library"].isHittable)
        app.navigationBars.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    func testStaleSavedSuggestionShowsNativeUnavailableAndReturnsToLibrary() {
        let app = openSearch(additionalArguments: ["-seedStaleSavedSearch"])
        app.textFields["search.input"].typeText("removed hero")
        let saved = app.buttons["search.savedSeries.00000000-0000-0000-0000-000000000007"]
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        saved.tap()

        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Series unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close"].exists)
        XCTAssertTrue(app.navigationBars.buttons["Library"].isHittable)
        app.navigationBars.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    func testSavedSuggestionRemainsActionableAtAccessibilityTextSize() {
        let app = openSearch(additionalArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        app.textFields["search.input"].typeText("moonlit")
        let saved = app.buttons["search.savedSeries.A4A029B1-778A-46DF-9B92-2E94378C8E11"]
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        for _ in 0..<3 where !saved.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(saved.isHittable)
        XCTAssertGreaterThanOrEqual(saved.frame.height, 44)
        XCTAssertTrue(saved.label.contains("Saved in Library"))
        XCTAssertTrue(saved.label.contains("Reading"))
        XCTAssertTrue(saved.label.contains("Chapter 12"))
        saved.tap()

        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Moonlit Edge"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close"].exists)
    }

    private func openSearch(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData"] + additionalArguments
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
