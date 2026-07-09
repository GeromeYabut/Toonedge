import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func presentingBrowserStoresStartPoint() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/chapter-1")

    router.presentBrowser(startPoint)

    #expect(router.presentedBrowser == startPoint)
    #expect(router.activeSheet == nil)
}

@Test func viewingOriginalPageOpensSourceURLWhenNoBrowserIsPresent() {
    var router = AppRouter()
    let readerSession = MockReaderSession.sample

    router.presentReader(readerSession)
    router.viewOriginalPage()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == .url(readerSession.sourceURL.absoluteString))
}

@Test func viewOriginalPageAfterAdjacentReplacementUsesCurrentChapterURL() {
    var router = AppRouter()
    var loaded = MockReaderSession.sample
    loaded.sourceURL = URL(string: "https://example.com/chapter-2")!

    router.presentReader(loaded)
    router.viewOriginalPage()

    #expect(router.presentedBrowser == .url("https://example.com/chapter-2"))
}

@Test func searchOverlayCanBePresentedAndDismissed() {
    var router = AppRouter()

    router.presentSearch()
    #expect(router.activeSheet == .search)

    router.dismissSheet()
    #expect(router.activeSheet == nil)
}

@Test func dismissingReaderToSeriesOpensCanonicalSeriesURL() {
    var router = AppRouter()
    let readerSession = MockReaderSession.sample

    router.presentReader(readerSession)
    router.dismissReaderToSeries()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == .url(readerSession.seriesURL.absoluteString))
}

@Test func readerBackFromLibraryReturnsToSeriesDetail() {
    var router = AppRouter()
    let seriesID = UUID()
    var session = MockReaderSession.sample
    session.launchOrigin = .library(seriesID: seriesID)

    router.presentReader(session)
    router.navigateBackFromReader()

    #expect(router.presentedReader == nil)
    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == seriesID)
}

@Test func readerBackFromHomeContinueReadingReturnsHome() {
    var router = AppRouter(selectedTab: .library)
    var session = MockReaderSession.sample
    session.launchOrigin = .homeContinueReading

    router.presentReader(session)
    router.navigateBackFromReader()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == nil)
    #expect(router.selectedTab == .home)
    #expect(router.pendingLibrarySeriesID == nil)
}

@Test func readerBackFromBrowserOpensCanonicalSeriesURL() {
    var router = AppRouter()
    var session = MockReaderSession.sample
    session.launchOrigin = .browser

    router.presentReader(session)
    router.navigateBackFromReader()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == .url(session.seriesURL.absoluteString))
}

@Test func openingLibraryRootDismissesReaderWithoutSelectingSeriesDetail() {
    var router = AppRouter()
    router.presentReader(.sample)
    router.openLibraryDetail(seriesID: UUID())

    router.openLibraryRoot()

    #expect(router.presentedReader == nil)
    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == nil)
}

@Test func openingLibraryRootDismissesBrowserOwnedReaderSoLibraryIsVisible() {
    var router = AppRouter()
    router.presentBrowser(.url("https://example.com/series/chapter-12"))
    router.presentReader(.sample)

    router.openLibraryRoot()

    #expect(router.selectedTab == .library)
    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == nil)
    #expect(router.pendingLibrarySeriesID == nil)
}

@Test func openingLibraryRecentSelectsLibraryRootRecentSegment() {
    var router = AppRouter(selectedTab: .home)

    router.openLibraryRecent()

    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySegment == .recent)
    #expect(router.pendingLibrarySeriesID == nil)
}

@Test func openingLibraryDetailSelectsLibraryAndStoresDestination() {
    var router = AppRouter()
    let seriesID = UUID()

    router.openLibraryDetail(seriesID: seriesID)

    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == seriesID)
}

@Test func openingHomeRootDismissesReaderBrowserAndPendingLibraryDestinations() {
    var router = AppRouter(selectedTab: .library)
    router.presentSearch()
    router.presentBrowser(.url("https://example.com/series/chapter-12"))
    router.presentReader(.sample)
    router.openLibraryDetail(seriesID: UUID())
    router.pendingLibrarySegment = .recent
    router.activeSheet = .search

    router.openHomeRoot()

    #expect(router.selectedTab == .home)
    #expect(router.activeSheet == nil)
    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == nil)
    #expect(router.pendingLibrarySeriesID == nil)
    #expect(router.pendingLibrarySegment == nil)
}
