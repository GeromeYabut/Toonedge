import XCTest

@MainActor
final class ToonEdgeBrowserReaderUITests: XCTestCase {
    func testManualFixtureOffersSecondaryToolAndPreservesExactOriginalHistory() {
        let app = launchBrowserFixture("manual")
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

    private func launchBrowserFixture(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-browserFixture", fixture]
        app.launch()
        return app
    }
}
