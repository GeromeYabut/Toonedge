import XCTest

@MainActor
final class ToonEdgeReaderZoomUITests: XCTestCase {
    func testRealPinchPanResetPreserveNativeFiducialForOneSecond() {
        let app = launchFixture()
        let canvas = app.scrollViews["zoom.fixture.canvas"]
        let fiducial = app.images["zoom.fiducial.0"]
        XCTAssertTrue(fiducial.waitForExistence(timeout: 5))
        XCTAssertTrue(fiducial.isHittable)
        let before = fiducial.frame
        let reset = app.buttons["zoom.fixture.reset"]
        let chrome = reset.frame

        canvas.pinch(withScale: 2, velocity: 1)
        let enlarged = waitFor(app) { ($0["scale"] as? Double ?? 0) > 1.2 }
        assertBound(enlarged)
        XCTAssertLessThanOrEqual(enlarged["focalErrorX"] as? Double ?? 1000, 2)
        XCTAssertLessThanOrEqual(enlarged["focalErrorY"] as? Double ?? 1000, 2)
        XCTAssertTrue(reset.isHittable, "Consumed pinch must not toggle chrome")
        assertFrame(reset.frame, matches: chrome)

        let oldOffset = enlarged["offsetY"] as? Double ?? 0
        canvas.swipeUp()
        let panned = waitFor(app) { abs(($0["offsetY"] as? Double ?? 0) - oldOffset) > 10 }
        assertBound(panned)
        XCTAssertTrue(reset.isHittable, "Consumed pan must not toggle chrome")
        reset.tap()
        _ = waitFor(app) { $0["resetReady"] as? Bool == true }
        for _ in 0..<11 {
            let data = snapshot(app)
            XCTAssertLessThanOrEqual(data["resetErrorX"] as? Double ?? 1000, 2)
            XCTAssertLessThanOrEqual(data["resetErrorY"] as? Double ?? 1000, 2)
            XCTAssertEqual(data["scale"] as? Double, 1)
            assertFrame(fiducial.frame, matches: before)
            Thread.sleep(forTimeInterval: 0.1)
        }
        reset.tap()
        _ = waitFor(app) { $0["resetReady"] as? Bool == true }
        assertFrame(fiducial.frame, matches: before)
    }

    func testDoubleTapChromeAndOriginalPageCoexistWithInspection() {
        let app = launchFixture()
        let canvas = app.scrollViews["zoom.fixture.canvas"]
        canvas.doubleTap()
        _ = waitFor(app) { abs(($0["scale"] as? Double ?? 0) - 2) < 0.01 }
        XCTAssertTrue(app.buttons["zoom.fixture.reset"].isHittable)
        canvas.doubleTap()
        _ = waitFor(app) { $0["resetReady"] as? Bool == true }
        XCTAssertTrue(app.buttons["zoom.fixture.reset"].isHittable)
        canvas.tap()
        let resetButton = app.buttons["zoom.fixture.reset"]
        let chromeHidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == false"),
            object: resetButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [chromeHidden], timeout: 2),
            .completed,
            "Single tap must make chrome non-hittable after recognition resolves"
        )
        XCTAssertFalse(app.buttons["zoom.fixture.reset"].isHittable)
        canvas.tap()
        XCTAssertTrue(app.buttons["zoom.fixture.reset"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["zoom.fixture.reset"].isHittable)
        app.buttons["zoom.fixture.enlarge"].tap()
        _ = waitFor(app) { abs(($0["scale"] as? Double ?? 0) - 2) < 0.01 }
        app.buttons["zoom.fixture.original"].tap()
        XCTAssertTrue(app.staticTexts["zoom.fixture.originalPage"].waitForExistence(timeout: 3))
        app.buttons["zoom.fixture.return"].tap()
        _ = waitFor(app) { abs(($0["scale"] as? Double ?? 0) - 2) < 0.01 }
        XCTAssertTrue(app.buttons["zoom.fixture.reset"].isHittable)
    }

    func testBoundedNativeReuseAccessibilityShrinkAndSessionReplacement() {
        let app = launchFixture()
        let initial = snapshot(app)
        let firstSession = initial["session"] as? String
        app.buttons["zoom.fixture.middle"].tap()
        var data = waitFor(app) { ($0["reused"] as? Int ?? 0) > 0 }
        assertBound(data)
        app.scrollViews["zoom.fixture.canvas"].swipeUp()
        data = snapshot(app)
        assertBound(data)
        app.buttons["zoom.fixture.last"].tap()
        data = waitFor(app) { ($0["pageIDs"] as? [Int] ?? []).contains(79) }
        assertBound(data)
        XCTAssertLessThan(data["created"] as? Int ?? 1000, 80)
        app.buttons["zoom.fixture.shrink"].tap()
        data = waitFor(app) { abs(($0["scale"] as? Double ?? 0) - 0.75) < 0.01 }
        assertBound(data)
        app.buttons["zoom.fixture.replace"].tap()
        data = waitFor(app) {
            ($0["session"] as? String) != firstSession && $0["pageCount"] as? Int == 3
        }
        XCTAssertEqual(data["scale"] as? Double, 1)
        XCTAssertEqual(data["resetReady"] as? Bool, false)
        assertBound(data)
        app.buttons["zoom.fixture.enlarge"].tap()
        _ = waitFor(app) { abs(($0["scale"] as? Double ?? 0) - 2) < 0.01 }
        app.buttons["zoom.fixture.reset"].tap()
        data = waitFor(app) { $0["resetReady"] as? Bool == true }
        assertBound(data)
    }

    private func launchFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-readerZoomFixture"]
        app.launch()
        XCTAssertTrue(app.scrollViews["zoom.fixture.canvas"].waitForExistence(timeout: 5))
        _ = waitFor(app) { ($0["pageCount"] as? Int ?? 0) == 80 }
        return app
    }

    private func snapshot(_ app: XCUIApplication) -> [String: Any] {
        let status = app.staticTexts["zoom.fixture.status"]
        guard let raw = status.value as? String, let bytes = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        else { return [:] }
        return parsed
    }

    @discardableResult
    private func waitFor(_ app: XCUIApplication,
                         condition: ([String: Any]) -> Bool) -> [String: Any] {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            let data = snapshot(app)
            if condition(data) { return data }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        XCTFail("Synthetic native condition did not become observable: \(snapshot(app))")
        return snapshot(app)
    }

    private func assertBound(_ data: [String: Any], file: StaticString = #filePath,
                             line: UInt = #line) {
        let materialized = data["materialized"] as? Int ?? 1000
        let visible = data["visible"] as? Int ?? 0
        XCTAssertLessThanOrEqual(materialized, visible == 0 ? 2 : visible + 2,
                                 file: file, line: line)
        XCTAssertEqual(materialized, data["nativeContainers"] as? Int, file: file, line: line)
        XCTAssertEqual(data["scrollOwners"] as? Int, 1, file: file, line: line)
    }

    private func assertFrame(_ actual: CGRect, matches expected: CGRect,
                             file: StaticString = #filePath, line: UInt = #line) {
        for (a, b) in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                       (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertLessThanOrEqual(abs(a - b), 2, file: file, line: line)
        }
    }
}
