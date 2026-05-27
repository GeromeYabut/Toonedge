import Foundation
import Testing
@testable import ToonEdgeAppCore

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

    await #expect(throws: AdjacentReaderSessionLoadError.unavailable) {
        _ = try await loader.loadAdjacentReaderSession(
            from: sourceURL,
            context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
        )
    }
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

    await #expect(throws: AdjacentReaderSessionLoadError.unavailable) {
        _ = try await loader.loadAdjacentReaderSession(
            from: sourceURL,
            context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
        )
    }
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

    await #expect(throws: AdjacentReaderSessionLoadError.unavailable) {
        _ = try await loader.loadAdjacentReaderSession(
            from: sourceURL,
            context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
        )
    }
}

private struct StubChapterDetector: ChapterPageDetecting {
    let result: DetectionResult

    func detect(page: DetectionPageAnalysis) -> DetectionResult {
        result
    }
}

private enum StubAdjacentPageLoader: AdjacentChapterPageLoading {
    case analysis(DetectionPageAnalysis)

    func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis {
        switch self {
        case .analysis(let analysis):
            analysis
        }
    }
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
