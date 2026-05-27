import Combine
import Foundation
import OSLog

public enum BrowserReaderPresentationState: Equatable, Sendable {
    case none
    case pendingBrowserOwnedReader
    case browserOwnedReaderVisible
}

public protocol BrowserReaderPresentationLogging: Sendable {
    func log(_ state: BrowserReaderPresentationState)
}

public struct OSLogBrowserReaderPresentationLogger: BrowserReaderPresentationLogging {
    private let logger: Logger

    public init(logger: Logger = Logger(subsystem: "com.toonedge.app", category: "BrowserReaderPresentation")) {
        self.logger = logger
    }

    public func log(_ state: BrowserReaderPresentationState) {
        logger.info("Browser reader presentation state=\(String(describing: state), privacy: .public)")
    }
}

@MainActor
public final class BrowserViewModel: ObservableObject {
    public let startPoint: BrowserStartPoint
    public let initialRequest: BrowserRequest?

    @Published public private(set) var currentURL: URL?
    @Published public private(set) var pageTitle: String
    @Published public private(set) var canGoBack: Bool
    @Published public private(set) var canGoForward: Bool
    @Published public private(set) var isLoading: Bool
    @Published public private(set) var pendingCommand: BrowserCommand?
    @Published public private(set) var detectionResult: DetectionResult?
    @Published public private(set) var showsCleanModeCTA: Bool
    @Published public private(set) var pendingReaderSession: MockReaderSession?
    @Published public private(set) var browserOwnedReaderSession: MockReaderSession?
    private let readerPresentationLogger: any BrowserReaderPresentationLogging

    public init(
        startPoint: BrowserStartPoint,
        readerPresentationLogger: any BrowserReaderPresentationLogging = OSLogBrowserReaderPresentationLogger()
    ) {
        self.startPoint = startPoint
        self.initialRequest = BrowserRequest(startPoint: startPoint)
        self.currentURL = initialRequest?.url
        self.pageTitle = ""
        self.canGoBack = false
        self.canGoForward = false
        self.isLoading = false
        self.detectionResult = nil
        self.showsCleanModeCTA = false
        self.pendingReaderSession = nil
        self.browserOwnedReaderSession = nil
        self.readerPresentationLogger = readerPresentationLogger
    }

    public var addressDisplay: String {
        if let host = currentURL?.host(), !host.isEmpty {
            return host
        }

        return initialRequest?.displayText ?? startPoint.displayText
    }

    public var subtitleDisplay: String {
        if pageTitle.isEmpty {
            return currentURL?.absoluteString ?? initialRequest?.url.absoluteString ?? ""
        }

        return pageTitle
    }

    public var readerPresentationState: BrowserReaderPresentationState {
        if browserOwnedReaderSession != nil {
            return .browserOwnedReaderVisible
        }

        if pendingReaderSession != nil {
            return .pendingBrowserOwnedReader
        }

        return .none
    }

    public func goBack() {
        guard canGoBack else { return }
        pendingCommand = BrowserCommand(action: .goBack)
    }

    public func goForward() {
        guard canGoForward else { return }
        pendingCommand = BrowserCommand(action: .goForward)
    }

    public func reload() {
        pendingCommand = BrowserCommand(action: .reload)
    }

    public func load(_ url: URL) {
        pendingCommand = BrowserCommand(action: .loadURL(url))
    }

    public func updateNavigation(
        url: URL?,
        title: String?,
        canGoBack: Bool,
        canGoForward: Bool,
        isLoading: Bool
    ) {
        currentURL = url ?? currentURL
        pageTitle = title ?? ""
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isLoading = isLoading
    }

    public func navigationDidStart() {
        detectionResult = nil
        showsCleanModeCTA = false
        pendingReaderSession = nil
    }

    public func handleDetectionResult(_ result: DetectionResult) {
        detectionResult = result

        switch result.confidence {
        case .high:
            showsCleanModeCTA = false
            pendingReaderSession = viableReaderSession(from: result.readerSession)
            if pendingReaderSession != nil {
                readerPresentationLogger.log(.pendingBrowserOwnedReader)
            }
        case .medium:
            showsCleanModeCTA = viableReaderSession(from: result.readerSession) != nil
        case .low:
            showsCleanModeCTA = false
        }
    }

    public func enterCleanModeManually() {
        guard let session = viableReaderSession(from: detectionResult?.readerSession) else {
            return
        }

        showsCleanModeCTA = false
        pendingReaderSession = session
    }

    public func clearPendingReaderSession(_ session: MockReaderSession) {
        if pendingReaderSession == session {
            pendingReaderSession = nil
        }
    }

    public func presentPendingReaderInsideBrowser(_ session: MockReaderSession) {
        guard isViableReaderSession(session) else {
            clearPendingReaderSession(session)
            return
        }

        browserOwnedReaderSession = session
        clearPendingReaderSession(session)
        readerPresentationLogger.log(.browserOwnedReaderVisible)
    }

    public func dismissBrowserOwnedReader() {
        browserOwnedReaderSession = nil
        readerPresentationLogger.log(.none)
    }

    public func clearCommand(_ command: BrowserCommand) {
        if pendingCommand == command {
            pendingCommand = nil
        }
    }

    private func viableReaderSession(from session: MockReaderSession?) -> MockReaderSession? {
        guard let session, isViableReaderSession(session) else {
            return nil
        }

        return session
    }

    private func isViableReaderSession(_ session: MockReaderSession) -> Bool {
        !session.imageURLs.isEmpty
    }
}
