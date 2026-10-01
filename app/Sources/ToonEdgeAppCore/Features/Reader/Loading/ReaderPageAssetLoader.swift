import Foundation

public protocol ReaderPageAssetLoading: Sendable {
    func load(
        imageURL: URL,
        sourceURL: URL,
        requestContext: ReaderImageRequestContext?
    ) async throws -> Data
}

public struct DefaultReaderPageAssetLoader: ReaderPageAssetLoading {
    let cache: (any ChapterAssetCaching)?
    let httpClient: any HTTPDataLoading

    public init(
        cache: (any ChapterAssetCaching)? = nil,
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader()
    ) {
        self.cache = cache
        self.httpClient = httpClient
    }

    public func load(
        imageURL: URL,
        sourceURL: URL,
        requestContext: ReaderImageRequestContext?
    ) async throws -> Data {
        if let fileURL = cache?.cachedAssetURL(for: imageURL, sourceURL: sourceURL),
           let data = try? Data(contentsOf: fileURL),
           !data.isEmpty {
            return data
        }

        let request = requestContext?.request(for: imageURL) ?? URLRequest(url: imageURL)
        let response = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ReaderPageFailure.invalidResponse
        }
        guard !response.data.isEmpty else {
            throw ReaderPageFailure.emptyData
        }
        return response.data
    }
}
