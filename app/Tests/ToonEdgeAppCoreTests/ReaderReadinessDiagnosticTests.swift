import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
import WebKit
@testable import ToonEdgeAppCore

private final class ReadinessTestBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func read() -> Value { lock.withLock { value } }
    func update(_ action: (inout Value) -> Void) { lock.withLock { action(&value) } }
}

private actor ReadinessHTTPClient: HTTPDataLoading {
    enum Reply: Sendable {
        case http(Data, Int)
        case transport(URLError.Code)
        case opaque
    }
    let reply: Reply
    private(set) var requests: [URLRequest] = []
    init(_ reply: Reply) { self.reply = reply }
    func data(from url: URL) async throws -> HTTPDataResponse { try await data(for: URLRequest(url: url)) }
    func data(for request: URLRequest) async throws -> HTTPDataResponse {
        requests.append(request)
        switch reply {
        case .http(let bytes, let status): return HTTPDataResponse(data: bytes, statusCode: status)
        case .transport(let code):
            throw URLError(code, userInfo: [NSURLErrorFailingURLStringErrorKey: "https://secret.invalid/private?token=secret"])
        case .opaque: throw ReadinessSecretError()
        }
    }
}
private struct ReadinessSecretError: Error, CustomStringConvertible {
    var description: String { "secret https://secret.invalid cookie=private" }
}

private func readinessSession(images: [URL]? = nil) -> MockReaderSession {
    let page = URL(string: "https://owned.toonedge.test/chapter-169?token=secret")!
    return MockReaderSession(seriesTitle: "private series", chapterTitle: "private title",
        sourceURL: page,
        imageURLs: images ?? [URL(string: "https://images.toonedge.test/first.png?token=secret")!,
                              URL(string: "https://images.toonedge.test/second.png")!],
        imageRequestContext: ReaderImageRequestContext(referer: page,
            cookieHeader: "private-cookie=secret", userAgent: "owned-private-user-agent"))
}

private func readinessPNG(width: Int = 1) throws -> Data {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let bitmap = try #require(CGContext(data: nil, width: width, height: 1,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
    bitmap.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    bitmap.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: 1))
    let image = try #require(bitmap.makeImage())
    let bytes = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(bytes as CFMutableData,
        "public.png" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    return bytes as Data
}

@Suite(.serialized)
@MainActor
struct ReaderReadinessDiagnosticTests {
    @Test func noImageReportsOneSafeOutcomeWithoutARequest() async {
        let client = ReadinessHTTPClient(.http(Data(), 200))
        let observations = ReadinessTestBox<[ReaderImagePreflightObservation]>([])
        let viable = await ReaderSessionImagePreflight(httpClient: client).isViable(
            readinessSession(images: []), observation: { item in observations.update { $0.append(item) } })
        #expect(!viable)
        #expect(await client.requests.isEmpty)
        #expect(observations.read() == [.init(outcome: .noImage)])
    }

    @Test(arguments: ["recognized", "http", "empty", "html", "timeout", "cancelled", "offline", "dns", "connection", "tls", "other", "opaque"])
    func preflightReportsTheFirstTerminalOutcomeWhilePreservingRequests(scenario: String) async throws {
        let reply: ReadinessHTTPClient.Reply
        let expected: ReaderImagePreflightObservation
        let viableExpected: Bool
        switch scenario {
        case "recognized":
            reply = .http(try readinessPNG(), 200)
            expected = .init(outcome: .recognizedImage, httpStatus: 200, pixelWidth: .small, pixelHeight: .small)
            viableExpected = true
        case "http":
            reply = .http(Data(), 403); expected = .init(outcome: .httpFailure, httpStatus: 403); viableExpected = false
        case "empty":
            reply = .http(Data(), 204); expected = .init(outcome: .emptyData, httpStatus: 204); viableExpected = false
        case "html":
            reply = .http(Data("<html>secret challenge</html>".utf8), 200)
            expected = .init(outcome: .unrecognizedImage, httpStatus: 200); viableExpected = false
        case "timeout":
            reply = .transport(.timedOut); expected = .init(outcome: .transportError, transport: .timedOut); viableExpected = false
        case "cancelled":
            reply = .transport(.cancelled); expected = .init(outcome: .transportError, transport: .cancelled); viableExpected = false
        case "offline":
            reply = .transport(.notConnectedToInternet); expected = .init(outcome: .transportError, transport: .offline); viableExpected = false
        case "dns":
            reply = .transport(.cannotFindHost); expected = .init(outcome: .transportError, transport: .dns); viableExpected = false
        case "connection":
            reply = .transport(.cannotConnectToHost); expected = .init(outcome: .transportError, transport: .connection); viableExpected = false
        case "tls":
            reply = .transport(.serverCertificateUntrusted); expected = .init(outcome: .transportError, transport: .tls); viableExpected = false
        case "other":
            reply = .transport(.badURL); expected = .init(outcome: .transportError, transport: .other); viableExpected = false
        default:
            reply = .opaque; expected = .init(outcome: .transportError, transport: .other); viableExpected = false
        }
        let client = ReadinessHTTPClient(reply)
        let observations = ReadinessTestBox<[ReaderImagePreflightObservation]>([])
        let session = readinessSession()
        let preflight = ReaderSessionImagePreflight(httpClient: client)
        let viable = await preflight.isViable(session, observation: { item in observations.update { $0.append(item) } })
        #expect(viable == viableExpected)
        #expect(observations.read() == [expected], "Exactly one safe terminal observation is required")
        let requests = await client.requests
        #expect(requests.count == 1, "Diagnostics must not retry or test another page")
        let request = try #require(requests.first)
        #expect(request.url == session.imageURLs.first)
        #expect(request.timeoutInterval == 8)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Referer") == session.sourceURL.absoluteString)
        #expect(request.value(forHTTPHeaderField: "Cookie") == "private-cookie=secret")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "owned-private-user-agent")
        #expect(!String(describing: observations.read()).contains("secret"))
        // The original call remains source compatible and makes the same decision.
        #expect(await preflight.isViable(session) == viableExpected)
        #expect(await client.requests.count == 2)
    }

    @Test(arguments: [1, 319, 320, 1023, 1024, 4095, 4096])
    func imageDimensionsAreSupplementalBuckets(width: Int) async throws {
        let client = ReadinessHTTPClient(.http(try readinessPNG(width: width), 200))
        let observed = ReadinessTestBox<[ReaderImagePreflightObservation]>([])
        #expect(await ReaderSessionImagePreflight(httpClient: client).isViable(readinessSession(),
            observation: { item in observed.update { $0.append(item) } }))
        let expected: ReaderReadinessPixelBucket = width < 320 ? .small : width < 1024 ? .medium : width < 4096 ? .large : .giant
        #expect(observed.read().map(\.pixelWidth) == [expected])
        #expect(observed.read().map(\.pixelHeight) == [.small])
    }

    @Test func requestWithoutContextRemainsUnadornedAndHasTheSameTimeout() async throws {
        let client = ReadinessHTTPClient(.http(Data(), 404))
        var session = readinessSession()
        session.imageRequestContext = nil
        let observations = ReadinessTestBox<[ReaderImagePreflightObservation]>([])
        #expect(!(await ReaderSessionImagePreflight(httpClient: client).isViable(session,
            observation: { item in observations.update { $0.append(item) } })))
        let requests = await client.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url == session.imageURLs.first)
        #expect(request.timeoutInterval == 8)
        #expect(request.allHTTPHeaderFields?.isEmpty != false)
        #expect(observations.read() == [.init(outcome: .httpFailure, httpStatus: 404)])
    }

    @Test func gateRequiresExactDebugOptInAndDefaultSinkIsSilent() {
        #expect(ReaderReadinessDiagnostics.isEnabled(arguments: ["app", "-readerReadinessDiagnostics"], debugBuild: true))
        for args in [[], ["-readerReadinessDiagnosticsExtra"], ["readerReadinessDiagnostics"], ["-uiTesting"]] {
            #expect(!ReaderReadinessDiagnostics.isEnabled(arguments: args, debugBuild: true))
        }
        #expect(!ReaderReadinessDiagnostics.isEnabled(arguments: ["-readerReadinessDiagnostics"], debugBuild: false))
        let lines = ReadinessTestBox<[String]>([])
        let sink = ReaderReadinessDiagnostics(lineWriter: { line in lines.update { $0.append(line) } })
        let nav = sink.startNavigation()
        #expect(!sink.emit(.init(navigation: nav, elapsedMs: 0, stage: .analysisStarted)))
        #expect(lines.read().isEmpty)
    }

    @Test func serializationHasOnlyTheExactSafeSchemaAndCanonicalEnums() throws {
        let lines = ReadinessTestBox<[String]>([])
        let sink = ReaderReadinessDiagnostics(enabled: true, now: { 10 },
            lineWriter: { line in lines.update { $0.append(line) } })
        let nav = sink.startNavigation()
        var event = ReaderReadinessEvent(navigation: nav, elapsedMs: 0, stage: .analysisCompleted)
        event.analysis = .initial; event.rawImages = 22; event.evidenceImages = 0
        event.parser = .genericHeuristic; event.disposition = .unavailable
        event.hardBlocks = [.paywall, .authentication, .paywall]
        #expect(sink.emit(event))
        #expect(lines.read().count == 1)
        let line = try #require(lines.read().first)
        #expect(line.hasPrefix("TOONEDGE_READINESS_V1 "))
        #expect(line.hasSuffix("\n"))
        #expect(line.utf8.count <= 4096)
        let payload = String(line.dropFirst(ReaderReadinessDiagnostics.wirePrefix.count)).trimmingCharacters(in: .newlines)
        let json = try #require(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
        #expect(Set(json.keys) == Set(["schema", "navigation", "elapsedMs", "stage", "analysis", "attempt",
            "rawImages", "evidenceImages", "candidates", "parser", "score", "disposition", "hardBlocks",
            "preflight", "httpStatus", "transport", "pixelWidth", "pixelHeight", "stop"]))
        #expect(json["schema"] as? Int == 1)
        #expect(json["navigation"] as? Int == 1)
        #expect(json["hardBlocks"] as? [String] == ["authentication", "paywall"])
        #expect(json["pixelWidth"] as? String == "unknown")
        for forbidden in ["https:", "secret", "cookie", "Referer", "User-Agent", "private title", "Data("] {
            #expect(!line.contains(forbidden))
        }
        let decoded = try JSONDecoder().decode(ReaderReadinessEvent.self, from: Data(payload.utf8))
        #expect(decoded.stage == .analysisCompleted)
        #expect(decoded.rawImages == 22)
        #expect(decoded.evidenceImages == 0)
        #expect(decoded.disposition == .unavailable)
    }

    @Test func sinkBoundsArePerNavigationPerRunAndInstanceAndRejectInvalidRanges() {
        let lines = ReadinessTestBox<[String]>([])
        let sink = ReaderReadinessDiagnostics(enabled: true, now: { 0 },
            lineWriter: { line in lines.update { $0.append(line) } })
        for expectedNav in 1...3 {
            let nav = sink.startNavigation()
            #expect(nav == expectedNav)
            let accepted = (0..<70).filter { _ in sink.emit(.init(navigation: nav, elapsedMs: 0, stage: .analysisStarted)) }.count
            #expect(accepted == (expectedNav < 3 ? 64 : 0))
        }
        #expect(lines.read().count == 128)
        #expect(lines.read().allSatisfy { $0.utf8.count <= 4096 })
        #expect(lines.read().reduce(0) { $0 + $1.utf8.count } <= 512 * 1024)
        let independent = ReaderReadinessDiagnostics(enabled: true, now: { 0 })
        #expect(independent.startNavigation() == 1)
        #expect(independent.emit(.init(navigation: 1, elapsedMs: 0, stage: .analysisStarted)))
        let freshLines = ReadinessTestBox<[String]>([])
        let fresh = ReaderReadinessDiagnostics(enabled: true, now: { 0 },
            lineWriter: { line in freshLines.update { $0.append(line) } })
        let nav = fresh.startNavigation()
        let valid = ReaderReadinessEvent(navigation: nav, elapsedMs: 0, stage: .analysisStarted)
        var invalid: [ReaderReadinessEvent] = []
        var e = valid; e.schema = 2; invalid.append(e)
        e = valid; e.navigation = 0; invalid.append(e)
        e = valid; e.navigation = 1000001; invalid.append(e)
        e = valid; e.elapsedMs = -1; invalid.append(e)
        e = valid; e.elapsedMs = 60000; invalid.append(e)
        e = valid; e.attempt = 7; invalid.append(e)
        e = valid; e.rawImages = -1; invalid.append(e)
        e = valid; e.evidenceImages = 1000001; invalid.append(e)
        e = valid; e.candidates = -1; invalid.append(e)
        e = valid; e.score = 10001; invalid.append(e)
        e = valid; e.httpStatus = 99; invalid.append(e)
        e = valid; e.httpStatus = 600; invalid.append(e)
        for event in invalid { #expect(!fresh.emit(event)) }
        #expect(freshLines.read().isEmpty)
        #expect(fresh.emit(valid), "Rejected events must not consume the accepted-event budget")
    }

    @Test func exactSixtySecondMonotonicWindowCannotBeExtendedByNewEvents() {
        let clock = ReadinessTestBox<TimeInterval>(100)
        let lines = ReadinessTestBox<[String]>([])
        let sink = ReaderReadinessDiagnostics(enabled: true, now: { clock.read() },
            lineWriter: { line in lines.update { $0.append(line) } })
        let nav = sink.startNavigation()
        clock.update { $0 = 99 }
        #expect(sink.elapsedMilliseconds(for: nav) == nil)
        #expect(!sink.emit(.init(navigation: nav, elapsedMs: 0, stage: .analysisStarted)))
        clock.update { $0 = 159.9995 }
        let elapsed = sink.elapsedMilliseconds(for: nav)
        #expect(elapsed == 59999)
        #expect(sink.emit(.init(navigation: nav, elapsedMs: 59999, stage: .analysisCompleted)))
        clock.update { $0 = 160 }
        #expect(sink.elapsedMilliseconds(for: nav) == nil)
        #expect(!sink.emit(.init(navigation: nav, elapsedMs: 59999, stage: .preflightCompleted)))
        clock.update { $0 = 161 }
        #expect(!sink.emit(.init(navigation: nav, elapsedMs: 0, stage: .handoff)))
        #expect(lines.read().count == 1)
    }

    @Test(arguments: ["automatic", "pendingDimensions", "blocked", "unreadable"])
    func actualCoordinatorBoundariesSeparateAnalysisGuardsPreflightAndHandoff(scenario: String) async throws {
        _ = NSApplication.shared
        let lines = ReadinessTestBox<[String]>([])
        let diagnostics = ReaderReadinessDiagnostics(enabled: true,
            lineWriter: { line in lines.update { $0.append(line) } })
        let url = URL(string: "https://fixture.toonedge.test/chapter-169?token=secret")!
        let model = BrowserViewModel(startPoint: .url(url.absoluteString))
        let client = ReadinessHTTPClient(scenario == "unreadable"
            ? .http(Data("<html>private response</html>".utf8), 200)
            : .http(try readinessPNG(), 200))
        let coordinator = BrowserWebView.Coordinator(viewModel: model,
            detector: ProfileAwareChapterDetector(),
            imagePreflight: ReaderSessionImagePreflight(httpClient: client), diagnostics: diagnostics)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        coordinator.attach(webView)
        defer { coordinator.teardown() }
        let images = (0..<6).map { index in
            scenario == "pendingDimensions"
                ? "<img src='https://images.invalid/secret-\(index).png' width='0' height='0'>"
                : "<img src='https://images.invalid/secret-\(index).png' width='390' height='1350' style='width:390px;height:1350px;display:block' class='chapter-page' data-reader-page-image data-reader-index='\(index)' alt='Owned chapter page'>"
        }.joined()
        let html = """
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'none'; style-src 'unsafe-inline'">
        <title>Owned Chapter 169 private title</title><body style="margin:0;width:390px">
        <main id="reader">\(scenario == "blocked" ? "<p>Sign in to continue</p>" : "")\(images)</main></body>
        """
        webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: html)
        try await waitForReaderTestCondition("owned coordinator settles existing behavior") {
            if scenario == "automatic" { return model.pendingReaderSession != nil }
            if scenario == "unreadable" { return model.readerUnavailableMessage != nil }
            return !webView.isLoading && model.detectionResult != nil
        }
        let trace = try lines.read().map { line -> ReaderReadinessEvent in
            #expect(line.hasPrefix(ReaderReadinessDiagnostics.wirePrefix))
            for forbidden in ["secret", "private", "https:", "Cookie", "User-Agent"] { #expect(!line.contains(forbidden)) }
            let payload = String(line.dropFirst(ReaderReadinessDiagnostics.wirePrefix.count))
            return try JSONDecoder().decode(ReaderReadinessEvent.self, from: Data(payload.utf8))
        }
        let stages = trace.map(\.stage)
        #expect(stages.contains(.navigationStarted))
        #expect(stages.contains(.navigationCommitted), "Commit separates an unanswered request from a slow load")
        #expect(stages.contains(.analysisStarted))
        #expect(stages.contains(.analysisCompleted), "A real detector pass must have a stage observation")
        let analysis = trace.first { $0.stage == .analysisCompleted }
        #expect(analysis?.analysis == .initial)
        #expect(analysis?.rawImages == 6)
        if scenario == "pendingDimensions" {
            #expect(analysis?.evidenceImages == 0)
            #expect(analysis?.candidates == 0)
            #expect(analysis?.disposition == .unavailable)
            #expect(analysis?.hardBlocks.contains(.nonviableSession) == true)
            #expect(trace.contains { $0.stage == .guardStopped && $0.stop == .hardBlock })
            #expect(!stages.contains(.preflightStarted))
            #expect(await client.requests.isEmpty)
        } else if scenario == "blocked" {
            #expect(analysis?.hardBlocks.contains(.authentication) == true)
            #expect(trace.contains { $0.stage == .guardStopped && $0.stop == .hardBlock })
            #expect(!stages.contains(.preflightStarted))
            #expect(await client.requests.isEmpty)
        } else {
            #expect(analysis?.evidenceImages == 6)
            #expect(analysis?.candidates == 6)
            #expect(analysis?.disposition == .automatic)
            #expect(stages.contains(.preflightStarted))
            #expect(stages.contains(.preflightCompleted))
            let preflight = trace.first { $0.stage == .preflightCompleted }
            #expect(preflight?.preflight == (scenario == "automatic" ? .recognizedImage : .unrecognizedImage))
            #expect(preflight?.httpStatus == 200)
            #expect(await client.requests.count == 1)
            if scenario == "automatic" {
                #expect(stages.contains(.handoff))
                #expect(trace.contains { $0.stage == .recoveryStopped && $0.stop == .viableResult })
                #expect(model.pendingReaderSession?.sourceURL == url)
            } else {
                #expect(!stages.contains(.handoff))
                #expect(trace.contains { $0.stage == .guardStopped && $0.stop == .unreadableImage })
                #expect(model.pendingReaderSession == nil)
            }
        }
        if let a = stages.firstIndex(of: .analysisCompleted), let p = stages.firstIndex(of: .preflightStarted) { #expect(a < p) }
        if let p = stages.firstIndex(of: .preflightCompleted), let h = stages.firstIndex(of: .handoff) { #expect(p < h) }
    }
}
