import Combine
import Foundation
import ImageIO

public struct ReaderImageRequestContext: Equatable, Sendable {
    public var referer: URL
    public var cookieHeader: String?
    public var userAgent: String

    public init(referer: URL, cookieHeader: String?, userAgent: String) {
        self.referer = referer
        self.cookieHeader = cookieHeader
        self.userAgent = userAgent
    }

    public func request(for imageURL: URL) -> URLRequest {
        var request = URLRequest(url: imageURL)
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let cookieHeader, !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        return request
    }
}

public struct ReaderSessionImagePreflight: Sendable {
    private let httpClient: any HTTPDataLoading

    public init(httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader()) {
        self.httpClient = httpClient
    }

    public func isViable(_ session: MockReaderSession) async -> Bool {
        guard let imageURL = session.imageURLs.first else { return false }
        var request = session.imageRequestContext?.request(for: imageURL) ?? URLRequest(url: imageURL)
        request.timeoutInterval = 8
        do {
            let response = try await httpClient.data(for: request)
            guard (200..<300).contains(response.statusCode), !response.data.isEmpty else { return false }
            guard let source = CGImageSourceCreateWithData(response.data as CFData, nil) else { return false }
            return CGImageSourceGetType(source) != nil && CGImageSourceGetCount(source) > 0
        } catch {
            return false
        }
    }
}

public enum ReaderPageImageLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded(Data)
    case failed
}

@MainActor
public final class ReaderPageImageLoader: ObservableObject {
    @Published public private(set) var state: ReaderPageImageLoadState

    private let imageURL: URL
    private let sourceURL: URL?
    private let assetCache: (any ChapterAssetCaching)?
    private let requestContext: ReaderImageRequestContext?
    private let httpClient: any HTTPDataLoading
    private let maxAttempts: Int
    private let retryDelayNanoseconds: UInt64

    public init(
        imageURL: URL,
        sourceURL: URL? = nil,
        assetCache: (any ChapterAssetCaching)? = nil,
        requestContext: ReaderImageRequestContext? = nil,
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
        maxAttempts: Int = 2,
        retryDelayNanoseconds: UInt64 = 250_000_000
    ) {
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        self.assetCache = assetCache
        self.requestContext = requestContext
        self.httpClient = httpClient
        self.maxAttempts = max(1, maxAttempts)
        self.retryDelayNanoseconds = retryDelayNanoseconds
        self.state = .idle
    }

    public func load() async {
        guard state != .loading else {
            return
        }

        state = .loading

        if let sourceURL,
           let cachedURL = assetCache?.cachedAssetURL(for: imageURL, sourceURL: sourceURL),
           let data = try? Data(contentsOf: cachedURL),
           !data.isEmpty {
            state = .loaded(data)
            return
        }

        for attempt in 1...maxAttempts {
            do {
                let request = requestContext?.request(for: imageURL) ?? URLRequest(url: imageURL)
                let response = try await httpClient.data(for: request)
                guard (200..<300).contains(response.statusCode), !response.data.isEmpty else {
                    throw URLError(.badServerResponse)
                }

                state = .loaded(response.data)
                return
            } catch {
                guard attempt < maxAttempts else {
                    state = .failed
                    return
                }

                if retryDelayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }
    }

    public func retry() async {
        state = .idle
        await load()
    }
}
