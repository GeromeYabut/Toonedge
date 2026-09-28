import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func readerSettingsSwatchesMatchFixedReaderCanvases() {
    for canvas in [ReaderCanvas.charcoal, .black, .paper] {
        #expect(ReaderSettingsView.swatch(for: canvas) == ReaderCanvasPalette.values(for: canvas).background.color)
    }
}

@Test func readerCanvasColorsDoNotDependOnSystemAppearance() {
    for canvas in [ReaderCanvas.charcoal, .black, .paper] {
        let values = ReaderCanvasPalette.values(for: canvas)
        #expect(values.textContrast >= 4.5)
    }
    #expect(ReaderCanvasPalette.values(for: .charcoal).background == .init(red: 0.05, green: 0.055, blue: 0.075))
    #expect(ReaderCanvasPalette.values(for: .black).background == .black)
    #expect(ReaderCanvasPalette.values(for: .paper).background == .init(red: 0.89, green: 0.86, blue: 0.78))
}

@Test func chapterIdentityPrefersExplicitNumberOverNoisyLabel() {
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: 1, chapterLabel: "Top", title: "Chapter 7 - Manhua Top") == "1")
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: 7, chapterLabel: "Chapter", title: "Chapter 1") == "7")
}

@MainActor
@Test func readerChapterIdentityRejectsTrailingBrandToken() throws {
    let session = MockReaderSession(
        seriesTitle: "Sample",
        chapterTitle: "Sample Manhwa - Chapter 1 - Manhwa Manhua Top",
        sourceURL: try #require(URL(string: "https://manhuatop.org/manhua/sample/chapter-1/")),
        imageURLs: []
    )
    let viewModel = ReaderViewModel(session: session)

    #expect(viewModel.currentChapterDisplayLabel == "Chapter 1")
    #expect(viewModel.canonicalChapterLabel == "1")
}

@MainActor
@Test func readerViewModelStartsWithChromeHiddenAndComputesInitialProgress() {
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(session: session)

    #expect(!viewModel.isChromeVisible)
    #expect(viewModel.progress.currentImageIndex == 0)
    #expect(viewModel.progress.fractionComplete == 0)
    #expect(viewModel.progressDisplay == "0%")
}

@Test func readerGesturePolicyOnlyTogglesFromReadingSurface() {
    let policy = ReaderGesturePolicy()

    #expect(policy.togglesChrome(for: .readingSurfaceTap))
    #expect(!policy.togglesChrome(for: .scroll))
    #expect(!policy.togglesChrome(for: .toolbarAction))
}

@MainActor
@Test func readerDefaultsToSeamlessPageFlow() {
    let viewModel = ReaderViewModel(session: .sample)

    #expect(!viewModel.settings.isPageSpacingEnabled)
}

@Test func mockReaderProgressRepositoryPersistsProgressBySourceURL() async {
    let repository = MockReaderProgressRepository()
    let progress = ReaderProgress(currentImageIndex: 3, totalImageCount: 5)
    let sourceURL = MockReaderSession.sample.sourceURL

    await repository.save(progress, for: sourceURL)
    let restored = await repository.progress(for: sourceURL)

    #expect(restored == progress)
}

@Test func userDefaultsReaderProgressRepositoryPersistsProgressAcrossInstances() async throws {
    let suiteName = "ToonEdgeProgressTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let sourceURL = MockReaderSession.sample.sourceURL
    let progress = ReaderProgress(currentImageIndex: 4, totalImageCount: 5)

    let writer = UserDefaultsReaderProgressRepository(userDefaults: defaults)
    await writer.save(progress, for: sourceURL)

    let reader = UserDefaultsReaderProgressRepository(userDefaults: defaults)
    let restored = await reader.progress(for: sourceURL)

    #expect(restored == progress)
    defaults.removePersistentDomain(forName: suiteName)
}

@MainActor
@Test func readerViewModelRestoresSavedProgressWhenSessionOpens() async {
    let repository = MockReaderProgressRepository()
    let session = MockReaderSession.sample
    await repository.save(
        ReaderProgress(currentImageIndex: 2, totalImageCount: session.imageURLs.count),
        for: session.sourceURL
    )

    let viewModel = ReaderViewModel(session: session, progressRepository: repository)
    await viewModel.restoreProgress()

    #expect(viewModel.progress.currentImageIndex == 2)
    #expect(viewModel.progressDisplay == "50%")
}

@MainActor
@Test func readerViewModelDoesNotOverwriteSavedProgressBeforeRestoreCompletes() async {
    let repository = MockReaderProgressRepository()
    let session = MockReaderSession.sample
    await repository.save(
        ReaderProgress(currentImageIndex: 2, totalImageCount: session.imageURLs.count),
        for: session.sourceURL
    )

    let viewModel = ReaderViewModel(session: session, progressRepository: repository)
    await viewModel.updateProgress(visibleImageIndex: 0)
    await viewModel.restoreProgress()

    #expect(viewModel.progress.currentImageIndex == 2)
}

@MainActor
@Test func readerViewModelSavesProgressWhenVisibleImageChanges() async {
    let repository = MockReaderProgressRepository()
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(session: session, progressRepository: repository)

    await viewModel.restoreProgress()
    await viewModel.updateProgress(visibleImageIndex: 3)
    let saved = await repository.progress(for: session.sourceURL)

    #expect(saved?.currentImageIndex == 3)
    #expect(saved?.totalImageCount == session.imageURLs.count)
}

@MainActor
@Test func readerVisiblePlaceholderDoesNotAdvanceProgressUntilImageLoads() async {
    let repository = MockReaderProgressRepository()
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(session: session, progressRepository: repository)

    await viewModel.restoreProgress()
    await viewModel.markImageVisible(index: 2)

    #expect(viewModel.progress.currentImageIndex == 0)
    #expect(await repository.progress(for: session.sourceURL) == nil)

    await viewModel.markImageLoaded(index: 2)

    #expect(viewModel.progress.currentImageIndex == 2)
    #expect(await repository.progress(for: session.sourceURL)?.currentImageIndex == 2)
}

@MainActor
@Test func readerViewModelRecordsRecentCacheMetadataWhenProgressIsSaved() async throws {
    let progressRepository = MockReaderProgressRepository()
    let cacheMetadataService = MockCacheMetadataService()
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(
        session: session,
        progressRepository: progressRepository,
        cacheMetadataManager: cacheMetadataService
    )

    await viewModel.restoreProgress()
    await viewModel.updateProgress(visibleImageIndex: 1)
    let entries = await cacheMetadataService.cacheMetadataEntries()
    let entry = try #require(entries.first)

    #expect(entry.sourceURL == session.sourceURL)
    #expect(entry.seriesTitle == session.seriesTitle)
    #expect(entry.chapterTitle == session.chapterTitle)
    #expect(entry.imageCount == session.imageURLs.count)
    #expect(entry.retentionState == .recent)
}

@MainActor
@Test func readerViewModelRecordsRecentReadingWhenProgressIsSaved() async {
    let progressRepository = MockReaderProgressRepository()
    let recentReadingRecorder = RecordingRecentReadingRecorder()
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(
        session: session,
        progressRepository: progressRepository,
        recentReadingRecorder: recentReadingRecorder
    )

    await viewModel.restoreProgress()
    await viewModel.updateProgress(visibleImageIndex: 2)

    let entry = await recentReadingRecorder.lastInput
    #expect(entry?.seriesID == session.seriesID)
    #expect(entry?.seriesTitle == session.seriesTitle)
    #expect(entry?.sourceURL == session.sourceURL)
    #expect(entry?.progress.currentImageIndex == 2)
}

@MainActor
@Test func readerViewModelEnrichesRecentReadingWithSeriesCoverMetadata() async throws {
    let coverURL = try #require(URL(string: "https://cdn.example.com/cover.jpg"))
    let recorder = RecordingRecentReadingRecorder()
    let viewModel = ReaderViewModel(
        session: .sample,
        progressRepository: MockReaderProgressRepository(),
        recentReadingRecorder: recorder,
        seriesMetadataService: StubSeriesMetadataFetcher(
            metadata: SeriesMetadataSnapshot(title: "Moonlit Edge", coverImageURL: coverURL)
        )
    )

    await viewModel.restoreProgress()
    await viewModel.updateProgress(visibleImageIndex: 1)

    #expect(await recorder.lastInput?.coverImageURL == coverURL)
}

@MainActor
@Test func readerViewModelRefreshesExistingPreviewImageWithPreferredSeriesCoverMetadata() async throws {
    let previewURL = try #require(URL(string: "https://vortexscans.org/api/og-image/series/past-life-returner/banner.webp"))
    let coverURL = try #require(URL(string: "https://storage.vortexscans.org/upload/cover.webp"))
    var session = MockReaderSession.sample
    session.coverImageURL = previewURL
    let recorder = RecordingRecentReadingRecorder()
    let viewModel = ReaderViewModel(
        session: session,
        progressRepository: MockReaderProgressRepository(),
        recentReadingRecorder: recorder,
        seriesMetadataService: StubSeriesMetadataFetcher(
            metadata: SeriesMetadataSnapshot(title: session.seriesTitle, coverImageURL: coverURL)
        )
    )

    await viewModel.restoreProgress()
    await viewModel.updateProgress(visibleImageIndex: 1)

    #expect(await recorder.lastInput?.coverImageURL == coverURL)
}

@MainActor
@Test func readerProgressUpdatesThrottleCacheMetadataWritesButKeepFinalProgress() async {
    let progressRepository = MockReaderProgressRepository()
    let cacheMetadataService = CountingCacheMetadataService()
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(
        session: session,
        progressRepository: progressRepository,
        cacheMetadataManager: cacheMetadataService
    )

    await viewModel.restoreProgress()
    await viewModel.updateProgress(visibleImageIndex: 0)
    await viewModel.updateProgress(visibleImageIndex: 1)
    await viewModel.updateProgress(visibleImageIndex: 2)
    await viewModel.updateProgress(visibleImageIndex: 3)

    let saved = await progressRepository.progress(for: session.sourceURL)
    #expect(await cacheMetadataService.recordCacheMetadataCallCount == 1)
    #expect(saved?.currentImageIndex == 3)
}

@MainActor
@Test func readerRetainActionPublishesCacheFeedback() async {
    let cacheMetadataService = MockCacheMetadataService()
    let viewModel = ReaderViewModel(
        session: .sample,
        cacheMetadataManager: cacheMetadataService
    )

    await viewModel.retainCurrentChapter()

    #expect(viewModel.cacheFeedback?.result == .retained)
    #expect(viewModel.cacheFeedback?.isFailure == false)
}

@MainActor
@Test func readerRetainFailurePublishesNonBlockingFailureFeedback() async {
    let viewModel = ReaderViewModel(
        session: .sample,
        cacheMetadataManager: FailingCacheMetadataService()
    )

    await viewModel.retainCurrentChapter()

    #expect(viewModel.cacheFeedback?.isFailure == true)
}

@MainActor
@Test func readerViewModelReflectsSuccessfulSaveState() async {
    let library = RecordingLibraryLifecycleService()
    let viewModel = ReaderViewModel(session: .sample, libraryLifecycleService: library)

    await viewModel.refreshSavedState()
    #expect(!viewModel.isSavedToLibrary)

    await viewModel.saveCurrentSessionToLibrary()

    #expect(viewModel.isSavedToLibrary)
    #expect(viewModel.libraryFeedback?.message == "Saved to Library.")
}

@MainActor
@Test func readerViewModelSavesWithSelectedLibraryState() async {
    let library = RecordingLibraryLifecycleService()
    let viewModel = ReaderViewModel(session: .sample, libraryLifecycleService: library)

    await viewModel.saveCurrentSessionToLibrary(libraryState: .dropped)

    let recorded = await library.lastAddToLibraryInput
    #expect(recorded?.libraryState == .dropped)
}

@MainActor
@Test func readerViewModelTogglesChromeVisibility() {
    let viewModel = ReaderViewModel(session: .sample)

    viewModel.toggleChrome()
    #expect(viewModel.isChromeVisible)

    viewModel.toggleChrome()
    #expect(!viewModel.isChromeVisible)
}

@MainActor
@Test func readerViewModelExposesConciseCurrentChapterDisplayLabel() {
    var session = MockReaderSession.sample
    session.chapterTitle = "Moonlit Edge Chapter 169 - The Long Road Back"
    let viewModel = ReaderViewModel(session: session)

    #expect(viewModel.currentChapterDisplayLabel == "Chapter 169")
    #expect(viewModel.currentChapterAccessibilityLabel == "Moonlit Edge, Chapter 169")
}

@MainActor
@Test func readerViewModelUpdatesCurrentChapterDisplayLabelAfterSessionReplacement() async {
    let viewModel = ReaderViewModel(session: .sample)
    var replacement = MockReaderSession.sample
    replacement.chapterTitle = "Chapter 13"
    replacement.sourceURL = URL(string: "https://example.com/series/chapter-13")!

    await viewModel.replaceSession(replacement)

    #expect(viewModel.currentChapterDisplayLabel == "Chapter 13")
    #expect(viewModel.progress.currentImageIndex == 0)
}

@MainActor
@Test func adjacentNavigationUsesStoredPayloadBeforeHiddenLoad() async throws {
    let next = MockChapter(title: "Chapter 13", sourceURL: URL(string: "https://example.com/series/chapter-13")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .homeContinueReading
    current.nextChapter = next
    var stored = MockReaderSession.sample
    stored.chapterTitle = "Chapter 13"
    stored.sourceURL = next.sourceURL
    stored.imageURLs = [URL(string: "https://img.example.com/13-1.webp")!]

    let library = StoredAdjacentLibraryLifecycleService(storedSessions: [next.sourceURL: stored])
    let hiddenLoader = RecordingAdjacentReaderSessionLoader(result: .failure(URLError(.badURL)))
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(.next, libraryLifecycleService: library, adjacentLoader: hiddenLoader)

    #expect(viewModel.session.sourceURL == next.sourceURL)
    #expect(viewModel.session.launchOrigin == .homeContinueReading)
    #expect(viewModel.progress.currentImageIndex == 0)
    #expect(viewModel.adjacentLoadState == .idle)
    #expect(await hiddenLoader.requestedURLs.isEmpty)
}

@MainActor
@Test func readerViewModelUsesAdjacentLoaderForUnstoredAppOriginNextChapter() async throws {
    let next = MockChapter(title: "Chapter 2", sourceURL: URL(string: "https://example.com/series/chapter-2")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .homeContinueReading
    current.nextChapter = next
    var loaded = MockReaderSession.sample
    loaded.chapterTitle = "Chapter 2"
    loaded.sourceURL = next.sourceURL
    loaded.imageURLs = [URL(string: "https://cdn.example.com/chapter-2/page-1.webp")!]

    let loader = RecordingAdjacentReaderSessionLoader(result: .success(loaded))
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: loader
    )

    #expect(viewModel.session.sourceURL == next.sourceURL)
    #expect(viewModel.session.launchOrigin == .homeContinueReading)
    #expect(await loader.requestedURLs == [next.sourceURL])
}

@MainActor
@Test func adjacentNavigationHiddenLoadSuccessPreservesLaunchContext() async throws {
    let next = MockChapter(title: "Chapter 13", sourceURL: URL(string: "https://example.com/series/chapter-13")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .library(seriesID: current.seriesID)
    current.nextChapter = next
    var loaded = MockReaderSession.sample
    loaded.chapterTitle = "Chapter 13"
    loaded.sourceURL = next.sourceURL
    loaded.imageURLs = [URL(string: "https://img.example.com/13-1.webp")!]

    let hiddenLoader = RecordingAdjacentReaderSessionLoader(result: .success(loaded))
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(.next, libraryLifecycleService: nil, adjacentLoader: hiddenLoader)

    #expect(viewModel.session.sourceURL == next.sourceURL)
    #expect(viewModel.session.launchOrigin == current.launchOrigin)
    #expect(viewModel.session.seriesID == current.seriesID)
    #expect(viewModel.adjacentLoadState == .idle)
    #expect(await hiddenLoader.requestedURLs == [next.sourceURL])
}

@MainActor
@Test func unseenAdjacentNavigationPreservesHomeBackContext() async throws {
    let next = MockChapter(title: "Chapter 2", sourceURL: URL(string: "https://example.com/chapter-2")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .homeContinueReading
    current.nextChapter = next
    var loaded = MockReaderSession.sample
    loaded.sourceURL = next.sourceURL
    loaded.chapterTitle = "Chapter 2"
    loaded.imageURLs = [URL(string: "https://cdn.example.com/page.webp")!]

    let viewModel = ReaderViewModel(session: current)
    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: RecordingAdjacentReaderSessionLoader(result: .success(loaded))
    )

    #expect(viewModel.session.launchOrigin == .homeContinueReading)
}

@MainActor
@Test func adjacentNavigationFailureLeavesCurrentChapterIntact() async throws {
    let next = MockChapter(title: "Chapter 13", sourceURL: URL(string: "https://example.com/series/chapter-13")!)
    var current = MockReaderSession.sample
    current.nextChapter = next
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: RecordingAdjacentReaderSessionLoader(result: .failure(URLError(.cannotDecodeContentData)))
    )

    #expect(viewModel.session.sourceURL == current.sourceURL)
    #expect(viewModel.adjacentLoadState.isFailure)
    #expect(viewModel.adjacentFailureMessage == "This chapter is unavailable in Reader Mode. Try again or open the original page.")
}

@MainActor
@Test func adjacentChallengeFailurePreservesTargetAndRetriesOnlyAfterUserAction() async throws {
    let nextURL = URL(string: "https://example.com/series/chapter-13")!
    let next = MockChapter(title: "Chapter 13", sourceURL: nextURL)
    var current = MockReaderSession.sample
    current.nextChapter = next
    var loaded = MockReaderSession.sample
    loaded.chapterTitle = "Chapter 13"
    loaded.sourceURL = nextURL
    loaded.imageURLs = [URL(string: "https://img.example.com/13-1.webp")!]
    let loader = SequencedAdjacentReaderSessionLoader(
        results: [
            .failure(
                AdjacentReaderSessionLoadError(
                    reason: .challengeOrRateLimit,
                    targetURL: nextURL,
                    confidence: .low,
                    parserPath: .browserSessionProfile,
                    challengeSignals: ["http-status:429"]
                )
            ),
            .success(loaded)
        ]
    )
    let viewModel = ReaderViewModel(session: current, adjacentRetryDelayNanoseconds: 0)

    await viewModel.navigateAdjacentChapter(.next, libraryLifecycleService: nil, adjacentLoader: loader)

    #expect(await loader.requestCount == 1)
    #expect(viewModel.adjacentFailure?.reason == .challengeOrRateLimit)
    #expect(viewModel.adjacentFailure?.targetURL == nextURL)
    #expect(viewModel.adjacentFailureMessage == "This site may be rate limiting Reader Mode. Try again in a moment or open the original page.")

    await viewModel.retryAdjacentChapter(libraryLifecycleService: nil, adjacentLoader: loader)

    #expect(await loader.requestCount == 2)
    #expect(viewModel.session.sourceURL == nextURL)
    #expect(viewModel.adjacentLoadState == .idle)
}

@MainActor
@Test func cancellingAdjacentNavigationPreventsLateSessionReplacement() async throws {
    let nextURL = try #require(URL(string: "https://example.com/series/chapter-13"))
    var current = MockReaderSession.sample
    current.nextChapter = MockChapter(title: "Chapter 13", sourceURL: nextURL)
    var loaded = MockReaderSession.sample
    loaded.chapterTitle = "Chapter 13"
    loaded.sourceURL = nextURL
    loaded.imageURLs = [try #require(URL(string: "https://img.example.com/13-1.webp"))]
    let loader = CancellationIgnoringAdjacentReaderSessionLoader(session: loaded)
    let viewModel = ReaderViewModel(session: current)

    let navigation = Task {
        await viewModel.navigateAdjacentChapter(.next, libraryLifecycleService: nil, adjacentLoader: loader)
    }
    await loader.waitUntilRequested()
    viewModel.cancelAdjacentNavigation()
    navigation.cancel()
    await loader.release()
    _ = await navigation.value

    #expect(viewModel.session.sourceURL == current.sourceURL)
    #expect(viewModel.adjacentLoadState == .idle)
}

@MainActor
@Test func adjacentNavigationRejectsBlankHiddenLoadedReaderSession() async throws {
    let next = MockChapter(title: "Chapter 13", sourceURL: URL(string: "https://example.com/series/chapter-13")!)
    var current = MockReaderSession.sample
    current.nextChapter = next
    var unsafe = MockReaderSession.sample
    unsafe.sourceURL = next.sourceURL
    unsafe.imageURLs = []
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: RecordingAdjacentReaderSessionLoader(result: .success(unsafe))
    )

    #expect(viewModel.session.sourceURL == current.sourceURL)
    #expect(viewModel.adjacentLoadState.isFailure)
}

@MainActor
@Test func adjacentNavigationDoesNotPromoteMockStockImageFallbackForAppOriginSession() async throws {
    let next = MockChapter(title: "Next Chapter", sourceURL: URL(string: "https://asuracomic.net/series/title/chapter/2")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .homeContinueReading
    current.nextChapter = next
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: nil
    )

    #expect(viewModel.session.sourceURL == current.sourceURL)
    #expect(viewModel.session.imageURLs == current.imageURLs)
    #expect(viewModel.adjacentLoadState.isFailure)
}

@MainActor
@Test func readerProgressClampsToAvailableImageRange() async {
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(session: session)

    await viewModel.updateProgress(visibleImageIndex: 99)

    #expect(viewModel.progress.currentImageIndex == session.imageURLs.count - 1)
    #expect(viewModel.progress.fractionComplete == 1)
    #expect(viewModel.progressDisplay == "100%")
}

@MainActor
@Test func readerSettingsMutationsUpdateSessionPreferences() {
    let viewModel = ReaderViewModel(session: .sample)

    viewModel.setDisplayMode(.fitScreen)
    viewModel.setPageSpacingEnabled(false)
    viewModel.setBrightnessAid(0.35)
    viewModel.setCanvas(.black)

    #expect(viewModel.settings.displayMode == .fitScreen)
    #expect(!viewModel.settings.isPageSpacingEnabled)
    #expect(viewModel.settings.brightnessAid == 0.35)
    #expect(viewModel.settings.readerCanvas == .black)
}

@Test func readerPlaceholderHeightUsesDetectedAspectRatioWhenAvailable() {
    let metadata = ReaderPageMetadata(pixelWidth: 800, pixelHeight: 14_000)

    let height = ReaderPageLayout.placeholderHeight(
        availableWidth: 390,
        displayMode: .fitWidth,
        metadata: metadata
    )

    #expect(height == 6_825)
}

@Test func readerPlaceholderHeightFallsBackWhenMetadataIsUnavailable() {
    let height = ReaderPageLayout.placeholderHeight(
        availableWidth: 390,
        displayMode: .fitWidth,
        metadata: nil
    )

    #expect(height == 430)
}

@Test func mockReaderServiceLoadsLinkedPreviousAndNextChapters() async throws {
    let service = MockReaderService()
    let session = MockReaderSession.sample

    let previous = try #require(session.previousChapter)
    let next = try #require(session.nextChapter)

    let previousSession = try await service.mockSession(for: previous)
    let nextSession = try await service.mockSession(for: next)

    #expect(previousSession.chapterTitle == previous.title)
    #expect(previousSession.sourceURL == previous.sourceURL)
    #expect(nextSession.chapterTitle == next.title)
    #expect(nextSession.sourceURL == next.sourceURL)
}

@Test func viewOriginalPageKeepsExistingBrowserWhenReaderIsAboveBrowser() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-12")

    router.presentBrowser(startPoint)
    router.presentReader(.sample)
    router.viewOriginalPage()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == startPoint)
}

@Test func adjacentFailureOpenOriginalUsesKnownAdjacentTarget() {
    var router = AppRouter()
    let targetURL = URL(string: "https://example.com/series/chapter-13")!
    router.presentReader(.sample)

    router.openOriginalPage(targetURL)

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == .url(targetURL.absoluteString))
}

@Test func readerChromeLayoutMovesSecondaryActionsToFloatingRail() {
    let savedLayout = ReaderChromeLayout.actions(
        launchOrigin: .browser,
        isLibraryAvailable: true,
        isSavedToLibrary: true,
        canNavigatePrevious: true,
        canNavigateNext: false
    )
    let unsavedLayout = ReaderChromeLayout.actions(
        launchOrigin: .homeContinueReading,
        isLibraryAvailable: true,
        isSavedToLibrary: false,
        canNavigatePrevious: false,
        canNavigateNext: true
    )
    let noLibraryLayout = ReaderChromeLayout.actions(
        launchOrigin: .library(seriesID: UUID()),
        isLibraryAvailable: false,
        isSavedToLibrary: false,
        canNavigatePrevious: false,
        canNavigateNext: false
    )

    #expect(savedLayout.top == [.back, .library])
    #expect(savedLayout.floating == [.download, .saved, .viewOriginalPage, .settings])
    #expect(savedLayout.bottom == [.previousChapter, .nextChapter])
    #expect(savedLayout.isEnabled(.previousChapter))
    #expect(!savedLayout.isEnabled(.nextChapter))

    #expect(unsavedLayout.floating == [.download, .save, .viewOriginalPage, .settings])
    #expect(!unsavedLayout.isEnabled(.previousChapter))
    #expect(unsavedLayout.isEnabled(.nextChapter))
    #expect(noLibraryLayout.floating == [.download, .viewOriginalPage, .settings])
    #expect(!noLibraryLayout.isEnabled(.previousChapter))
    #expect(!noLibraryLayout.isEnabled(.nextChapter))

    #expect(savedLayout.launchOrigin == .browser)
    #expect(unsavedLayout.launchOrigin == .homeContinueReading)
    if case .library = noLibraryLayout.launchOrigin {
        // Expected origin is retained for origin-aware Back routing.
    } else {
        Issue.record("Expected Library launch origin")
    }

    for layout in [savedLayout, unsavedLayout, noLibraryLayout] {
        #expect(layout.top == [.back, .library])
        #expect(layout.floating.contains(.viewOriginalPage))
        #expect(layout.floating.contains(.settings))
        #expect(layout.showsChapterContext)
        #expect(layout.showsProgress)
        #expect(layout.minimumActionSize == 44)
        #expect(Set(layout.actions.map(layout.identifier(for:))).count == layout.actions.count)
    }
}

@Test func adjacentRecoveryActionsKeepAccessibleHitRegions() {
    let layout = ReaderAdjacentRecoveryActionLayout()

    #expect(layout.minimumHitSize(for: .retry) >= 44)
    #expect(layout.minimumHitSize(for: .openOriginal) >= 44)
}

private struct FailingCacheMetadataService: CacheMetadataManaging {
    func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        throw URLError(.cannotWriteToFile)
    }

    func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        throw URLError(.cannotRemoveFile)
    }

    func updateCacheRetention(
        for sourceURL: URL,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) async throws -> CacheActionResult {
        throw URLError(.cannotWriteToFile)
    }

    func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        []
    }

    func downloadSummary() async -> DownloadSummary {
        DownloadSummary(cachedItemCount: 0, storageDescription: "No cached chapters yet")
    }
}

private actor CountingCacheMetadataService: CacheMetadataManaging {
    private(set) var recordCacheMetadataCallCount = 0

    func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        recordCacheMetadataCallCount += 1
        return input.retentionState == .retained ? .retained : .recent
    }

    func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        .removed
    }

    func updateCacheRetention(
        for sourceURL: URL,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) async throws -> CacheActionResult {
        retentionState == .retained ? .retained : .recent
    }

    func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        []
    }

    func downloadSummary() async -> DownloadSummary {
        DownloadSummary(cachedItemCount: 0, storageDescription: "No cached chapters yet")
    }
}

private actor RecordingRecentReadingRecorder: RecentReadingRecording {
    private(set) var lastInput: RecentReadingInput?

    func recordRecentReading(_ input: RecentReadingInput) async throws {
        lastInput = input
    }
}

private actor RecordingLibraryLifecycleService: LibraryLifecycleManaging {
    private var savedCanonicalURLs: Set<URL> = []
    private(set) var lastAddToLibraryInput: LibrarySeriesInput?

    func homeSnapshot() async -> HomeSnapshot { .init(continueReading: [], recentlyUpdated: [], library: []) }
    func librarySnapshot() async -> LibrarySnapshot { .init(series: []) }
    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? { nil }
    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {
        lastAddToLibraryInput = input
        savedCanonicalURLs.insert(input.canonicalURL)
    }
    func removeFromLibrary(seriesID: UUID) async throws {}
    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {}
    func recordUpdateCheckResult(seriesID: UUID, latestChapterLabel: String?, hasUnreadUpdates: Bool, checkedAt: Date) async throws {}
    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {}
    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? { nil }
    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? { nil }
    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? { nil }
    func isSaved(canonicalURL: URL) async -> Bool { savedCanonicalURLs.contains(canonicalURL) }
}

private actor StoredAdjacentLibraryLifecycleService: LibraryLifecycleManaging {
    private let storedSessions: [URL: MockReaderSession]

    init(storedSessions: [URL: MockReaderSession]) {
        self.storedSessions = storedSessions
    }

    func homeSnapshot() async -> HomeSnapshot { .init(continueReading: [], recentlyUpdated: [], library: []) }
    func librarySnapshot() async -> LibrarySnapshot { .init(series: []) }
    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? { nil }
    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {}
    func removeFromLibrary(seriesID: UUID) async throws {}
    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {}
    func recordUpdateCheckResult(seriesID: UUID, latestChapterLabel: String?, hasUnreadUpdates: Bool, checkedAt: Date) async throws {}
    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {}
    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? { nil }
    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? { nil }
    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? { storedSessions[sourceURL] }
    func isSaved(canonicalURL: URL) async -> Bool { false }
}

private actor RecordingReaderSessionProvider: ReaderSessionProviding {
    private let result: Result<MockReaderSession, Error>
    private(set) var requestedChapters: [MockChapter] = []

    init(result: Result<MockReaderSession, Error>) {
        self.result = result
    }

    func mockSession(for chapter: MockChapter) async throws -> MockReaderSession {
        requestedChapters.append(chapter)
        return try result.get()
    }

    nonisolated var supportsUnstoredAdjacentLoading: Bool {
        true
    }
}

private actor RecordingAdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let result: Result<MockReaderSession, Error>
    private(set) var requestedURLs: [URL] = []

    init(result: Result<MockReaderSession, Error>) {
        self.result = result
    }

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        requestedURLs.append(url)
        return try result.get()
    }
}

private actor SequencedAdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private var results: [Result<MockReaderSession, Error>]
    private(set) var requestCount = 0

    init(results: [Result<MockReaderSession, Error>]) {
        self.results = results
    }

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        requestCount += 1
        guard !results.isEmpty else {
            throw AdjacentReaderSessionLoadError(reason: .unavailable, targetURL: url)
        }
        return try results.removeFirst().get()
    }
}

private actor CancellationIgnoringAdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let session: MockReaderSession
    private var requested = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(session: MockReaderSession) {
        self.session = session
    }

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        requested = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return session
    }

    func waitUntilRequested() async {
        while !requested {
            await Task.yield()
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private extension AdjacentChapterLoadState {
    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

private struct StubSeriesMetadataFetcher: SeriesMetadataFetching {
    let metadata: SeriesMetadataSnapshot?

    func metadata(for seriesURL: URL) async throws -> SeriesMetadataSnapshot? {
        metadata
    }
}

@MainActor
@Test func readerPageImageLoaderRetriesTransientFailureBeforeLoading() async throws {
    let imageURL = try #require(URL(string: "https://img.example.com/page-1.webp"))
    let client = SequencedHTTPDataLoader(
        responses: [
            .failure(URLError(.timedOut)),
            .success(HTTPDataResponse(data: Data([1, 2, 3]), statusCode: 200))
        ]
    )
    let loader = ReaderPageImageLoader(imageURL: imageURL, httpClient: client, retryDelayNanoseconds: 0)

    await loader.load()

    #expect(loader.state == .loaded(Data([1, 2, 3])))
    #expect(await client.requestCount == 2)
}

@MainActor
@Test func readerPageImageLoaderPreservesEphemeralRequestHeadersOnRetry() async throws {
    let imageURL = try #require(URL(string: "https://images.example.test/chapter/001.jpg"))
    let referer = try #require(URL(string: "https://comizy.io/sample/chapter-1"))
    let client = RecordingRequestHTTPDataLoader()
    let loader = ReaderPageImageLoader(
        imageURL: imageURL,
        requestContext: ReaderImageRequestContext(referer: referer, cookieHeader: "session=fixture", userAgent: "Fixture Mobile Safari"),
        httpClient: client,
        maxAttempts: 1,
        retryDelayNanoseconds: 0
    )

    await loader.load()
    await loader.retry()

    let requests = await client.requests
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Referer") == referer.absoluteString })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Cookie") == "session=fixture" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "User-Agent") == "Fixture Mobile Safari" })
}

@MainActor
@Test func readerPageImageLoaderUsesRetainedAssetWithoutNetwork() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = try #require(URL(string: "https://fixture.example/chapter-1"))
    let imageURL = try #require(URL(string: "https://images.example.test/chapter-1/001.png"))
    let expected = Data([9, 8, 7])
    try cache.store(expected, for: imageURL, sourceURL: sourceURL)
    let client = AlwaysFailingHTTPDataLoader()
    let loader = ReaderPageImageLoader(
        imageURL: imageURL,
        sourceURL: sourceURL,
        assetCache: cache,
        httpClient: client,
        retryDelayNanoseconds: 0
    )

    await loader.load()

    #expect(loader.state == .loaded(expected))
    #expect(await client.requestCount == 0)
}

@Test func chapterAssetRetentionDownloadsEveryPageInOrder() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=="))
    let client = FixedHTTPDataLoader(response: HTTPDataResponse(data: png, statusCode: 200))
    let service = ChapterAssetRetentionService(assetCache: cache, httpClient: client)
    let sourceURL = try #require(URL(string: "https://fixture.example/chapter-1"))
    let imageURLs = try (1...3).map { index in
        try #require(URL(string: "https://images.example.test/chapter-1/00\(index).png"))
    }
    let session = MockReaderSession(
        seriesTitle: "Fixture",
        chapterTitle: "Chapter 1",
        sourceURL: sourceURL,
        imageURLs: imageURLs
    )

    let retainedBytes = try await service.retainAssets(for: session)

    #expect(retainedBytes == Int64(png.count * imageURLs.count))
    #expect(imageURLs.allSatisfy { cache.cachedAssetURL(for: $0, sourceURL: sourceURL) != nil })
}

private actor RecordingRequestHTTPDataLoader: HTTPDataLoading {
    private(set) var requests: [URLRequest] = []

    func data(from url: URL) async throws -> HTTPDataResponse {
        throw URLError(.badURL)
    }

    func data(for request: URLRequest) async throws -> HTTPDataResponse {
        requests.append(request)
        return HTTPDataResponse(data: Data([1, 2, 3]), statusCode: 200)
    }
}

@Test func readerPreflightRejectsSuccessfulHTMLInsteadOfImage() async throws {
    let client = FixedHTTPDataLoader(response: HTTPDataResponse(data: Data("<html>challenge</html>".utf8), statusCode: 200))
    let session = MockReaderSession(
        seriesTitle: "Fixture",
        chapterTitle: "Chapter 1",
        sourceURL: try #require(URL(string: "https://comizy.io/sample/chapter-1")),
        imageURLs: [try #require(URL(string: "https://images.example.test/001.jpg"))]
    )

    let result = await ReaderSessionImagePreflight(httpClient: client).isViable(session)

    #expect(!result)
}

@Test func readerPreflightAcceptsDecodableImage() async throws {
    let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg=="))
    let client = FixedHTTPDataLoader(response: HTTPDataResponse(data: png, statusCode: 200))
    let session = MockReaderSession(
        seriesTitle: "Fixture",
        chapterTitle: "Chapter 1",
        sourceURL: try #require(URL(string: "https://comizy.io/sample/chapter-1")),
        imageURLs: [try #require(URL(string: "https://images.example.test/001.png"))]
    )

    #expect(await ReaderSessionImagePreflight(httpClient: client).isViable(session))
}

private struct FixedHTTPDataLoader: HTTPDataLoading {
    let response: HTTPDataResponse

    func data(from url: URL) async throws -> HTTPDataResponse { response }
}

private actor SequencedHTTPDataLoader: HTTPDataLoading {
    private var responses: [Result<HTTPDataResponse, Error>]
    private(set) var requestCount = 0

    init(responses: [Result<HTTPDataResponse, Error>]) {
        self.responses = responses
    }

    func data(from url: URL) async throws -> HTTPDataResponse {
        requestCount += 1
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }

        return try responses.removeFirst().get()
    }
}

private actor AlwaysFailingHTTPDataLoader: HTTPDataLoading {
    private(set) var requestCount = 0

    func data(from url: URL) async throws -> HTTPDataResponse {
        requestCount += 1
        throw URLError(.notConnectedToInternet)
    }
}
