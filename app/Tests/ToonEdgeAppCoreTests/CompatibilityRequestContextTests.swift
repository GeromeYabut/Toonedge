import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func matrixRequestMetadataSurvivesBrowserPresentationAndRetry() async throws {
    // Runtime-only synthetic metadata; no cookie-store access or remote request occurs.
    let fixture = try matrixRequestFixture()
    let context = ReaderImageRequestContext(
        referer: fixture.page.pageURL,
        cookieHeader: "matrix_fixture=synthetic",
        userAgent: "Matrix Fixture Agent"
    )
    let visible = try matrixPresentRequestSession(fixture: fixture, context: context)
    let preservesContext = visible.imageRequestContext == context
    #expect(preservesContext)
    #expect(visible.imageURLs.map(\.absoluteString) == fixture.row.expected.readerURLs)
    #expect(visible.sourceURL == fixture.page.pageURL)

    let client = MatrixRequestHTTPClient()
    let loader = DefaultReaderPageAssetLoader(httpClient: client, retryDelayNanoseconds: 0)
    let imageURL = try #require(visible.imageURLs.first)
    let data = try await loader.load(imageURL: imageURL, sourceURL: visible.sourceURL,
                                     requestContext: visible.imageRequestContext)
    #expect(data == Data([1]))
    let requests = await client.requests
    #expect(requests.count == 2)
    for request in requests {
        #expect(request.url == imageURL)
        // Compare booleans so a failure never renders request headers into retained output.
        let preservesReferer = request.value(forHTTPHeaderField: "Referer") == context.referer.absoluteString
        let preservesCookie = request.value(forHTTPHeaderField: "Cookie") == context.cookieHeader
        let preservesUserAgent = request.value(forHTTPHeaderField: "User-Agent") == context.userAgent
        #expect(preservesReferer)
        #expect(preservesCookie)
        #expect(preservesUserAgent)
    }
}

@MainActor
@Test(arguments: [nil, ""] as [String?])
func matrixRequestOmitsAbsentCookieMetadata(cookieHeader: String?) async throws {
    let fixture = try matrixRequestFixture()
    let context = ReaderImageRequestContext(referer: fixture.page.pageURL, cookieHeader: cookieHeader,
                                            userAgent: "Matrix Fixture Agent")
    let visible = try matrixPresentRequestSession(fixture: fixture, context: context)
    let preservesContext = visible.imageRequestContext == context
    #expect(preservesContext)
    #expect(visible.imageURLs.map(\.absoluteString) == fixture.row.expected.readerURLs)

    let client = MatrixRequestHTTPClient()
    let loader = DefaultReaderPageAssetLoader(httpClient: client, retryDelayNanoseconds: 0)
    let imageURL = try #require(visible.imageURLs.first)
    #expect(try await loader.load(imageURL: imageURL, sourceURL: visible.sourceURL,
                                  requestContext: visible.imageRequestContext) == Data([1]))
    let requests = await client.requests
    #expect(requests.count == 2)
    for request in requests {
        #expect(request.url == imageURL)
        let omitsCookie = request.value(forHTTPHeaderField: "Cookie") == nil
        let preservesReferer = request.value(forHTTPHeaderField: "Referer") == context.referer.absoluteString
        let preservesUserAgent = request.value(forHTTPHeaderField: "User-Agent") == context.userAgent
        #expect(omitsCookie)
        #expect(preservesReferer)
        #expect(preservesUserAgent)
    }
}

private func matrixRequestFixture() throws -> (row: CompatibilityMatrixCase, page: DetectionPageAnalysis) {
    let row = try #require(loadMatrixManifest().cases.first { $0.id == "request_context" })
    #expect(row.capability == .requestContext)
    #expect(row.coverage == .partial)
    #expect(row.evidence.contains(.requestHeaders))
    var page = try loadMatrixAnalysis(named: #require(row.analysisFixture))
    // A neutral runtime URL variant makes query/fragment preservation observable.
    var components = try #require(URLComponents(url: page.pageURL, resolvingAgainstBaseURL: false))
    components.queryItems = [URLQueryItem(name: "matrix", value: "runtime")]
    components.fragment = "panel"
    page.pageURL = try #require(components.url)
    #expect(Set(row.expected.readerURLs.compactMap { URL(string: $0)?.host() }) == ["cdn.example.test"])
    return (row, page)
}

@MainActor
private func matrixPresentRequestSession(
    fixture: (row: CompatibilityMatrixCase, page: DetectionPageAnalysis), context: ReaderImageRequestContext
) throws -> MockReaderSession {
    var result = matrixDetectorResult(page: fixture.page, row: fixture.row)
    #expect(result.diagnostics.parserPath == .genericHeuristic)
    #expect(result.readerEntryDisposition == .automatic)
    #expect(result.diagnostics.hardBlocks.isEmpty)
    var session = try #require(result.readerSession)
    // The Browser coordinator supplies context after detection; emulate that boundary in memory.
    session.imageRequestContext = context
    result.readerSession = session
    let model = BrowserViewModel(startPoint: .url(fixture.page.pageURL.absoluteString))
    model.handleDetectionResult(result)
    #expect(model.browserOwnedReaderSession == nil)
    let pending = try #require(model.pendingReaderSession)
    let pendingPreservesContext = pending.imageRequestContext == context
    #expect(pendingPreservesContext)
    #expect(pending.imageURLs.map(\.absoluteString) == fixture.row.expected.readerURLs)
    model.presentPendingReaderInsideBrowser(pending)
    #expect(model.pendingReaderSession == nil)
    #expect(model.readerPresentationState == .browserOwnedReaderVisible)
    #expect(model.currentURL == fixture.page.pageURL)
    return try #require(model.browserOwnedReaderSession)
}

private actor MatrixRequestHTTPClient: HTTPDataLoading {
    private(set) var requests: [URLRequest] = []

    func data(from url: URL) async throws -> HTTPDataResponse {
        try await data(for: URLRequest(url: url))
    }

    // Override the protocol default: its URL-only forwarding discards request headers.
    func data(for request: URLRequest) async throws -> HTTPDataResponse {
        requests.append(request)
        if requests.count == 1 { throw URLError(.timedOut) }
        return HTTPDataResponse(data: Data([1]), statusCode: 200)
    }
}
