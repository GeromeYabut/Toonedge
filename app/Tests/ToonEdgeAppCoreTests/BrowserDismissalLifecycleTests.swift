import AppKit
import Combine
import SwiftUI
import Testing
import WebKit
@testable import ToonEdgeAppCore

@MainActor
private struct DismissalHost: View {
    @ObservedObject var model: BrowserViewModel
    let visible: Bool
    var body: some View {
        VStack {
            Text(model.detectionResult == nil ? "Empty" : "Detected")
            Text(String(describing: model.cleanModePresentation))
            if visible {
                BrowserWebView(viewModel: model, detector: ProfileAwareChapterDetector())
            }
        }
    }
}

@Suite(.serialized)
@MainActor
struct BrowserDismissalLifecycleTests {
    @Test(arguments: ["empty", "recommended", "automatic", "unreadable"])
    func mountedDestructionDoesNotPublishAndReopens(state: String) async throws {
        _ = NSApplication.shared
        let model = BrowserViewModel(startPoint: .searchQuery(""))
        #expect(model.initialRequest == nil) // Production representable cannot reach the network.
        let host = NSHostingView(rootView: DismissalHost(model: model, visible: true))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 390, height: 844),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        host.layoutSubtreeIfNeeded()
        try await waitForReaderTestCondition("production Browser mounted") { self.findWebView(host) != nil }
        let webView = try #require(findWebView(host))
        let coordinator = try #require(webView.navigationDelegate as? BrowserWebView.Coordinator)
        if state != "empty" {
            let fixture: BrowserPresentationFixture = state == "automatic" ? .highConfidence : .mediumConfidence
            let result = fixture.detectionResult
            model.updateNavigation(url: result.pageURL, title: "Owned Chapter", canGoBack: false,
                                   canGoForward: false, isLoading: false)
            if state == "unreadable" { model.handleUnreadableDetectionResult(result) }
            else { model.handleDetectionResult(result) }
        }
        host.layoutSubtreeIfNeeded()
        await Task.yield()
        var emissions = 0
        let subscription = model.objectWillChange.sink { emissions += 1 }
        let oldResult = model.detectionResult
        let oldPresentation = model.cleanModePresentation
        let oldSession = model.pendingReaderSession
        let oldMessage = model.readerUnavailableMessage
        host.rootView = DismissalHost(model: model, visible: false)
        host.layoutSubtreeIfNeeded()
        try await waitForReaderTestCondition("SwiftUI dismantled production Browser") {
            webView.navigationDelegate == nil && self.findWebView(host) == nil
        }
        coordinator.teardown() // Repeated cleanup must also be silent.
        coordinator.webView(webView, didStartProvisionalNavigation: nil)
        coordinator.webView(webView, didFinish: nil)
        await Task.yield()
        #expect(emissions == 0, "Destruction must not publish into the SwiftUI graph being removed")
        #expect(model.detectionResult == oldResult)
        #expect(model.cleanModePresentation == oldPresentation)
        #expect(model.pendingReaderSession == oldSession)
        #expect(model.readerUnavailableMessage == oldMessage)
        subscription.cancel()

        // A valid owner boundary resets a deliberately reused model before the new mount.
        model.navigationDidStart()
        #expect(model.detectionResult == nil && model.pendingReaderSession == nil)
        #expect(model.cleanModePresentation == .hidden && model.readerUnavailableMessage == nil)
        host.rootView = DismissalHost(model: model, visible: true)
        host.layoutSubtreeIfNeeded()
        try await waitForReaderTestCondition("fresh Browser mounted") {
            guard let newView = self.findWebView(host) else { return false }
            return newView !== webView && newView.navigationDelegate != nil
        }
        let fresh = BrowserPresentationFixture.mediumConfidence.detectionResult
        model.updateNavigation(url: fresh.pageURL, title: "Fresh Chapter", canGoBack: false,
                               canGoForward: false, isLoading: false)
        model.handleDetectionResult(fresh)
        coordinator.webView(webView, didFinish: nil)
        #expect(model.detectionResult == fresh)
        #expect(model.cleanModePresentation == .recommendedBanner)
        host.rootView = DismissalHost(model: model, visible: false)
        host.layoutSubtreeIfNeeded()
        try await waitForReaderTestCondition("fresh Browser dismantled") { self.findWebView(host) == nil }
        withExtendedLifetime(coordinator) {}
    }

    private func findWebView(_ view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        return view.subviews.lazy.compactMap { findWebView($0) }.first
    }
}
