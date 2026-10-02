import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func manualDispositionShowsOnlySecondaryAction() {
    let result = browserEntryResult(.manual)
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    #expect(!model.showsCleanModeCTA)
    #expect(model.pendingReaderSession == nil)
    model.enterCleanModeManually()
    #expect(model.pendingReaderSession == result.readerSession)
}

@MainActor
@Test func browserEntryHonorsDispositionRatherThanConfidence() {
    var result = browserEntryResult(.recommended)
    result.confidence = .high
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    #expect(model.showsCleanModeCTA)
    #expect(model.pendingReaderSession == nil)
}

@MainActor
@Test func unavailableDispositionCannotEnterReader() {
    var result = browserEntryResult(.manual)
    result.readerEntryDisposition = .unavailable
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    model.enterCleanModeManually()
    model.presentPendingReaderInsideBrowser(result.readerSession!)
    #expect(model.pendingReaderSession == nil)
    #expect(model.browserOwnedReaderSession == nil)
}

@MainActor
@Test func typedHardBlocksPreventEveryBrowserEntry() {
    for block in DetectionHardBlock.allCases {
        for disposition in [ReaderEntryDisposition.automatic, .recommended, .manual] {
            var result = browserEntryResult(disposition)
            result.diagnostics.hardBlocks = [block]
            let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
            model.handleDetectionResult(result)
            model.enterCleanModeManually()
            model.presentPendingReaderInsideBrowser(result.readerSession!)
            #expect(!model.showsCleanModeCTA)
            #expect(model.pendingReaderSession == nil)
            #expect(model.browserOwnedReaderSession == nil)
        }
    }
}

@MainActor
@Test func unreadableResultRemovesEligibilityAndKeepsExactBrowserNavigation() {
    let result = browserEntryResult(.manual)
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.updateNavigation(url: result.pageURL, title: "Synthetic chapter", canGoBack: true, canGoForward: true, isLoading: false)
    model.handleDetectionResult(result)
    model.handleUnreadableDetectionResult(result)
    model.enterCleanModeManually()
    model.presentPendingReaderInsideBrowser(result.readerSession!)
    #expect(model.detectionResult?.readerSession == nil)
    #expect(model.detectionResult?.readerEntryDisposition == .unavailable)
    #expect(model.pendingReaderSession == nil)
    #expect(model.browserOwnedReaderSession == nil)
    #expect(model.readerUnavailableMessage != nil)
    #expect(model.currentURL == result.pageURL)
    #expect(model.canGoBack && model.canGoForward)
    #expect(model.pendingCommand == nil)
}

@MainActor
@Test func freshUnavailableResultClearsPreviousAutomaticPendingEntry() {
    let result = browserEntryResult(.automatic)
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    var unavailable = result
    unavailable.readerEntryDisposition = .unavailable
    model.handleDetectionResult(unavailable)
    model.presentPendingReaderInsideBrowser(result.readerSession!)
    #expect(model.pendingReaderSession == nil)
    #expect(model.browserOwnedReaderSession == nil)
}

@MainActor
@Test func navigationClearsEntryAndRejectsPreviousPendingReader() {
    let result = browserEntryResult(.automatic)
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    model.navigationDidStart()
    model.presentPendingReaderInsideBrowser(result.readerSession!)
    #expect(model.detectionResult == nil)
    #expect(model.pendingReaderSession == nil)
    #expect(model.browserOwnedReaderSession == nil)
}

@MainActor
@Test func automaticDispositionCannotBeEnteredThroughManualAction() {
    let result = browserEntryResult(.automatic)
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    model.clearPendingReaderSession(result.readerSession!)
    model.enterCleanModeManually()
    #expect(model.pendingReaderSession == nil)
}

@MainActor
@Test func browserRejectsSessionForDifferentSourcePage() {
    var result = browserEntryResult(.manual)
    result.readerSession?.sourceURL = URL(string: "https://fixture.toonedge.test/other-chapter")!
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    model.enterCleanModeManually()
    #expect(model.pendingReaderSession == nil)
}

@MainActor
@Test func browserReloadImmediatelyClearsManualEligibility() {
    let result = browserEntryResult(.manual)
    let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
    model.handleDetectionResult(result)
    model.reload()
    model.enterCleanModeManually()
    #expect(model.pendingReaderSession == nil)
    #expect(model.detectionResult == nil)
    #expect(model.pendingCommand?.action == .reload)
}

@MainActor
@Test func queuedNavigationRejectsLateAutomaticAndManualDetection() throws {
    for action in ["reload", "load", "back", "forward"] {
        for disposition in [ReaderEntryDisposition.automatic, .recommended, .manual] {
            let result = browserEntryResult(disposition)
            let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
            model.updateNavigation(url: result.pageURL, title: nil, canGoBack: true, canGoForward: true, isLoading: false)
            model.handleDetectionResult(result)
            enqueueBrowserNavigation(action, on: model)
            let command = try #require(model.pendingCommand)

            // The old WebView is still idle and its command has not been consumed.
            model.handleDetectionResult(result)
            model.enterCleanModeManually()
            model.presentPendingReaderInsideBrowser(result.readerSession!)

            #expect(model.detectionResult == nil)
            #expect(model.cleanModePresentation == .hidden)
            #expect(model.pendingReaderSession == nil)
            #expect(model.browserOwnedReaderSession == nil)
            #expect(model.pendingCommand == command)
        }
    }
}

@MainActor
@Test func queuedNavigationRejectsLateUnreadableDelivery() throws {
    for action in ["reload", "load", "back", "forward"] {
        let result = browserEntryResult(.manual)
        let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
        model.updateNavigation(url: result.pageURL, title: nil, canGoBack: true, canGoForward: true, isLoading: false)
        model.handleDetectionResult(result)
        enqueueBrowserNavigation(action, on: model)
        let command = try #require(model.pendingCommand)

        model.handleUnreadableDetectionResult(result)

        #expect(model.detectionResult == nil)
        #expect(model.readerUnavailableMessage == nil)
        #expect(model.cleanModePresentation == .hidden)
        #expect(model.pendingReaderSession == nil)
        #expect(model.pendingCommand == command)
    }
}

@MainActor
@Test func consumedNavigationAcceptsFreshDetectionAfterNavigation() throws {
    for disposition in [ReaderEntryDisposition.automatic, .recommended, .manual] {
        let result = browserEntryResult(disposition)
        let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
        model.reload()
        let command = try #require(model.pendingCommand)
        model.clearCommand(command)
        model.navigationDidStart()
        model.updateNavigation(url: result.pageURL, title: nil, canGoBack: true, canGoForward: false, isLoading: false)

        model.handleDetectionResult(result)

        #expect(model.detectionResult == result)
        if disposition == .automatic {
            #expect(model.pendingReaderSession == result.readerSession)
        } else {
            #expect(model.cleanModePresentation == (disposition == .recommended ? .recommendedBanner : .manualTool))
            model.enterCleanModeManually()
            #expect(model.pendingReaderSession == result.readerSession)
        }
    }
}

@MainActor
private func enqueueBrowserNavigation(_ action: String, on model: BrowserViewModel) {
    switch action {
    case "reload": model.reload()
    case "load": model.load(URL(string: "https://fixture.toonedge.test/chapter-2")!)
    case "back": model.goBack()
    case "forward": model.goForward()
    default: preconditionFailure("Unknown synthetic navigation action")
    }
}

private func browserEntryResult(
    _ disposition: ReaderEntryDisposition,
    session suppliedSession: MockReaderSession? = nil
) -> DetectionResult {
    let pageURL = suppliedSession?.sourceURL ?? URL(string: "https://fixture.toonedge.test/chapter-1?position=7#panel-2")!
    let session = suppliedSession ?? MockReaderSession(
        seriesTitle: "Synthetic Fixture",
        chapterTitle: "Chapter 1",
        sourceURL: pageURL,
        imageURLs: [URL(string: "https://images.example.test/001.jpg")!]
    )
    return DetectionResult(
        pageURL: pageURL, confidence: .low, score: 50, candidates: [],
        readerSession: session,
        diagnostics: .init(confidence: .low, score: 50, parserPath: .genericHeuristic),
        readerEntryDisposition: disposition
    )
}

@MainActor
@Test func browserEntryPresentationDistinguishesEveryDisposition() {
    for (disposition, expected) in [
        (ReaderEntryDisposition.automatic, BrowserCleanModePresentation.hidden),
        (.recommended, .recommendedBanner), (.manual, .manualTool), (.unavailable, .hidden)
    ] {
        let result = browserEntryResult(disposition)
        let model = BrowserViewModel(startPoint: .url(result.pageURL.absoluteString))
        model.handleDetectionResult(result)
        #expect(model.cleanModePresentation == expected)
        #expect((model.pendingReaderSession != nil) == (disposition == .automatic))
        model.navigationDidStart()
        #expect(model.cleanModePresentation == .hidden)
    }
}

@Test func sameURLReloadReschedulesDetectionAndInvalidatesOldGeneration() {
    let url = URL(string: "https://fixture.toonedge.test/chapter-1")!
    var policy = BrowserDetectionNavigationPolicy()
    let oldGeneration = policy.generation
    let initial = policy.shouldSchedule(url: url, isLoading: false)
    #expect(initial)
    policy.navigationDidStart()
    #expect(policy.generation != oldGeneration)
    #expect(!policy.isCurrent(oldGeneration))
    let reload = policy.shouldSchedule(url: url, isLoading: false)
    #expect(reload)
    #expect(policy.isCurrent(policy.generation))
    let duplicate = policy.shouldSchedule(url: url, isLoading: false)
    #expect(!duplicate)
}

@Test func quietBrowserChromeDoesNotDuplicateReloadOrStatusLabel() {
    let layout = BrowserChromeLayout()

    #expect(layout.reloadPlacement == .bottomToolbar)
    #expect(layout.showsTopReload == false)
    #expect(layout.showsDecorativeBrowserStatus == false)
    #expect(layout.minimumActionSize == 44)
}

@Test func browserChromeLayoutExposesStableActionIdentifiers() {
    let layout = BrowserChromeLayout()

    #expect(layout.cleanModeActionIdentifier == "browser.cleanModeAction")
    #expect(layout.manualCleanModeActionIdentifier == "browser.tryCleanMode")
    #expect(layout.closeActionIdentifier == "browser.close")
    #expect(layout.reloadActionIdentifier == "browser.reload")
    #expect(layout.backActionIdentifier == "browser.back")
    #expect(layout.forwardActionIdentifier == "browser.forward")
}

@Test func routeObservationSchedulesSettledURLOnce() throws {
    let series = try #require(URL(string: "https://vortexscans.org/series/past-life-returner"))
    let chapter = try #require(URL(string: "https://vortexscans.org/series/past-life-returner/chapter-169"))
    var policy = BrowserDetectionNavigationPolicy()

    let loadingSeries = policy.shouldSchedule(url: series, isLoading: true)
    let settledSeries = policy.shouldSchedule(url: series, isLoading: false)
    let loadingChapter = policy.shouldSchedule(url: chapter, isLoading: true)
    let settledChapter = policy.shouldSchedule(url: chapter, isLoading: false)
    let duplicateChapter = policy.shouldSchedule(url: chapter, isLoading: false)
    #expect(!loadingSeries)
    #expect(settledSeries)
    #expect(!loadingChapter)
    #expect(settledChapter)
    #expect(!duplicateChapter)
}

@MainActor
@Test func unreadableDetectedSessionStaysInBrowserWithFallbackMessage() throws {
    let sourceURL = try #require(URL(string: "https://comizy.io/sample/chapter-1"))
    let session = MockReaderSession(
        seriesTitle: "Fixture",
        chapterTitle: "Chapter 1",
        sourceURL: sourceURL,
        imageURLs: [try #require(URL(string: "https://images.example.test/001.jpg"))]
    )
    let viewModel = BrowserViewModel(startPoint: .url(sourceURL.absoluteString))
    let result = DetectionResult(
        pageURL: sourceURL,
        confidence: .high,
        score: 90,
        candidates: [],
        readerSession: session,
        diagnostics: .init(confidence: .high, score: 90, parserPath: .genericHeuristic)
    )

    viewModel.handleUnreadableDetectionResult(result)

    #expect(viewModel.pendingReaderSession == nil)
    #expect(!viewModel.showsCleanModeCTA)
    #expect(viewModel.readerUnavailableMessage != nil)
    #expect(viewModel.currentURL == sourceURL)
}

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

    viewModel.handleDetectionResult(browserEntryResult(.automatic, session: session))
    viewModel.presentPendingReaderInsideBrowser(session)
    viewModel.dismissBrowserOwnedReader()

    #expect(viewModel.browserOwnedReaderSession == nil)
    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedReader == nil)
}

@MainActor
@Test func browserOwnedReaderAcceptsOnlyViableAdjacentSessionReplacement() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let adjacentURL = try #require(URL(string: "https://example.com/series/chapter-13"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let current = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/12-1.jpg"))]
    )
    var adjacent = current
    adjacent.chapterTitle = "Chapter 13"
    adjacent.sourceURL = adjacentURL
    adjacent.imageURLs = [try #require(URL(string: "https://img.example.com/13-1.jpg"))]

    viewModel.handleDetectionResult(browserEntryResult(.automatic, session: current))
    viewModel.presentPendingReaderInsideBrowser(current)
    viewModel.replaceBrowserOwnedReaderSession(adjacent)

    #expect(viewModel.browserOwnedReaderSession?.sourceURL == adjacentURL)
    #expect(viewModel.pendingCommand == nil)
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
@Test func browserReaderPresentationAppliesLibraryLaunchOriginOverrideForInitialURL() throws {
    let seriesID = UUID()
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: seriesID)
    )
    let session = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
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

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .library(seriesID: seriesID))
    #expect(viewModel.readerPresentationState == .browserOwnedReaderVisible)
}

@Test func browserOwnedReaderBackFromLibraryOriginReturnsToSeriesDetail() {
    let seriesID = UUID()
    var router = AppRouter(selectedTab: .library)
    var session = MockReaderSession.sample
    session.launchOrigin = .library(seriesID: seriesID)

    BrowserOwnedReaderBackRoute(session: session).apply(to: &router)

    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == seriesID)
    #expect(router.presentedBrowser == nil)
    #expect(router.presentedReader == nil)
}

@MainActor
@Test func browserReaderPresentationKeepsBrowserOriginWithoutOverride() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
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

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .browser)
}

@MainActor
@Test func browserReaderLaunchOriginOverrideDoesNotApplyToDifferentURL() throws {
    let initialURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let navigatedURL = try #require(URL(string: "https://example.com/other/chapter-1"))
    let viewModel = BrowserViewModel(
        startPoint: .url(initialURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: UUID())
    )
    let session = MockReaderSession(
        seriesTitle: "Other Series",
        chapterTitle: "Chapter 1",
        sourceURL: navigatedURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )

    viewModel.updateNavigation(
        url: navigatedURL,
        title: "Other Series Chapter 1",
        canGoBack: true,
        canGoForward: false,
        isLoading: false
    )
    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: navigatedURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .browser)
    #expect(viewModel.readerPresentationState == .browserOwnedReaderVisible)

    let initialSession = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: initialURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/2.jpg"))],
        launchOrigin: .browser
    )

    viewModel.dismissBrowserOwnedReader()
    viewModel.presentPendingReaderInsideBrowser(initialSession)

    #expect(viewModel.browserOwnedReaderSession == nil)
}

@MainActor
@Test func browserReaderLaunchOriginOverrideIsConsumedAfterVisibleReaderPresentation() throws {
    let seriesID = UUID()
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: seriesID)
    )
    let firstSession = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )
    let secondSession = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/2.jpg"))],
        launchOrigin: .browser
    )

    viewModel.handleDetectionResult(browserEntryResult(.automatic, session: firstSession))
    viewModel.presentPendingReaderInsideBrowser(firstSession)
    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .library(seriesID: seriesID))

    viewModel.dismissBrowserOwnedReader()
    viewModel.handleDetectionResult(browserEntryResult(.automatic, session: secondSession))
    viewModel.presentPendingReaderInsideBrowser(secondSession)

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .browser)
}

@MainActor
@Test func browserReaderLaunchOriginOverrideDoesNotPromoteLowConfidenceDetection() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: UUID())
    )
    let session = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .low,
            score: 20,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .low, score: 20, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == nil)
    #expect(viewModel.browserOwnedReaderSession == nil)
    #expect(viewModel.readerPresentationState == .none)
    #expect(!viewModel.isLoading)
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

@MainActor
@Test func browserSaveFeedbackRequiresAuthoritativeSuccessAndExposesFailure() async {
    let feedback = RecordingInteractionFeedback()
    let operation = BrowserLibrarySaveOperation(interactionFeedback: feedback)
    let savedSessionID = UUID()

    let saved = await operation.perform(sessionID: savedSessionID) { }
    #expect(saved)
    #expect(operation.failureMessage == nil)
    #expect(feedback.events == [.operationSucceeded])

    let failedOperation = BrowserLibrarySaveOperation(interactionFeedback: feedback)
    let failedSessionID = UUID()
    let failed = await failedOperation.perform(sessionID: failedSessionID) {
        throw URLError(.cannotWriteToFile)
    }
    #expect(!failed)
    #expect(failedOperation.failureMessage == "Could not save this series.")
    #expect(!failedOperation.isSaving)
    #expect(feedback.events == [.operationSucceeded])
}

@MainActor
@Test func duplicateBrowserSaveWhileAuthoritativeSaveIsPendingRemainsSilent() async {
    let feedback = RecordingInteractionFeedback()
    let operation = BrowserLibrarySaveOperation(interactionFeedback: feedback)
    let gate = SuspendedBrowserSaveGate()

    let firstSave = Task {
        await operation.perform {
            await gate.suspend()
        }
    }
    await gate.waitUntilSuspended()

    let duplicateSave = await operation.perform { }
    #expect(!duplicateSave)
    #expect(feedback.events.isEmpty)

    await gate.resume()
    #expect(await firstSave.value)
    #expect(feedback.events == [.operationSucceeded])
}

@MainActor
@Test func browserSaveCompletionFromPreviousDetectedSessionIsStaleAndSilent() async {
    let feedback = RecordingInteractionFeedback()
    let operation = BrowserLibrarySaveOperation(interactionFeedback: feedback)
    let previousSessionGate = SuspendedBrowserSaveGate()
    let previousSessionID = UUID()
    let currentSessionID = UUID()

    let previousSessionSave = Task {
        await operation.perform(sessionID: previousSessionID) {
            await previousSessionGate.suspend()
        }
    }
    await previousSessionGate.waitUntilSuspended()

    operation.reset(for: currentSessionID)
    #expect(!operation.isSaving)
    #expect(operation.successMessage == nil)
    #expect(operation.failureMessage == nil)

    #expect(await operation.perform(sessionID: currentSessionID) { })
    #expect(operation.successMessage == "Saved to Library")
    #expect(feedback.events == [.operationSucceeded])

    await previousSessionGate.resume()
    #expect(!(await previousSessionSave.value))
    #expect(operation.successMessage == "Saved to Library")
    #expect(operation.failureMessage == nil)
    #expect(feedback.events == [.operationSucceeded])
}

@MainActor
@Test func repeatedBrowserSaveAfterConfirmedSuccessIsVisibleAndSilent() async {
    let feedback = RecordingInteractionFeedback()
    let operation = BrowserLibrarySaveOperation(interactionFeedback: feedback)

    #expect(await operation.perform { })
    #expect(operation.isSaved)
    #expect(operation.successMessage == "Saved to Library")

    #expect(!(await operation.perform { }))
    #expect(feedback.events == [.operationSucceeded])
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
    let firstAttempt = policy.shouldScheduleFollowUp(for: firstURL, recommendation: .browserSessionFollowUp, confidence: .low)
    let duplicateAttempt = policy.shouldScheduleFollowUp(for: firstURL, recommendation: .browserSessionFollowUp, confidence: .low)
    let nonRetryAttempt = policy.shouldScheduleFollowUp(for: firstURL, recommendation: .none, confidence: .low)
    let secondURLAttempt = policy.shouldScheduleFollowUp(for: secondURL, recommendation: .browserSessionFollowUp, confidence: .low)

    #expect(firstAttempt)
    #expect(!duplicateAttempt)
    #expect(!nonRetryAttempt)
    #expect(secondURLAttempt)
}

@Test func browserSessionFollowUpWaitsForDelayedSPAContentToSettle() throws {
    let vortexURL = try #require(URL(string: "https://vortexscans.org/series/sample/chapter-168"))
    let defaultURL = try #require(URL(string: "https://mangafire.to/read/sample/en/chapter-1"))

    #expect(BrowserDetectionRetryPolicy.followUpDelayNanoseconds(for: vortexURL) == 12_000_000_000)
    #expect(BrowserDetectionRetryPolicy.followUpDelayNanoseconds(for: defaultURL) == 900_000_000)
}

@Test func vortexLowConfidenceRouteGetsOneBoundedFollowUpWithoutAProfileRetry() throws {
    var policy = BrowserDetectionRetryPolicy()
    var highConfidencePolicy = BrowserDetectionRetryPolicy()
    let url = try #require(URL(string: "https://vortexscans.org/series/sample/chapter-168"))
    let firstAttempt = policy.shouldScheduleFollowUp(for: url, recommendation: .none, confidence: .low)
    let duplicateAttempt = policy.shouldScheduleFollowUp(for: url, recommendation: .none, confidence: .low)
    let highConfidenceAttempt = highConfidencePolicy.shouldScheduleFollowUp(
        for: url,
        recommendation: .none,
        confidence: .high
    )

    #expect(firstAttempt)
    #expect(!duplicateAttempt)
    #expect(!highConfidenceAttempt)
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

private actor SuspendedBrowserSaveGate {
    private var operationContinuation: CheckedContinuation<Void, Never>?
    private var waiterContinuation: CheckedContinuation<Void, Never>?

    func suspend() async {
        waiterContinuation?.resume()
        waiterContinuation = nil
        await withCheckedContinuation { continuation in
            operationContinuation = continuation
        }
    }

    func waitUntilSuspended() async {
        if operationContinuation != nil { return }
        await withCheckedContinuation { continuation in
            waiterContinuation = continuation
        }
    }

    func resume() {
        operationContinuation?.resume()
        operationContinuation = nil
    }
}
