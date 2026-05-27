import Combine
import Foundation

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
    private let httpClient: any HTTPDataLoading
    private let maxAttempts: Int
    private let retryDelayNanoseconds: UInt64

    public init(
        imageURL: URL,
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
        maxAttempts: Int = 2,
        retryDelayNanoseconds: UInt64 = 250_000_000
    ) {
        self.imageURL = imageURL
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

        for attempt in 1...maxAttempts {
            do {
                let response = try await httpClient.data(from: imageURL)
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
