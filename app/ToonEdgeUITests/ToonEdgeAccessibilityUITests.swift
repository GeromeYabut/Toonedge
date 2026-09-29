import XCTest

@MainActor
final class ToonEdgeAccessibilityUITests: XCTestCase {
    func testPrimaryTabsRemainHittableInLightAppearance() {
        assertPrimaryTabsRemainHittable(appearance: .light)
    }

    func testPrimaryTabsRemainHittableInDarkAppearance() {
        assertPrimaryTabsRemainHittable(appearance: .dark)
    }

    func testHomeEditorialSearchEntryRemainsReachableAtAccessibilityTextSize() {
        let app = launchApp(contentSizeCategory: .accessibilityXXXL)
        let searchEntry = app.buttons["home.searchEntry"]
        XCTAssertTrue(searchEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(searchEntry.isHittable)
        XCTAssertEqual(searchEntry.label, "Search the web or paste a chapter link")
    }

    func testPrimaryTabsRemainHittableAtAccessibilityTextSize() {
        let app = launchApp(contentSizeCategory: .accessibilityXXXL)
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

    func testDelayedDownloadsTransitionFromLoadingToEmpty() {
        let app = launchApp(extraArguments: ["-seedDelayedDownloadsEmpty"])
        tabButton(app, identifier: "tab.downloads", label: "Downloads").tap()

        XCTAssertTrue(app.descendants(matching: .any)["downloads.loading"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["downloads.empty"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["downloads.empty"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["downloads.loading"].exists)
    }

    func testDelayedDownloadsTransitionFromLoadingToContent() {
        let app = launchApp(extraArguments: ["-seedDelayedDownloadsContent"])
        tabButton(app, identifier: "tab.downloads", label: "Downloads").tap()

        XCTAssertTrue(app.descendants(matching: .any)["downloads.loading"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Delayed Chapter 7"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["downloads.empty"].exists)
    }

    func testDownloadsEditorialHeaderAndActionsRemainAccessibleAtLargeText() {
        let app = launchApp(
            contentSizeCategory: .accessibilityXXXL,
            extraArguments: ["-seedDownloads20"]
        )
        tabButton(app, identifier: "tab.downloads", label: "Downloads").tap()

        let storageHeader = app.descendants(matching: .any)["downloads.storageHeader"]
        XCTAssertTrue(storageHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(storageHeader.label.contains("20 chapters"))
        XCTAssertFalse(app.staticTexts["Local reading cache"].exists)

        let firstRemove = app.buttons["Remove Fixture Series, Fixture Chapter 20 from cache"]
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<25 where !firstRemove.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(firstRemove.isHittable)
        XCTAssertTrue(firstRemove.label.contains("Fixture Series"))
        XCTAssertTrue(firstRemove.label.contains("Fixture Chapter 20"))
    }

    func testDelayedPopulatedLibraryNeverShowsEmptyState() {
        let app = launchApp(extraArguments: ["-seedDelayedLibrary"])
        app.tabBars.buttons["tab.library"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["library.loading"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["library.empty"].exists)
        XCTAssertTrue(app.staticTexts["Moonlit Edge"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["library.empty"].exists)
    }

    func testReaderOnlyExposesContextuallyValidControlsAction() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-browserFixture", "medium"]
        app.launch()

        let cleanMode = app.buttons["browser.cleanModeAction"]
        XCTAssertTrue(cleanMode.waitForExistence(timeout: 5))
        cleanMode.tap()

        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertEqual(reader.value as? String, "Show Reader Controls")

        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(reader.value as? String, "Hide Reader Controls")
    }

    private func assertPrimaryTabsRemainHittable(appearance: TestAppearance) {
        let app = launchApp(appearance: appearance)
        let tabs = [
            ("tab.home", "Home"),
            ("tab.library", "Library"),
            ("tab.downloads", "Downloads"),
            ("tab.settings", "Settings")
        ]
        for (identifier, label) in tabs {
            let button = tabButton(app, identifier: identifier, label: label)
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing \(identifier) in \(appearance.rawValue)")
            XCTAssertTrue(button.isHittable, "Unhittable \(identifier) in \(appearance.rawValue)")
            button.tap()
            XCTAssertTrue(button.isSelected, "Unselected \(identifier) in \(appearance.rawValue)")
            for (otherIdentifier, otherLabel) in tabs {
                XCTAssertTrue(tabButton(app, identifier: otherIdentifier, label: otherLabel).isHittable,
                              "Unhittable \(otherIdentifier) on \(identifier) in \(appearance.rawValue)")
            }
        }
    }

    private func launchApp(
        appearance: TestAppearance? = nil,
        contentSizeCategory: TestContentSizeCategory? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData"] + extraArguments
        if let appearance {
            app.launchArguments += ["-AppleInterfaceStyle", appearance.rawValue]
        }
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory.rawValue]
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

    private enum TestAppearance: String {
        case light = "Light"
        case dark = "Dark"
    }

    private enum TestContentSizeCategory: String {
        case accessibilityXXXL = "UICTContentSizeCategoryAccessibilityXXXL"
    }
}
