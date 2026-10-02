import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func prefetchWindowIncludesOneBehindAndTwoAhead() {
    let policy = ReaderPrefetchPolicy(behind: 1, ahead: 2, maximumConcurrentLoads: 3)

    #expect(policy.targetIndexes(current: 4, pageCount: 10) == [4, 5, 6, 3])
    #expect(policy.targetIndexes(current: 0, pageCount: 2) == [0, 1])
}

@Test func assetLoaderUsesCacheWithoutNetwork() async throws {
    let cache = SpyChapterAssetCache(data: Data([1, 2, 3]))
    let http = SpyHTTPDataLoader()
    let loader = DefaultReaderPageAssetLoader(cache: cache, httpClient: http)
    let data = try await loader.load(
        imageURL: try #require(URL(string: "https://cdn.example/page.jpg")),
        sourceURL: try #require(URL(string: "https://reader.example/chapter-1")),
        requestContext: nil
    )

    #expect(data == Data([1, 2, 3]))
    #expect(await http.requestCount == 0)
}

@Test func assetLoaderRetriesTimeoutWithOriginalRequestHeaders() async throws {
    let http = SequencedReaderHTTPClient(results: [
        .failure(URLError(.timedOut)),
        .success(HTTPDataResponse(data: Data([7, 8]), statusCode: 200))
    ])
    let imageURL = try #require(URL(string: "https://cdn.example/page.jpg"))
    let sourceURL = try #require(URL(string: "https://reader.example/chapter-1"))
    let context = ReaderImageRequestContext(
        referer: sourceURL, cookieHeader: "session=fixture", userAgent: "Fixture Reader"
    )
    let loader = DefaultReaderPageAssetLoader(httpClient: http, retryDelayNanoseconds: 0)

    let data = try await loader.load(imageURL: imageURL, sourceURL: sourceURL, requestContext: context)

    #expect(data == Data([7, 8]))
    let requests = await http.requests
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { request in
        request.url == imageURL &&
        request.value(forHTTPHeaderField: "Referer") == sourceURL.absoluteString &&
        request.value(forHTTPHeaderField: "Cookie") == "session=fixture" &&
        request.value(forHTTPHeaderField: "User-Agent") == "Fixture Reader"
    })
}

@Test func assetLoaderCancellationDuringRetryDelayStopsFurtherAttempts() async throws {
    let http = SequencedReaderHTTPClient(results: [.failure(URLError(.timedOut))])
    let loader = DefaultReaderPageAssetLoader(httpClient: http, retryDelayNanoseconds: 1_000_000_000)
    let imageURL = try #require(URL(string: "https://cdn.example/page.jpg"))
    let sourceURL = try #require(URL(string: "https://reader.example/chapter-1"))
    let task = Task {
        try await loader.load(imageURL: imageURL, sourceURL: sourceURL, requestContext: nil)
    }

    try await http.waitForRequestCount(1)
    try await Task.sleep(for: .milliseconds(30))
    #expect(await http.requests.count == 1)
    task.cancel()
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    #expect(await http.requests.count == 1)
}

@Test func imageDecoderRejectsNonImageBytes() async {
    await #expect(throws: ReaderImageDecodeError.invalidImage) {
        try await ImageIOReaderImageDecoder().decode(Data("not-image".utf8))
    }
}

@Test func imageDecoderCancelsBeforeReturningDecodedImage() async throws {
    let data = try #require(validPNGData)
    let task = Task {
        try await ImageIOReaderImageDecoder().decode(data)
    }
    task.cancel()

    await #expect(throws: CancellationError.self) {
        _ = try await task.value
    }
}

@Test func imageDecoderRechecksCancellationAfterDetachedTaskCompletes() async throws {
    let data = try #require(validPNGData)
    let gate = ReaderImageDecoderReturnGate()
    let decoder = ImageIOReaderImageDecoder(beforeReturning: {
        await gate.waitForRelease()
    })
    let task = Task {
        try await decoder.decode(data)
    }

    await gate.waitUntilDecoderIsReadyToReturn()
    task.cancel()
    await gate.release()

    await #expect(throws: CancellationError.self) {
        _ = try await task.value
    }
}

@Test func imageDecoderDecodesValidImageWithPixelDimensions() async throws {
    let data = try #require(validPNGData)

    let image = try await ImageIOReaderImageDecoder().decode(data)

    #expect(image.pixelWidth == 1)
    #expect(image.pixelHeight == 1)
}

private let validPNGData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==")

private actor ReaderImageDecoderReturnGate {
    private var isDecoderReadyToReturn = false
    private var readyContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilDecoderIsReadyToReturn() async {
        guard !isDecoderReadyToReturn else { return }
        await withCheckedContinuation { continuation in
            readyContinuation = continuation
        }
    }

    func waitForRelease() async {
        isDecoderReadyToReturn = true
        readyContinuation?.resume()
        readyContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private final class SpyChapterAssetCache: ChapterAssetCaching, @unchecked Sendable {
    private let fileURL: URL

    init(data: Data) {
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? data.write(to: fileURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func chapterDirectory(for sourceURL: URL) -> URL {
        FileManager.default.temporaryDirectory
    }

    func cachedAssetURL(for assetURL: URL, sourceURL: URL) -> URL? {
        FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func store(_ data: Data, for assetURL: URL, sourceURL: URL) throws {}
}

private actor SpyHTTPDataLoader: HTTPDataLoading {
    private(set) var requestCount = 0

    func data(from url: URL) async throws -> HTTPDataResponse {
        requestCount += 1
        return HTTPDataResponse(data: Data(), statusCode: 500)
    }
}

private actor SequencedReaderHTTPClient: HTTPDataLoading {
    private var results: [Result<HTTPDataResponse, Error>]
    private(set) var requests: [URLRequest] = []

    init(results: [Result<HTTPDataResponse, Error>]) { self.results = results }

    func data(from url: URL) async throws -> HTTPDataResponse {
        try await data(for: URLRequest(url: url))
    }

    func data(for request: URLRequest) async throws -> HTTPDataResponse {
        requests.append(request)
        guard !results.isEmpty else { throw URLError(.badServerResponse) }
        return try results.removeFirst().get()
    }

    func waitForRequestCount(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while requests.count < count && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(requests.count >= count)
    }
}

@Test @MainActor func pipelineBoundsConcurrentLoadsAndSuppressesCancelledResults() async throws {
    let loader = SuspendedReaderAssetLoader()
    let pipeline = ReaderPagePipeline(
        session: .pipelineFixture(pageCount: 8),
        assetLoader: loader,
        decoder: ImageIOReaderImageDecoder(),
        policy: .init(behind: 1, ahead: 2, maximumConcurrentLoads: 3)
    )

    pipeline.updateVisibleIndex(3)
    try await loader.waitForRequestCount(3)
    #expect(await loader.maximumConcurrentRequests == 3)
    pipeline.cancel()
    try await loader.waitForCancellationCount(3)
    await loader.completeAll()
    try await loader.waitForNoActiveRequests()
    let didDrain = await pipeline.waitForWorkToDrain()
    #expect(didDrain)
    #expect(pipeline.states.values.allSatisfy { $0.status == .idle })
}

@Test @MainActor func pipelineEnforcesGlobalConcurrencyCapWhenPolicyRequestsMore() async throws {
    let loader = SuspendedReaderAssetLoader()
    let pipeline = ReaderPagePipeline(
        session: .pipelineFixture(pageCount: 8),
        assetLoader: loader,
        policy: .init(behind: 2, ahead: 4, maximumConcurrentLoads: 7)
    )

    pipeline.updateVisibleIndex(3)
    try await loader.waitForRequestCount(3)
    #expect(await loader.requestCount == 3)
    #expect(await loader.maximumConcurrentRequests == 3)
    pipeline.cancel()
    try await loader.waitForCancellationCount(3)
    await loader.completeAll()
    try await loader.waitForNoActiveRequests()
    let didDrain = await pipeline.waitForWorkToDrain()
    #expect(didDrain)
}

@Test @MainActor func pipelineDeduplicatesRepeatedURLsWithinTheWorkingWindow() async throws {
    let loader = SuspendedReaderAssetLoader()
    var session = MockReaderSession.pipelineFixture(pageCount: 3)
    session.imageURLs[1] = session.imageURLs[0]
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 0, ahead: 2, maximumConcurrentLoads: 3)
    )

    pipeline.updateVisibleIndex(0)
    try await loader.waitForRequestCount(2)
    #expect(await loader.requestedURLs.filter { $0 == session.imageURLs[0] }.count == 1)
    await loader.completeAll()
    try await waitForPipelineState { pipeline.states[0]?.status == .ready && pipeline.states[1]?.status == .ready }
    #expect(pipeline.states[0]?.image != nil)
    #expect(pipeline.states[1]?.image != nil)
    pipeline.cancel()
}

@Test @MainActor func reversedVisibilityWaitsForCancelledFetchBeforeStartingNewWork() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 7)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 1, ahead: 2, maximumConcurrentLoads: 1)
    )

    pipeline.updateVisibleIndex(3)
    try await loader.waitForRequestCount(1)
    pipeline.updateVisibleIndex(0)
    try await loader.waitForCancellationCount(1)
    #expect(await loader.requestedURLs == [session.imageURLs[3]])
    await loader.complete(url: session.imageURLs[3])
    try await loader.waitForRequestCount(2)
    #expect(await loader.requestedURLs[1] == session.imageURLs[0])
    #expect(await loader.maximumConcurrentRequests == 1)
    pipeline.cancel()
    try await loader.waitForCancellationCount(2)
    await loader.completeAll()
    try await loader.waitForNoActiveRequests()
    let didDrain = await pipeline.waitForWorkToDrain()
    #expect(didDrain)
}

@Test @MainActor func revisitedCancelledURLDoesNotStartDuplicateWhileOldFetchRuns() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 6)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 0, ahead: 1, maximumConcurrentLoads: 2)
    )

    pipeline.updateVisibleIndex(3)
    try await loader.waitForRequestCount(2)
    pipeline.updateVisibleIndex(0)
    try await loader.waitForCancellationCount(2)
    pipeline.updateVisibleIndex(3)
    try await waitForPipelineState {
        pipeline.states[3]?.status == .queued && pipeline.states[4]?.status == .queued
    }
    await loader.complete(url: session.imageURLs[4])
    try await loader.waitForRequestCount(3)
    #expect(await loader.requestedURLs.filter { $0 == session.imageURLs[3] }.count == 1)
    pipeline.cancel()
    try await loader.waitForCancellationCount(3)
    await loader.completeAll()
    try await loader.waitForNoActiveRequests()
    let didDrain = await pipeline.waitForWorkToDrain()
    #expect(didDrain)
}

@Test @MainActor func memoryPressureKeepsOnlyVisibleDecodedImage() async throws {
    let loader = SuspendedReaderAssetLoader()
    let pipeline = ReaderPagePipeline(
        session: .pipelineFixture(pageCount: 6), assetLoader: loader,
        policy: .init(behind: 1, ahead: 2, maximumConcurrentLoads: 3)
    )

    pipeline.updateVisibleIndex(2)
    try await loader.waitForRequestCount(3)
    await loader.completeAll()
    try await loader.waitForRequestCount(4)
    await loader.completeAll()
    try await waitForPipelineState { [1, 2, 3, 4].allSatisfy { pipeline.states[$0]?.status == .ready } }
    pipeline.handleMemoryPressure()
    try await waitForPipelineState { [1, 3, 4].allSatisfy { pipeline.states[$0]?.image == nil } }
    #expect(pipeline.states[2]?.image != nil)
    pipeline.cancel()
}

@Test @MainActor func learnedTallDimensionsSurviveEvictionAndRevisitWithoutPixels() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 3)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        decoder: TallReaderDecoder(),
        policy: .init(behind: 0, ahead: 0, maximumConcurrentLoads: 1)
    )

    pipeline.updateVisibleIndex(0)
    try await loader.waitForRequestCount(1)
    await loader.completeAll()
    try await waitForPipelineState { pipeline.states[0]?.status == .ready }
    pipeline.updateVisibleIndex(2)
    try await waitForPipelineState { pipeline.states[0]?.status == .idle }
    try await loader.waitForRequestCount(2)
    #expect(pipeline.states[0]?.image == nil)
    #expect(ReaderPageLayout.placeholderHeight(
        availableWidth: 390, displayMode: .fitWidth,
        metadata: pipeline.states[0]?.learnedMetadata
    ) == 6_825)

    pipeline.updateVisibleIndex(0)
    await loader.complete(url: session.imageURLs[2])
    try await waitForPipelineState { pipeline.states[0]?.status == .loading }
    #expect(pipeline.states[0]?.image == nil)
    #expect(pipeline.states[0]?.learnedMetadata?.pixelHeight == 14_000)
    pipeline.cancel()
    await loader.completeAll()
    _ = await pipeline.waitForWorkToDrain()
}

@Test @MainActor func stationaryVisiblePageReadyTransitionAdvancesProgress() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 3)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 0, ahead: 0, maximumConcurrentLoads: 1)
    )
    let viewModel = ReaderViewModel(session: session, pagePipelineFactory: { _ in pipeline })
    let frames = [1: CGRect(x: 0, y: 0, width: 390, height: 390)]
    let selection = try #require(ReaderViewportPageSelector.selection(
        frames: frames, viewportHeight: 600, pipelineID: ObjectIdentifier(pipeline)
    ))

    await viewModel.markImageVisible(index: selection.index, isReady: false, pipelineID: selection.pipelineID)
    pipeline.updateVisibleIndex(selection.index)
    try await loader.waitForRequestCount(1)
    #expect(viewModel.progress.currentImageIndex == 0)
    await loader.completeAll()
    try await waitForPipelineState { pipeline.states[1]?.status == .ready }
    try await waitForPipelineState { viewModel.progress.currentImageIndex == 1 }
    #expect(frames[1]?.height == 390)
    pipeline.cancel()
}

@Test @MainActor func finalProgressKeepsThreeVisibleReadyPagesInTheLoadingWindow() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 40)
    let pipeline = ReaderPagePipeline(session: session, assetLoader: loader)
    let viewModel = ReaderViewModel(session: session, pagePipelineFactory: { _ in pipeline })
    pipeline.updateVisibleIndex(37)
    try await loader.waitForRequestCount(3)
    await loader.completeAll()
    try await loader.waitForRequestCount(4)
    await loader.completeAll()
    try await waitForPipelineState { (36...39).allSatisfy { pipeline.states[$0]?.status == .ready } }

    let frames = [
        37: CGRect(x: 0, y: -270, width: 390, height: 390),
        38: CGRect(x: 0, y: 120, width: 390, height: 390),
        39: CGRect(x: 0, y: 510, width: 390, height: 390)
    ]
    let selection = try #require(ReaderViewportPageSelector.selection(
        frames: frames, viewportHeight: 900,
        pipelineID: ObjectIdentifier(pipeline), lastPageIndex: 39
    ))
    #expect(selection.index == 39)
    #expect(selection.loadingAnchorIndex == 37)

    pipeline.updateVisibleIndex(selection.loadingAnchorIndex)
    await viewModel.markImageVisible(
        index: selection.index, isReady: pipeline.states[selection.index]?.status == .ready,
        pipelineID: selection.pipelineID
    )
    #expect(viewModel.progress.fractionComplete == 1)
    #expect((37...39).allSatisfy { pipeline.states[$0]?.status == .ready && pipeline.states[$0]?.image != nil })

    let laterFrames = [
        38: CGRect(x: 0, y: -270, width: 390, height: 390),
        39: CGRect(x: 0, y: 120, width: 390, height: 390)
    ]
    let laterSelection = try #require(ReaderViewportPageSelector.selection(
        frames: laterFrames, viewportHeight: 900,
        pipelineID: ObjectIdentifier(pipeline), lastPageIndex: 39
    ))
    #expect(laterSelection.index == 39)
    #expect(laterSelection.loadingAnchorIndex == 38)
    #expect(laterSelection != selection)
    pipeline.cancel()
}

@Test @MainActor func readyBeforeVisibilityCallbackStillAdvancesProgress() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 3)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 0, ahead: 0, maximumConcurrentLoads: 1)
    )
    let viewModel = ReaderViewModel(session: session, pagePipelineFactory: { _ in pipeline })
    pipeline.updateVisibleIndex(1)
    try await loader.waitForRequestCount(1)
    await loader.completeAll()
    try await waitForPipelineState { pipeline.states[1]?.status == .ready }

    await viewModel.markImageVisible(index: 1, isReady: false, pipelineID: ObjectIdentifier(pipeline))

    #expect(viewModel.progress.currentImageIndex == 1)
    pipeline.cancel()
}

@Test @MainActor func retryHoldsItsConcurrencySlotUntilSecondAttemptCompletes() async throws {
    let session = MockReaderSession.pipelineFixture(pageCount: 2)
    let http = RetryGateReaderHTTPClient(firstURL: session.imageURLs[0], imageData: try #require(validPNGData))
    let pipeline = ReaderPagePipeline(
        session: session,
        assetLoader: DefaultReaderPageAssetLoader(httpClient: http, retryDelayNanoseconds: 0),
        policy: .init(behind: 0, ahead: 1, maximumConcurrentLoads: 1)
    )

    pipeline.updateVisibleIndex(0)
    try await http.waitForRequestCount(2)
    #expect(await http.requestedURLs == [session.imageURLs[0], session.imageURLs[0]])
    await http.releaseSecondAttempt()
    try await waitForPipelineState { pipeline.states[0]?.status == .ready && pipeline.states[1]?.status == .ready }
    #expect(await http.requestedURLs == [session.imageURLs[0], session.imageURLs[0], session.imageURLs[1]])
    pipeline.cancel()
}

@Test @MainActor func terminalLoaderFailureStaysPageLocalAndRequiresExplicitRetry() async throws {
    let session = MockReaderSession.pipelineFixture(pageCount: 2)
    let http = PageLocalReaderHTTPClient(failingURL: session.imageURLs[0], imageData: try #require(validPNGData))
    let loader = DefaultReaderPageAssetLoader(httpClient: http, retryDelayNanoseconds: 0)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 0, ahead: 1, maximumConcurrentLoads: 2)
    )

    pipeline.updateVisibleIndex(0)
    try await waitForPipelineState {
        pipeline.states[0]?.status == .failed && pipeline.states[1]?.status == .ready
    }
    #expect(await http.attempts(for: session.imageURLs[0]) == 2)
    pipeline.updateVisibleIndex(1)
    pipeline.updateVisibleIndex(0)
    #expect(pipeline.states[0]?.status == .failed)
    #expect(await http.attempts(for: session.imageURLs[0]) == 2)
    pipeline.retry(index: 0)
    try await waitForPipelineState { pipeline.states[0]?.status == .ready }
    #expect(await http.attempts(for: session.imageURLs[0]) == 3)
    #expect(pipeline.states[1]?.status == .ready)
    pipeline.cancel()
}

private struct TallReaderDecoder: ReaderImageDecoding {
    func decode(_ data: Data) async throws -> ReaderDecodedImage {
        let image = try await ImageIOReaderImageDecoder().decode(data)
        return ReaderDecodedImage(cgImage: image.cgImage, pixelWidth: 800, pixelHeight: 14_000)
    }
}

private actor PageLocalReaderHTTPClient: HTTPDataLoading {
    let failingURL: URL
    let imageData: Data
    private var attemptCounts: [URL: Int] = [:]

    init(failingURL: URL, imageData: Data) {
        self.failingURL = failingURL
        self.imageData = imageData
    }

    func data(from url: URL) async throws -> HTTPDataResponse {
        attemptCounts[url, default: 0] += 1
        if url == failingURL && attemptCounts[url, default: 0] <= 2 {
            throw URLError(.timedOut)
        }
        return HTTPDataResponse(data: imageData, statusCode: 200)
    }

    func attempts(for url: URL) -> Int { attemptCounts[url, default: 0] }
}

private actor RetryGateReaderHTTPClient: HTTPDataLoading {
    let firstURL: URL
    let imageData: Data
    private(set) var requestedURLs: [URL] = []
    private var secondAttemptContinuation: CheckedContinuation<Void, Never>?

    init(firstURL: URL, imageData: Data) {
        self.firstURL = firstURL
        self.imageData = imageData
    }

    func data(from url: URL) async throws -> HTTPDataResponse {
        requestedURLs.append(url)
        if url == firstURL && requestedURLs.count == 1 {
            throw URLError(.timedOut)
        }
        if url == firstURL && requestedURLs.count == 2 {
            await withCheckedContinuation { secondAttemptContinuation = $0 }
        }
        return HTTPDataResponse(data: imageData, statusCode: 200)
    }

    func releaseSecondAttempt() {
        secondAttemptContinuation?.resume()
        secondAttemptContinuation = nil
    }

    func waitForRequestCount(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while requestedURLs.count < count && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(requestedURLs.count >= count)
    }
}

@Test @MainActor func visibleFailureStaysLocalAndRetriesWithoutResettingNeighbor() async throws {
    let loader = SuspendedReaderAssetLoader()
    let session = MockReaderSession.pipelineFixture(pageCount: 2)
    let pipeline = ReaderPagePipeline(
        session: session, assetLoader: loader,
        policy: .init(behind: 0, ahead: 1, maximumConcurrentLoads: 2)
    )

    pipeline.updateVisibleIndex(0)
    try await loader.waitForRequestCount(2)
    await loader.fail(url: session.imageURLs[0], error: ReaderPageFailure.invalidResponse)
    await loader.complete(url: session.imageURLs[1])
    try await waitForPipelineState { pipeline.states[0]?.status == .failed && pipeline.states[1]?.status == .ready }
    #expect(pipeline.states[0]?.failure == .invalidResponse)
    pipeline.retry(index: 0)
    try await loader.waitForRequestCount(3)
    await loader.complete(url: session.imageURLs[0])
    try await waitForPipelineState { pipeline.states[0]?.status == .ready }
    #expect(pipeline.states[1]?.status == .ready)
    pipeline.cancel()
}

private extension MockReaderSession {
    static func pipelineFixture(pageCount: Int) -> Self {
        MockReaderSession(
            seriesTitle: "Fixture",
            chapterTitle: "Chapter 1",
            sourceURL: URL(string: "https://example.com/chapter-1")!,
            imageURLs: (0..<pageCount).map { URL(string: "https://example.com/page-\($0).png")! }
        )
    }
}

private actor SuspendedReaderAssetLoader: ReaderPageAssetLoading {
    private var continuations: [URL: [CheckedContinuation<Data, Error>]] = [:]
    private(set) var requestCount = 0
    private var concurrentRequests = 0
    private var cancellationCount = 0
    private(set) var maximumConcurrentRequests = 0
    private(set) var requestedURLs: [URL] = []

    func load(imageURL: URL, sourceURL: URL, requestContext: ReaderImageRequestContext?) async throws -> Data {
        requestCount += 1
        requestedURLs.append(imageURL)
        concurrentRequests += 1
        maximumConcurrentRequests = max(maximumConcurrentRequests, concurrentRequests)
        defer { concurrentRequests -= 1 }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations[imageURL, default: []].append(continuation)
            }
        } onCancel: {
            Task { await self.recordCancellation() }
        }
    }

    func waitForRequestCount(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while requestCount < count && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(requestCount >= count)
    }

    func waitForCancellationCount(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while cancellationCount < count && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(cancellationCount >= count)
    }

    func waitForNoActiveRequests() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while concurrentRequests > 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(concurrentRequests == 0)
    }

    func completeAll() {
        let pending = continuations.values.flatMap { $0 }
        continuations.removeAll()
        for continuation in pending {
            continuation.resume(returning: validPNGData!)
        }
    }

    func complete(url: URL) {
        continuations.removeValue(forKey: url)?.forEach { $0.resume(returning: validPNGData!) }
    }

    func fail(url: URL, error: Error) {
        continuations.removeValue(forKey: url)?.forEach { $0.resume(throwing: error) }
    }

    private func recordCancellation() {
        cancellationCount += 1
    }
}

@MainActor private func waitForPipelineState(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition() && ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition())
}
