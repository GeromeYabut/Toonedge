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
    let maxAttempts: Int
    let retryDelayNanoseconds: UInt64

    public init(
        cache: (any ChapterAssetCaching)? = nil,
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
        maxAttempts: Int = 2,
        retryDelayNanoseconds: UInt64 = 250_000_000
    ) {
        self.cache = cache
        self.httpClient = httpClient
        self.maxAttempts = max(1, maxAttempts)
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    public func load(
        imageURL: URL,
        sourceURL: URL,
        requestContext: ReaderImageRequestContext?
    ) async throws -> Data {
        try Task.checkCancellation()
        if let fileURL = cache?.cachedAssetURL(for: imageURL, sourceURL: sourceURL),
           let data = try? Data(contentsOf: fileURL),
           !data.isEmpty {
            try Task.checkCancellation()
            return data
        }

        let request = requestContext?.request(for: imageURL) ?? URLRequest(url: imageURL)
        var attempt = 0
        while true {
            attempt += 1
            try Task.checkCancellation()
            do {
                let response = try await httpClient.data(for: request)
                try Task.checkCancellation()
                guard (200..<300).contains(response.statusCode) else {
                    throw ReaderPageFailure.invalidResponse
                }
                guard !response.data.isEmpty else {
                    throw ReaderPageFailure.emptyData
                }
                return response.data
            } catch {
                try Task.checkCancellation()
                guard attempt < maxAttempts else { throw error }
                if retryDelayNanoseconds > 0 {
                    try await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }
    }
}
