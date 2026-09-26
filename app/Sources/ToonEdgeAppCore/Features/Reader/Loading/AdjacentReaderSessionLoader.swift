import Foundation
import OSLog
import WebKit

public struct AdjacentReaderSessionLoadError: Error, Equatable, Sendable {
    public let reason: AdjacentReaderSessionLoadFailureReason
    public let targetURL: URL?
    public let confidence: DetectionConfidence?
    public let parserPath: DetectionParserPath?
    public let challengeSignals: [String]

    public init(
        reason: AdjacentReaderSessionLoadFailureReason,
        targetURL: URL?,
        confidence: DetectionConfidence? = nil,
        parserPath: DetectionParserPath? = nil,
        challengeSignals: [String] = []
    ) {
        self.reason = reason
        self.targetURL = targetURL
        self.confidence = confidence
        self.parserPath = parserPath
        self.challengeSignals = challengeSignals
    }
}

public struct AdjacentReaderSessionLoadDiagnostic: Equatable, Sendable {
    public let direction: ReaderChapterDirection
    public let elapsedMilliseconds: Int
    public let reason: AdjacentReaderSessionLoadFailureReason
    public let targetHost: String?
    public let confidence: DetectionConfidence?
    public let parserPath: DetectionParserPath?
    public let challengeSignals: [String]
}

public protocol AdjacentReaderSessionLoadDiagnosticsLogging: Sendable {
    func log(_ diagnostic: AdjacentReaderSessionLoadDiagnostic) async
}

public struct OSLogAdjacentReaderSessionLoadDiagnosticsLogger: AdjacentReaderSessionLoadDiagnosticsLogging {
    private let logger: Logger

    public init(logger: Logger = Logger(subsystem: "com.toonedge.app", category: "AdjacentReaderLoad")) {
        self.logger = logger
    }

    public func log(_ diagnostic: AdjacentReaderSessionLoadDiagnostic) async {
        logger.info(
            "Adjacent Reader load failed direction=\(diagnostic.direction.diagnosticLabel, privacy: .public) elapsedMs=\(diagnostic.elapsedMilliseconds, privacy: .public) reason=\(diagnostic.reason.rawValue, privacy: .public) host=\(diagnostic.targetHost ?? "none", privacy: .public) confidence=\(diagnostic.confidence?.rawValue ?? "none", privacy: .public) parserPath=\(diagnostic.parserPath?.rawValue ?? "none", privacy: .public) challengeSignals=\(diagnostic.challengeSignals.joined(separator: ","), privacy: .public)"
        )
    }
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
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdjacentChapterTransportError.unavailable
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        if let failure = AdjacentChapterHTTPResponseClassifier.failureReason(
            statusCode: httpResponse.statusCode,
            html: html
        ) {
            throw failure == .challengeOrRateLimit
                ? AdjacentChapterTransportError.challengeOrRateLimit
                : AdjacentChapterTransportError.unavailable
        }
        return html
    }
}

enum AdjacentChapterHTTPResponseClassifier {
    static func failureReason(
        statusCode: Int,
        html: String
    ) -> AdjacentReaderSessionLoadFailureReason? {
        guard !(200..<300).contains(statusCode) else { return nil }
        if statusCode == 429 || !StaticHTMLChapterPageAnalysisParser.challengeSignals(in: html).isEmpty {
            return .challengeOrRateLimit
        }
        return .unavailable
    }
}

@MainActor
public final class AdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let detector: any ChapterPageDetecting
    private let pageLoader: any AdjacentChapterPageLoading
    private let htmlLoader: (any AdjacentChapterHTMLLoading)?
    private let diagnosticsLogger: any AdjacentReaderSessionLoadDiagnosticsLogging

    public init(
        detector: any ChapterPageDetecting,
        pageLoader: any AdjacentChapterPageLoading,
        htmlLoader: (any AdjacentChapterHTMLLoading)? = nil,
        diagnosticsLogger: any AdjacentReaderSessionLoadDiagnosticsLogging = OSLogAdjacentReaderSessionLoadDiagnosticsLogger()
    ) {
        self.detector = detector
        self.pageLoader = pageLoader
        self.htmlLoader = htmlLoader
        self.diagnosticsLogger = diagnosticsLogger
    }

    public func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        let startedAt = Date()
        let primaryFailure: AdjacentReaderSessionLoadError

        do {
            let analysis = try await pageLoader.loadPageAnalysis(from: url)
            return try viableSession(from: analysis, targetURL: url, preserving: context)
        } catch {
            primaryFailure = typedFailure(from: error, targetURL: url)
        }

        if primaryFailure.reason == .challengeOrRateLimit {
            await log(primaryFailure, context: context, startedAt: startedAt)
            throw primaryFailure
        }

        if let htmlLoader {
            do {
                let html = try await htmlLoader.loadHTML(from: url)
                let analysis = StaticHTMLChapterPageAnalysisParser.analysis(html: html, pageURL: url)
                return try viableSession(from: analysis, targetURL: url, preserving: context)
            } catch {
                let fallbackFailure = typedFailure(from: error, targetURL: url)
                let finalFailure = preferredFailure(primaryFailure, fallbackFailure)
                await log(finalFailure, context: context, startedAt: startedAt)
                throw finalFailure
            }
        }

        await log(primaryFailure, context: context, startedAt: startedAt)
        throw primaryFailure
    }

    private func viableSession(
        from analysis: DetectionPageAnalysis,
        targetURL: URL,
        preserving context: AdjacentReaderSessionLoadContext
    ) throws -> MockReaderSession {
        let result = detector.detect(page: analysis)
        if analysis.isChallengeOrRateLimitPage {
            throw AdjacentReaderSessionLoadError(
                reason: .challengeOrRateLimit,
                targetURL: targetURL,
                confidence: result.confidence,
                parserPath: result.diagnostics.parserPath,
                challengeSignals: analysis.challengeSignals
            )
        }
        guard result.confidence == .high else {
            throw AdjacentReaderSessionLoadError(
                reason: .lowConfidence,
                targetURL: targetURL,
                confidence: result.confidence,
                parserPath: result.diagnostics.parserPath,
                challengeSignals: analysis.challengeSignals
            )
        }
        guard var session = result.readerSession,
              !session.imageURLs.isEmpty,
              !session.usesMockOrStockImages else {
            throw AdjacentReaderSessionLoadError(
                reason: .nonViableImages,
                targetURL: targetURL,
                confidence: result.confidence,
                parserPath: result.diagnostics.parserPath,
                challengeSignals: analysis.challengeSignals
            )
        }
        session.launchOrigin = context.currentSession.launchOrigin
        return session
    }

    private func typedFailure(from error: Error, targetURL: URL) -> AdjacentReaderSessionLoadError {
        if let typed = error as? AdjacentReaderSessionLoadError {
            return typed
        }
        if let transport = error as? AdjacentChapterTransportError {
            return AdjacentReaderSessionLoadError(
                reason: transport == .challengeOrRateLimit ? .challengeOrRateLimit : .unavailable,
                targetURL: targetURL
            )
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return AdjacentReaderSessionLoadError(reason: .timeout, targetURL: targetURL)
        }
        return AdjacentReaderSessionLoadError(reason: .unavailable, targetURL: targetURL)
    }

    private func preferredFailure(
        _ primary: AdjacentReaderSessionLoadError,
        _ fallback: AdjacentReaderSessionLoadError
    ) -> AdjacentReaderSessionLoadError {
        let priority: [AdjacentReaderSessionLoadFailureReason: Int] = [
            .challengeOrRateLimit: 5,
            .timeout: 4,
            .lowConfidence: 3,
            .nonViableImages: 2,
            .unavailable: 1
        ]
        return priority[fallback.reason, default: 0] > priority[primary.reason, default: 0]
            ? fallback
            : primary
    }

    private func log(
        _ error: AdjacentReaderSessionLoadError,
        context: AdjacentReaderSessionLoadContext,
        startedAt: Date
    ) async {
        await diagnosticsLogger.log(
            AdjacentReaderSessionLoadDiagnostic(
                direction: context.direction,
                elapsedMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1_000)),
                reason: error.reason,
                targetHost: error.targetURL?.host()?.lowercased(),
                confidence: error.confidence,
                parserPath: error.parserPath,
                challengeSignals: error.challengeSignals
            )
        )
    }
}

private enum AdjacentChapterTransportError: Error, Equatable {
    case challengeOrRateLimit
    case unavailable
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
            nextChapterURL: chapterNavigationURL(label: "next", html: html, pageURL: pageURL),
            challengeSignals: challengeSignals(in: html)
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

    static func challengeSignals(in html: String) -> [String] {
        let normalized = html.lowercased()
        return [
            normalized.contains("just a moment") ? "title:just-a-moment" : nil,
            normalized.contains("challenge-platform") ? "challenge-platform-script" : nil,
            normalized.contains("too many requests") || normalized.contains("rate limit") || normalized.contains("http 429")
                ? "rate-limit-copy"
                : nil
        ].compactMap { $0 }
    }
}

private extension DetectionPageAnalysis {
    var isChallengeOrRateLimitPage: Bool {
        !challengeSignals.isEmpty || title.lowercased().contains("just a moment")
    }
}

private extension ReaderChapterDirection {
    var diagnosticLabel: String {
        switch self {
        case .previous: "previous"
        case .next: "next"
        }
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
    private var responseChallengeSignals: [String] = []

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

                var page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                page.challengeSignals.append(contentsOf: self.responseChallengeSignals)
                page.challengeSignals = Array(Set(page.challengeSignals)).sorted()
                self.finish(.success(page))
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse {
            if response.statusCode == 429 {
                responseChallengeSignals.append("http-status:429")
            }
            if response.value(forHTTPHeaderField: "cf-mitigated")?.lowercased() == "challenge" {
                responseChallengeSignals.append("cf-mitigated:challenge")
            }
        }
        decisionHandler(.allow)
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
