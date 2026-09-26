import Foundation
import WebKit

public enum AdjacentReaderSessionLoadError: Error, Equatable, Sendable {
    case unavailable
}

public protocol AdjacentChapterPageLoading: Sendable {
    func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis
}

public protocol AdjacentChapterHTMLLoading: Sendable {
    func loadHTML(from url: URL) async throws -> String
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

public struct URLSessionAdjacentChapterHTMLLoader: AdjacentChapterHTMLLoading {
    public init() {}

    public func loadHTML(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return html
    }
}

@MainActor
public final class AdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let detector: any ChapterPageDetecting
    private let pageLoader: any AdjacentChapterPageLoading
    private let htmlLoader: (any AdjacentChapterHTMLLoading)?

    public init(
        detector: any ChapterPageDetecting,
        pageLoader: any AdjacentChapterPageLoading,
        htmlLoader: (any AdjacentChapterHTMLLoading)? = nil
    ) {
        self.detector = detector
        self.pageLoader = pageLoader
        self.htmlLoader = htmlLoader
    }

    public func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        do {
            let result = detector.detect(page: try await pageLoader.loadPageAnalysis(from: url))
            return try viableSession(from: result, preserving: context)
        } catch {
            guard let htmlLoader else {
                throw error
            }
            let html = try await htmlLoader.loadHTML(from: url)
            let analysis = StaticHTMLChapterPageAnalysisParser.analysis(html: html, pageURL: url)
            return try viableSession(from: detector.detect(page: analysis), preserving: context)
        }
    }

    private func viableSession(
        from result: DetectionResult,
        preserving context: AdjacentReaderSessionLoadContext
    ) throws -> MockReaderSession {
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

enum StaticHTMLChapterPageAnalysisParser {
    static func analysis(html: String, pageURL: URL) -> DetectionPageAnalysis {
        let images = imageTags(in: html).enumerated().compactMap { index, tag -> DetectionImageCandidate? in
            let attributes = attributes(in: tag)
            guard attributes["data-reader-page-image"] != nil,
                  let src = attributes["src"] else {
                return nil
            }

            let width = Double(attributes["width"] ?? "") ?? 0
            let height = Double(attributes["height"] ?? "") ?? 0
            return DetectionImageCandidate(
                src: src,
                lazySources: [],
                srcset: attributes["srcset"],
                width: width,
                height: height,
                top: Double(index) * max(height, 1_000),
                left: 0,
                className: attributes["class"],
                id: attributes["id"],
                alt: attributes["alt"],
                parentSignature: "figure image-container",
                semanticHints: [
                    "data-reader-page-image",
                    attributes["data-reader-index"] == nil ? nil : "data-reader-index"
                ].compactMap { $0 }
            )
        }

        return DetectionPageAnalysis(
            pageURL: pageURL,
            title: title(in: html) ?? pageURL.lastPathComponent,
            documentHeight: images.reduce(0) { $0 + max($1.height, 1_000) },
            viewportWidth: 390,
            images: images,
            previousChapterURL: chapterNavigationURL(label: "prev", html: html, pageURL: pageURL),
            nextChapterURL: chapterNavigationURL(label: "next", html: html, pageURL: pageURL)
        )
    }

    private static func imageTags(in html: String) -> [String] {
        matches(pattern: #"<img\b[^>]*data-reader-page-image[^>]*>"#, in: html)
    }

    private static func attributes(in tag: String) -> [String: String] {
        var result: [String: String] = [:]
        for match in regexMatches(pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*(?:=\s*"([^"]*)")?"#, in: tag) {
            guard match.count >= 2 else { continue }
            result[match[1].lowercased()] = match.count > 2 ? decodeEntities(match[2]) : ""
        }
        return result
    }

    private static func title(in html: String) -> String? {
        guard let match = regexMatches(pattern: #"<title[^>]*>(.*?)</title>"#, in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]).first,
              match.count > 1 else {
            return nil
        }
        return decodeEntities(match[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chapterNavigationURL(label: String, html: String, pageURL: URL) -> URL? {
        for match in regexMatches(pattern: #"<a\b([^>]*)>(.*?)</a>"#, in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            guard match.count > 2 else { continue }
            let anchorAttributes = attributes(in: match[1])
            let text = stripTags(match[2]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard text == label || text.contains("\(label) chapter") else { continue }
            guard let href = anchorAttributes["href"] else { return nil }
            return URL(string: href, relativeTo: pageURL)?.absoluteURL
        }
        return nil
    }

    private static func stripTags(_ value: String) -> String {
        value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    private static func matches(pattern: String, in value: String) -> [String] {
        regexMatches(pattern: pattern, in: value, options: [.caseInsensitive]).compactMap(\.first)
    }

    private static func regexMatches(
        pattern: String,
        in value: String,
        options: NSRegularExpression.Options = []
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).map { match in
            (0..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: value) else {
                    return nil
                }
                return String(value[range])
            }
        }
    }

    private static func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
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
