import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
import WebKit
@testable import ToonEdgeAppCore

private struct HydrationEvent: Sendable {
    let url: URL
    let candidates: Int
    let hardBlocks: Set<DetectionHardBlock>
}
private final class HydrationLogger: DetectionDiagnosticsLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [HydrationEvent] = []
    var events: [HydrationEvent] { lock.withLock { storage } }
    func log(_ diagnostics: DetectionDiagnostics, pageURL: URL) {
        lock.withLock { storage.append(.init(url: pageURL,
            candidates: diagnostics.candidateCount, hardBlocks: diagnostics.hardBlocks)) }
    }
}
@MainActor
private final class HydrationBrowser {
    let logger = HydrationLogger()
    let model: BrowserViewModel
    let coordinator: BrowserWebView.Coordinator
    let webView: WKWebView
    let client: HydrationHTTPClient
    init(url: URL, client: HydrationHTTPClient = HydrationHTTPClient()) {
        self.client = client
        _ = NSApplication.shared
        model = BrowserViewModel(startPoint: .url(url.absoluteString))
        coordinator = BrowserWebView.Coordinator(viewModel: model,
            detector: ProfileAwareChapterDetector(diagnosticsLogger: logger),
            imagePreflight: ReaderSessionImagePreflight(httpClient: client))
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(
            source: BrowserPageSanitizerScript.javaScript, injectionTime: .atDocumentEnd,
            forMainFrameOnly: false))
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        webView.customUserAgent = BrowserUserAgent.mobileSafari
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        coordinator.attach(webView)
    }
    func stop() {
        coordinator.teardown()
        webView.configuration.userContentController.removeAllUserScripts()
    }
    func optionalEpoch() async throws -> String? {
        let value = try await webView.evaluateJavaScript("window.__toonEdgeReadiness?.epoch",
            in: nil, contentWorld: BrowserHydrationReadinessScript.world)
        return value as? String
    }
    func epoch() async throws -> String {
        let value = try await optionalEpoch()
        return try #require(value)
    }
    func waitForInitialAnalysis() async throws {
        try await waitForReaderTestCondition("initial settled analysis") {
            !self.webView.isLoading && !self.logger.events.isEmpty
        }
    }
    func page() async throws -> DetectionPageAnalysis {
        let value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
        let json = try #require(value as? String)
        return try JSONDecoder().decode(DetectionPageAnalysis.self, from: Data(json.utf8))
    }
}
private func hydrationHTML(direct: Bool, blocked: Bool = false) -> String {
    """
    <!doctype html><html><head>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'">
    <title>\(direct ? "Owned Chapter 169" : "Owned Series")</title>
    <style>html,body{margin:0;width:390px}img{display:block;width:390px;height:1350px}</style>
    </head><body><button id="open">Open chapter</button><main id="reader"></main>
    <script>
    window.fixtureReady = false;
    function fill() {
      document.getElementById('reader').innerHTML = '\(blocked ? "<p>Sign in to continue</p>" : "")' +
        Array.from({length:6}, (_,i) =>
        '<img src="http://127.0.0.1:1/page-'+i+'.png" width="390" height="1350" class="chapter-page" data-reader-page-image data-reader-index="'+i+'" alt="Owned chapter page">').join('');
      window.fixtureReady = true;
    }
    document.getElementById('open').onclick = function() {
      history.pushState(null,'','/series/owned-fixture/chapter-169');
      document.title = 'Owned Chapter 169';
      setTimeout(fill, window.routeDelay || 0);
    };
    \(direct ? "fill();" : "")
    </script></body></html>
    """
}
@Suite(.serialized)
@MainActor
struct BrowserHydrationRecoveryTests {
    @Test func lateRouteReceivesAnalysisAfterLegacyRetry() async throws {
        let series = URL(string: "https://vortexscans.org/series/owned-fixture")!
        let chapter = series.appendingPathComponent("chapter-169")
        let browser = HydrationBrowser(url: series)
        defer { browser.stop() }
        browser.webView.loadSimulatedRequest(URLRequest(url: series), responseHTML: hydrationHTML(direct: false))
        try await waitForReaderTestCondition("initial settled analysis") {
            !browser.webView.isLoading && !browser.logger.events.isEmpty
        }
        _ = try await browser.webView.evaluateJavaScript(
            "window.routeDelay=14000; document.getElementById('open').click(); true")
        try await waitForReaderTestCondition("legacy chapter analysis and retry", timeout: .seconds(14)) {
            browser.logger.events.filter { $0.url == chapter && $0.candidates == 0 }.count >= 2
        }
        try await waitForReaderTestCondition("14-second owned hydration", timeout: .seconds(5)) {
            (try? await browser.webView.evaluateJavaScript("window.fixtureReady === true") as? Bool) == true
        }
        try await Task.sleep(for: .milliseconds(1600))
        let page = try await browser.page()
        let manual = ProfileAwareChapterDetector(diagnosticsLogger: HydrationLogger())
            .detectBrowserSessionFollowUp(page: page)
        #expect(manual.candidates.count == 6)
        #expect(manual.diagnostics.hardBlocks.isEmpty)
        #expect(browser.logger.events.contains { $0.url == chapter && $0.candidates == 6 },
            "The ready same-URL chapter must receive an additional automatic analysis")
        try await waitForReaderTestCondition("safe late Reader handoff") { browser.model.pendingReaderSession != nil }
        let session = try #require(browser.model.pendingReaderSession)
        #expect(session.sourceURL == chapter)
        #expect(session.imageURLs.count == 6)
        #expect(browser.model.detectionResult?.readerEntryDisposition == .automatic)
        #expect(browser.model.detectionResult?.diagnostics.hardBlocks.isEmpty == true)
        #expect(await browser.client.requestCount == 1)
    }

    @Test(arguments: [true, false])
    func immediateRoutesRetainSafeHandoffAndIgnoreNoise(direct: Bool) async throws {
        let series = URL(string: "https://vortexscans.org/series/owned-fixture")!
        let chapter = series.appendingPathComponent("chapter-169")
        let browser = HydrationBrowser(url: direct ? chapter : series)
        defer { browser.stop() }
        browser.webView.loadSimulatedRequest(URLRequest(url: direct ? chapter : series),
            responseHTML: hydrationHTML(direct: direct))
        try await browser.waitForInitialAnalysis()
        if !direct {
            _ = try await browser.webView.evaluateJavaScript("document.getElementById('open').click(); true")
        }
        try await waitForReaderTestCondition("immediate Reader handoff") { browser.model.pendingReaderSession != nil }
        let completed = browser.logger.events.count
        let session = browser.model.pendingReaderSession
        _ = try await browser.webView.evaluateJavaScript("""
            for (let i=0;i<100;i++) {
              const node=document.createElement('span'); node.textContent='owned noise'; document.body.append(node); node.remove();
              document.querySelector('img').setAttribute('src', 'http://127.0.0.1:1/page-0.png');
            } true;
            """)
        try await Task.sleep(for: .milliseconds(1200))
        #expect(browser.logger.events.count == completed)
        #expect(browser.model.pendingReaderSession == session)
        #expect(session?.sourceURL == chapter)
        #expect(await browser.client.requestCount == 1)
    }

    @Test(arguments: ["blocked", "unreadable", "visibility", "marker", "index"])
    func readinessChangesPreserveEligibilityAndSafety(scenario: String) async throws {
        let url = URL(string: "https://fixture.toonedge.test/chapter-169")!
        let blocked = scenario == "blocked"
        let client = HydrationHTTPClient(unreadable: scenario == "unreadable")
        let browser = HydrationBrowser(url: url, client: client)
        defer { browser.stop() }
        if blocked || scenario == "unreadable" {
            browser.webView.loadSimulatedRequest(URLRequest(url: url),
                responseHTML: hydrationHTML(direct: false, blocked: blocked))
            try await browser.waitForInitialAnalysis()
            _ = try await browser.webView.evaluateJavaScript("fill(); true")
            try await waitForReaderTestCondition("readiness analysis") { browser.logger.events.count >= 2 }
            if blocked {
                try await waitForReaderTestCondition("blocked result") {
                    browser.model.detectionResult?.diagnostics.hardBlocks.contains(.authentication) == true
                }
                #expect(await client.requestCount == 0)
            } else {
                try await waitForReaderTestCondition("unreadable fallback") { browser.model.readerUnavailableMessage != nil }
                #expect(await client.requestCount == 1)
            }
            browser.model.enterCleanModeManually()
            #expect(browser.model.pendingReaderSession == nil)
            #expect(browser.model.cleanModePresentation == .hidden)
            #expect(browser.model.detectionResult?.readerEntryDisposition == .unavailable)
            #expect(browser.model.currentURL == url)
            return
        }

        let setup: String
        let change: String
        if scenario == "visibility" {
            setup = """
                fill();
                const reader=document.getElementById('reader');
                reader.style.visibility='hidden';
                Array.from(reader.querySelectorAll('img')).forEach((image,index) => {
                  if (index >= 3) image.remove();
                  else { image.style.height='4500px'; image.height=4500; }
                });
                """
            change = "document.getElementById('reader').style.visibility='visible'; true"
        } else if scenario == "marker" {
            setup = """
                fill();
                document.querySelectorAll('img').forEach(image => {
                  image.style.width='240px'; image.width=240;
                  image.removeAttribute('data-reader-page-image');
                });
                """
            change = "document.querySelectorAll('img').forEach(image => image.setAttribute('data-reader-page-image','')); true"
        } else {
            setup = """
                fill();
                document.getElementById('reader').id='content';
                document.querySelectorAll('img').forEach(image => {
                  image.style.width='240px'; image.width=240;
                  image.className=''; image.alt='Owned';
                  image.removeAttribute('data-reader-index');
                });
                """
            change = "document.querySelectorAll('img').forEach(image => image.setAttribute('data-reader-index','')); true"
        }
        let html = hydrationHTML(direct: true).replacingOccurrences(of: "fill();", with: setup)
        browser.webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: html)
        try await browser.waitForInitialAnalysis()
        try await waitForReaderTestCondition("initial unavailable result") { browser.model.detectionResult != nil }
        let initial = try #require(browser.model.detectionResult)
        #expect(initial.readerEntryDisposition == .unavailable)
        #expect(initial.candidates.count == (scenario == "visibility" ? 3 : 0))
        #expect(browser.model.pendingReaderSession == nil)
        #expect(await client.requestCount == 0)
        let beforePage = try await browser.page()
        let beforeResult = ProfileAwareChapterDetector(diagnosticsLogger: HydrationLogger()).detect(page: beforePage)
        #expect(beforeResult.readerEntryDisposition == .unavailable)
        if scenario == "visibility" {
            #expect(beforePage.images.allSatisfy { $0.renderedHeight == 0 })
        } else {
            #expect(beforeResult.candidates.isEmpty)
            let marker = scenario == "marker" ? "data-reader-page-image" : "data-reader-index"
            #expect(beforePage.images.allSatisfy { !$0.semanticHints.contains(marker) })
        }

        // Recovery is still active: these mutations must consume no extra full analysis.
        let completed = browser.logger.events.count
        _ = try await browser.webView.evaluateJavaScript("""
            for (let i=0;i<100;i++) {
              const node=document.createElement('span'); node.textContent='owned noise'; document.body.append(node); node.remove();
              const image=document.querySelector('img'); image.setAttribute('src',image.getAttribute('src'));
            } true;
            """)
        try await Task.sleep(for: .milliseconds(900))
        #expect(browser.logger.events.count == completed)
        #expect(await client.requestCount == 0)

        // Only inherited visibility or an absent-to-empty semantic attribute changes.
        _ = try await browser.webView.evaluateJavaScript(change)
        let afterPage = try await browser.page()
        let afterResult = ProfileAwareChapterDetector(diagnosticsLogger: HydrationLogger()).detect(page: afterPage)
        #expect(afterResult.readerEntryDisposition == .automatic)
        #expect(afterResult.candidates.count == (scenario == "visibility" ? 3 : 6))
        #expect(afterResult.diagnostics.hardBlocks.isEmpty)
        if scenario == "visibility" {
            #expect(afterPage.images.allSatisfy { ($0.renderedHeight ?? 0) > 0 })
        } else {
            let marker = scenario == "marker" ? "data-reader-page-image" : "data-reader-index"
            #expect(afterPage.images.allSatisfy { $0.semanticHints.contains(marker) })
        }
        // Convert the expected missing signal into explicit semantic assertions in RED.
        try? await waitForReaderTestCondition("readiness-only safe handoff", timeout: .seconds(2)) {
            browser.model.pendingReaderSession != nil
        }
        #expect(browser.logger.events.count == completed + 1,
            "A readiness-only semantic change must receive one additional real detector pass")
        #expect(browser.model.pendingReaderSession?.sourceURL == url,
            "The newly eligible owned chapter must reach safe Reader handoff")
        #expect(browser.model.pendingReaderSession?.imageURLs.count == afterResult.candidates.count)
        #expect(await client.requestCount == 1)
    }

    @Test(arguments: ["sameURL", "differentURL", "replacement", "teardown"])
    func stalePreflightAndMessagesCannotDeliverOrRecreateWork(action: String) async throws {
        let url = URL(string: "https://fixture.toonedge.test/chapter-169")!
        let client = HydrationHTTPClient(hold: true)
        defer { Task { await client.release() } }
        let browser = HydrationBrowser(url: url, client: client)
        defer { browser.stop() }
        browser.webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: hydrationHTML(direct: true))
        try await waitForReaderTestCondition("held real preflight") { await client.requestCount == 1 }
        let oldEpoch = try await browser.epoch()
        var replacement: WKWebView?
        if action == "sameURL" || action == "differentURL" {
            let destination = action == "sameURL" ? url : url.deletingLastPathComponent().appendingPathComponent("chapter-170")
            browser.webView.loadSimulatedRequest(URLRequest(url: destination), responseHTML: hydrationHTML(direct: false))
            try await waitForReaderTestCondition("fresh document epoch") {
                let epoch = try? await browser.optionalEpoch()
                return !browser.webView.isLoading && epoch != nil && epoch != oldEpoch
                    && browser.logger.events.contains { $0.candidates == 0 }
            }
        } else if action == "replacement" {
            replacement = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
            browser.coordinator.attach(replacement!)
        } else { browser.coordinator.teardown() }
        let completed = browser.logger.events.count
        browser.coordinator.receiveReadinessMessage(["epoch": oldEpoch, "revision": 1], from: browser.webView, isMainFrame: true)
        if action == "replacement" || action == "teardown" {
            browser.coordinator.webView(browser.webView, didFinish: nil)
        }
        await client.release()
        try await Task.sleep(for: .milliseconds(1200))
        #expect(browser.model.pendingReaderSession == nil)
        #expect(browser.model.cleanModePresentation == .hidden)
        #expect(browser.logger.events.count == completed)
        #expect(await client.requestCount == 1)
        withExtendedLifetime(replacement) {}
    }

    @Test func fixedWindowAttemptAndCancellationBoundaries() {
        var policy = BrowserHydrationRecoveryPolicy(startedAt: 100)
        let beforeStart = policy.takeAttempt(at: 99)
        #expect(!beforeStart)
        for time in [100.0, 114, 120, 129.999] {
            let allowed = policy.takeAttempt(at: time)
            #expect(allowed)
        }
        #expect(policy.attempts == 4)
        let overBudget = policy.takeAttempt(at: 129.999)
        #expect(!overBudget)
        var expired = BrowserHydrationRecoveryPolicy(startedAt: 100)
        let atDeadline = expired.takeAttempt(at: 130)
        #expect(!atDeadline)
        let afterDeadline = expired.takeAttempt(at: 145)
        #expect(!afterDeadline)
        var cancelled = BrowserHydrationRecoveryPolicy(startedAt: 100)
        cancelled.stop()
        let afterStop = cancelled.takeAttempt(at: 114)
        #expect(!afterStop)
        let fresh = BrowserHydrationRecoveryPolicy(startedAt: 140)
        #expect(fresh.canAttempt(at: 154))
    }

    @Test func malformedDuplicateAndWrongSourceSignalsCannotAuthorizeAnalysis() async throws {
        let url = URL(string: "https://fixture.toonedge.test/chapter-169")!
        let browser = HydrationBrowser(url: url)
        defer { browser.stop() }
        browser.webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: hydrationHTML(direct: false))
        try await browser.waitForInitialAnalysis()
        let epoch = try await browser.epoch()
        let other = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let valid: [String: Any] = ["epoch": epoch, "revision": 1]
        let completed = browser.logger.events.count
        let malformedBodies: [Any] = ["bad", [:] as [String: Any],
            ["epoch":epoch, "revision":"1"], ["epoch":epoch, "revision":true],
            ["epoch":UUID().uuidString, "revision":1], ["epoch":epoch, "revision":0],
            ["epoch":epoch, "revision":1, "extra":true]]
        for body in malformedBodies {
            browser.coordinator.receiveReadinessMessage(body, from: browser.webView, isMainFrame: true)
        }
        browser.coordinator.receiveReadinessMessage(valid, from: browser.webView, isMainFrame: false)
        browser.coordinator.receiveReadinessMessage(valid, from: other, isMainFrame: true)
        try await Task.sleep(for: .milliseconds(700))
        #expect(browser.logger.events.count == completed)
        browser.coordinator.receiveReadinessMessage(valid, from: browser.webView, isMainFrame: true)
        try await waitForReaderTestCondition("valid scheduling hint") { browser.logger.events.count == completed + 1 }
        for _ in 0..<100 { browser.coordinator.receiveReadinessMessage(valid, from: browser.webView, isMainFrame: true) }
        try await Task.sleep(for: .milliseconds(700))
        #expect(browser.logger.events.count == completed + 1)
        #expect(browser.model.pendingReaderSession == nil)
    }

    @Test func changingImageStormUsesFiniteAnalysisBudget() async throws {
        let url = URL(string: "https://fixture.toonedge.test/chapter-169")!
        let browser = HydrationBrowser(url: url)
        defer { browser.stop() }
        browser.webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: hydrationHTML(direct: false))
        try await browser.waitForInitialAnalysis()
        let initial = browser.logger.events.count
        _ = try await browser.webView.evaluateJavaScript("""
            document.getElementById('reader').innerHTML = '<img id="tiny" src="http://127.0.0.1:1/tiny.png" style="width:10px;height:10px">'; true;
            """)
        for index in 1...7 {
            try await Task.sleep(for: .milliseconds(650))
            _ = try await browser.webView.evaluateJavaScript("""
                for (let i=0;i<100;i++) {
                  document.getElementById('tiny').src='http://127.0.0.1:1/tiny-\(index).png';
                  const noise=document.createElement('span'); document.body.append(noise); noise.remove();
                } true;
                """)
        }
        try await Task.sleep(for: .milliseconds(800))
        #expect(browser.logger.events.count == initial + BrowserHydrationRecoveryPolicy.maximumAttempts)
        #expect(await browser.client.requestCount == 0)
        #expect(browser.model.pendingReaderSession == nil)
    }

    @Test func readinessDuringPreflightCoalescesWithoutDuplicateHandoff() async throws {
        let url = URL(string: "https://fixture.toonedge.test/chapter-169")!
        let client = HydrationHTTPClient(hold: true)
        defer { Task { await client.release() } }
        let browser = HydrationBrowser(url: url, client: client)
        defer { browser.stop() }
        browser.webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: hydrationHTML(direct: true))
        try await waitForReaderTestCondition("held real preflight") { await client.requestCount == 1 }
        _ = try await browser.webView.evaluateJavaScript("document.querySelector('img').src='http://127.0.0.1:1/changed.png'; true")
        try await Task.sleep(for: .milliseconds(800))
        #expect(await client.requestCount == 1)
        #expect(browser.logger.events.count == 1)
        await client.release()
        try await waitForReaderTestCondition("single safe handoff") { browser.model.pendingReaderSession != nil }
        try await Task.sleep(for: .milliseconds(800))
        #expect(browser.logger.events.count == 1)
        #expect(await client.requestCount == 1)
    }
}

private actor HydrationHTTPClient: HTTPDataLoading {
    private let hold: Bool
    private let unreadable: Bool
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var requestCount = 0
    init(hold: Bool = false, unreadable: Bool = false) { self.hold = hold; self.unreadable = unreadable }
    func data(from url: URL) async throws -> HTTPDataResponse { try await data(for: URLRequest(url: url)) }
    func data(for request: URLRequest) async throws -> HTTPDataResponse {
        requestCount += 1
        if hold && !released { await withCheckedContinuation { waiters.append($0) } }
        let bytes: Data
        if unreadable { bytes = Data("<html>not an image</html>".utf8) }
        else { bytes = try await MainActor.run { try ownedHydrationPNG() } }
        return HTTPDataResponse(data: bytes, statusCode: 200)
    }
    func release() {
        released = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
@MainActor
private func ownedHydrationPNG() throws -> Data {
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let bitmap = try #require(CGContext(data: nil, width: 2, height: 2,
        bitsPerComponent: 8, bytesPerRow: 8, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
    bitmap.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    bitmap.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    let image = try #require(bitmap.makeImage())
    let bytes = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(bytes as CFMutableData,
        "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    let png = bytes as Data
    let imageSource = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    #expect(CGImageSourceCreateImageAtIndex(imageSource, 0, nil) != nil)
    return png
}
