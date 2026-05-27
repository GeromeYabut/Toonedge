import Foundation
import WebKit

public enum AdjacentReaderSessionLoadError: Error, Equatable, Sendable {
    case unavailable
}

public protocol AdjacentChapterPageLoading: Sendable {
    func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis
}

@MainActor
public final class HiddenWebViewAdjacentChapterPageLoader: NSObject, AdjacentChapterPageLoading {
    private let timeoutNanoseconds: UInt64

    public init(timeoutNanoseconds: UInt64 = 15_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    public func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis {
        let webView = WKWebView(frame: .zero)
        let coordinator = HiddenWebViewLoadCoordinator(webView: webView, url: url)
        return try await coordinator.loadAndAnalyze(timeoutNanoseconds: timeoutNanoseconds)
    }
}

@MainActor
public final class AdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let detector: any ChapterPageDetecting
    private let pageLoader: any AdjacentChapterPageLoading

    public init(detector: any ChapterPageDetecting, pageLoader: any AdjacentChapterPageLoading) {
        self.detector = detector
        self.pageLoader = pageLoader
    }

    public func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        let analysis = try await pageLoader.loadPageAnalysis(from: url)
        let result = detector.detect(page: analysis)
        guard result.confidence == .high,
              var session = result.readerSession,
              !session.imageURLs.isEmpty,
              !session.usesMockOrStockImages else {
            throw AdjacentReaderSessionLoadError.unavailable
        }
        session.launchOrigin = context.currentSession.launchOrigin
        return session
    }
}

private extension MockReaderSession {
    var usesMockOrStockImages: Bool {
        imageURLs.contains { url in
            let host = url.host()?.lowercased()
            return host == "picsum.photos" || host == "images.unsplash.com"
        }
    }
}

@MainActor
private final class HiddenWebViewLoadCoordinator: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let url: URL
    private var continuation: CheckedContinuation<DetectionPageAnalysis, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(webView: WKWebView, url: URL) {
        self.webView = webView
        self.url = url
        super.init()
        self.webView.navigationDelegate = self
    }

    deinit {
        timeoutTask?.cancel()
    }

    func loadAndAnalyze(timeoutNanoseconds: UInt64) async throws -> DetectionPageAnalysis {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                self?.finish(.failure(URLError(.timedOut)))
            }
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }

            do {
                let value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
                guard let json = value as? String, let data = json.data(using: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }

                let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                self.finish(.success(page))
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<DetectionPageAnalysis, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        webView.stopLoading()
        webView.navigationDelegate = nil

        switch result {
        case .success(let page):
            continuation.resume(returning: page)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
