import XCTest
import UIKit

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
        app.launchArguments = ["-uiTesting", "-resetTestData", "-resetLibraryOrganization"] + (additionalArguments.contains("-libraryDensity") ? [] : ["-libraryDensity", "comfortable"]) + additionalArguments
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

@MainActor
final class ToonEdgeSearchHistoryUITests: XCTestCase {
    private let queryID = "13600000-0000-0000-0000-000000000001"
    private let linkID = "13600000-0000-0000-0000-000000000002"
    private var fixtureID = UUID().uuidString

    func testIndividualQueryAndLinkDeletionPersistsWithoutReseeding() {
        var app = launchFixture(reset: true)
        openSearch(app)
        let input = app.textFields["search.input"]
        input.typeText("history")
        let query = app.buttons["search.history.delete.\(queryID)"]
        XCTAssertTrue(query.waitForExistence(timeout: 5), "Persistent synthetic query must be seeded before first search")
        guard query.exists else { return }
        reach(app, query)
        query.tap()
        XCTAssertTrue(query.waitForNonExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "history")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let link = app.buttons["search.history.delete.\(linkID)"]
        XCTAssertTrue(link.exists)
        reach(app, link)
        link.tap()
        XCTAssertTrue(link.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search.history.delete.13600000-0000-0000-0000-000000000003"].exists)
        app.terminate()
        app = launchFixture(reset: false)
        openSearch(app)
        app.textFields["search.input"].typeText("history")
        XCTAssertFalse(app.buttons["search.history.delete.\(queryID)"].exists)
        XCTAssertFalse(app.buttons["search.history.delete.\(linkID)"].exists)
        XCTAssertTrue(app.buttons["search.history.delete.13600000-0000-0000-0000-000000000003"].waitForExistence(timeout: 5))
    }

    func testRemoveFailureRetryAndDismissKeepSearchUsable() {
        var app = launchFixture(reset: true, extra: ["-searchHistoryFailure", "remove-once"])
        openSearch(app)
        app.textFields["search.input"].typeText("history")
        let deletion = app.buttons["search.history.delete.\(queryID)"]
        XCTAssertTrue(deletion.waitForExistence(timeout: 5))
        reach(app, deletion)
        deletion.tap()
        XCTAssertTrue(app.buttons["search.history.retry"].waitForExistence(timeout: 5))
        reach(app, app.buttons["search.history.retry"])
        XCTAssertTrue(deletion.exists)
        XCTAssertTrue(app.buttons["search.history.dismiss"].isHittable)
        XCTAssertTrue(app.buttons["search.cancel"].isHittable)
        XCTAssertEqual(app.textFields["search.input"].value as? String, "history")
        app.buttons["search.history.retry"].tap()
        XCTAssertTrue(deletion.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search.history.delete.\(linkID)"].exists)
        app.buttons["search.history.dismiss"].tap()
        XCTAssertFalse(app.buttons["search.history.retry"].exists)
        app.terminate()
        app = launchFixture(reset: false)
        openSearch(app)
        app.textFields["search.input"].typeText("history")
        XCTAssertTrue(app.buttons["search.history.delete.\(linkID)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search.history.delete.\(queryID)"].exists)
    }

    func testOnlyRecentRowsOfferDeletionAndSavedRoutingDoesNotRecordHistory() {
        let app = launchFixture(reset: true)
        openSearch(app)
        let saved = app.buttons["search.savedSeries.13600000-0000-0000-0000-000000000100"]
        XCTAssertFalse(saved.exists, "Saved title matching intentionally requires a nonempty query")
        XCTAssertFalse(app.buttons["search.history.delete.13600000-0000-0000-0000-000000000004"].exists, "Copied link wins over persisted duplicate")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "search.suggestion", "Open copied link")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "search.suggestion", "history-site.example")).firstMatch.exists)
        app.buttons["search.cancel"].tap()
        assertHistoryCount(app, 15)
        openSearch(app)
        app.textFields["search.input"].typeText("History Saved")
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search.submitSuggestion"].exists)
        XCTAssertFalse(app.buttons["search.history.delete.13600000-0000-0000-0000-000000000100"].exists)
        saved.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["History Saved"].firstMatch.waitForExistence(timeout: 5))
        assertHistoryCount(app, 15)
    }

    func testRecentOpenRegionEdgeAndExplicitWebActionRouteToBrowser() {
        var app = launchFixture(reset: true)
        openSearch(app)
        app.textFields["search.input"].typeText("history")
        let row = app.buttons["search.history.\(linkID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        reach(app, row)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.terminate()
        app = launchFixture(reset: false)
        openSearch(app)
        app.textFields["search.input"].typeText("https://history.example/copied")
        XCTAssertFalse(app.buttons["search.history.delete.13600000-0000-0000-0000-000000000004"].exists)
        let web = app.buttons["search.submitSuggestion"]
        XCTAssertTrue(web.waitForExistence(timeout: 5))
        web.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
    }

    func testSettingsCancelAndConfirmedClearPersistAndRemainUsableWhenEmpty() {
        var app = launchFixture(reset: true)
        openConfirmation(app)
        assertConfirmation(app)
        app.alerts.buttons["Cancel"].tap()
        assertHistoryCount(app, 15)
        app.terminate()
        app = launchFixture(reset: false)
        assertHistoryCount(app, 15)
        openConfirmation(app)
        app.alerts.buttons["Clear Search History"].tap()
        XCTAssertTrue(app.staticTexts["settings.historyResult"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["settings.historyResult"].label, "Search history cleared.")
        XCTAssertTrue(app.buttons["settings.historyDismiss"].isHittable)
        XCTAssertTrue(app.buttons["settings.clearSearchHistory"].isEnabled)
        assertHistoryCount(app, 0)
        app.terminate()
        app = launchFixture(reset: false)
        assertHistoryCount(app, 0)
        openConfirmation(app)
        app.alerts.buttons["Clear Search History"].tap()
        XCTAssertTrue(app.staticTexts["settings.historyResult"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.clearSearchHistory"].isEnabled)
    }

    func testSettingsFailureRetryRequiresFreshConfirmationAndCancelDoesNotClear() {
        let app = launchFixture(reset: true, extra: ["-searchHistoryFailure", "clear-once"])
        openConfirmation(app)
        app.alerts.buttons["Clear Search History"].tap()
        XCTAssertTrue(app.buttons["settings.historyRetry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["settings.historyResult"].label, "Couldn’t clear search history. Try again.")
        XCTAssertTrue(app.buttons["settings.historyDismiss"].isHittable)
        XCTAssertTrue(tabButton(app, identifier: "tab.home", label: "Home").isHittable)
        assertHistoryCount(app, 15)
        app.buttons["settings.historyRetry"].tap()
        assertConfirmation(app)
        app.alerts.buttons["Cancel"].tap()
        assertHistoryCount(app, 15)
        // Retry consumes its old feedback when it opens confirmation. After cancel,
        // the ordinary clear control remains available for a fresh confirmation.
        openConfirmation(app)
        app.alerts.buttons["Clear Search History"].tap()
        XCTAssertTrue(app.staticTexts["settings.historyResult"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["settings.historyResult"].label, "Search history cleared.")
        assertHistoryCount(app, 0)
        XCTAssertTrue(app.buttons["settings.clearSearchHistory"].isEnabled)
    }

    func testClearPreservesProtectedPersistentStateAndNondefaultLibraryPresentation() {
        var app = launchFixture(reset: true, extra: ["-libraryDensity", "list", "-librarySources", "history.example"])
        tabButton(app, identifier: "tab.library", label: "Library").tap()
        app.buttons["Planned"].tap()
        app.buttons["library.sort"].tap()
        let picker = app.buttons["library.organization.sortPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let ascending = app.buttons["library.sort.titleAscending"]
        XCTAssertTrue(ascending.waitForExistence(timeout: 5))
        ascending.tap()
        app.buttons["library.organization.done"].tap()
        app.buttons["historyFixture.capture"].tap()
        XCTAssertTrue(app.staticTexts["historyFixture.result"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["historyFixture.result"].label, "Fixture baseline captured")
        openConfirmation(app)
        app.alerts.buttons["Clear Search History"].tap()
        XCTAssertTrue(app.staticTexts["settings.historyResult"].waitForExistence(timeout: 5))
        verifySentinel(app)
        app.terminate()
        app = launchFixture(reset: false)
        assertHistoryCount(app, 0)
        verifySentinel(app)
        tabButton(app, identifier: "tab.library", label: "Library").tap()
        XCTAssertEqual(app.buttons["Planned"].value as? String, "Selected")
        XCTAssertTrue((app.buttons["library.sort"].value as? String ?? "").contains("Title · A–Z"))
        XCTAssertTrue((app.buttons["library.sort"].value as? String ?? "").contains("history.example"))
    }

    func testHistoryControlsAndRecoveryRemainAccessibleAtLargestTextSize() {
        let app = launchFixture(reset: true, extra: ["-searchHistoryFailure", "remove-once", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openSearch(app)
        app.textFields["search.input"].typeText("history query")
        let deletion = app.buttons["search.history.delete.\(queryID)"]
        XCTAssertTrue(deletion.waitForExistence(timeout: 5))
        reach(app, deletion)
        XCTAssertGreaterThanOrEqual(deletion.frame.width, 44)
        XCTAssertGreaterThanOrEqual(deletion.frame.height, 44)
        XCTAssertEqual(deletion.label, "Remove history query alpha from Search History")
        reach(app, deletion)
        deletion.tap()
        let retry = app.buttons["search.history.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        reach(app, retry)
        XCTAssertTrue(retry.isHittable)
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
        XCTAssertTrue(app.buttons["search.history.dismiss"].isHittable)
        XCTAssertTrue(app.buttons["search.cancel"].isHittable)
        app.buttons["search.history.dismiss"].tap()
        XCTAssertTrue(deletion.exists)
        app.buttons["search.cancel"].tap()
        openConfirmation(app)
        assertConfirmation(app)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(tabButton(app, identifier: "tab.home", label: "Home").isHittable)
    }

    private func tabButton(_ app: XCUIApplication, identifier: String, label: String) -> XCUIElement {
        let identified = app.tabBars.buttons[identifier]
        return identified.exists ? identified : app.tabBars.buttons[label]
    }

    private func reach(_ app: XCUIApplication, _ element: XCUIElement) {
        // Target the foreground scroll containing this exact action. Home can remain
        // in the accessibility tree behind Search's sheet; full swipes also overshoot
        // a tall row whose centered trash button occupies a small keyboard viewport.
        // The trailing gutter above/below the centered trash is outside the giant
        // open button; dragging over its title can accidentally activate that row.
        let scroll = app.scrollViews.containing(.button, identifier: element.identifier).firstMatch
        for _ in 0..<20 {
            if element.isHittable { break }
            guard scroll.exists, scroll.frame.height > 0 else { break }
            let viewport = scroll.frame
            let targetCenter = element.frame.midY
            let upward = targetCenter > viewport.midY
            let distance = min(max(abs(targetCenter - viewport.midY), 20), viewport.height * 0.45)
            let startY: CGFloat = upward ? 0.75 : 0.25
            let endY = startY + (upward ? -distance : distance) / viewport.height
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: startY))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: endY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable)
    }

    private func openConfirmation(_ app: XCUIApplication) {
        tabButton(app, identifier: "tab.settings", label: "Settings").tap()
        let clear = app.buttons["settings.clearSearchHistory"]
        // Settings uses a LazyVStack: at accessibility sizes the utility may not
        // exist in the accessibility tree until its foreground content is scrolled.
        for _ in 0..<12 where !clear.exists {
            guard let foreground = app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
                XCTFail("Settings must expose its foreground scroll view")
                return
            }
            foreground.swipeUp()
        }
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        reach(app, clear)
        XCTAssertTrue(clear.isEnabled)
        clear.tap()
        XCTAssertTrue(app.alerts["Clear Search History?"].waitForExistence(timeout: 5))
    }

    private func assertConfirmation(_ app: XCUIApplication) {
        let alert = app.alerts["Clear Search History?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        // XCUI subscript treats long text as an identifier and rejects >128 chars.
        let message = alert.staticTexts.matching(NSPredicate(format: "label == %@",
            "This removes recent searches and links from ToonEdge. Your Library, reading progress, downloads, cookies, and website data are not changed." )).firstMatch
        XCTAssertTrue(message.exists)
        XCTAssertTrue(alert.buttons["Cancel"].isHittable)
        XCTAssertTrue(alert.buttons["Clear Search History"].isHittable)
    }

    private func assertHistoryCount(_ app: XCUIApplication, _ count: Int) {
        app.buttons["historyFixture.verify"].tap()
        XCTAssertTrue(app.staticTexts["historyFixture.count"].waitForExistence(timeout: 5))
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "History records: \(count)"), object: app.staticTexts["historyFixture.count"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func verifySentinel(_ app: XCUIApplication) {
        app.buttons["historyFixture.verify"].tap()
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Protected fixture state unchanged"), object: app.staticTexts["historyFixture.result"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }

    private func launchFixture(reset: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-librarySourceFixture", "-searchHistoryFixture", fixtureID] + (reset ? ["-resetSearchHistoryFixture", "-resetLibraryOrganization"] + (extra.contains("-libraryDensity") ? [] : ["-libraryDensity", "comfortable"]) : []) + extra
        app.launch()
        XCTAssertTrue(app.buttons["home.searchEntry"].waitForExistence(timeout: 10))
        for (identifier, label) in [("tab.home", "Home"), ("tab.library", "Library"),
                                    ("tab.downloads", "Downloads"), ("tab.settings", "Settings")] {
            XCTAssertTrue(tabButton(app, identifier: identifier, label: label).isHittable,
                          "Fixture diagnostics must not cover the \(label) tab")
        }
        return app
    }

    private func openSearch(_ app: XCUIApplication) {
        app.buttons["home.searchEntry"].tap()
        XCTAssertTrue(app.textFields["search.input"].waitForExistence(timeout: 5))
    }
}

@MainActor
final class ToonEdgeSharedSearchUITests: XCTestCase {
    // XCUI may report a 44-point frame as 43.99999999999994. Allow at most
    // 0.001 point of measurement rounding; the required hit size stays 44.
    private let geometryTolerance: CGFloat = 0.001

    func testDarkHomeHasTitleAndCompactSearch() throws {
        let app = launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let entry = app.buttons["home.searchEntry"]
        XCTAssertTrue(entry.isHittable)
        XCTAssertEqual(entry.frame.height, 44, accuracy: 0.5)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Owned Recent Only")).firstMatch.exists)
        let image = XCUIScreen.main.screenshot().image
        let crop = try XCTUnwrap(image.cgImage?.cropping(to:
            CGRect(x: 2 * image.scale, y: 300 * image.scale, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 255, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        XCTAssertLessThan(pixel[0], 8)
        XCTAssertLessThan(pixel[1], 8)
        XCTAssertLessThan(pixel[2], 8)
    }

    func testUtilitySearchCancelPreservesTabsAndLibraryOrganization() {
        let app = launch()
        tab(app, "Library").tap()
        app.buttons["Planned"].tap()
        let summary = app.staticTexts["library.sources.summary"].label
        for (name, identifier) in [("Library", "library.search"),
                                    ("Downloads", "downloads.search"),
                                    ("Settings", "settings.search")] {
            tab(app, name).tap()
            let search = app.buttons[identifier]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(search.frame.width, 44)
            search.tap()
            XCTAssertTrue(app.textFields["search.input"].waitForExistence(timeout: 5))
            app.textFields["search.input"].typeText("cancel this")
            app.buttons["search.cancel"].tap()
            XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
            XCTAssertTrue(tab(app, name).isSelected)
            XCTAssertTrue(app.navigationBars[name].exists)
        }
        tab(app, "Library").tap()
        XCTAssertEqual(app.buttons["Planned"].value as? String, "Selected")
        XCTAssertEqual(app.staticTexts["library.sources.summary"].label, summary)
    }

    func testBrowserAddressSearchLoadsRepeatedRequestsAndSavedSelection() {
        let app = launch(["-browserFixture", "low"])
        let address = app.buttons["browser.search"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        address.tap()
        app.buttons["search.cancel"].tap()
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        let destination = "https://owned.toonedge.test/search-result"
        for _ in 0..<2 {
            address.tap()
            submit(app, destination)
            XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
            let loaded = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", destination), object: address)
            XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 5), .completed)
            XCTAssertTrue(address.isHittable)
        }
        address.tap()
        chooseSaved(app)
        assertNativeSavedDetail(app)
    }

    func testBrowserOwnedReaderSearchCancelKeepsScaleThenCommitsWebSelection() {
        let app = launch(["-browserFixture", "medium", "-readerIntegratedZoomFixture"])
        let clean = app.buttons["browser.cleanModeAction"]
        XCTAssertTrue(clean.waitForExistence(timeout: 5))
        clean.tap()
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["reader.search"].exists)
        _ = waitForReader(app) { $0["firstPageReady"] as? Bool == true }
        revealReader(app)
        assertReaderChromeGeometry(app)
        attachOwnedScreenshot(app, name: "owned-reader-normal-chrome")
        app.buttons["reader.zoom.enlarge"].tap()
        let before = waitForReader(app) { ($0["scale"] as? Double ?? 0) > 1.5 }
        app.buttons["reader.search"].tap()
        XCTAssertTrue(app.textFields["search.input"].waitForExistence(timeout: 5))
        app.buttons["search.cancel"].tap()
        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        let after = waitForReader(app) { ($0["scale"] as? Double ?? 0) > 1.5 }
        XCTAssertEqual(before["session"] as? String, after["session"] as? String)
        XCTAssertEqual(before["pipeline"] as? String, after["pipeline"] as? String)
        XCTAssertEqual(before["scale"] as? Double, after["scale"] as? Double)
        XCTAssertTrue(app.buttons["reader.search"].isHittable)
        app.buttons["reader.search"].tap()
        submit(app, "https://owned.toonedge.test/new-destination")
        XCTAssertTrue(reader.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.search"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["browser.search"].value as? String,
                       "https://owned.toonedge.test/new-destination")
        app.terminate()
        let savedApp = launch(["-browserFixture", "medium"])
        XCTAssertTrue(savedApp.buttons["browser.cleanModeAction"].waitForExistence(timeout: 5))
        savedApp.buttons["browser.cleanModeAction"].tap()
        XCTAssertTrue(savedApp.descendants(matching: .any)["reader.root"].waitForExistence(timeout: 5))
        revealReader(savedApp)
        savedApp.buttons["reader.search"].tap()
        chooseSaved(savedApp)
        assertNativeSavedDetail(savedApp)
        savedApp.terminate()

        let accessible = launch(["-UIPreferredContentSizeCategoryName",
                                 "UICTContentSizeCategoryAccessibilityXXXL"])
        let recent = accessible.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Owned Recent Only")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        if !recent.isHittable { accessible.scrollViews.firstMatch.swipeUp() }
        recent.tap()
        XCTAssertTrue(accessible.descendants(matching: .any)["reader.root"].waitForExistence(timeout: 5))
        revealReader(accessible)
        assertReaderChromeGeometry(accessible)
        attachOwnedScreenshot(accessible, name: "owned-reader-accessibilityXXXL-chrome")
        accessible.buttons["reader.search"].tap()
        XCTAssertTrue(accessible.textFields["search.input"].waitForExistence(timeout: 5))
        XCTAssertTrue(accessible.buttons["search.cancel"].isHittable)
        accessible.buttons["search.cancel"].tap()
        XCTAssertTrue(accessible.textFields["search.input"].waitForNonExistence(timeout: 5))
        assertReaderChromeGeometry(accessible)
    }

    func testLibraryCompactSummaryControlsAndAccessibilityFallback() {
        var app = launch()
        tab(app, "Library").tap()
        let count = app.staticTexts["library.count"]
        let summary = app.staticTexts["library.sources.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(count.frame.maxX, summary.frame.minX)
        XCTAssertLessThan(summary.frame.height, 32)
        let density = app.buttons["library.density.comfortable"]
        let organization = app.buttons["library.sort"]
        XCTAssertGreaterThanOrEqual(density.frame.height + geometryTolerance, 44)
        XCTAssertGreaterThanOrEqual(organization.frame.height + geometryTolerance, 44)
        XCTAssertGreaterThan(organization.frame.minX, density.frame.maxX)
        XCTAssertLessThanOrEqual(app.frame.maxX - organization.frame.maxX, 24)
        organization.tap()
        XCTAssertTrue(app.buttons["library.organization.sortPicker"].waitForExistence(timeout: 5))
        app.buttons["library.organization.done"].tap()
        app.terminate()
        app = launch(["-UIPreferredContentSizeCategoryName",
                      "UICTContentSizeCategoryAccessibilityXXXL"])
        tab(app, "Library").tap()
        XCTAssertTrue(app.staticTexts["library.sources.summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.sort"].isHittable)
        XCTAssertTrue(app.buttons["library.search"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["library.sort"].frame.height + geometryTolerance, 44)
    }

    func testRecentOnlyHomeReaderSearchCancelAndDirectReaderWebSelection() {
        let app = launch(["-readerIntegratedZoomFixture"])
        let recent = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Owned Recent Only")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        recent.tap()
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        revealReader(app)
        XCTAssertEqual(app.staticTexts["reader.chapter.context"].label, "Chapter 7")
        app.buttons["reader.search"].tap()
        XCTAssertTrue(app.textFields["search.input"].waitForExistence(timeout: 5))
        app.buttons["search.cancel"].tap()
        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(reader.exists)
        XCTAssertEqual(app.staticTexts["reader.chapter.context"].label, "Chapter 7")
        app.buttons["reader.search"].tap()
        submit(app, "https://owned.toonedge.test/direct-reader-search")
        XCTAssertTrue(reader.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.search"].waitForExistence(timeout: 5))
        app.buttons["browser.close"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        recent.tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        revealReader(app)
        app.buttons["reader.search"].tap()
        chooseSaved(app)
        assertNativeSavedDetail(app)
    }

    private func assertReaderChromeGeometry(_ app: XCUIApplication,
                                           file: StaticString = #filePath, line: UInt = #line) {
        let identifiers = ["reader.back", "reader.library", "reader.search",
                           "reader.viewOriginalPage", "reader.settings", "reader.retainChapter",
                           "reader.zoom.reset"]
        let actions = identifiers.map { app.buttons[$0] }
        for action in actions {
            XCTAssertTrue(action.exists, action.identifier, file: file, line: line)
            XCTAssertTrue(action.isHittable, action.identifier, file: file, line: line)
            XCTAssertGreaterThanOrEqual(action.frame.width + geometryTolerance, 44, action.identifier, file: file, line: line)
            XCTAssertGreaterThanOrEqual(action.frame.height + geometryTolerance, 44, action.identifier, file: file, line: line)
            XCTAssertTrue(app.frame.contains(action.frame), action.identifier, file: file, line: line)
        }
        for i in actions.indices {
            for j in actions.indices where j > i {
                let overlap = actions[i].frame.intersection(actions[j].frame)
                XCTAssertFalse(overlap.width > 1 && overlap.height > 1,
                    "Reader action hit targets overlap", file: file, line: line)
            }
        }
        let progress = app.staticTexts["reader.progress.value"]
        XCTAssertTrue(progress.exists, file: file, line: line)
        // A numeric percentage is wider than one line's height, including at AX.
        // The previous fixed 44-point width wrapped 0% onto two lines.
        XCTAssertLessThan(progress.frame.height, progress.frame.width,
            "Reader percentage must remain on one line", file: file, line: line)
        XCTAssertTrue(app.frame.contains(progress.frame), file: file, line: line)
        let context = app.staticTexts["reader.chapter.context"]
        XCTAssertTrue(context.exists, file: file, line: line)
        XCTAssertTrue(app.frame.contains(context.frame), file: file, line: line)
        for action in actions {
            let overlap = context.frame.intersection(action.frame)
            XCTAssertFalse(overlap.width > 1 && overlap.height > 1,
                "Chapter context overlaps an action", file: file, line: line)
        }
    }
    private func attachOwnedScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sharedSearchFixture",
            "-resetLibraryOrganization", "-libraryDensity", "comfortable"] + extra
        app.launch()
        return app
    }
    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let identified = app.tabBars.buttons["tab.\(name.lowercased())"]
        return identified.exists ? identified : app.tabBars.buttons[name]
    }
    private func submit(_ app: XCUIApplication, _ text: String) {
        let input = app.textFields["search.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText(text + "\n")
    }
    private func chooseSaved(_ app: XCUIApplication) {
        let input = app.textFields["search.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("moonlit")
        let saved = app.buttons["search.savedSeries.A4A029B1-778A-46DF-9B92-2E94378C8E11"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
    }
    private func assertNativeSavedDetail(_ app: XCUIApplication) {
        XCTAssertTrue(app.textFields["search.input"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue Chapter 12"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.close"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader.root"].exists)
        XCTAssertTrue(app.navigationBars.buttons["Library"].isHittable)
    }
    private func revealReader(_ app: XCUIApplication) {
        if !app.buttons["reader.search"].isHittable {
            app.descendants(matching: .any)["reader.root"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.buttons["reader.search"].waitForExistence(timeout: 5))
    }
    private func waitForReader(_ app: XCUIApplication,
                              _ condition: ([String: Any]) -> Bool) -> [String: Any] {
        let deadline = Date().addingTimeInterval(8)
        repeat {
            if let raw = app.staticTexts["reader.zoom.status"].value as? String,
               let bytes = raw.data(using: .utf8),
               let value = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
               condition(value) { return value }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        XCTFail("Owned Reader did not reach the expected native state")
        return [:]
    }
}
