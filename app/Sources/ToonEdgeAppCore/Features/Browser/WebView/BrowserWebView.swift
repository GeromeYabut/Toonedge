import SwiftUI
import WebKit

#if os(iOS)
public struct BrowserWebView: UIViewRepresentable {
    @ObservedObject private var viewModel: BrowserViewModel
    private let detector: any ChapterPageDetecting
    private let presentationFixture: BrowserPresentationFixture?

    public init(
        viewModel: BrowserViewModel,
        detector: any ChapterPageDetecting,
        presentationFixture: BrowserPresentationFixture? = nil
    ) {
        self.viewModel = viewModel
        self.detector = detector
        self.presentationFixture = presentationFixture
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, detector: detector, presentationFixture: presentationFixture)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: BrowserPageSanitizerScript.javaScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = BrowserUserAgent.mobileSafari
        context.coordinator.attach(webView)
        context.coordinator.loadInitialRequestIfNeeded()
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.handlePendingCommand()
    }
}
#else
public struct BrowserWebView: NSViewRepresentable {
    @ObservedObject private var viewModel: BrowserViewModel
    private let detector: any ChapterPageDetecting
    private let presentationFixture: BrowserPresentationFixture?

    public init(
        viewModel: BrowserViewModel,
        detector: any ChapterPageDetecting,
        presentationFixture: BrowserPresentationFixture? = nil
    ) {
        self.viewModel = viewModel
        self.detector = detector
        self.presentationFixture = presentationFixture
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, detector: detector, presentationFixture: presentationFixture)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: BrowserPageSanitizerScript.javaScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = BrowserUserAgent.mobileSafari
        context.coordinator.attach(webView)
        context.coordinator.loadInitialRequestIfNeeded()
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.handlePendingCommand()
    }
}
#endif

public struct BrowserDetectionRetryPolicy {
    private var retriedURLs: Set<URL> = []

    public init() {}

    public static func followUpDelayNanoseconds(for url: URL) -> UInt64 {
        let host = url.host()?.lowercased() ?? ""
        return host == "vortexscans.org" || host.hasSuffix(".vortexscans.org")
            ? 12_000_000_000
            : 900_000_000
    }

    public mutating func shouldScheduleFollowUp(
        for url: URL,
        recommendation: DetectionRetryRecommendation,
        confidence: DetectionConfidence
    ) -> Bool {
        let host = url.host()?.lowercased() ?? ""
        let isVortexRoute = host == "vortexscans.org" || host.hasSuffix(".vortexscans.org")
        guard recommendation == .browserSessionFollowUp || (isVortexRoute && confidence == .low) else {
            return false
        }

        return retriedURLs.insert(url).inserted
    }
}

public struct BrowserDetectionNavigationPolicy {
    private var lastScheduledURL: URL?
    public private(set) var generation = UUID()

    public init() {}

    public mutating func navigationDidStart() {
        generation = UUID()
        lastScheduledURL = nil
    }

    public func isCurrent(_ generation: UUID) -> Bool {
        self.generation == generation
    }

    public mutating func shouldSchedule(url: URL?, isLoading: Bool) -> Bool {
        guard let url, !isLoading, lastScheduledURL != url else { return false }
        lastScheduledURL = url
        return true
    }
}

public struct BrowserPopupPolicy: Sendable {
    public init() {}

    public func shouldAllowTargetWindowNavigation(to destinationURL: URL, from pageURL: URL?) -> Bool {
        guard let destinationHost = destinationURL.host()?.lowercased(),
              let pageHost = pageURL?.host()?.lowercased() else {
            return false
        }

        return destinationHost == pageHost || destinationHost.hasSuffix(".\(pageHost)")
    }
}

public enum BrowserPageSanitizerScript {
    public static let javaScript = """
    (() => {
      \(PageAnalysisScript.accessGatePreservationJavaScript)
      const blockedSelectorFragments = [
        'ad', 'ads', 'advert', 'banner', 'sponsor', 'promo',
        'popup', 'pop-up', 'popunder', 'modal', 'overlay',
        'sidebar', 'float', 'sticky'
      ];
      const readerAllowFragments = [
        'reading-content',
        'manga-reading-content',
        'wp-manga',
        'chapter',
        'reader'
      ];

      const textFor = (node) => [
        node.id || '',
        node.className || '',
        node.getAttribute && (node.getAttribute('aria-label') || ''),
        node.getAttribute && (node.getAttribute('role') || '')
      ].join(' ').toLowerCase();

      const isReaderNode = (node) => {
        const text = textFor(node);
        return readerAllowFragments.some((fragment) => text.includes(fragment));
      };

      const shouldHide = (node) => {
        const text = textFor(node);
        if (!text || isReaderNode(node)) return false;
        if (!blockedSelectorFragments.some((fragment) => text.includes(fragment))) return false;
        // Keep a positive blocking surface intact, including noise-labelled copy or controls.
        // Primary content itself does not exempt ordinary ads elsewhere in the chapter.
        for (let ancestor = node.parentElement; ancestor; ancestor = ancestor.parentElement) {
          if (toonEdgeCanPreserveGateSubtree(ancestor)) return false;
        }
        // Preserve the visible access gate and any noise-labelled wrapper containing it.
        return !toonEdgeHasAccessGateEvidence(node)
          && !Array.from(node.querySelectorAll(toonEdgeAccessGateSelector)).some(toonEdgeHasAccessGateEvidence);
      };

      const hideNoise = () => {
        Array.from(document.querySelectorAll('aside, iframe, [class], [id]')).forEach((node) => {
          if (shouldHide(node)) {
            node.style.setProperty('display', 'none', 'important');
            node.style.setProperty('visibility', 'hidden', 'important');
            node.setAttribute('data-toonedge-hidden-noise', 'true');
          }
        });
      };

      if (!window.__toonEdgeOriginalOpen) {
        window.__toonEdgeOriginalOpen = window.open;
        window.open = function(url, target, features) {
          const destination = String(url || '');
          if (/doubleclick|googlesyndication|adservice|pop|promo|advert/i.test(destination)) {
            return null;
          }
          return window.__toonEdgeOriginalOpen.call(window, url, target, features);
        };
      }

      hideNoise();
      new MutationObserver(hideNoise).observe(document.documentElement, { childList: true, subtree: true });
    })();
    """
}

public enum BrowserUserAgent {
    public static let mobileSafari = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1"
}

public extension BrowserWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private weak var webView: WKWebView?
        private let viewModel: BrowserViewModel
        private let detector: any ChapterPageDetecting
        private let presentationFixture: BrowserPresentationFixture?
        private var hasLoadedInitialRequest = false
        private var handledCommandID: UUID?
        private var urlObservation: NSKeyValueObservation?
        private var navigationPolicy = BrowserDetectionNavigationPolicy()
        private var lastObservedURL: URL?
        private var retryPolicy = BrowserDetectionRetryPolicy()
        private let popupPolicy = BrowserPopupPolicy()

        init(
            viewModel: BrowserViewModel,
            detector: any ChapterPageDetecting,
            presentationFixture: BrowserPresentationFixture? = nil
        ) {
            self.viewModel = viewModel
            self.detector = detector
            self.presentationFixture = presentationFixture
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.observedURLDidChange(on: webView)
                }
            }
        }

        @MainActor
        private func observedURLDidChange(on webView: WKWebView) {
            if lastObservedURL != webView.url {
                lastObservedURL = webView.url
                invalidateDetection()
            }
            updateState(from: webView, isLoading: webView.isLoading)
            if let presentationFixture {
                let result = presentationFixture.detectionResult
                if webView.url == result.pageURL {
                    viewModel.handleDetectionResult(result)
                }
                return
            }
            scheduleDetection(for: webView)
        }

        @MainActor
        func loadInitialRequestIfNeeded() {
            guard !hasLoadedInitialRequest else { return }
            if let presentationFixture {
                hasLoadedInitialRequest = true
                if case .manual = presentationFixture {
                    // A user gesture after the initial document commits creates real native history.
                    webView?.loadSimulatedRequest(
                        URLRequest(url: URL(string: "https://fixture.toonedge.test/synthetic-start")!),
                        responseHTML: """
                        <!doctype html><meta name="viewport" content="width=device-width">
                        <body style="font:20px system-ui;padding:24px;background:#f4f2ed">
                        Synthetic chapter for Browser navigation testing.
                        <button style="font:inherit;padding:16px"
                          onclick='history.pushState(null, "", "/chapter-1?position=7#panel-2");this.hidden=true'>
                        Open synthetic chapter
                        </button>
                        </body>
                        """
                    )
                } else if case .manualUnreadable = presentationFixture {
                    viewModel.handleUnreadableDetectionResult(presentationFixture.detectionResult)
                } else {
                    viewModel.handleDetectionResult(presentationFixture.detectionResult)
                }
                return
            }

            guard !hasLoadedInitialRequest, let request = viewModel.initialRequest else {
                return
            }

            hasLoadedInitialRequest = true
            webView?.load(URLRequest(url: request.url))
        }

        @MainActor
        func handlePendingCommand() {
            guard let command = viewModel.pendingCommand, handledCommandID != command.id else {
                return
            }

            handledCommandID = command.id
            invalidateDetection()

            switch command.action {
            case .goBack:
                webView?.goBack()
            case .goForward:
                webView?.goForward()
            case .reload:
                webView?.reload()
            case .loadURL(let url):
                webView?.load(URLRequest(url: url))
            }

            viewModel.clearCommand(command)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            invalidateDetection()
            updateState(from: webView, isLoading: true)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateState(from: webView, isLoading: true)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            lastObservedURL = webView.url
            updateState(from: webView, isLoading: false)
            if let presentationFixture {
                if webView.url == presentationFixture.detectionResult.pageURL {
                    viewModel.handleDetectionResult(presentationFixture.detectionResult)
                }
                return
            }
            scheduleDetection(for: webView)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            updateState(from: webView, isLoading: false)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            updateState(from: webView, isLoading: false)
        }

        @MainActor
        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let destinationURL = navigationAction.request.url else {
                return nil
            }

            if popupPolicy.shouldAllowTargetWindowNavigation(to: destinationURL, from: webView.url) {
                webView.load(navigationAction.request)
            }

            return nil
        }

        @MainActor
        private func updateState(from webView: WKWebView, isLoading: Bool) {
            viewModel.updateNavigation(
                url: webView.url,
                title: webView.title,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward,
                isLoading: isLoading
            )
        }

        @MainActor
        private func invalidateDetection() {
            navigationPolicy.navigationDidStart()
            retryPolicy = BrowserDetectionRetryPolicy()
            viewModel.navigationDidStart()
        }

        @MainActor
        private func scheduleDetection(for webView: WKWebView) {
            if presentationFixture != nil { return }
            guard navigationPolicy.shouldSchedule(url: webView.url, isLoading: webView.isLoading),
                  let url = webView.url else {
                return
            }

            let generation = navigationPolicy.generation
            Task { @MainActor [weak webView, viewModel, detector] in
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard let webView, self.navigationPolicy.isCurrent(generation),
                      webView.url == url, !webView.isLoading else {
                    return
                }

                do {
                    let value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
                    guard let json = value as? String, let data = json.data(using: .utf8) else {
                        return
                    }

                    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                    let result = detector.detect(page: page)
                    guard self.navigationPolicy.isCurrent(generation),
                          webView.url == page.pageURL, !webView.isLoading else {
                        return
                    }

                    await self.deliverDetectionResult(result, in: webView, generation: generation)
                    guard self.navigationPolicy.isCurrent(generation) else { return }
                    if self.retryPolicy.shouldScheduleFollowUp(
                        for: page.pageURL,
                        recommendation: result.retryRecommendation,
                        confidence: result.confidence
                    ) {
                        self.scheduleFollowUpDetection(for: webView, url: page.pageURL)
                    }
                } catch {
                    guard self.navigationPolicy.isCurrent(generation),
                          webView.url == url, !webView.isLoading,
                          let currentURL = webView.url else {
                        return
                    }

                    viewModel.handleDetectionResult(
                        DetectionResult(
                            pageURL: currentURL,
                            confidence: .low,
                            score: 0,
                            candidates: [],
                            readerSession: nil,
                            diagnostics: DetectionDiagnostics(
                                confidence: .low,
                                score: 0,
                                parserPath: .genericHeuristic,
                                messages: ["pageAnalysisFailed"]
                            )
                        )
                    )
                }
            }
        }

        @MainActor
        private func scheduleFollowUpDetection(for webView: WKWebView, url: URL) {
            let generation = navigationPolicy.generation
            Task { @MainActor [weak webView, detector] in
                try? await Task.sleep(
                    nanoseconds: BrowserDetectionRetryPolicy.followUpDelayNanoseconds(for: url)
                )
                guard let webView, self.navigationPolicy.isCurrent(generation),
                      webView.url == url, !webView.isLoading else {
                    return
                }

                do {
                    let value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
                    guard let json = value as? String, let data = json.data(using: .utf8) else {
                        return
                    }

                    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                    guard self.navigationPolicy.isCurrent(generation),
                          webView.url == page.pageURL, !webView.isLoading else {
                        return
                    }

                    let result = (detector as? ProfileAwareChapterDetector)?
                        .detectBrowserSessionFollowUp(page: page) ?? detector.detect(page: page)
                    await self.deliverDetectionResult(result, in: webView, generation: generation)
                } catch {
                    return
                }
            }
        }

        @MainActor
        private func deliverDetectionResult(
            _ result: DetectionResult, in webView: WKWebView, generation: UUID
        ) async {
            guard navigationPolicy.isCurrent(generation),
                  webView.url == result.pageURL, !webView.isLoading else { return }
            guard result.readerEntryDisposition != .unavailable,
                  result.diagnostics.hardBlocks.isEmpty,
                  var session = result.readerSession,
                  session.sourceURL == result.pageURL,
                  !session.imageURLs.isEmpty else {
                viewModel.handleDetectionResult(result)
                return
            }

            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            guard navigationPolicy.isCurrent(generation),
                  webView.url == result.pageURL, !webView.isLoading else { return }
            let imageHost = session.imageURLs.first?.host()?.lowercased() ?? ""
            let matchingCookies = cookies.filter { cookie in
                let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
                return !domain.isEmpty && (imageHost == domain || imageHost.hasSuffix(".\(domain)"))
            }
            let cookieHeader = HTTPCookie.requestHeaderFields(with: matchingCookies)["Cookie"]
            session.imageRequestContext = ReaderImageRequestContext(
                referer: session.sourceURL,
                cookieHeader: cookieHeader,
                userAgent: webView.customUserAgent ?? BrowserUserAgent.mobileSafari
            )

            let viable = await ReaderSessionImagePreflight().isViable(session)
            guard navigationPolicy.isCurrent(generation),
                  webView.url == result.pageURL, !webView.isLoading else { return }
            if viable {
                var prepared = result
                prepared.readerSession = session
                viewModel.handleDetectionResult(prepared)
            } else {
                viewModel.handleUnreadableDetectionResult(result)
            }
        }
    }
}
