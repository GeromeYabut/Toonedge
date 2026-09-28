import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func homeContinueBrowserFallbackPreservesHomeOrigin() throws {
    let sourceURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let target = ContinueReadingTarget(seriesID: UUID(), chapterID: UUID(), sourceURL: sourceURL, progress: .init(currentImageIndex: 0, totalImageCount: 0))
    var router = AppRouter()

    HomeContinueReadingNavigation.presentBrowserFallback(for: target, router: &router)

    #expect(router.presentedBrowser == .url(sourceURL.absoluteString))
    #expect(router.presentedBrowserReaderLaunchOrigin == .homeContinueReading)
}

@Test func presentingBrowserStoresStartPoint() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/chapter-1")

    router.presentBrowser(startPoint)

    #expect(router.presentedBrowser == startPoint)
    #expect(router.activeSheet == nil)
}

@Test func presentingBrowserCanCarryReaderLaunchOrigin() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-107")
    let seriesID = UUID()

    router.presentBrowser(startPoint, readerLaunchOrigin: .library(seriesID: seriesID))

    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedBrowserReaderLaunchOrigin == .library(seriesID: seriesID))
    #expect(router.activeSheet == nil)
}

@Test func dismissingBrowserClearsReaderLaunchOriginOverride() {
    var router = AppRouter()
    router.presentBrowser(
        .url("https://example.com/series/chapter-107"),
        readerLaunchOrigin: .library(seriesID: UUID())
    )

    router.dismissBrowser()

    #expect(router.presentedBrowser == nil)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
}

@Test func clearingBrowserReaderLaunchOriginKeepsBrowserVisible() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-107")
    router.presentBrowser(startPoint, readerLaunchOrigin: .library(seriesID: UUID()))

    router.clearPresentedBrowserReaderLaunchOrigin()

    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
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

@Test func readerBackFromLibraryFallbackDetectedReaderReturnsToSeriesDetail() {
    var router = AppRouter(selectedTab: .library)
    let seriesID = UUID()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-107")
    var detectedSession = MockReaderSession.sample
    detectedSession.launchOrigin = .library(seriesID: seriesID)

    router.presentBrowser(startPoint, readerLaunchOrigin: .library(seriesID: seriesID))
    router.presentReader(detectedSession)
    router.clearPresentedBrowserReaderLaunchOrigin()
    router.navigateBackFromReader()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == nil)
    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == seriesID)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
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

@Test func readerLibraryActionOpensLibraryRootFromEveryLaunchOrigin() {
    let origins: [ReaderLaunchOrigin] = [
        .browser,
        .homeContinueReading,
        .library(seriesID: UUID())
    ]

    for origin in origins {
        var router = AppRouter(selectedTab: .home)
        var session = MockReaderSession.sample
        session.launchOrigin = origin
        router.presentReader(session)

        router.openLibraryRoot()

        #expect(router.selectedTab == .library)
        #expect(router.presentedReader == nil)
        #expect(router.presentedBrowser == nil)
        #expect(router.pendingLibrarySeriesID == nil)
    }
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
    var router = AppRouter(selectedTab: .home)
    let seriesID = UUID()

    router.openLibraryDetail(seriesID: seriesID)

    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == seriesID)
    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == nil)
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
