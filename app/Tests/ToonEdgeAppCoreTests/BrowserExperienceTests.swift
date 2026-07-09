import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func directURLStartPointBuildsInitialBrowserRequest() throws {
    let request = try #require(BrowserRequest(startPoint: .url("https://example.com/chapter-12")))

    #expect(request.url.absoluteString == "https://example.com/chapter-12")
    #expect(request.displayText == "example.com")
}

@Test func queryStartPointBuildsSearchResultsRequest() throws {
    let request = try #require(BrowserRequest(startPoint: .searchQuery("moonlit edge chapter 13")))

    #expect(request.url.host() == "www.google.com")
    #expect(request.url.query(percentEncoded: false)?.contains("q=moonlit edge chapter 13") == true)
    #expect(request.displayText == "moonlit edge chapter 13")
}

@MainActor
@Test func browserViewModelTracksNavigationState() {
    let viewModel = BrowserViewModel(startPoint: .url("https://example.com/chapter-12"))

    viewModel.updateNavigation(
        url: URL(string: "https://example.com/chapter-13")!,
        title: "Chapter 13",
        canGoBack: true,
        canGoForward: false,
        isLoading: false
    )

    #expect(viewModel.addressDisplay == "example.com")
    #expect(viewModel.pageTitle == "Chapter 13")
    #expect(viewModel.canGoBack)
    #expect(!viewModel.canGoForward)
    #expect(!viewModel.isLoading)
}

@Test func detectedSessionLibraryInputUsesExplicitSaveState() throws {
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: try #require(URL(string: "https://example.com/series/chapter-12")),
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    let input = DetectedSessionLibraryInputBuilder.input(
        for: session,
        addressDisplay: "example.com",
        libraryState: .dropped
    )

    #expect(input.libraryState == .dropped)
}

@MainActor
@Test func browserViewModelCanLoadExplicitURLIntoExistingBrowser() throws {
    let viewModel = BrowserViewModel(startPoint: .url("https://example.com/chapter-12"))
    let seriesURL = try #require(URL(string: "https://example.com/series"))

    viewModel.load(seriesURL)

    #expect(viewModel.pendingCommand?.action == .loadURL(seriesURL))
}

@MainActor
@Test func browserOwnsDetectedReaderPresentationWithoutChangingAppShellReader() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let startPoint = BrowserStartPoint.url(pageURL.absoluteString)
    var router = AppRouter()
    router.presentBrowser(startPoint)
    let viewModel = BrowserViewModel(startPoint: startPoint)
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(viewModel.browserOwnedReaderSession == session)
    #expect(viewModel.pendingReaderSession == nil)
    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedReader == nil)
}

@MainActor
@Test func dismissingBrowserOwnedReaderKeepsBrowserPresented() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let startPoint = BrowserStartPoint.url(pageURL.absoluteString)
    var router = AppRouter()
    router.presentBrowser(startPoint)
    let viewModel = BrowserViewModel(startPoint: startPoint)
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.presentPendingReaderInsideBrowser(session)
    viewModel.dismissBrowserOwnedReader()

    #expect(viewModel.browserOwnedReaderSession == nil)
    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedReader == nil)
}

@MainActor
@Test func browserReaderPresentationStateTracksPendingAndVisibleReader() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.readerPresentationState == .pendingBrowserOwnedReader)

    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(viewModel.readerPresentationState == .browserOwnedReaderVisible)
}

@MainActor
@Test func browserDoesNotPresentEmptyReaderSession() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let emptySession = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: []
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: emptySession,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(emptySession)

    #expect(viewModel.pendingReaderSession == nil)
    #expect(viewModel.browserOwnedReaderSession == nil)
    #expect(viewModel.readerPresentationState == .none)
}

@MainActor
@Test func browserReaderPresentationLogsPendingAndVisibleTransitions() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let logger = RecordingBrowserReaderPresentationLogger()
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerPresentationLogger: logger
    )
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))]
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(logger.events == [.pendingBrowserOwnedReader, .browserOwnedReaderVisible])
}

@Test func detectedSessionLibraryInputUsesCanonicalSeriesURLAndNumericChapterLabel() throws {
    let sourceURL = try #require(URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/3"))
    let session = MockReaderSession(
        seriesTitle: "The Cold-Blooded Warrior | Asura Scans",
        chapterTitle: "The Cold-Blooded Warrior Chapter 3 - Read Online | Asura Scans",
        sourceURL: sourceURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/page-1.jpg"))]
    )

    let input = DetectedSessionLibraryInputBuilder.input(
        for: session,
        addressDisplay: "asurascans.com"
    )

    #expect(input.canonicalURL == URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241")!)
    #expect(input.latestKnownChapterLabel == "3")
    #expect(input.chapters.first?.chapterLabel == "3")
    #expect(input.chapters.first?.chapterNumber == 3)
}

@Test func homeContinueReadingNavigationDoesNotFallbackToMockExampleDomain() throws {
    #expect(HomeContinueReadingNavigation.browserStartPoint(for: nil) == nil)

    let sourceURL = try #require(URL(string: "https://asurascans.com/comics/sample/chapter/4"))
    let target = ContinueReadingTarget(
        seriesID: UUID(),
        chapterID: UUID(),
        sourceURL: sourceURL,
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
    )

    #expect(HomeContinueReadingNavigation.browserStartPoint(for: target) == .url(sourceURL.absoluteString))
}

private final class RecordingBrowserReaderPresentationLogger: BrowserReaderPresentationLogging, @unchecked Sendable {
    private(set) var events: [BrowserReaderPresentationState] = []

    func log(_ state: BrowserReaderPresentationState) {
        events.append(state)
    }
}

@Test func viewOriginalPageKeepsExistingBrowserStateWhenReaderWasOpenedAboveBrowser() {
    var router = AppRouter()
    let originalStartPoint = BrowserStartPoint.searchQuery("sample chapter")

    router.presentBrowser(originalStartPoint)
    router.presentReader(.sample)
    router.viewOriginalPage()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == originalStartPoint)
}

@Test func browserDetectionRetryPolicyAllowsOnlyOneFollowUpPerURL() throws {
    var policy = BrowserDetectionRetryPolicy()
    let firstURL = try #require(URL(string: "https://mangafire.to/read/sample/en/chapter-1"))
    let secondURL = try #require(URL(string: "https://mangafire.to/read/sample/en/chapter-2"))
    let firstAttempt = policy.shouldScheduleFollowUp(for: firstURL, recommendation: .browserSessionFollowUp)
    let duplicateAttempt = policy.shouldScheduleFollowUp(for: firstURL, recommendation: .browserSessionFollowUp)
    let nonRetryAttempt = policy.shouldScheduleFollowUp(for: firstURL, recommendation: .none)
    let secondURLAttempt = policy.shouldScheduleFollowUp(for: secondURL, recommendation: .browserSessionFollowUp)

    #expect(firstAttempt)
    #expect(!duplicateAttempt)
    #expect(!nonRetryAttempt)
    #expect(secondURLAttempt)
}

@Test func browserPopupPolicyBlocksThirdPartyTargetWindowPopups() throws {
    let pageURL = try #require(URL(string: "https://manhuaus.com/manga/sample/chapter-1/"))
    let sameHostURL = try #require(URL(string: "https://manhuaus.com/manga/sample/chapter-2/"))
    let adURL = try #require(URL(string: "https://ads.example.com/popunder"))
    let policy = BrowserPopupPolicy()

    #expect(policy.shouldAllowTargetWindowNavigation(to: sameHostURL, from: pageURL))
    #expect(!policy.shouldAllowTargetWindowNavigation(to: adURL, from: pageURL))
}

@Test func browserPageSanitizerScriptSuppressesCommonAdAndPopupSurfaces() {
    #expect(BrowserPageSanitizerScript.javaScript.contains("window.open"))
    #expect(BrowserPageSanitizerScript.javaScript.contains("popup"))
    #expect(BrowserPageSanitizerScript.javaScript.contains("advert"))
    #expect(BrowserPageSanitizerScript.javaScript.contains("wp-manga"))
}
