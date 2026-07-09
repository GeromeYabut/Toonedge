import Foundation

public struct AppRouter: Equatable, Sendable {
    public var selectedTab: AppTab
    public var activeSheet: AppSheet?
    public var presentedBrowser: BrowserStartPoint?
    public var presentedReader: MockReaderSession?
    public var pendingLibrarySeriesID: UUID?
    public var pendingLibrarySegment: LibrarySegment?

    public init(
        selectedTab: AppTab = .home,
        activeSheet: AppSheet? = nil,
        presentedBrowser: BrowserStartPoint? = nil,
        presentedReader: MockReaderSession? = nil,
        pendingLibrarySeriesID: UUID? = nil,
        pendingLibrarySegment: LibrarySegment? = nil
    ) {
        self.selectedTab = selectedTab
        self.activeSheet = activeSheet
        self.presentedBrowser = presentedBrowser
        self.presentedReader = presentedReader
        self.pendingLibrarySeriesID = pendingLibrarySeriesID
        self.pendingLibrarySegment = pendingLibrarySegment
    }

    public mutating func presentSearch() {
        activeSheet = .search
    }

    public mutating func dismissSheet() {
        activeSheet = nil
    }

    public mutating func presentBrowser(_ startPoint: BrowserStartPoint) {
        activeSheet = nil
        presentedBrowser = startPoint
    }

    public mutating func dismissBrowser() {
        presentedBrowser = nil
    }

    public mutating func presentReader(_ session: MockReaderSession) {
        presentedReader = session
    }

    public mutating func dismissReader() {
        presentedReader = nil
    }

    public mutating func viewOriginalPage() {
        guard let sourceURL = presentedReader?.sourceURL else {
            presentedReader = nil
            return
        }

        presentedReader = nil
        if presentedBrowser == nil {
            presentedBrowser = .url(sourceURL.absoluteString)
        }
    }

    public mutating func dismissReaderToSeries() {
        guard let seriesURL = presentedReader?.seriesURL else {
            presentedReader = nil
            return
        }

        presentedReader = nil
        presentedBrowser = .url(seriesURL.absoluteString)
    }

    public mutating func navigateBackFromReader() {
        guard let session = presentedReader else { return }

        switch session.launchOrigin {
        case .library(let seriesID):
            openLibraryDetail(seriesID: seriesID)
        case .homeContinueReading:
            selectedTab = .home
            presentedReader = nil
            pendingLibrarySeriesID = nil
            pendingLibrarySegment = nil
        case .browser:
            dismissReaderToSeries()
        case .direct:
            dismissReader()
        }
    }

    public mutating func openLibraryRoot() {
        selectedTab = .library
        pendingLibrarySeriesID = nil
        pendingLibrarySegment = nil
        presentedReader = nil
        presentedBrowser = nil
    }

    public mutating func openHomeRoot() {
        selectedTab = .home
        activeSheet = nil
        pendingLibrarySeriesID = nil
        pendingLibrarySegment = nil
        presentedReader = nil
        presentedBrowser = nil
    }

    public mutating func openLibraryRecent() {
        selectedTab = .library
        pendingLibrarySeriesID = nil
        pendingLibrarySegment = .recent
        presentedReader = nil
        presentedBrowser = nil
    }

    public mutating func openLibraryDetail(seriesID: UUID) {
        selectedTab = .library
        pendingLibrarySeriesID = seriesID
        pendingLibrarySegment = nil
        presentedReader = nil
        presentedBrowser = nil
    }

    public mutating func consumePendingLibrarySeriesID() -> UUID? {
        defer { pendingLibrarySeriesID = nil }
        return pendingLibrarySeriesID
    }

    public mutating func consumePendingLibrarySegment() -> LibrarySegment? {
        defer { pendingLibrarySegment = nil }
        return pendingLibrarySegment
    }
}
