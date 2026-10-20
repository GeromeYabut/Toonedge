import XCTest

@MainActor
final class ToonEdgeReaderIntegratedZoomUITests: XCTestCase {
    func testPinchStickyReleasePanAndMeasuredReset() {
        let app = launch()
        let pinchTraceOrigin = snapshot(app)
        defer { attachPinchTraceForPinchCase(app, origin: pinchTraceOrigin) }
        let canvas = app.scrollViews["reader.readingSurface"]
        setChromeForPinchCase(app, visible: false)
        let outwardInteraction = number(snapshot(app), "interaction")
        canvas.pinch(withScale: 2, velocity: 1)
        var data = waitFor(app) { ($0["scale"] as? Double ?? 0) > 1.3 &&
            ($0["interaction"] as? Double ?? 0) > outwardInteraction &&
            ($0["pinchSamples"] as? Int ?? 0) > 1 && $0["pinching"] as? Bool == false }
        XCTAssertFalse(app.buttons["reader.zoom.reset"].isHittable, "Consumed pinch must keep chrome hidden")
        XCTAssertLessThanOrEqual(number(data, "focalErrorX"), 2)
        XCTAssertLessThanOrEqual(number(data, "focalErrorY"), 2)
        setChromeForPinchCase(app, visible: true)
        app.buttons["reader.zoom.enlarge"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 }
        setChromeForPinchCase(app, visible: false)
        let detentInteraction = number(snapshot(app), "interaction")
        canvas.pinch(withScale: 0.50, velocity: -0.5)
        data = waitFor(app) { $0["pinchHeld"] as? Bool == true && $0["scale"] as? Double == 1 &&
            ($0["interaction"] as? Double ?? 0) > detentInteraction &&
            ($0["pinchSamples"] as? Int ?? 0) > 1 && $0["pinching"] as? Bool == false }
        XCTAssertFalse(app.buttons["reader.zoom.reset"].isHittable, "Consumed detent pinch must keep chrome hidden")
        XCTAssertGreaterThan(number(data, "pinchSamples"), 1)
        XCTAssertEqual(data["pinchBelow"] as? Bool, false)
        setChromeForPinchCase(app, visible: true)
        app.buttons["reader.zoom.enlarge"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 }
        setChromeForPinchCase(app, visible: false)
        let breakthroughInteraction = number(snapshot(app), "interaction")
        canvas.pinch(withScale: 0.35, velocity: -0.5)
        data = waitFor(app) { $0["pinchHeld"] as? Bool == true && $0["pinchBelow"] as? Bool == true &&
            ($0["interaction"] as? Double ?? 0) > breakthroughInteraction &&
            ($0["pinchSamples"] as? Int ?? 0) > 2 && $0["pinching"] as? Bool == false }
        XCTAssertFalse(app.buttons["reader.zoom.reset"].isHittable, "Consumed breakthrough pinch must keep chrome hidden")
        XCTAssertGreaterThan(number(data, "pinchSamples"), 2)
        XCTAssertLessThan(number(data, "scale"), 1)
        let retained = number(data, "scale")
        Thread.sleep(forTimeInterval: 0.15)
        XCTAssertEqual(number(snapshot(app), "scale"), retained, accuracy: 0.001)
        setChromeForPinchCase(app, visible: true)
        app.buttons["reader.zoom.enlarge"].tap()
        let beforePan = number(waitFor(app) { $0["scale"] as? Double == 2 }, "offsetY")
        setChromeForPinchCase(app, visible: false)
        let panInteraction = number(snapshot(app), "interaction")
        canvas.swipeUp()
        _ = waitFor(app) { abs(($0["offsetY"] as? Double ?? 0) - beforePan) > 10 &&
            ($0["interaction"] as? Double ?? 0) > panInteraction && $0["pinching"] as? Bool == false }
        XCTAssertFalse(app.buttons["reader.zoom.reset"].isHittable, "Consumed pan must keep chrome hidden")
        setChromeForPinchCase(app, visible: true)
        app.buttons["reader.zoom.reset"].tap()
        _ = waitFor(app) { $0["resetReady"] as? Bool == true }
        let started = Date()
        for _ in 0..<11 {
            data = snapshot(app)
            XCTAssertEqual(number(data, "scale"), 1, accuracy: 0.001)
            XCTAssertLessThanOrEqual(number(data, "resetErrorX"), 2)
            XCTAssertLessThanOrEqual(number(data, "resetErrorY"), 2)
            assertBound(data)
            Thread.sleep(forTimeInterval: 0.11)
        }
        XCTAssertGreaterThan(Date().timeIntervalSince(started), 1)
    }

    func testTapsFixedChromeAndOriginalPage() {
        let app = launch()
        let canvas = app.scrollViews["reader.readingSurface"]
        let reset = app.buttons["reader.zoom.reset"]
        let frame = reset.frame
        canvas.doubleTap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 }
        XCTAssertTrue(reset.isHittable)
        assertFrame(reset.frame, frame)
        canvas.doubleTap()
        _ = waitFor(app) { $0["resetReady"] as? Bool == true }
        canvas.tap()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == false"), object: reset)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 3), .completed)
        canvas.tap()
        XCTAssertTrue(reset.waitForExistence(timeout: 3)); XCTAssertTrue(reset.isHittable)
        app.buttons["reader.zoom.enlarge"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 }
        app.buttons["reader.viewOriginalPage"].tap()
        XCTAssertTrue(app.staticTexts["reader.zoom.ownedOriginal"].waitForExistence(timeout: 3))
        app.buttons["reader.zoom.return"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 }
        XCTAssertTrue(reset.isHittable)
    }

    func testLongShortContainersReuseAndLoadingLimit() {
        let app = launch()
        assertBound(snapshot(app))
        for target in ["middle", "last", "first"] {
            app.buttons["reader.zoom.\(target)"].tap()
            let index = target == "middle" ? 40 : (target == "last" ? 79 : 0)
            let data = waitFor(app) { ($0["reused"] as? Int ?? 0) > 0 &&
                ($0["pageIDs"] as? [Int] ?? []).contains(index) }
            assertBound(data)
            XCTAssertLessThan(data["created"] as? Int ?? 1000, 80)
        }
        app.buttons["reader.nextChapter"].tap()
        let data = waitFor(app) { $0["pageCount"] as? Int == 12 && $0["restoreFinished"] as? Bool == true }
        assertBound(data)
        let shortReady = waitFor(app) { ($0["visible"] as? Int ?? 0) > 4 &&
            $0["readyVisible"] as? Int == $0["visible"] as? Int }
        assertBound(shortReady)
        XCTAssertEqual(number(data, "scale"), 1)
        app.buttons["reader.zoom.shrink"].tap()
        assertBound(waitFor(app) { $0["scale"] as? Double == 0.75 })
    }

    func testDelayedDecodedDimensionsAndPageRetry() {
        let app = launch(waitForReady: false, delayedImage: true)
        _ = waitFor(app) { $0["firstPageStatus"] as? String == "loading" &&
            $0["firstPageReady"] as? Bool == false && ($0["unresolved"] as? Int ?? 0) > 0 }
        app.buttons["reader.zoom.enlarge"].tap()
        let pending = waitFor(app) { $0["scale"] as? Double == 2 &&
            $0["firstPageStatus"] as? String == "loading" && $0["firstPageReady"] as? Bool == false }
        let revision = number(pending, "geometryRevision")
        let release = app.buttons["reader.zoom.releaseImage"]
        XCTAssertTrue(release.isHittable)
        release.tap()
        let decoded = waitFor(app) { ($0["geometryRevision"] as? Double ?? 0) > revision &&
            $0["measurementGeometryRevision"] as? Int == $0["geometryRevision"] as? Int &&
            $0["firstPageStatus"] as? String == "ready" && $0["firstPageReady"] as? Bool == true }
        XCTAssertTrue(app.images["reader.image.1"].exists)
        XCTAssertEqual(number(decoded, "scale"), 2)
        XCTAssertLessThanOrEqual(number(decoded, "relayoutErrorX"), 2)
        XCTAssertLessThanOrEqual(number(decoded, "relayoutErrorY"), 2)
        app.buttons["reader.zoom.reset"].tap()
        let canvas = app.scrollViews["reader.readingSurface"]
        for _ in 0..<3 where !app.buttons["reader.page.retry.2"].isHittable { canvas.swipeUp() }
        let retry = app.buttons["reader.page.retry.2"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5)); XCTAssertTrue(retry.isHittable)
        retry.tap()
        XCTAssertTrue(app.images["reader.image.2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["reader.page.failed.2"].exists)
        assertBound(snapshot(app))
    }

    func testViewportFitAndSpacingPreserveNativeAnchor() {
        let app = launch()
        app.buttons["reader.zoom.middle"].tap()
        _ = waitFor(app) { ($0["pageIDs"] as? [Int] ?? []).contains(40) }
        app.buttons["reader.zoom.enlarge"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 }
        let oldHeight = number(snapshot(app), "viewportHeight")
        app.buttons["reader.zoom.resizeViewport"].tap()
        var data = waitFor(app) { abs(($0["viewportHeight"] as? Double ?? 0) - oldHeight) > 10 &&
            $0["measurementGeometryRevision"] as? Int == $0["geometryRevision"] as? Int }
        XCTAssertLessThanOrEqual(number(data, "relayoutErrorX"), 2)
        XCTAssertLessThanOrEqual(number(data, "relayoutErrorY"), 2)
        app.buttons["reader.settings"].tap()
        XCTAssertTrue(app.segmentedControls["reader-settings.fit"].waitForExistence(timeout: 3))
        app.segmentedControls["reader-settings.fit"].buttons["Fit Screen"].tap()
        app.switches["reader-settings.pageSpacing"].tap()
        app.buttons["reader-settings.done"].tap()
        data = waitFor(app) { $0["displayMode"] as? String == "fitScreen" && $0["spacing"] as? Bool == true &&
            $0["measurementGeometryRevision"] as? Int == $0["geometryRevision"] as? Int }
        XCTAssertEqual(number(data, "scale"), 2)
        XCTAssertLessThanOrEqual(number(data, "relayoutErrorX"), 2)
        XCTAssertLessThanOrEqual(number(data, "relayoutErrorY"), 2)
        app.buttons["reader.zoom.reset"].tap()
        data = waitFor(app) { $0["resetReady"] as? Bool == true }
        XCTAssertLessThanOrEqual(number(data, "resetErrorX"), 2)
        XCTAssertLessThanOrEqual(number(data, "resetErrorY"), 2)
    }

    func testChapterPipelineReplacementAndDelayedRestoreRejection() {
        // A: actual old restore stays held through inspection, then completes in place.
        var app = launch(waitForReady: false, delayedRestore: true)
        _ = waitForGate(app) { $0["pending"] as? Int == 1 && $0["completed"] as? Int == 0 }
        let sameHost = snapshot(app)
        XCTAssertEqual(sameHost["restoreFinished"] as? Bool, false)
        _ = waitForGate(app) { $0["pending"] as? Int == 1 && $0["completed"] as? Int == 0 }
        app.buttons["reader.zoom.enlarge"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 && $0["restoreFinished"] as? Bool == false }
        app.buttons["reader.zoom.releaseRestore"].tap()
        _ = waitForGate(app) { $0["pending"] as? Int == 0 && $0["completed"] as? Int == 1 && $0["timedOut"] as? Bool == false }
        var data = waitFor(app) { $0["restoreFinished"] as? Bool == true }
        XCTAssertEqual(number(data, "scale"), 2, "Delayed restore must not reset user inspection")
        XCTAssertEqual(data["pipeline"] as? String, sameHost["pipeline"] as? String)
        XCTAssertLessThan(number(data, "offsetY"), 2000, "Late page-five restore must not jump native canvas")
        app.terminate()

        // B: a fresh actual old restore remains held across chapter/pipeline replacement.
        app = launch(waitForReady: false, delayedRestore: true)
        _ = waitForGate(app) { $0["pending"] as? Int == 1 && $0["completed"] as? Int == 0 }
        let oldHost = snapshot(app)
        XCTAssertEqual(oldHost["restoreFinished"] as? Bool, false)
        _ = waitForGate(app) { $0["pending"] as? Int == 1 && $0["completed"] as? Int == 0 }
        app.buttons["reader.zoom.enlarge"].tap()
        _ = waitFor(app) { $0["scale"] as? Double == 2 && $0["restoreFinished"] as? Bool == false }
        app.buttons["reader.nextChapter"].tap()
        data = waitFor(app) { $0["pageCount"] as? Int == 12 && $0["restoreFinished"] as? Bool == true }
        XCTAssertNotEqual(data["pipeline"] as? String, oldHost["pipeline"] as? String)
        XCTAssertNotEqual(data["session"] as? String, oldHost["session"] as? String)
        XCTAssertEqual(number(data, "scale"), 1)
        XCTAssertEqual(data["resetRequest"] as? String, "")
        XCTAssertEqual(number(data, "interaction"), 0)
        let currentSession = data["session"] as? String
        let currentPipeline = data["pipeline"] as? String
        _ = waitForGate(app) { $0["pending"] as? Int == 1 && $0["completed"] as? Int == 0 }
        app.buttons["reader.zoom.releaseRestore"].tap()
        _ = waitForGate(app) { $0["pending"] as? Int == 0 && $0["completed"] as? Int == 1 && $0["timedOut"] as? Bool == false }
        data = waitFor(app) { $0["session"] as? String == currentSession &&
            $0["pipeline"] as? String == currentPipeline && $0["restoreFinished"] as? Bool == true }
        XCTAssertEqual(number(data, "scale"), 1)
        XCTAssertEqual(data["resetRequest"] as? String, "")
        XCTAssertEqual(number(data, "interaction"), 0)
        assertBound(data)
    }

    private func gateSnapshot(_ app: XCUIApplication) -> [String: Any] {
        guard let raw = app.staticTexts["reader.zoom.restoreGate"].value as? String,
              let bytes = raw.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return [:] }
        return result
    }
    @discardableResult private func waitForGate(_ app: XCUIApplication,
                                                _ condition: ([String: Any]) -> Bool) -> [String: Any] {
        let end = Date().addingTimeInterval(7)
        repeat {
            let data = gateSnapshot(app)
            if condition(data) { return data }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < end
        XCTFail("Actual held/completed restore precondition unavailable: \(gateSnapshot(app))")
        return gateSnapshot(app)
    }

    private func launch(waitForReady: Bool = true, delayedRestore: Bool = false,
                        delayedImage: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-readerIntegratedZoomFixture"]
        if delayedRestore { app.launchArguments.append("-integratedZoomDelayedRestore") }
        if delayedImage { app.launchArguments.append("-integratedZoomDelayedImage") }
        app.launch()
        XCTAssertTrue(app.scrollViews["reader.readingSurface"].waitForExistence(timeout: 5))
        _ = waitFor(app) { $0["pageCount"] as? Int == 80 }
        if waitForReady { _ = waitFor(app) { ($0["ready"] as? Int ?? 0) > 0 && $0["restoreFinished"] as? Bool == true } }
        if delayedRestore {
            _ = waitForGate(app) { $0["pending"] as? Int == 1 && $0["completed"] as? Int == 0 }
        }
        let reset = app.buttons["reader.zoom.reset"]
        if !reset.isHittable { app.scrollViews["reader.readingSurface"].tap() }
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: reset)
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 3), .completed,
            "Actual Reader starts with hidden chrome; reveal it through its normal surface tap")
        XCTAssertTrue(reset.isHittable)
        return app
    }
    private func snapshot(_ app: XCUIApplication) -> [String: Any] {
        guard let raw = app.staticTexts["reader.zoom.status"].value as? String,
              let bytes = raw.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return [:] }
        return result
    }
    @discardableResult private func waitFor(_ app: XCUIApplication, timeout: TimeInterval = 7,
                                            _ condition: ([String: Any]) -> Bool) -> [String: Any] {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            let data = snapshot(app)
            if condition(data) { return data }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < end
        XCTFail("Actual Reader precondition/measurement unavailable: \(snapshot(app))")
        return snapshot(app)
    }
    private func number(_ data: [String: Any], _ key: String) -> Double {
        guard let number = data[key] as? NSNumber else { XCTFail("Missing measured \(key)"); return .infinity }
        return number.doubleValue
    }
    private func assertBound(_ data: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        let visible = data["visible"] as? Int ?? 0
        XCTAssertLessThanOrEqual(data["materialized"] as? Int ?? 1000, visible == 0 ? 2 : visible + 2, file: file, line: line)
        XCTAssertEqual(data["materialized"] as? Int, data["nativeContainers"] as? Int, file: file, line: line)
        XCTAssertEqual(data["scrollOwners"] as? Int, 1, file: file, line: line)
        XCTAssertLessThanOrEqual(data["peakLoading"] as? Int ?? 1000, 3, file: file, line: line)
    }
    private func assertFrame(_ actual: CGRect, _ expected: CGRect) {
        for pair in [(actual.minX, expected.minX), (actual.minY, expected.minY),
                     (actual.width, expected.width), (actual.height, expected.height)] {
            XCTAssertEqual(pair.0, pair.1, accuracy: 2)
        }
    }

    /// Exclusive to the physical-pinch case; defer retains native input even on assertion failure.
    private func attachPinchTraceForPinchCase(_ app: XCUIApplication, origin: [String: Any]) {
        let current = snapshot(app)
        let raw = app.staticTexts["reader.zoom.pinchTrace"].value as? String
        let trace = raw.flatMap { $0.data(using: .utf8) }.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        let value: [String: Any] = [
            "available": trace != nil,
            "originSession": origin["session"] as? String ?? "",
            "originPipeline": origin["pipeline"] as? String ?? "",
            "currentSession": current["session"] as? String ?? "",
            "currentPipeline": current["pipeline"] as? String ?? "",
            "trace": trace as Any? ?? NSNull()
        ]
        do {
            let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
            attachment.name = "owned-native-pinch-trace"
            attachment.lifetime = .keepAlways
            add(attachment)
        } catch {
            XCTFail("Owned native pinch trace JSON could not be attached")
        }
        XCTAssertNotNil(trace, "Owned native pinch trace unavailable; diagnosis is inconclusive")
    }

    /// Only the physical-pinch case needs the entire native canvas unobstructed.
    private func setChromeForPinchCase(_ app: XCUIApplication, visible: Bool) {
        let reset = app.buttons["reader.zoom.reset"]
        if reset.isHittable != visible { app.scrollViews["reader.readingSurface"].tap() }
        let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == %@", NSNumber(value: visible)), object: reset)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 3), .completed)
        XCTAssertEqual(reset.isHittable, visible)
    }
}
