import Foundation
import ImageIO

public struct ChapterAssetRetentionService: ChapterAssetRetaining {
    private let assetCache: any ChapterAssetCaching
    private let httpClient: any HTTPDataLoading

    public init(
        assetCache: any ChapterAssetCaching,
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader()
    ) {
        self.assetCache = assetCache
        self.httpClient = httpClient
    }

    public func retainAssets(for session: MockReaderSession) async throws -> Int64 {
        guard !session.imageURLs.isEmpty else {
            throw URLError(.cannotDecodeContentData)
        }

        var downloads: [(URL, Data)] = []
        downloads.reserveCapacity(session.imageURLs.count)
        for imageURL in session.imageURLs {
            if let cachedURL = assetCache.cachedAssetURL(for: imageURL, sourceURL: session.sourceURL),
               let data = try? Data(contentsOf: cachedURL),
               !data.isEmpty {
                downloads.append((imageURL, data))
                continue
            }

            let request = session.imageRequestContext?.request(for: imageURL) ?? URLRequest(url: imageURL)
            let response = try await httpClient.data(for: request)
            guard (200..<300).contains(response.statusCode),
                  !response.data.isEmpty,
                  let imageSource = CGImageSourceCreateWithData(response.data as CFData, nil),
                  CGImageSourceGetType(imageSource) != nil else {
                throw URLError(.cannotDecodeContentData)
            }
            downloads.append((imageURL, response.data))
        }

        for (imageURL, data) in downloads {
            try assetCache.store(data, for: imageURL, sourceURL: session.sourceURL)
        }
        return downloads.reduce(0) { $0 + Int64($1.1.count) }
    }
}
