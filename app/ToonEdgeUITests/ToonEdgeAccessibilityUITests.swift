import XCTest

@MainActor
final class ToonEdgeAccessibilityUITests: XCTestCase {
    func testHomeSearchEntryIsAvailable() {
        let app = launchApp()
        let searchEntry = app.buttons["home.searchEntry"]
        XCTAssertTrue(searchEntry.waitForExistence(timeout: 5))
        XCTAssertEqual(searchEntry.label, "Search the web or paste a chapter link")
    }

    func testPrimaryTabsRemainHittableAtAccessibilityTextSize() {
        let app = launchApp(largeText: true)
        for tab in [("tab.library", "Library"), ("tab.downloads", "Downloads"), ("tab.settings", "Settings")] {
            let button = tabButton(app, identifier: tab.0, label: tab.1)
            XCTAssertTrue(button.exists, "Missing \(tab.1)")
            XCTAssertTrue(button.isHittable, "Unhittable \(tab.1)")
        }
        tabButton(app, identifier: "tab.settings", label: "Settings").tap()
        for tab in [("tab.home", "Home"), ("tab.library", "Library"), ("tab.downloads", "Downloads"), ("tab.settings", "Settings")] {
            XCTAssertTrue(tabButton(app, identifier: tab.0, label: tab.1).isHittable, "Unhittable on Settings: \(tab.1)")
        }
        attachScreenshot(app, name: "settings-large-text")
    }

    func testTwentiethDownloadEntryIsReachable() {
        let app = launchApp(extraArguments: ["-seedDownloads20"])
        app.tabBars.buttons["tab.downloads"].tap()
        let finalRow = app.staticTexts["Fixture Chapter 20"]
        let list = app.scrollViews.firstMatch
        for _ in 0..<20 where !finalRow.isHittable {
            list.swipeUp()
        }
        XCTAssertTrue(finalRow.isHittable)
        let remove = app.buttons["Remove Fixture Series, Fixture Chapter 20 from cache"]
        for _ in 0..<5 where !remove.isHittable {
            list.swipeUp()
        }
        XCTAssertTrue(remove.isHittable)
        attachScreenshot(app, name: "downloads-final-entry")
    }

    func testDelayedPopulatedLibraryNeverShowsEmptyState() {
        let app = launchApp(extraArguments: ["-seedDelayedLibrary"])
        app.tabBars.buttons["tab.library"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["library.loading"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["library.empty"].exists)
        XCTAssertTrue(app.staticTexts["Moonlit Edge"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["library.empty"].exists)
    }

    private func launchApp(largeText: Bool = false, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData"] + extraArguments
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        }
        app.launch()
        return app
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tabButton(_ app: XCUIApplication, identifier: String, label: String) -> XCUIElement {
        let identified = app.tabBars.buttons[identifier]
        return identified.exists ? identified : app.tabBars.buttons[label]
    }
}
