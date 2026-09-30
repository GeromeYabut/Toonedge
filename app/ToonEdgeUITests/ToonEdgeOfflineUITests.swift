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
final class ToonEdgeLongChapterUITests: XCTestCase {
    func testLongChapterTraversesFortyPanelsAndRecoversTransientImageFailure() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetTestData", "-readerHardeningFixture", "long-chapter"]
        app.launch()

        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertEqual(reader.elementType, .scrollView)
        let surface = reader

        let firstImage = loadedImage(page: 1, in: app)
        let firstFailure = app.descendants(matching: .any)["reader.page.failed.1"]
        let firstPlaceholder = app.staticTexts["Page 1"]
        if firstFailure.waitForExistence(timeout: 1) {
            XCTFail("Panel 1 rendered failure UI instead of its decoded image")
        } else {
            XCTAssertTrue(firstImage.waitForExistence(timeout: 5), "Panel 1 did not load while stationary")
            XCTAssertFalse(firstPlaceholder.exists, "Panel 1 remained in its loading placeholder state")
        }

        for page in 2...40 {
            let image = loadedImage(page: page, in: app)
            let failure = app.descendants(matching: .any)["reader.page.failed.\(page)"]
            for _ in 0..<5 {
                if image.waitForExistence(timeout: 1) || failure.exists {
                    break
                }
                surface.swipeUp()
            }
            if page == 20 {
                XCTAssertTrue(failure.waitForExistence(timeout: 3), "Panel 20 did not expose its one transient failure")
                app.buttons["Retry"].tap()
            }
            XCTAssertTrue(image.waitForExistence(timeout: 3), "Panel \(page) never loaded in sequence")
            XCTAssertGreaterThan(image.frame.width, 0)
            XCTAssertGreaterThan(image.frame.height, 0)
            XCTAssertFalse(
                failure.exists,
                "Panel \(page) remained blank after its explicit retry opportunity"
            )
        }

        if !app.buttons["reader.back"].exists {
            reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let progress = app.staticTexts["reader.progress.value"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, "100%")
    }

    private func loadedImage(page: Int, in app: XCUIApplication) -> XCUIElement {
        app.images.matching(
            NSPredicate(format: "label == %@", "Reader image \(page)")
        ).firstMatch
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
        let app = launchFixture("adjacent-challenge")
        assertFailureRemainsUntilUserAction("Reader access is temporarily limited.", in: app)

        app.buttons["reader.adjacent.retry"].tap()

        assertReaderChapter(2, in: app)
        assertNoFailureFeedback(in: app)
    }

    func testTypedFailuresKeepCurrentChapterAndOpenKnownOriginalTarget() {
        let failures = [
            ("adjacent-timeout", "Chapter timed out."),
            ("adjacent-challenge", "Reader access is temporarily limited."),
            ("adjacent-unavailable", "Chapter unavailable in Reader."),
            ("adjacent-low-confidence", "Chapter could not be verified."),
            ("adjacent-nonviable", "No usable chapter images found.")
        ]

        for (fixture, message) in failures {
            XCTContext.runActivity(named: fixture) { _ in
                let app = launchFixture(fixture)
                assertFailureRemainsUntilUserAction(message, in: app)
                app.buttons["reader.adjacent.openOriginal"].tap()
                assertChapterTwoOriginalPage(in: app)
                app.terminate()
            }
        }
    }

    func testAdjacentSuccessViewsOriginalForChapterTwoWithoutStaleFailure() {
        let app = launchFixture("adjacent-success")
        assertReaderChapter(1, in: app)
        app.buttons["reader.nextChapter"].tap()

        assertReaderChapter(2, in: app)
        assertNoFailureFeedback(in: app)
        let original = app.buttons["reader.viewOriginalPage"]
        XCTAssertEqual(original.label, "View Original Page")
        original.tap()

        assertChapterTwoOriginalPage(in: app)
    }

    func testAdjacentSuccessBackReturnsToHomeWithoutStaleFailure() {
        let app = launchFixture("adjacent-success")
        assertReaderChapter(1, in: app)
        app.buttons["reader.nextChapter"].tap()

        assertReaderChapter(2, in: app)
        assertNoFailureFeedback(in: app)
        app.buttons["reader.back"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.searchEntry"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["browser.root"].exists)
        assertNoFailureFeedback(in: app)
    }

    private func assertChapterTwoOriginalPage(in app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.close"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForNonExistence(timeout: 5))
        // This exact reserved URL is fixture content, never a live browsing address.
        XCTAssertTrue(app.staticTexts["https://fixture.example/series/chapter-2"].waitForExistence(timeout: 5))
    }

    private func launchFixture(_ fixture: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-resetTestData",
            "-readerHardeningFixture",
            fixture
        ]
        app.launch()
        return app
    }

    private func assertFailureRemainsUntilUserAction(_ message: String, in app: XCUIApplication) {
        assertReaderChapter(1, in: app)
        app.buttons["reader.nextChapter"].tap()
        assertFailure(message, in: app)

        // UI stability evidence; the package request-count test proves no hidden retry.
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        assertFailure(message, in: app)
    }

    private func assertFailure(_ message: String, in app: XCUIApplication) {
        let feedback = app.descendants(matching: .any)["reader.adjacent.feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        let text = app.staticTexts[message]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.label, message)
        assertReaderChapter(1, in: app)
        XCTAssertTrue(app.scrollViews["reader.readingSurface"].exists)
        let retry = app.buttons["reader.adjacent.retry"]
        let original = app.buttons["reader.adjacent.openOriginal"]
        XCTAssertEqual(retry.label, "Retry")
        XCTAssertEqual(original.label, "Open Original")
        XCTAssertTrue(retry.isEnabled)
        XCTAssertTrue(original.isEnabled)
    }

    private func assertNoFailureFeedback(in app: XCUIApplication) {
        XCTAssertFalse(app.descendants(matching: .any)["reader.adjacent.feedback"].exists)
        XCTAssertFalse(app.buttons["reader.adjacent.retry"].exists)
        XCTAssertFalse(app.buttons["reader.adjacent.openOriginal"].exists)
    }

    private func assertReaderChapter(_ number: Int, in app: XCUIApplication) {
        revealReaderChrome(in: app)
        let chapter = app.staticTexts["reader.chapter.label"]
        let expected = "Adjacent Outcome Fixture, Chapter \(number)"
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: chapter
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 6), .completed)
        XCTAssertEqual(chapter.label, expected)
    }

    private func revealReaderChrome(in app: XCUIApplication) {
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        if !app.buttons["reader.back"].exists {
            reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.buttons["reader.back"].waitForExistence(timeout: 5))
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
