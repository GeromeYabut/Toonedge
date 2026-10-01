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
