import SwiftUI
import WebKit

#if os(iOS)
public struct BrowserWebView: UIViewRepresentable {
    @ObservedObject private var viewModel: BrowserViewModel
    private let detector: any ChapterPageDetecting

    public init(viewModel: BrowserViewModel, detector: any ChapterPageDetecting) {
        self.viewModel = viewModel
        self.detector = detector
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, detector: detector)
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

    public init(viewModel: BrowserViewModel, detector: any ChapterPageDetecting) {
        self.viewModel = viewModel
        self.detector = detector
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, detector: detector)
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

    public mutating func shouldScheduleFollowUp(
        for url: URL,
        recommendation: DetectionRetryRecommendation
    ) -> Bool {
        guard recommendation == .browserSessionFollowUp else {
            return false
        }

        return retriedURLs.insert(url).inserted
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
        return blockedSelectorFragments.some((fragment) => text.includes(fragment));
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
        private var hasLoadedInitialRequest = false
        private var handledCommandID: UUID?
        private var lastAutoDetectionURL: URL?
        private var retryPolicy = BrowserDetectionRetryPolicy()
        private let popupPolicy = BrowserPopupPolicy()

        init(viewModel: BrowserViewModel, detector: any ChapterPageDetecting) {
            self.viewModel = viewModel
            self.detector = detector
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        @MainActor
        func loadInitialRequestIfNeeded() {
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
            viewModel.navigationDidStart()
            updateState(from: webView, isLoading: true)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            updateState(from: webView, isLoading: true)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateState(from: webView, isLoading: false)
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
        private func scheduleDetection(for webView: WKWebView) {
            guard let url = webView.url, lastAutoDetectionURL != url else {
                return
            }

            lastAutoDetectionURL = url

            Task { @MainActor [weak webView, viewModel, detector] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard let webView, webView.url == url else {
                    return
                }

                do {
                    let value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
                    guard let json = value as? String, let data = json.data(using: .utf8) else {
                        return
                    }

                    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                    let result = detector.detect(page: page)
                    guard webView.url == page.pageURL else {
                        return
                    }

                    viewModel.handleDetectionResult(result)
                    if self.retryPolicy.shouldScheduleFollowUp(
                        for: page.pageURL,
                        recommendation: result.retryRecommendation
                    ) {
                        self.scheduleFollowUpDetection(for: webView, url: page.pageURL)
                    }
                } catch {
                    guard let currentURL = webView.url else {
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
            Task { @MainActor [weak webView, viewModel, detector] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let webView, webView.url == url else {
                    return
                }

                do {
                    let value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
                    guard let json = value as? String, let data = json.data(using: .utf8) else {
                        return
                    }

                    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                    guard webView.url == page.pageURL else {
                        return
                    }

                    if let detector = detector as? ProfileAwareChapterDetector {
                        viewModel.handleDetectionResult(detector.detectBrowserSessionFollowUp(page: page))
                    } else {
                        viewModel.handleDetectionResult(detector.detect(page: page))
                    }
                } catch {
                    return
                }
            }
        }
    }
}
