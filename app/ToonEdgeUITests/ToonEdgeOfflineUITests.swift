import XCTest

@MainActor
final class ToonEdgeOfflineUITests: XCTestCase {
    func testFailedDownloadRemovalPreservesRowAndRetrySucceeds() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData", "-seedDownloadsRemovalRetry"]
        app.launch()
        app.tabBars.buttons["tab.downloads"].tap()

        let chapter = app.staticTexts["Retry Chapter 9"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        app.buttons["Remove Retry Fixture, Retry Chapter 9 from cache"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["downloads.feedback.failure"].waitForExistence(timeout: 5))
        XCTAssertTrue(chapter.exists, "A failed removal must preserve its row")
        let retry = app.buttons["downloads.removal.retry"]
        XCTAssertTrue(retry.exists)
        retry.tap()

        XCTAssertTrue(chapter.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["downloads.feedback.success"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["downloads.empty"].exists)
    }

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
final class ToonEdgeAuthoritativeContinueUITests: XCTestCase {
    func testImmediateReaderReturnKeepsChapterThreeAndRefreshesProgress() {
        let app = launchFixture("continue-target")
        openFixtureSeries(in: app)
        assertContinueChapterThree(in: app)

        app.buttons["Continue Chapter 3"].tap()
        assertReaderChapter(3, in: app)
        let progress = advanceReaderProgress(in: app)
        returnToSeriesDetail(in: app)

        assertContinueChapterThree(in: app)
        assertChapterThreeProgress(progress, in: app)
    }

    func testFixtureRelaunchKeepsChapterThreeContinueDestination() {
        let app = launchFixture("continue-target")
        openFixtureSeries(in: app)
        assertContinueChapterThree(in: app)
        app.buttons["Continue Chapter 3"].tap()
        assertReaderChapter(3, in: app)
        let progress = advanceReaderProgress(in: app)
        returnToSeriesDetail(in: app)
        assertChapterThreeProgress(progress, in: app)

        // This relaunch verifies the UI fixture's persisted journey. Production SwiftData
        // reconstruction is covered separately by the DEF-021 Task 1 repository tests.
        relaunchFixture("continue-target", in: app)
        openFixtureSeries(in: app)
        assertContinueChapterThree(in: app)
        assertChapterThreeProgress(progress, in: app)
        app.buttons["Continue Chapter 3"].tap()
        assertReaderChapter(3, in: app)
    }

    func testAdjacentDiscoveryRefreshesContinueAndSurvivesFixtureRelaunch() {
        let app = launchFixture("continue-adjacent-discovery")
        assertReaderChapter(2, in: app)
        app.buttons["reader.nextChapter"].tap()
        assertReaderChapter(3, in: app)
        let progress = advanceReaderProgress(in: app)
        returnToSeriesDetail(in: app)

        assertContinueChapterThree(in: app)
        assertChapterThreeProgress(progress, in: app)

        relaunchFixture("continue-adjacent-discovery", in: app)
        // The fixture restores Series Detail directly after the discovered chapter is saved.
        assertContinueChapterThree(in: app)
        assertChapterThreeProgress(progress, in: app)
        app.buttons["Continue Chapter 3"].tap()
        assertReaderChapter(3, in: app)
    }

    private func launchFixture(_ scenario: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData", "-readerHardeningFixture", scenario]
        app.launch()
        return app
    }

    private func relaunchFixture(_ scenario: String, in app: XCUIApplication) {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-readerHardeningFixture", scenario]
        app.launch()
    }

    private func openFixtureSeries(in app: XCUIApplication) {
        let identifiedLibraryTab = app.tabBars.buttons["tab.library"]
        let libraryTab = identifiedLibraryTab.exists ? identifiedLibraryTab : app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 5))
        libraryTab.tap()
        let series = app.staticTexts["Continue Journey Fixture"]
        XCTAssertTrue(series.waitForExistence(timeout: 5))
        series.tap()
    }

    private func assertContinueChapterThree(in app: XCUIApplication) {
        let action = app.buttons["Continue Chapter 3"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        XCTAssertEqual(action.label, "Continue Chapter 3")
        XCTAssertTrue(action.isEnabled)
        XCTAssertFalse(app.buttons["Continue Chapter 1"].exists)
        XCTAssertFalse(app.buttons["Continue Chapter 2"].exists)
    }

    private func revealReaderChrome(in app: XCUIApplication) {
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        if !app.buttons["reader.back"].exists {
            reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.buttons["reader.back"].waitForExistence(timeout: 5))
    }

    private func assertReaderChapter(_ number: Int, in app: XCUIApplication) {
        revealReaderChrome(in: app)
        let chapter = app.staticTexts["reader.chapter.label"]
        let expected = "Continue Journey Fixture, Chapter \(number)"
        assertLabel(expected, on: chapter)
    }

    private func advanceReaderProgress(in app: XCUIApplication) -> String {
        let progress = app.staticTexts["reader.progress.value"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        let previousProgress = progress.label
        app.scrollViews["reader.readingSurface"].swipeUp()
        revealReaderChrome(in: app)
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@ AND label ENDSWITH %@", previousProgress, "%"),
            object: progress
        )
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed)
        let percentage = Int(progress.label.replacingOccurrences(of: "%", with: "")) ?? 0
        XCTAssertGreaterThan(percentage, 0)
        XCTAssertLessThan(percentage, 100, "The Continue target must remain in progress")
        return progress.label
    }

    private func returnToSeriesDetail(in app: XCUIApplication) {
        app.buttons["reader.back"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForNonExistence(timeout: 5))
    }

    private func assertChapterThreeProgress(_ progress: String, in app: XCUIApplication) {
        let row = app.buttons["Chapter 3, In Progress, \(progress)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Series Detail must show the latest Reader progress")
        XCTAssertEqual(row.label, "Chapter 3, In Progress, \(progress)")
    }

    private func assertLabel(_ label: String, on element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertEqual(element.label, label)
    }
}

@MainActor
final class ToonEdgeAdjacentFailureUITests: XCTestCase {
    func testChallengeFailureOffersExplicitRetryAndRecoversAfterUserAction() {
        let app = launchFixture()
        revealReaderChrome(in: app)

        app.buttons["Next"].tap()

        XCTAssertTrue(app.staticTexts["Reader access is temporarily limited."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["reader.adjacent.feedback"].exists)
        XCTAssertTrue(app.staticTexts["reader.chapter.label"].label.contains("Chapter 1"))
        XCTAssertTrue(app.scrollViews.firstMatch.exists, "The current Reader session should remain visible")
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
        app.launchArguments = [
            "-uiTesting",
            "-readerHardeningFixture",
            "adjacent-challenge"
        ]
        app.launch()
        return app
    }

    private func revealReaderChrome(in app: XCUIApplication) {
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
    }
}

@MainActor
final class ToonEdgeNumericAdjacencyUITests: XCTestCase {
    func testSparseChapter155NextOpens156Never169() {
        let app = launchFixture("numeric-adjacency")
        revealChrome(in: app)

        app.buttons["reader.nextChapter"].tap()

        assertChapter("Chapter 156", in: app)
        XCTAssertFalse(app.staticTexts["reader.chapter.label"].label.contains("169"))
    }

    func testSparseChapter155PreviousOpens154Never1() {
        let app = launchFixture("numeric-adjacency")
        revealChrome(in: app)

        app.buttons["reader.previousChapter"].tap()

        assertChapter("Chapter 154", in: app)
        XCTAssertFalse(app.staticTexts["reader.chapter.label"].label.hasSuffix("Chapter 1"))
    }

    func testUnsafeNumericPatternDoesNotExposeSparseAdjacentTargets() {
        let app = launchFixture("numeric-adjacency-unsafe")
        revealChrome(in: app)

        XCTAssertFalse(app.buttons["reader.previousChapter"].isEnabled)
        XCTAssertFalse(app.buttons["reader.nextChapter"].isEnabled)
    }

    private func launchFixture(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-readerHardeningFixture", fixture]
        app.launch()
        return app
    }

    private func revealChrome(in app: XCUIApplication) {
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["reader.chapter.label"].waitForExistence(timeout: 5))
    }

    private func assertChapter(_ expectedChapter: String, in app: XCUIApplication) {
        let chapterLabel = app.staticTexts["reader.chapter.label"]
        let expectedLabel = "Numeric Adjacency Fixture, \(expectedChapter)"
        let matchingLabel = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: matchingLabel, object: chapterLabel)

        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertEqual(chapterLabel.label, expectedLabel)
    }
}
