import XCTest

@MainActor
final class ToonEdgeLibraryUITests: XCTestCase {
    func testLibrarySortImmediatelyReordersTitlesAndActivity() {
        let app = launchSortingLibrary()
        app.buttons["List library view"].tap()

        assertTitle("Moonlit Edge", precedes: "Signal Tower", in: app)
        selectSort("titleAscending", value: "Title · A–Z", in: app)
        assertTitle("Glass Harbor", precedes: "Moonlit Edge", in: app)
        selectSort("titleDescending", value: "Title · Z–A", in: app)
        assertTitle("Signal Tower", precedes: "North Star Courier", in: app)
        selectSort("recentOldest", value: "Recent activity · Oldest", in: app)
        assertTitle("North Star Courier", precedes: "Signal Tower", in: app)
        selectSort("recentNewest", value: "Recent activity · Newest", in: app)
        assertTitle("Moonlit Edge", precedes: "Signal Tower", in: app)
    }

    func testLibraryUnreadSortRetainsReadTitlesAndComposesWithSegments() {
        let app = launchSortingLibrary()
        app.buttons["List library view"].tap()
        selectSort("unreadUpdates", value: "Unread updates first", in: app)

        XCTAssertTrue(app.staticTexts["4 titles"].exists)
        assertTitle("Signal Tower", precedes: "Glass Harbor", in: app)
        reveal(app.staticTexts["Moonlit Edge"], in: app)
        reveal(app.staticTexts["North Star Courier"], in: app)

        scrollLibraryToTop(in: app)
        app.buttons["Reading"].tap()
        XCTAssertEqual(app.buttons["Reading"].value as? String, "Selected")
        assertSortValue("Unread updates first", in: app)
        XCTAssertTrue(app.staticTexts["3 titles"].exists)
        XCTAssertFalse(app.staticTexts["Glass Harbor"].exists)
        assertTitle("Signal Tower", precedes: "Moonlit Edge", in: app)

        scrollLibraryToTop(in: app)
        app.buttons["Planned"].tap()
        assertSortValue("Unread updates first", in: app)
        XCTAssertTrue(app.staticTexts["1 title"].exists)
        XCTAssertTrue(app.staticTexts["Glass Harbor"].exists)
        XCTAssertFalse(app.staticTexts["Moonlit Edge"].exists)
    }

    func testLibraryOrganizationPersistsAndResetPreservesDensity() {
        let app = launchSortingLibrary()
        app.buttons["Compact library view"].tap()
        app.buttons["Reading"].tap()
        selectSort("titleDescending", value: "Title · Z–A", in: app)

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openLibraryOrganization(in: app)

        XCTAssertEqual(app.buttons["Reading"].value as? String, "Selected")
        assertSortValue("Title · Z–A", in: app)
        XCTAssertEqual(app.buttons["Compact library view"].value as? String, "Selected")
        assertTitle("Signal Tower", precedes: "North Star Courier", in: app)

        app.buttons["library.sort"].tap()
        let reset = app.buttons["library.sort.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()

        XCTAssertEqual(app.buttons["Recent"].value as? String, "Selected")
        assertSortValue("Recent activity · Newest", in: app)
        XCTAssertEqual(app.buttons["Compact library view"].value as? String, "Selected")
        XCTAssertTrue(app.staticTexts["4 titles"].exists)
        assertTitle("Moonlit Edge", precedes: "Signal Tower", in: app)
    }

    func testLibraryOrganizationLaunchResetRestoresDefaultsWithoutResettingDensity() {
        let app = launchSortingLibrary()
        app.buttons["Compact library view"].tap()
        app.buttons["Planned"].tap()
        selectSort("titleDescending", value: "Title · Z–A", in: app)

        app.terminate()
        app.launchArguments = ["-uiTesting", "-resetLibraryOrganization"]
        app.launch()
        openLibraryOrganization(in: app)

        XCTAssertEqual(app.buttons["Recent"].value as? String, "Selected")
        assertSortValue("Recent activity · Newest", in: app)
        XCTAssertEqual(app.buttons["Compact library view"].value as? String, "Selected")
        XCTAssertTrue(app.staticTexts["4 titles"].exists)
    }

    func testLibrarySortAtAccessibilitySizePreservesRefreshAndSeriesNavigation() {
        let app = launchSortingLibrary(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let sort = app.buttons["library.sort"]
        XCTAssertEqual(sort.label, "Sort library")
        XCTAssertTrue(sort.isHittable)
        XCTAssertGreaterThanOrEqual(sort.frame.height, 44)
        selectSort("titleAscending", value: "Title · A–Z", in: app)

        let refresh = app.buttons["Check for new chapters"]
        reveal(refresh, in: app)
        XCTAssertTrue(refresh.isEnabled)
        refresh.tap()
        XCTAssertTrue(app.staticTexts["No new chapters"].waitForExistence(timeout: 5))
        assertSortValue("Title · A–Z", in: app)

        let series = app.staticTexts["Glass Harbor"]
        reveal(series, in: app)
        series.tap()
        let saved = app.buttons["Saved series"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertEqual(saved.value as? String, "Planned")
        XCTAssertTrue(app.buttons["Start Chapter 1"].exists)
    }

    func testSeriesDetailKeepsOneContinueActionAndVisibleChapterUtilityAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetTestData",
            "-resetLibraryOrganization",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
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

    func testLibraryFilterSelectionNarrowsVisibleCollection() {
        let app = launchLibrary()

        let plannedFilter = app.buttons["Planned"]
        XCTAssertTrue(plannedFilter.waitForExistence(timeout: 5))
        plannedFilter.tap()

        XCTAssertEqual(plannedFilter.value as? String, "Selected")
        XCTAssertTrue(app.staticTexts["Glass Harbor"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Moonlit Edge"].exists)
    }

    func testLibraryDensitySelectionPersistsAcrossRelaunch() {
        let app = launchLibrary()
        let listMode = app.buttons["List library view"]
        let compactMode = app.buttons["Compact library view"]
        XCTAssertTrue(listMode.waitForExistence(timeout: 5))
        XCTAssertTrue(compactMode.exists)

        listMode.tap()
        XCTAssertEqual(listMode.value as? String, "Selected")
        compactMode.tap()
        XCTAssertEqual(compactMode.value as? String, "Selected")

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        openLibrary(in: app)

        let relaunchedCompactMode = app.buttons["Compact library view"]
        XCTAssertTrue(relaunchedCompactMode.waitForExistence(timeout: 5))
        XCTAssertEqual(relaunchedCompactMode.value as? String, "Selected")
    }

    func testSeriesDetailMutationFailureOffersRetryAndRecovers() {
        let app = launchLibrary(extraArguments: ["-seedSeriesMutationRetry"])
        let series = app.staticTexts["Moonlit Edge"]
        XCTAssertTrue(series.waitForExistence(timeout: 5))
        series.tap()

        let savedSeries = app.buttons["Saved series"]
        XCTAssertTrue(savedSeries.waitForExistence(timeout: 5))
        XCTAssertEqual(savedSeries.value as? String, "Reading")
        savedSeries.tap()
        let markPlanned = app.buttons["Mark Planned"]
        XCTAssertTrue(markPlanned.waitForExistence(timeout: 5))
        markPlanned.tap()

        let failureTitle = app.staticTexts["Library update failed"]
        XCTAssertTrue(failureTitle.waitForExistence(timeout: 5))
        let retry = app.buttons["series-detail.mutation-retry"]
        XCTAssertTrue(retry.exists)
        retry.tap()

        XCTAssertTrue(failureTitle.waitForNonExistence(timeout: 5))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(app.buttons["Saved series"].value as? String, "Planned")
    }

    private func launchLibrary(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetLibraryOrganization"] + extraArguments
        app.launch()
        openLibrary(in: app)
        return app
    }

    private func launchSortingLibrary(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetLibraryOrganization"] + extraArguments
        app.launch()
        openLibraryOrganization(in: app)
        return app
    }

    private func openLibraryOrganization(in app: XCUIApplication) {
        let identifiedLibraryTab = app.tabBars.buttons["tab.library"]
        let libraryTab = identifiedLibraryTab.exists ? identifiedLibraryTab : app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()
        XCTAssertTrue(app.buttons["library.sort"].waitForExistence(timeout: 5))
    }

    private func selectSort(_ identifier: String, value: String, in app: XCUIApplication) {
        scrollLibraryToTop(in: app)
        app.buttons["library.sort"].tap()
        let choice = app.buttons["library.sort.\(identifier)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        assertSortValue(value, in: app)
    }

    private func assertSortValue(_ value: String, in app: XCUIApplication) {
        let matchesValue = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: matchesValue, object: app.buttons["library.sort"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func libraryScrollView(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(.button, identifier: "library.sort").firstMatch
    }

    private func scrollLibraryToTop(in app: XCUIApplication) {
        let scrollView = libraryScrollView(in: app)
        for _ in 0..<4 where !app.buttons["Recent"].isHittable {
            scrollView.swipeDown()
        }
        XCTAssertTrue(app.buttons["library.sort"].isHittable)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let scrollView = libraryScrollView(in: app)
        for _ in 0..<5 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func assertTitle(_ firstTitle: String, precedes secondTitle: String, in app: XCUIApplication) {
        scrollLibraryToTop(in: app)
        let first = app.staticTexts[firstTitle]
        let second = app.staticTexts[secondTitle]
        reveal(second, in: app)
        XCTAssertTrue(first.exists)
        XCTAssertGreaterThan(first.frame.height, 0)
        XCTAssertGreaterThan(second.frame.height, 0)
        if abs(first.frame.minY - second.frame.minY) < 1 {
            XCTAssertLessThan(first.frame.minX, second.frame.minX)
        } else {
            XCTAssertLessThan(first.frame.minY, second.frame.minY)
        }
    }

    private func openLibrary(in app: XCUIApplication) {
        let identifiedLibraryTab = app.tabBars.buttons["tab.library"]
        let libraryTab = identifiedLibraryTab.exists ? identifiedLibraryTab : app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()
        XCTAssertTrue(app.staticTexts["Moonlit Edge"].waitForExistence(timeout: 5))
    }
}
