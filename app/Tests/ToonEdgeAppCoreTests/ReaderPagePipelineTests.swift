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

private struct SpyChapterAssetCache: ChapterAssetCaching {
    let data: Data

    func chapterDirectory(for sourceURL: URL) -> URL {
        FileManager.default.temporaryDirectory
    }

    func cachedAssetURL(for assetURL: URL, sourceURL: URL) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? data.write(to: fileURL)
        return fileURL
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
