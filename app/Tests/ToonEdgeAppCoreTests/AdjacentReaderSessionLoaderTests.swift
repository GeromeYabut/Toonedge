import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func adjacentLoaderReturnsTypedChallengeAndRateLimitFailure() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2?session=secret")!
    let analysis = DetectionPageAnalysis(
        pageURL: sourceURL,
        title: "Just a moment...",
        documentHeight: 700,
        viewportWidth: 390,
        images: [],
        challengeSignals: ["http-status:429", "challenge-platform-script"]
    )
    let diagnostics = RecordingAdjacentLoadDiagnosticsLogger()
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.analysis(analysis),
        diagnosticsLogger: diagnostics
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)
    let event = try #require(await diagnostics.events.first)

    #expect(error?.reason == .challengeOrRateLimit)
    #expect(error?.targetURL == sourceURL)
    #expect(event.direction == .next)
    #expect(event.reason == .challengeOrRateLimit)
    #expect(event.targetHost == "example.com")
    #expect(event.challengeSignals == ["http-status:429", "challenge-platform-script"])
    #expect(event.parserPath == .genericHeuristic)
}

@MainActor
@Test func adjacentLoaderReturnsTypedTimeoutFailure() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.failure(URLError(.timedOut))
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)

    #expect(error?.reason == .timeout)
    #expect(error?.targetURL == sourceURL)
}

@MainActor
@Test func adjacentLoaderDoesNotBypassStaticRateLimitFixture() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.failure(URLError(.cannotConnectToHost)),
        htmlLoader: StubAdjacentHTMLLoader(
            html: """
            <html>
              <head><title>Too Many Requests</title></head>
              <body>HTTP 429 — rate limit exceeded. Try again later.</body>
            </html>
            """
        )
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)

    #expect(error?.reason == .challengeOrRateLimit)
    #expect(error?.challengeSignals == ["rate-limit-copy"])
}

@Test func adjacentHTTPResponseClassifiesChallengeBodiesBeforeGenericHTTPFailure() {
    #expect(
        AdjacentChapterHTTPResponseClassifier.failureReason(
            statusCode: 403,
            html: "<html><title>Just a moment...</title><script src=\"/challenge-platform/x.js\"></script></html>"
        ) == .challengeOrRateLimit
    )
    #expect(
        AdjacentChapterHTTPResponseClassifier.failureReason(
            statusCode: 503,
            html: "<html><body>Rate limit exceeded. Try again later.</body></html>"
        ) == .challengeOrRateLimit
    )
    #expect(
        AdjacentChapterHTTPResponseClassifier.failureReason(
            statusCode: 404,
            html: "<html><body>Not found</body></html>"
        ) == .unavailable
    )
}

@MainActor
@Test func adjacentLoaderDoesNotUseStaticFallbackToBypassChallengePage() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    let challenge = DetectionPageAnalysis(
        pageURL: sourceURL,
        title: "Just a moment...",
        documentHeight: 700,
        viewportWidth: 390,
        images: [],
        challengeSignals: ["challenge-platform-script"]
    )
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.analysis(challenge),
        htmlLoader: StubAdjacentHTMLLoader(html: vortexChapterHTML(pageNumberCount: 5))
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)

    #expect(error?.reason == .challengeOrRateLimit)
}

@MainActor
@Test func adjacentLoaderRejectsLowConfidenceDetectionResult() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    let detector = StubChapterDetector(
        result: DetectionResult(
            pageURL: sourceURL,
            confidence: .low,
            score: 0,
            candidates: [],
            readerSession: nil,
            diagnostics: DetectionDiagnostics(confidence: .low, score: 0, parserPath: .genericHeuristic)
        )
    )
    let loader = AdjacentReaderSessionLoader(
        detector: detector,
        pageLoader: StubAdjacentPageLoader.analysis(.mockLowConfidencePage(url: sourceURL))
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)

    #expect(error?.reason == .lowConfidence)
    #expect(error?.targetURL == sourceURL)
    #expect(error?.confidence == .low)
}

@MainActor
@Test func adjacentLoaderPromotesOnlyHighConfidenceViableSession() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    var session = MockReaderSession.sample
    session.sourceURL = sourceURL
    session.imageURLs = [URL(string: "https://cdn.example.com/chapter-2/page-1.webp")!]
    let result = DetectionResult(
        pageURL: sourceURL,
        confidence: .high,
        score: 100,
        candidates: [],
        readerSession: session,
        diagnostics: DetectionDiagnostics(confidence: .high, score: 100, parserPath: .genericHeuristic)
    )
    var current = MockReaderSession.sample
    current.launchOrigin = .library(seriesID: current.seriesID)
    let loader = AdjacentReaderSessionLoader(
        detector: StubChapterDetector(result: result),
        pageLoader: StubAdjacentPageLoader.analysis(.mockHighConfidencePage(url: sourceURL))
    )

    let loaded = try await loader.loadAdjacentReaderSession(
        from: sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: current, direction: .next)
    )

    #expect(loaded.sourceURL == sourceURL)
    #expect(loaded.launchOrigin == current.launchOrigin)
    #expect(!loaded.imageURLs.isEmpty)
}

@MainActor
@Test func adjacentLoaderFallsBackToStaticHTMLForVortexReaderPageWhenHiddenLoadFails() async throws {
    let sourceURL = URL(string: "https://vortexscans.org/series/past-life-returner/chapter-170")!
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.failure(URLError(.timedOut)),
        htmlLoader: StubAdjacentHTMLLoader(
            html: """
            <html>
              <head><title>Past Life Returner Chapter 170</title></head>
              <body>
                <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-0001.webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page 1" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="0"></figure>
                <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-0002.webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page 2" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="1"></figure>
                <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-0003.webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page 3" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="2"></figure>
                <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-0004.webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page 4" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="3"></figure>
                <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-0005.webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page 5" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="4"></figure>
                <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-0006.webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page 6" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="5"></figure>
                <nav aria-label="Chapter navigation">
                  <a href="/series/past-life-returner/chapter-169">Prev</a>
                  <a href="/series/past-life-returner/chapter-171">Next</a>
                </nav>
              </body>
            </html>
            """
        )
    )

    let loaded = try await loader.loadAdjacentReaderSession(
        from: sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
    )

    #expect(loaded.sourceURL == sourceURL)
    #expect(loaded.chapterTitle == "Past Life Returner Chapter 170")
    #expect(loaded.imageURLs.count == 6)
    #expect(loaded.previousChapter?.sourceURL == URL(string: "https://vortexscans.org/series/past-life-returner/chapter-169")!)
    #expect(loaded.nextChapter?.sourceURL == URL(string: "https://vortexscans.org/series/past-life-returner/chapter-171")!)
}

@MainActor
@Test func adjacentLoaderFallsBackToStaticHTMLWhenHiddenAnalysisIsNotViable() async throws {
    let sourceURL = URL(string: "https://vortexscans.org/series/past-life-returner/chapter-170")!
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.analysis(
            DetectionPageAnalysis(
                pageURL: sourceURL,
                title: "Past Life Returner Chapter 170",
                documentHeight: 1_000,
                viewportWidth: 390,
                images: []
            )
        ),
        htmlLoader: StubAdjacentHTMLLoader(html: vortexChapterHTML(pageNumberCount: 6))
    )

    let loaded = try await loader.loadAdjacentReaderSession(
        from: sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
    )

    #expect(loaded.sourceURL == sourceURL)
    #expect(loaded.imageURLs.count == 6)
}

@MainActor
@Test func adjacentLoaderStaticHTMLFallbackWorksWithProductionProfileAwareDetector() async throws {
    let sourceURL = URL(string: "https://vortexscans.org/series/past-life-returner/chapter-170")!
    let loader = AdjacentReaderSessionLoader(
        detector: ProfileAwareChapterDetector(),
        pageLoader: StubAdjacentPageLoader.analysis(
            DetectionPageAnalysis(
                pageURL: sourceURL,
                title: "Past Life Returner Chapter 170",
                documentHeight: 1_000,
                viewportWidth: 390,
                images: []
            )
        ),
        htmlLoader: StubAdjacentHTMLLoader(html: vortexChapterHTML(pageNumberCount: 6))
    )

    let loaded = try await loader.loadAdjacentReaderSession(
        from: sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
    )

    #expect(loaded.sourceURL == sourceURL)
    #expect(loaded.imageURLs.count == 6)
}

@MainActor
@Test func adjacentLoaderExtractsStaticHTMLNavigationWhenLabelsContainIconEntities() async throws {
    let sourceURL = URL(string: "https://vortexscans.org/series/past-life-returner/chapter-170")!
    let loader = AdjacentReaderSessionLoader(
        detector: GenericChapterDetector(),
        pageLoader: StubAdjacentPageLoader.failure(URLError(.timedOut)),
        htmlLoader: StubAdjacentHTMLLoader(
            html: """
            <html>
              <head><title>Past Life Returner Chapter 170</title></head>
              <body>
                \(vortexImageTags(pageNumberCount: 6))
                <nav aria-label="Chapter navigation">
                  <a href="/series/past-life-returner/chapter-169"><span aria-hidden="true">&larr;</span>Prev</a>
                  <a href="/series/past-life-returner/chapter-171">Next<span aria-hidden="true">&rarr;</span></a>
                </nav>
              </body>
            </html>
            """
        )
    )

    let loaded = try await loader.loadAdjacentReaderSession(
        from: sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
    )

    #expect(loaded.previousChapter?.sourceURL == URL(string: "https://vortexscans.org/series/past-life-returner/chapter-169")!)
    #expect(loaded.nextChapter?.sourceURL == URL(string: "https://vortexscans.org/series/past-life-returner/chapter-171")!)
}

@MainActor
@Test func adjacentLoaderRejectsHighConfidenceBlankSession() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    var session = MockReaderSession.sample
    session.sourceURL = sourceURL
    session.imageURLs = []
    let result = DetectionResult(
        pageURL: sourceURL,
        confidence: .high,
        score: 100,
        candidates: [],
        readerSession: session,
        diagnostics: DetectionDiagnostics(confidence: .high, score: 100, parserPath: .genericHeuristic)
    )
    let loader = AdjacentReaderSessionLoader(
        detector: StubChapterDetector(result: result),
        pageLoader: StubAdjacentPageLoader.analysis(.mockHighConfidencePage(url: sourceURL))
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)

    #expect(error?.reason == .nonViableImages)
}

@MainActor
@Test func adjacentLoaderRejectsHighConfidenceStockImageSession() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    var session = MockReaderSession.sample
    session.sourceURL = sourceURL
    let result = DetectionResult(
        pageURL: sourceURL,
        confidence: .high,
        score: 100,
        candidates: [],
        readerSession: session,
        diagnostics: DetectionDiagnostics(confidence: .high, score: 100, parserPath: .genericHeuristic)
    )
    let loader = AdjacentReaderSessionLoader(
        detector: StubChapterDetector(result: result),
        pageLoader: StubAdjacentPageLoader.analysis(.mockHighConfidencePage(url: sourceURL))
    )

    let error = await capturedAdjacentLoadError(loader: loader, url: sourceURL)

    #expect(error?.reason == .nonViableImages)
}

private struct StubChapterDetector: ChapterPageDetecting {
    let result: DetectionResult

    func detect(page: DetectionPageAnalysis) -> DetectionResult {
        result
    }
}

private enum StubAdjacentPageLoader: AdjacentChapterPageLoading {
    case analysis(DetectionPageAnalysis)
    case failure(Error)

    func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis {
        switch self {
        case .analysis(let analysis):
            analysis
        case .failure(let error):
            throw error
        }
    }
}

private struct StubAdjacentHTMLLoader: AdjacentChapterHTMLLoading {
    let html: String

    func loadHTML(from url: URL) async throws -> String {
        html
    }
}

private actor RecordingAdjacentLoadDiagnosticsLogger: AdjacentReaderSessionLoadDiagnosticsLogging {
    private(set) var events: [AdjacentReaderSessionLoadDiagnostic] = []

    func log(_ diagnostic: AdjacentReaderSessionLoadDiagnostic) {
        events.append(diagnostic)
    }
}

@MainActor
private func capturedAdjacentLoadError(
    loader: AdjacentReaderSessionLoader,
    url: URL
) async -> AdjacentReaderSessionLoadError? {
    do {
        _ = try await loader.loadAdjacentReaderSession(
            from: url,
            context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
        )
        return nil
    } catch let error as AdjacentReaderSessionLoadError {
        return error
    } catch {
        return nil
    }
}

private func vortexChapterHTML(pageNumberCount: Int) -> String {
    return """
    <html>
      <head><title>Past Life Returner Chapter 170</title></head>
      <body>
        \(vortexImageTags(pageNumberCount: pageNumberCount))
        <nav aria-label="Chapter navigation">
          <a href="/series/past-life-returner/chapter-169">Prev</a>
          <a href="/series/past-life-returner/chapter-171">Next</a>
        </nav>
      </body>
    </html>
    """
}

private func vortexImageTags(pageNumberCount: Int) -> String {
    (1...pageNumberCount).map { page in
        """
        <figure><img src="https://storage.vortexscans.org/upload/series/past-life-returner/chapter-170/page-\(String(format: "%04d", page)).webp" width="800" height="5000" alt="Past Life Returner Chapter 170 Page \(page)" class="h-auto w-full object-contain" data-reader-page-image data-reader-index="\(page - 1)"></figure>
        """
    }.joined(separator: "\n")
}

private extension DetectionPageAnalysis {
    static func mockLowConfidencePage(url: URL) -> DetectionPageAnalysis {
        DetectionPageAnalysis(
            pageURL: url,
            title: "Chapter 2",
            documentHeight: 1_200,
            viewportWidth: 390,
            images: []
        )
    }

    static func mockHighConfidencePage(url: URL) -> DetectionPageAnalysis {
        DetectionPageAnalysis(
            pageURL: url,
            title: "Chapter 2",
            documentHeight: 12_000,
            viewportWidth: 390,
            images: [
                DetectionImageCandidate(
                    src: "https://cdn.example.com/chapter-2/page-1.webp",
                    lazySources: [],
                    srcset: nil,
                    width: 800,
                    height: 1_600,
                    top: 0,
                    left: 0,
                    className: "chapter-page",
                    id: nil,
                    alt: "Page 1",
                    parentSignature: "reader"
                )
            ]
        )
    }
}
