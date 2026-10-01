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
