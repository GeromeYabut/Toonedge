import Foundation
import WebKit
#if canImport(AppKit)
import AppKit
#endif
@testable import ToonEdgeAppCore

/// Real HTML parser/layout integration. CSP denies resource bytes; no fake DOM or decoder rewrite.
@MainActor
final class MatrixWebKitHarness: NSObject, WKNavigationDelegate {
    enum Failure: Error { case invalidOrigin, invalidGeometry, nonStringAnalysis, timeout, unexpectedNavigation, externalResourceBytes, hydrationNotReady }
    private var webView: WKWebView?
    private var navigationContinuation: CheckedContinuation<Void, any Error>?
    private var navigationTimeout: Task<Void, Never>?
    private var expectedURL: URL?
    private(set) var navigationPolicyDecisionCount = 0
    private(set) var externalResourceByteCount = -1
    private(set) var rawSourceAttributes: [String?] = []

    func analyze(html: String, pageURL: URL, sanitize: Bool, phase: MatrixPhase) async throws -> DetectionPageAnalysis {
        defer { tearDown() }
        try await load(html: html, pageURL: pageURL, sanitize: sanitize)
        if phase == .afterHydration || phase == .profileFollowUp { try await hydrate() }
        return try await extract(pageURL: pageURL)
    }

    /// Both extractions deliberately share one WebView/document and origin.
    func analyzeHydration(html: String, pageURL: URL, sanitize: Bool) async throws -> (DetectionPageAnalysis, DetectionPageAnalysis) {
        defer { tearDown() }
        try await load(html: html, pageURL: pageURL, sanitize: sanitize)
        let before = try await extract(pageURL: pageURL)
        try await hydrate()
        return (before, try await extract(pageURL: pageURL))
    }

    private func load(html: String, pageURL: URL, sanitize: Bool) async throws {
        guard pageURL.scheme == "https", pageURL.host()?.hasSuffix(".example.test") == true,
              html.contains("default-src 'none'; img-src 'none'") else { throw Failure.invalidOrigin }
        #if canImport(AppKit)
        _ = NSApplication.shared
        #endif
        expectedURL = pageURL
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        if sanitize {
            configuration.userContentController.addUserScript(WKUserScript(
                source: BrowserPageSanitizerScript.javaScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true
            ))
        }
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        view.navigationDelegate = self
        webView = view
        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            navigationTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                self?.completeNavigation(.failure(Failure.timeout))
            }
            view.loadSimulatedRequest(URLRequest(url: pageURL), responseHTML: html)
        }
    }

    private func hydrate() async throws {
        let ready = try await evaluate("window.matrixHydrate(); window.matrixHydrated === true", as: Bool.self)
        guard ready == true else { throw Failure.hydrationNotReady }
    }

    private func extract(pageURL: URL) async throws -> DetectionPageAnalysis {
        // Verify the real document before every extraction, including post-mutation extraction.
        guard (try await evaluate("window.location.href", as: String.self)) == pageURL.absoluteString else {
            throw Failure.invalidOrigin
        }
        guard let payload = try await evaluate(PageAnalysisScript.javaScript, as: String.self) else {
            throw Failure.nonStringAnalysis
        }
        let analysis = try JSONDecoder().decode(DetectionPageAnalysis.self, from: Data(payload.utf8))
        guard analysis.pageURL == pageURL else { throw Failure.invalidOrigin }
        guard analysis.viewportWidth.isFinite, analysis.viewportHeight.isFinite,
              analysis.viewportWidth == 390, analysis.viewportHeight == 844,
              analysis.documentHeight.isFinite, analysis.documentHeight > 0 else { throw Failure.invalidGeometry }
        // CSP blocks fetching. Assert unloaded image bytes and the browser's resource-byte counter.
        guard (try await evaluate("Array.from(document.images).every(i => i.naturalWidth === 0 && i.naturalHeight === 0)", as: Bool.self)) == true else {
            throw Failure.externalResourceBytes
        }
        externalResourceByteCount = (try await evaluate("performance.getEntriesByType('resource').reduce((n,e) => n + (e.decodedBodySize || 0), 0)", as: Int.self)) ?? -1
        guard externalResourceByteCount == 0 else { throw Failure.externalResourceBytes }
        guard let attributes = try await evaluate("JSON.stringify(Array.from(document.images).map(i => i.getAttribute('src')))", as: String.self) else { throw Failure.nonStringAnalysis }
        rawSourceAttributes = try JSONDecoder().decode([String?].self, from: Data(attributes.utf8))
        return analysis
    }

    private func evaluate<Value: Sendable>(_ script: String, as type: Value.Type) async throws -> Value? {
        guard let view = webView else { throw Failure.unexpectedNavigation }
        // Callback API supplies errors faithfully; timeout is bounded even if WebKit stops responding.
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            let timeout = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                guard !finished else { return }
                finished = true
                continuation.resume(throwing: Failure.timeout)
            }
            view.evaluateJavaScript(script) { value, error in
                guard !finished else { return }
                finished = true
                timeout.cancel()
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value as? Value) }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { completeNavigation(.success(())) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { completeNavigation(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { completeNavigation(.failure(error)) }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        navigationPolicyDecisionCount += 1
        let allowed = navigationAction.targetFrame?.isMainFrame == true && navigationAction.request.url == expectedURL
        decisionHandler(allowed ? .allow : .cancel)
        if !allowed { completeNavigation(.failure(Failure.unexpectedNavigation)) }
    }

    private func completeNavigation(_ result: Result<Void, any Error>) {
        guard let continuation = navigationContinuation else { return }
        navigationContinuation = nil
        navigationTimeout?.cancel()
        navigationTimeout = nil
        continuation.resume(with: result)
    }

    private func tearDown() {
        completeNavigation(.failure(CancellationError()))
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeAllUserScripts()
        webView = nil
        expectedURL = nil
    }
}
