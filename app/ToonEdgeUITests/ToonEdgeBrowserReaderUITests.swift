import XCTest

@MainActor
final class ToonEdgeBrowserReaderUITests: XCTestCase {
    func testManualFixtureOffersSecondaryToolAndPreservesExactOriginalHistory() {
        let app = launchBrowserFixture("manual")
        let chapter = app.webViews.buttons["Open synthetic chapter"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["https://fixture.toonedge.test/synthetic-start"].waitForExistence(timeout: 5))
        chapter.tap()
        let manual = app.buttons["browser.tryCleanMode"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        XCTAssertEqual(manual.label, "Try Clean Mode")
        XCTAssertTrue(manual.isHittable)
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader.root"].exists)
        XCTAssertTrue(app.buttons["browser.back"].isEnabled)
        manual.tap()
        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForExistence(timeout: 5))
        revealReaderChrome(in: app)
        app.buttons["reader.viewOriginalPage"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForNonExistence(timeout: 2))
        let original = "https://fixture.toonedge.test/chapter-1?position=7#panel-2"
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.back"].isEnabled)
        app.buttons["browser.back"].tap()
        XCTAssertTrue(app.staticTexts["https://fixture.toonedge.test/synthetic-start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.tryCleanMode"].exists)
    }

    func testUnreadableManualFixtureKeepsOriginalPageAndHidesEntry() {
        let app = launchBrowserFixture("manual-unreadable")
        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["browser.readerUnavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.tryCleanMode"].exists)
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader.root"].exists)
        XCTAssertTrue(app.staticTexts["https://fixture.toonedge.test/chapter-1"].exists)
    }

    func testTypedHardBlockFixtureHidesAllEntry() {
        let app = launchBrowserFixture("typed-hardblock")
        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.tryCleanMode"].exists)
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader.root"].exists)
    }

    func testHighConfidenceFixtureAutomaticallyOpensReader() {
        let app = launchBrowserFixture("high")

        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
    }

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

    func testViewOriginalFromBrowserOwnedReaderReturnsToOriginatingBrowser() {
        let app = launchBrowserFixture("medium")
        openMediumConfidenceReader(in: app)
        revealReaderChrome(in: app)

        let viewOriginal = app.buttons["reader.viewOriginalPage"]
        XCTAssertTrue(viewOriginal.waitForExistence(timeout: 2))
        viewOriginal.tap()

        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForNonExistence(timeout: 2))
    }

    func testBackFromAutoOpenedBrowserReaderReturnsToBrowser() {
        let app = launchBrowserFixture("high")
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        revealReaderChrome(in: app)

        let back = app.buttons["reader.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 2))
        back.tap()

        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(reader.waitForNonExistence(timeout: 2))
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

    func testWebtoonBrowserOnlyProfileNeverExposesCleanModeOrReader() {
        assertBrowserOnlyProfile(
            fixture: "protected-webtoon",
            displayedURL: "https://m.webtoons.com/en/action/toonedge-fixture/viewer"
        )
    }

    func testGlobalComixBrowserOnlyProfileNeverExposesCleanModeOrReader() {
        assertBrowserOnlyProfile(
            fixture: "protected-globalcomix",
            displayedURL: "https://www.globalcomix.com/c/toonedge-fixture/chapters/en/1"
        )
    }

    func testNonviableFixtureDoesNotExposeCleanModeAction() {
        assertCleanModeIsUnavailable(for: "nonviable")
    }

    private func assertCleanModeIsUnavailable(for fixture: String) {
        let app = launchBrowserFixture(fixture)
        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
    }

    private func assertBrowserOnlyProfile(fixture: String, displayedURL: String) {
        let app = launchBrowserFixture(fixture)
        XCTAssertTrue(app.otherElements["browser.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[displayedURL].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader.root"].exists)

        RunLoop.current.run(until: Date().addingTimeInterval(1))

        XCTAssertFalse(app.buttons["browser.cleanModeAction"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["reader.root"].exists)
    }

    private func openMediumConfidenceReader(in app: XCUIApplication) {
        let cleanMode = app.buttons["browser.cleanModeAction"]
        XCTAssertTrue(cleanMode.waitForExistence(timeout: 5))
        cleanMode.tap()
        XCTAssertTrue(app.descendants(matching: .any)["reader.root"].waitForExistence(timeout: 5))
    }

    private func revealReaderChrome(in app: XCUIApplication) {
        let reader = app.descendants(matching: .any)["reader.root"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["reader.chrome"].waitForExistence(timeout: 2))
    }


    func testCloseLowConfidenceBrowserAndReopenInSameProcess() {
        assertCloseAndReopen(fixture: "low", expectsBanner: false)
    }

    func testCloseRecommendedBrowserAndReopenInSameProcess() {
        assertCloseAndReopen(fixture: "medium", expectsBanner: true)
    }

    private func assertCloseAndReopen(fixture: String, expectsBanner: Bool) {
        let app = launchBrowserFixture(fixture)
        let browser = app.otherElements["browser.root"]
        XCTAssertTrue(browser.waitForExistence(timeout: 5))
        if expectsBanner { XCTAssertTrue(app.buttons["browser.cleanModeAction"].waitForExistence(timeout: 5)) }
        app.buttons["browser.close"].tap()
        XCTAssertTrue(browser.waitForNonExistence(timeout: 5))
        let search = app.buttons["home.searchEntry"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        let input = app.textFields["search.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.typeText("https://fixture.toonedge.test/chapter-1\n")
        XCTAssertTrue(browser.waitForExistence(timeout: 5))
        if expectsBanner { XCTAssertTrue(app.buttons["browser.cleanModeAction"].waitForExistence(timeout: 5)) }
        app.buttons["browser.close"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func launchBrowserFixture(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-browserFixture", fixture,
            "-resetLibraryOrganization",
            "-ToonEdge.Library.segment", "recent",
            "-ToonEdge.Library.sortKey", "activity",
            "-ToonEdge.Library.sortDirection", "descending",
            "-ToonEdge.Library.selectedViewMode", "comfortable"
        ]
        app.launch()
        return app
    }
}

@MainActor
final class ToonEdgeLiveSiteReaderUITests: XCTestCase {
    private var liveApp: XCUIApplication?

    private enum Failure: String, Error {
        case homeAbsent, searchAbsent, readerNotObserved
        case readerSurfaceAbsent, originalControlAbsent
        case browserReturnAbsent, destinationMismatch, homeReturnAbsent
        case navigationBudgetExceeded
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 120
    }

    override func tearDown() {
        liveApp?.terminate()
        liveApp = nil
        super.tearDown()
    }

    func test01ManhwaTop() {
        run("MP-06",
            "https://manhwatop.com/manga/my-little-brother-is-the-academys-hotshot/chapter-7/")
    }

    func test02MangaGeko() {
        run("MP-11",
            "https://www.mgeko.cc/reader/en/martial-wild-west-chapter-1-eng-li/")
    }

    func test03MangaGekoReadinessDiagnostic() {
        enum Outcome: String {
            case invalidRunID, observed, pass, unexpected
            case homeAbsent, searchAbsent, readerNotObserved
            case readerSurfaceAbsent, originalControlAbsent
            case browserReturnAbsent, destinationMismatch, homeReturnAbsent
            case navigationBudgetExceeded
        }

        let methodStart = ProcessInfo.processInfo.systemUptime
        var navigationStart: TimeInterval?
        var entryElapsed: TimeInterval = 0
        var runIDValid = false
        var launches = 0
        var browserObserved = false
        var readerObserved = false
        var browserAtReaderCheck = false
        var readerAtReaderCheck = false
        var manualEntry = false
        var originalVerified = false
        var homeReturned = false

        func milliseconds(_ elapsed: TimeInterval) -> Int {
            guard elapsed.isFinite else { return 0 }
            return Int(min(max(elapsed * 1_000, 0), 240_000))
        }

        func emit(_ outcome: Outcome) {
            let now = ProcessInfo.processInfo.systemUptime
            let result: [String: Any] = [
                "schema": 1, "case": "MP-11", "outcome": outcome.rawValue,
                "runIDValid": runIDValid, "launches": launches,
                "browserObserved": browserObserved, "readerObserved": readerObserved,
                "browserAtReaderCheck": browserAtReaderCheck, "readerAtReaderCheck": readerAtReaderCheck,
                "manualEntry": manualEntry, "originalVerified": originalVerified,
                "homeReturned": homeReturned, "readerEntryElapsedMs": milliseconds(entryElapsed),
                "navigationElapsedMs": navigationStart.map { milliseconds(now - $0) } ?? 0,
                "methodElapsedMs": milliseconds(now - methodStart)
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                print("TOONEDGE_READINESS_UI_V1 " + text)
            }
        }

        // The controller nonce is required before creating or launching the app.
        guard let runID = ProcessInfo.processInfo.environment["TOONEDGE_READINESS_RUN_ID"],
              runID.utf8.count == 36, let uuid = UUID(uuidString: runID),
              uuid.uuidString == runID else {
            emit(.invalidRunID)
            XCTFail("ReadinessDiagnostic invalidRunID")
            return
        }
        runIDValid = true
        let app = XCUIApplication()
        liveApp = app
        app.launchArguments = ["-readerReadinessDiagnostics", "-readerReadinessRunID", runID]
        app.launchEnvironment = [:]
        app.launch()
        launches = 1

        func require(_ condition: Bool, _ failure: Failure) throws {
            if !condition { throw failure }
        }

        do {
            let home = app.buttons["home.searchEntry"]
            try require(home.waitForExistence(timeout: 10), .homeAbsent)
            home.tap()
            let input = app.textFields["search.input"]
            try require(input.waitForExistence(timeout: 5), .searchAbsent)
            input.tap()
            let url = "https://www.mgeko.cc/reader/en/martial-wild-west-chapter-1-eng-li/"
            input.typeText(url)
            let start = ProcessInfo.processInfo.systemUptime
            navigationStart = start
            input.typeText("\n")

            let browser = app.descendants(matching: .any)["browser.root"]
            let reader = app.descendants(matching: .any)["reader.root"]
            let cta = app.buttons["browser.cleanModeAction"]
            var readerFirstObserved: TimeInterval?
            while (ProcessInfo.processInfo.systemUptime - start) < 40 {
                if reader.exists {
                    readerFirstObserved = ProcessInfo.processInfo.systemUptime
                    break
                }
                browserObserved = browserObserved || browser.exists
                if !manualEntry && cta.exists && cta.isEnabled && cta.isHittable {
                    manualEntry = true
                    cta.tap()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            readerAtReaderCheck = reader.exists
            if readerAtReaderCheck && readerFirstObserved == nil {
                readerFirstObserved = ProcessInfo.processInfo.systemUptime
            }
            entryElapsed = (readerFirstObserved ?? ProcessInfo.processInfo.systemUptime) - start
            browserAtReaderCheck = browser.exists
            browserObserved = browserObserved || browserAtReaderCheck
            readerObserved = readerFirstObserved != nil || readerAtReaderCheck
            // Record factual Browser/Reader observations before the entry assertion.
            emit(.observed)
            try require(readerAtReaderCheck && entryElapsed <= 40, .readerNotObserved)
            let surface = app.descendants(matching: .any)["reader.readingSurface"]
            try require(surface.exists && surface.isHittable, .readerSurfaceAbsent)
            let original = app.buttons["reader.viewOriginalPage"]
            if !original.exists || !original.isHittable { surface.tap() }
            try require(original.waitForExistence(timeout: 3) && original.isHittable,
                        .originalControlAbsent)
            try require((ProcessInfo.processInfo.systemUptime - start) < 50,
                        .navigationBudgetExceeded)
            original.tap()
            try require(browser.waitForExistence(timeout: 4), .browserReturnAbsent)
            try require(app.buttons["browser.search"].value as? String == url,
                        .destinationMismatch)
            originalVerified = true
            app.buttons["browser.close"].tap()
            try require(home.waitForExistence(timeout: 4), .homeReturnAbsent)
            homeReturned = true
            try require((ProcessInfo.processInfo.systemUptime - start) <= 60,
                        .navigationBudgetExceeded)
            emit(.pass)
        } catch {
            let outcome = (error as? Failure).flatMap { Outcome(rawValue: $0.rawValue) } ?? .unexpected
            emit(outcome)
            XCTFail("ReadinessDiagnostic " + outcome.rawValue)
        }
    }

    private func run(_ caseID: String, _ url: String) {
        let app = XCUIApplication()
        liveApp = app
        app.launchArguments = []
        app.launchEnvironment = [:]
        var readerObserved = false
        var manualEntry = false
        var originalVerified = false
        var homeReturned = false
        var navigationStart: TimeInterval?

        func require(_ condition: Bool, _ failure: Failure) throws {
            if !condition { throw failure }
        }

        func emit(_ outcome: String) {
            let result: [String: Any] = [
                "case": caseID, "outcome": outcome,
                "readerObserved": readerObserved, "manualEntry": manualEntry,
                "originalVerified": originalVerified, "homeReturned": homeReturned,
                "navigationElapsedMs": navigationStart.map {
                    Int((ProcessInfo.processInfo.systemUptime - $0) * 1000)
                } ?? 0
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result,
                                                       options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                print("TOONEDGE_LIVE_UI_V1 " + text)
            }
        }

        app.launch()
        do {
            let home = app.buttons["home.searchEntry"]
            try require(home.waitForExistence(timeout: 10), .homeAbsent)
            home.tap()
            let input = app.textFields["search.input"]
            try require(input.waitForExistence(timeout: 5), .searchAbsent)
            input.tap()
            input.typeText(url)
            navigationStart = ProcessInfo.processInfo.systemUptime
            input.typeText("\n")

            let reader = app.descendants(matching: .any)["reader.root"]
            let cta = app.buttons["browser.cleanModeAction"]
            let start = navigationStart!
            while (ProcessInfo.processInfo.systemUptime - start) < 40 && !reader.exists {
                if !manualEntry && cta.exists && cta.isEnabled && cta.isHittable {
                    manualEntry = true
                    cta.tap()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            try require(reader.exists, .readerNotObserved)
            readerObserved = true
            let surface = app.descendants(matching: .any)["reader.readingSurface"]
            try require(surface.exists && surface.isHittable, .readerSurfaceAbsent)
            let original = app.buttons["reader.viewOriginalPage"]
            if !original.exists || !original.isHittable { surface.tap() }
            try require(original.waitForExistence(timeout: 3) && original.isHittable,
                        .originalControlAbsent)
            try require((ProcessInfo.processInfo.systemUptime - start) < 50,
                        .navigationBudgetExceeded)
            original.tap()
            try require(app.descendants(matching: .any)["browser.root"]
                            .waitForExistence(timeout: 4), .browserReturnAbsent)
            try require(app.buttons["browser.search"].value as? String == url,
                        .destinationMismatch)
            originalVerified = true
            app.buttons["browser.close"].tap()
            try require(home.waitForExistence(timeout: 4), .homeReturnAbsent)
            homeReturned = true
            try require((ProcessInfo.processInfo.systemUptime - start) <= 60,
                        .navigationBudgetExceeded)
            emit("pass")
        } catch {
            let outcome = (error as? Failure)?.rawValue ?? "unexpected"
            emit(outcome)
            XCTFail("LiveReader " + caseID + ": " + outcome)
        }
    }
}
