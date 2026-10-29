import CoreFoundation
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

    public static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown()
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

    public static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown()
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
    private var lastScheduleWasBeforeLoadSettled = false
    public private(set) var generation = UUID()

    public init() {}

    public mutating func navigationDidStart() {
        generation = UUID()
        lastScheduledURL = nil
        lastScheduleWasBeforeLoadSettled = false
    }

    public func isCurrent(_ generation: UUID) -> Bool {
        self.generation == generation
    }

    // A parsed document may be analysed while subresources still load; the settled
    // load then earns exactly one more pass for that URL.
    public mutating func shouldSchedule(url: URL?, isLoading: Bool, documentReady: Bool = false) -> Bool {
        guard let url, !isLoading || documentReady else { return false }
        if lastScheduledURL == url {
            guard !isLoading, lastScheduleWasBeforeLoadSettled else { return false }
        }
        lastScheduledURL = url
        lastScheduleWasBeforeLoadSettled = isLoading
        return true
    }
}


// Recovery has a fixed monotonic deadline; events cannot extend its lifetime.
struct BrowserHydrationRecoveryPolicy: Sendable {
    static let windowSeconds: TimeInterval = 30
    static let debounceMilliseconds = 500
    static let maximumAttempts = 4
    let startedAt: TimeInterval
    private(set) var attempts = 0
    private var stopped = false
    init(startedAt: TimeInterval) { self.startedAt = startedAt }
    func canAttempt(at now: TimeInterval) -> Bool {
        !stopped && now >= startedAt && now < startedAt + Self.windowSeconds
            && attempts < Self.maximumAttempts
    }
    mutating func takeAttempt(at now: TimeInterval) -> Bool {
        guard canAttempt(at: now) else { return false }
        attempts += 1
        return true
    }
    mutating func stop() { stopped = true }
}

@MainActor
enum BrowserHydrationReadinessScript {
    static let world = WKContentWorld.world(name: "ToonEdgeBrowserReadiness")
    static let handlerName = "toonEdgeReadiness"
    static func install(epoch: UUID, remainingSeconds: TimeInterval) -> String {
        """
        (() => {
          const previous = window.__toonEdgeReadiness;
          if (previous) previous.stop();
          const epoch = '\(epoch.uuidString)';
          const attributes = ['src', 'srcset', 'data-src', 'data-original', 'data-lazy-src',
            'data-lazy', 'data-url', 'data-image', 'data-full', 'data-full-src', 'data-actualsrc',
            'data-srcset', 'data-lazy-srcset', 'width', 'height', 'class', 'id', 'style', 'hidden',
            'data-reader-page-image', 'data-reader-index', 'data-page', 'role'];
          let timer = null, expiry = null, stopped = false, revision = 0;
          // This fingerprint stays in the isolated world; no text/image URLs cross the bridge.
          const fingerprint = () => JSON.stringify(Array.from(document.images).slice(0, 512).map(image => {
            const rect = image.getBoundingClientRect();
            const parent = image.parentElement;
            const style = window.getComputedStyle(image);
            // Match PageAnalysisScript's visible-height evidence, including inherited visibility.
            const visible = !image.hidden && rect.width > 0 && rect.height > 0 && style.display !== 'none'
              && style.visibility !== 'hidden' && style.opacity !== '0';
            return [attributes.map(key => {
                const value = image.getAttribute(key);
                return value === null ? null : value.slice(0, 2048);
              }),
              image.currentSrc, image.complete, image.naturalWidth, image.naturalHeight,
              Math.round(rect.width), Math.round(rect.height),
              visible && Number.isFinite(rect.height) ? rect.height : 0,
              parent ? [parent.id, parent.className] : null];
          }));
          let last = fingerprint();
          const flush = () => {
            timer = null;
            if (stopped) return;
            const current = fingerprint();
            if (last === current) return;
            last = current;
            try { window.webkit.messageHandlers.\(handlerName).postMessage({epoch, revision: ++revision}); }
            catch (_) { stop(); }
          };
          // Coalesce from the first event; storms cannot slide the timer forever.
          const changed = () => {
            if (!stopped && timer === null) timer = setTimeout(flush, \(BrowserHydrationRecoveryPolicy.debounceMilliseconds));
          };
          const hasImage = node => node.nodeType === 1 &&
            (node.tagName === 'IMG' || !!node.querySelector('img'));
          const observer = new MutationObserver(records => {
            if (records.some(record => record.type === 'attributes' ? hasImage(record.target) :
                Array.from(record.addedNodes).concat(Array.from(record.removedNodes)).some(hasImage))) changed();
          });
          const imageEvent = event => { if (event.target && event.target.tagName === 'IMG') changed(); };
          const stop = () => {
            stopped = true;
            observer.disconnect();
            clearTimeout(timer); clearTimeout(expiry); timer = null;
            document.removeEventListener('load', imageEvent, true);
            document.removeEventListener('error', imageEvent, true);
          };
          window.__toonEdgeReadiness = {epoch, stop};
          observer.observe(document.documentElement, {childList:true, subtree:true, attributes:true, attributeFilter:attributes});
          document.addEventListener('load', imageEvent, true);
          document.addEventListener('error', imageEvent, true);
          expiry = setTimeout(stop, \(Int(max(0, remainingSeconds) * 1000)));
          return epoch;
        })();
        """
    }
    static func stop(epoch: UUID) -> String {
        "if (window.__toonEdgeReadiness?.epoch === '\(epoch.uuidString)') window.__toonEdgeReadiness.stop();"
    }
}

@MainActor
private final class BrowserHydrationMessageHandler: NSObject, WKScriptMessageHandler {
    weak var coordinator: BrowserWebView.Coordinator?
    init(coordinator: BrowserWebView.Coordinator) { self.coordinator = coordinator }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else { return }
        coordinator?.receiveReadinessMessage(message.body, from: webView, isMainFrame: message.frameInfo.isMainFrame)
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
      // Ordinary layout words (read-container, fade-out) are not ad evidence.
      const blockedIdentifierPattern = /(?:^|[^a-z0-9])(?:ad|ads|advert|advertisement|advertisements|advertising|banner|sponsor|sponsored|promo|promotion|popup|pop-up|popunder|modal|overlay|sidebar|float|sticky)(?=$|[^a-z0-9])/;
      const benignLayoutIdentifiers = new Set(['sidebar-hidden']);
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

      const hasBlockedIdentifier = (node) => {
        // A benign layout state must not shield another class such as ad-slot.
        return textFor(node).split(/\\s+/).filter(Boolean).some((identifier) =>
          !benignLayoutIdentifiers.has(identifier) && blockedIdentifierPattern.test(identifier));
      };

      const shouldHide = (node) => {
        // Document roots are layout owners, never disposable noise surfaces.
        if (node.matches('html, body') || isReaderNode(node)) return false;
        if (!hasBlockedIdentifier(node)) return false;
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
    @MainActor
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
        private let imagePreflight: ReaderSessionImagePreflight
        private let diagnostics: ReaderReadinessDiagnostics
        private var diagnosticNavigation = 0
        private var diagnosticGeneration: UUID?
        private var diagnosticStopRecorded = false
        private var scheduledDetectionTask: Task<Void, Never>?
        private var followUpTask: Task<Void, Never>?
        private var analysisTask: Task<Void, Never>?
        private var recoveryExpiryTask: Task<Void, Never>?
        private var recoveryPolicy: BrowserHydrationRecoveryPolicy?
        private var bridgeEpoch: UUID?
        private var lastReadinessRevision = 0
        private var pendingRecovery = false
        private var pendingFollowUp = false
        private var pendingSettledPass = false
        private var provisionalRecommendationDelivered = false
        private var hasViableResult = false
        private var documentIsReady = false
        private var documentReadyTask: Task<Void, Never>?
        private static let documentReadyPollLimit = 120
        private enum AnalysisKind: Equatable { case initial, followUp, recovery }

        init(
            viewModel: BrowserViewModel,
            detector: any ChapterPageDetecting,
            presentationFixture: BrowserPresentationFixture? = nil,
            imagePreflight: ReaderSessionImagePreflight = ReaderSessionImagePreflight(),
            diagnostics: ReaderReadinessDiagnostics? = nil
        ) {
            self.viewModel = viewModel
            self.detector = detector
            self.presentationFixture = presentationFixture
            self.imagePreflight = imagePreflight
            self.diagnostics = diagnostics ?? .shared
        }

        func attach(_ webView: WKWebView) {
            teardown()
            self.webView = webView
            webView.navigationDelegate = self
            webView.uiDelegate = self
            hasLoadedInitialRequest = false
            lastObservedURL = nil
            documentIsReady = false
            webView.configuration.userContentController.add(
                BrowserHydrationMessageHandler(coordinator: self),
                contentWorld: BrowserHydrationReadinessScript.world,
                name: BrowserHydrationReadinessScript.handlerName
            )
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.observedURLDidChange(on: webView)
                }
            }
        }

        @MainActor
        private func observedURLDidChange(on webView: WKWebView) {
            guard self.webView === webView else { return }
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
            stopObservingDocumentReadiness()
            invalidateDetection()

            switch command.action {
            case .goBack:
                webView?.goBack()
            case .goForward:
                webView?.goForward()
            case .reload:
                webView?.reload()
            case .loadURL(let url):
                #if DEBUG
                if presentationFixture != nil,
                   ProcessInfo.processInfo.arguments.contains("-uiTesting"),
                   ProcessInfo.processInfo.arguments.contains("-sharedSearchFixture") {
                    webView?.loadSimulatedRequest(URLRequest(url: url), responseHTML: """
                        <!doctype html><meta name="viewport" content="width=device-width">
                        <body style="background:#000;color:#fff;font:20px system-ui;padding:24px">
                        Owned search destination
                        </body>
                        """)
                } else {
                    webView?.load(URLRequest(url: url))
                }
                #else
                webView?.load(URLRequest(url: url))
                #endif
            }

            viewModel.clearCommand(command)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard self.webView === webView else { return }
            stopObservingDocumentReadiness()
            invalidateDetection()
            updateState(from: webView, isLoading: true)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            guard self.webView === webView else { return }
            updateState(from: webView, isLoading: true)
            recordReadiness(.navigationCommitted, generation: navigationPolicy.generation)
            observeDocumentReadiness(in: webView)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard self.webView === webView else { return }
            stopObservingDocumentReadiness()
            lastObservedURL = webView.url
            updateState(from: webView, isLoading: false)
            startReadinessDiagnostics(generation: navigationPolicy.generation)
            recordReadiness(.navigationFinished, generation: navigationPolicy.generation)
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
            guard self.webView === webView else { return }
            stopObservingDocumentReadiness()
            recordReadiness(.navigationFailed, generation: navigationPolicy.generation,
                transport: .category(for: error))
            updateState(from: webView, isLoading: false)
        }

        @MainActor
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard self.webView === webView else { return }
            stopObservingDocumentReadiness()
            recordReadiness(.navigationFailed, generation: navigationPolicy.generation,
                transport: .category(for: error))
            updateState(from: webView, isLoading: false)
        }

        @MainActor
        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard self.webView === webView,
                  navigationAction.targetFrame == nil,
                  let destinationURL = navigationAction.request.url else {
                return nil
            }

            if popupPolicy.shouldAllowTargetWindowNavigation(to: destinationURL, from: webView.url) {
                stopObservingDocumentReadiness()
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

        func teardown() {
            // SwiftUI may be destroying its observation graph here. Cancel work without
            // publishing presentation resets into the graph being removed.
            cancelDetectionWork(diagnosticReason: .teardown)
            stopObservingDocumentReadiness()
            urlObservation?.invalidate()
            urlObservation = nil
            let detachedView = webView
            webView = nil
            if let detachedView {
                detachedView.configuration.userContentController.removeScriptMessageHandler(
                    forName: BrowserHydrationReadinessScript.handlerName,
                    contentWorld: BrowserHydrationReadinessScript.world)
                detachedView.navigationDelegate = nil
                detachedView.uiDelegate = nil
                detachedView.stopLoading()
            }
        }

        private func invalidateDetection() {
            cancelDetectionWork()
            viewModel.navigationDidStart()
            startReadinessDiagnostics(generation: navigationPolicy.generation)
        }

        private func cancelDetectionWork(diagnosticReason: ReaderReadinessStop = .navigationChanged) {
            if let webView {
                stopRecovery(in: webView, generation: navigationPolicy.generation, diagnosticReason: diagnosticReason)
            }
            scheduledDetectionTask?.cancel()
            followUpTask?.cancel()
            analysisTask?.cancel()
            recoveryExpiryTask?.cancel()
            scheduledDetectionTask = nil
            followUpTask = nil
            analysisTask = nil
            recoveryExpiryTask = nil
            pendingRecovery = false
            pendingFollowUp = false
            pendingSettledPass = false
            provisionalRecommendationDelivered = false
            hasViableResult = false
            recoveryPolicy = nil
            bridgeEpoch = nil
            lastReadinessRevision = 0
            navigationPolicy.navigationDidStart()
            retryPolicy = BrowserDetectionRetryPolicy()
        }

        private func isCurrent(_ webView: WKWebView, url: URL, generation: UUID) -> Bool {
            self.webView === webView && navigationPolicy.isCurrent(generation)
                && webView.url == url && (!webView.isLoading || documentIsReady) && viewModel.pendingCommand == nil
                && !Task.isCancelled
        }

        private func documentIsCurrent(_ webView: WKWebView, url: URL, generation: UUID) async -> Bool {
            guard isCurrent(webView, url: url, generation: generation) else { return false }
            // Missing bridge preserves legacy native-guarded URL/load behavior.
            guard bridgeEpoch == generation else { return true }
            let value = try? await webView.evaluateJavaScript(
                "window.__toonEdgeReadiness?.epoch === '\(generation.uuidString)'",
                in: nil, contentWorld: BrowserHydrationReadinessScript.world)
            return isCurrent(webView, url: url, generation: generation) && (value as? Bool) == true
        }

        private func scheduleDetection(for webView: WKWebView) {
            guard self.webView === webView, presentationFixture == nil, !hasViableResult,
                  navigationPolicy.shouldSchedule(url: webView.url, isLoading: webView.isLoading,
                      documentReady: documentIsReady),
                  let url = webView.url else { return }
            let generation = navigationPolicy.generation
            startReadinessDiagnostics(generation: generation)
            // A settled pass keeps the generation's fixed recovery window and budget.
            if recoveryPolicy == nil {
                recoveryPolicy = BrowserHydrationRecoveryPolicy(startedAt: ProcessInfo.processInfo.systemUptime)
            }
            scheduledDetectionTask?.cancel()
            scheduledDetectionTask = Task { @MainActor [weak self, weak webView] in
                do { try await Task.sleep(nanoseconds: 750_000_000) } catch { return }
                guard let self, let webView,
                      self.isCurrent(webView, url: url, generation: generation) else { return }
                self.requestAnalysis(.initial, in: webView, url: url, generation: generation)
            }
        }

        // Detection waits for a parsed document, not for every subresource to settle.
        private func observeDocumentReadiness(in webView: WKWebView) {
            documentReadyTask?.cancel()
            documentIsReady = false
            guard presentationFixture == nil else { return }
            documentReadyTask = Task { @MainActor [weak self, weak webView] in
                for _ in 0..<Self.documentReadyPollLimit {
                    do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
                    guard let self, let webView, self.webView === webView, webView.isLoading else { return }
                    let state = try? await webView.evaluateJavaScript("document.readyState",
                        in: nil, contentWorld: BrowserHydrationReadinessScript.world)
                    guard !Task.isCancelled, self.webView === webView, webView.isLoading else { return }
                    guard let state = state as? String, state != "loading" else { continue }
                    self.documentIsReady = true
                    self.documentReadyTask = nil
                    self.recordReadiness(.documentReady, generation: self.navigationPolicy.generation)
                    self.scheduleDetection(for: webView)
                    return
                }
            }
        }

        private func stopObservingDocumentReadiness() {
            documentReadyTask?.cancel()
            documentReadyTask = nil
            documentIsReady = false
        }

        private func installRecovery(in webView: WKWebView, url: URL, generation: UUID) async {
            guard let policy = recoveryPolicy,
                  isCurrent(webView, url: url, generation: generation) else { return }
            let remaining = max(0, policy.startedAt + BrowserHydrationRecoveryPolicy.windowSeconds
                - ProcessInfo.processInfo.systemUptime)
            guard remaining > 0 else { return }
            let value = try? await webView.evaluateJavaScript(
                BrowserHydrationReadinessScript.install(epoch: generation, remainingSeconds: remaining),
                in: nil, contentWorld: BrowserHydrationReadinessScript.world)
            guard isCurrent(webView, url: url, generation: generation),
                  (value as? String) == generation.uuidString else { return }
            bridgeEpoch = generation
            recoveryExpiryTask = Task { @MainActor [weak self, weak webView] in
                do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) } catch { return }
                guard let self, let webView,
                      self.isCurrent(webView, url: url, generation: generation) else { return }
                self.stopRecovery(in: webView, generation: generation)
            }
        }

        // Hints schedule the existing classifier; they never authorize Reader entry.
        func receiveReadinessMessage(_ body: Any, from webView: WKWebView, isMainFrame: Bool) {
            let generation = navigationPolicy.generation
            guard isMainFrame, let url = webView.url,
                  isCurrent(webView, url: url, generation: generation),
                  bridgeEpoch == generation, !hasViableResult,
                  recoveryPolicy?.canAttempt(at: ProcessInfo.processInfo.systemUptime) == true,
                  let payload = body as? [String: Any], payload.count == 2,
                  let epoch = payload["epoch"] as? String, epoch == generation.uuidString,
                  let number = payload["revision"] as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(),
                  let revision = payload["revision"] as? Int, revision > lastReadinessRevision else { return }
            lastReadinessRevision = revision
            requestAnalysis(.recovery, in: webView, url: url, generation: generation)
        }

        private func stopRecovery(
            in webView: WKWebView, generation: UUID, diagnosticReason: ReaderReadinessStop? = nil
        ) {
            guard navigationPolicy.isCurrent(generation) else { return }
            if recoveryPolicy != nil, !diagnosticStopRecorded {
                recordReadiness(.recoveryStopped, generation: generation,
                    stop: diagnosticReason ?? readinessRecoveryStopReason())
                diagnosticStopRecorded = true
            }
            recoveryPolicy?.stop()
            pendingRecovery = false
            recoveryExpiryTask?.cancel()
            recoveryExpiryTask = nil
            webView.evaluateJavaScript(BrowserHydrationReadinessScript.stop(epoch: generation),
                in: nil, in: BrowserHydrationReadinessScript.world) { _ in }
        }

        private func requestAnalysis(_ kind: AnalysisKind, in webView: WKWebView, url: URL, generation: UUID) {
            guard isCurrent(webView, url: url, generation: generation), !hasViableResult else { return }
            if analysisTask != nil {
                if kind == .recovery { pendingRecovery = true }
                if kind == .followUp { pendingFollowUp = true }
                if kind == .initial { pendingSettledPass = true }
                return
            }
            analysisTask = Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                defer {
                    if self.navigationPolicy.isCurrent(generation) { self.analysisTask = nil }
                }
                var next = kind
                if kind == .initial, self.bridgeEpoch != generation {
                    await self.installRecovery(in: webView, url: url, generation: generation)
                }
                while self.isCurrent(webView, url: url, generation: generation), !self.hasViableResult {
                    if next == .recovery {
                        guard self.recoveryPolicy?.takeAttempt(at: ProcessInfo.processInfo.systemUptime) == true else {
                            self.stopRecovery(in: webView, generation: generation)
                            return
                        }
                    }
                    await self.analyze(next, in: webView, url: url, generation: generation)
                    guard self.isCurrent(webView, url: url, generation: generation), !self.hasViableResult else { return }
                    if self.recoveryPolicy?.canAttempt(at: ProcessInfo.processInfo.systemUptime) != true {
                        self.stopRecovery(in: webView, generation: generation)
                    }
                    if self.pendingSettledPass {
                        self.pendingSettledPass = false
                        next = .initial
                    } else if self.pendingFollowUp {
                        self.pendingFollowUp = false
                        next = .followUp
                    } else if self.pendingRecovery {
                        self.pendingRecovery = false
                        next = .recovery
                    } else { return }
                }
            }
        }

        private func analyze(_ kind: AnalysisKind, in webView: WKWebView, url: URL, generation: UUID) async {
            let analysisKind: ReaderReadinessAnalysis
            switch kind {
            case .initial: analysisKind = .initial
            case .followUp: analysisKind = .followUp
            case .recovery: analysisKind = .recovery
            }
            do {
                guard await documentIsCurrent(webView, url: url, generation: generation) else {
                    recordReadiness(.guardStopped, generation: generation, analysis: analysisKind, stop: .staleDocument)
                    return
                }
                let diagnostic = recordReadiness(.analysisStarted, generation: generation, analysis: analysisKind)
                let analysedWhileLoading = webView.isLoading
                let value: Any?
                if bridgeEpoch == generation {
                    value = try await webView.evaluateJavaScript("""
                        (() => {
                          if (window.__toonEdgeReadiness?.epoch !== '\(generation.uuidString)') return null;
                          return \(PageAnalysisScript.javaScript)
                        })();
                        """, in: nil, contentWorld: BrowserHydrationReadinessScript.world)
                } else {
                    value = try await webView.evaluateJavaScript(PageAnalysisScript.javaScript)
                }
                guard let json = value as? String, let data = json.data(using: .utf8) else {
                    recordReadiness(.analysisFailed, generation: generation, template: diagnostic, stop: .analysisFailure)
                    return
                }
                let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: data)
                guard page.pageURL == url,
                      await documentIsCurrent(webView, url: url, generation: generation) else {
                    recordReadiness(.guardStopped, generation: generation, template: diagnostic, stop: .staleDocument)
                    return
                }
                let result = kind == .initial ? detector.detect(page: page)
                    : (detector as? ProfileAwareChapterDetector)?.detectBrowserSessionFollowUp(page: page)
                        ?? detector.detect(page: page)
                let completed = recordReadiness(.analysisCompleted, generation: generation,
                    template: diagnostic, page: page, result: result)
                let provisional = await deliverDetectionResult(result, in: webView, generation: generation,
                    diagnostic: completed, analysedWhileLoading: analysedWhileLoading)
                guard !provisional, isCurrent(webView, url: url, generation: generation), !hasViableResult else { return }
                if kind == .initial, retryPolicy.shouldScheduleFollowUp(
                    for: page.pageURL, recommendation: result.retryRecommendation, confidence: result.confidence
                ) { scheduleFollowUpDetection(for: webView, url: page.pageURL) }
            } catch {
                recordReadiness(.analysisFailed, generation: generation, analysis: analysisKind, stop: .analysisFailure,
                    transport: .category(for: error))
                guard kind == .initial,
                      await documentIsCurrent(webView, url: url, generation: generation) else { return }
                viewModel.handleDetectionResult(DetectionResult(
                    pageURL: url, confidence: .low, score: 0, candidates: [], readerSession: nil,
                    diagnostics: DetectionDiagnostics(confidence: .low, score: 0,
                        parserPath: .genericHeuristic, messages: ["pageAnalysisFailed"])))
            }
        }

        private func scheduleFollowUpDetection(for webView: WKWebView, url: URL) {
            let generation = navigationPolicy.generation
            followUpTask = Task { @MainActor [weak self, weak webView] in
                do {
                    try await Task.sleep(nanoseconds: BrowserDetectionRetryPolicy.followUpDelayNanoseconds(for: url))
                } catch { return }
                guard let self, let webView,
                      self.isCurrent(webView, url: url, generation: generation) else { return }
                self.requestAnalysis(.followUp, in: webView, url: url, generation: generation)
            }
        }

        @MainActor @discardableResult
        private func deliverDetectionResult(
            _ result: DetectionResult, in webView: WKWebView, generation: UUID,
            diagnostic: ReaderReadinessEvent? = nil, analysedWhileLoading: Bool = false
        ) async -> Bool {
            guard await documentIsCurrent(webView, url: result.pageURL, generation: generation) else {
                recordReadiness(.guardStopped, generation: generation, template: diagnostic, stop: .staleDocument)
                return false
            }
            // Once the user has acted on a provisional banner, later passes must not change what they chose.
            if provisionalRecommendationDelivered, viewModel.cleanModePresentation != .recommendedBanner {
                hasViableResult = true
                stopRecovery(in: webView, generation: generation)
                return false
            }
            guard result.readerEntryDisposition != .unavailable,
                  result.diagnostics.hardBlocks.isEmpty,
                  var session = result.readerSession,
                  session.sourceURL == result.pageURL,
                  !session.imageURLs.isEmpty else {
                let reason: ReaderReadinessStop
                if !result.diagnostics.hardBlocks.isEmpty { reason = .hardBlock }
                else if result.readerEntryDisposition == .unavailable { reason = .unavailable }
                else if result.readerSession == nil { reason = .missingSession }
                else if result.readerSession?.sourceURL != result.pageURL { reason = .sourceMismatch }
                else { reason = .noImages }
                recordReadiness(.guardStopped, generation: generation, template: diagnostic, stop: reason)
                viewModel.handleDetectionResult(result)
                return false
            }

            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            guard await documentIsCurrent(webView, url: result.pageURL, generation: generation) else {
                recordReadiness(.guardStopped, generation: generation, template: diagnostic, stop: .staleDocument)
                return false
            }
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

            recordReadiness(.preflightStarted, generation: generation, template: diagnostic)
            let buffer = diagnostics.elapsedMilliseconds(for: diagnosticNavigation) != nil
                ? ReaderPreflightObservationBuffer() : nil
            let observation: (@Sendable (ReaderImagePreflightObservation) -> Void)?
            if let buffer { observation = { buffer.record($0) } } else { observation = nil }
            let viable = await imagePreflight.isViable(session, observation: observation)
            recordReadiness(.preflightCompleted, generation: generation, template: diagnostic,
                observation: buffer?.read())
            guard await documentIsCurrent(webView, url: result.pageURL, generation: generation) else {
                recordReadiness(.guardStopped, generation: generation, template: diagnostic, stop: .staleDocument)
                return false
            }
            if viable {
                var prepared = result
                prepared.readerSession = session
                let provisional = analysedWhileLoading && prepared.readerEntryDisposition == .automatic
                if provisional { prepared.readerEntryDisposition = .recommended }
                viewModel.handleDetectionResult(prepared)
                if viewModel.pendingReaderSession != nil {
                    recordReadiness(.handoff, generation: generation, template: diagnostic)
                }
                // Late page scripts may still add blocking markers; the settled pass decides automatic entry.
                if provisional {
                    provisionalRecommendationDelivered = true
                    followUpTask?.cancel()
                    followUpTask = nil
                    pendingFollowUp = false
                    stopRecovery(in: webView, generation: generation)
                    return true
                }
                hasViableResult = true
                pendingFollowUp = false
                followUpTask?.cancel()
                followUpTask = nil
                stopRecovery(in: webView, generation: generation)
            } else {
                recordReadiness(.guardStopped, generation: generation, template: diagnostic, stop: .unreadableImage)
                viewModel.handleUnreadableDetectionResult(result)
            }
            return false
        }

        private func startReadinessDiagnostics(generation: UUID) {
            guard presentationFixture == nil, diagnosticGeneration != generation else { return }
            diagnosticGeneration = generation
            diagnosticNavigation = diagnostics.startNavigation()
            diagnosticStopRecorded = false
            recordReadiness(.navigationStarted, generation: generation)
        }

        private func readinessRecoveryStopReason() -> ReaderReadinessStop {
            if hasViableResult { return .viableResult }
            guard let policy = recoveryPolicy else { return .cancelled }
            if ProcessInfo.processInfo.systemUptime >= policy.startedAt + BrowserHydrationRecoveryPolicy.windowSeconds {
                return .recoveryDeadline
            }
            return policy.attempts >= BrowserHydrationRecoveryPolicy.maximumAttempts ? .attemptLimit : .cancelled
        }

        @discardableResult
        private func recordReadiness(
            _ stage: ReaderReadinessStage, generation: UUID,
            template: ReaderReadinessEvent? = nil,
            analysis: ReaderReadinessAnalysis = .none,
            page: DetectionPageAnalysis? = nil, result: DetectionResult? = nil,
            stop: ReaderReadinessStop = .none,
            observation: ReaderImagePreflightObservation? = nil,
            transport: ReaderReadinessTransport = .none
        ) -> ReaderReadinessEvent? {
            guard diagnosticGeneration == generation,
                  let elapsed = diagnostics.elapsedMilliseconds(for: diagnosticNavigation) else { return nil }
            var event = template ?? ReaderReadinessEvent(
                navigation: diagnosticNavigation, elapsedMs: elapsed, stage: stage, analysis: analysis)
            event.navigation = diagnosticNavigation
            event.elapsedMs = elapsed
            event.stage = stage
            event.stop = stop
            if template == nil, analysis == .recovery { event.attempt = recoveryPolicy?.attempts ?? 0 }
            if let page {
                event.rawImages = min(1_000_000, page.images.count)
                event.evidenceImages = ReaderReadinessDiagnostics.evidenceImageCount(in: page)
            }
            if let result {
                event.candidates = min(1_000_000, result.candidates.count)
                event.parser = ReaderReadinessParser(rawValue: result.diagnostics.parserPath.rawValue) ?? .none
                event.score = min(10_000, max(-10_000, result.score))
                event.disposition = ReaderReadinessDisposition(rawValue: result.readerEntryDisposition.rawValue) ?? .none
                event.hardBlocks = result.diagnostics.hardBlocks.sorted { $0.rawValue < $1.rawValue }
            }
            if let observation {
                event.preflight = observation.outcome
                event.httpStatus = observation.httpStatus
                event.transport = observation.transport
                event.pixelWidth = observation.pixelWidth
                event.pixelHeight = observation.pixelHeight
            } else if transport != .none { event.transport = transport }
            diagnostics.emit(event)
            return event
        }
    }
}
