import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func readerViewModelStartsWithChromeHiddenAndComputesInitialProgress() {
    let session = MockReaderSession.sample
    let viewModel = ReaderViewModel(session: session)

    #expect(!viewModel.isChromeVisible)
    #expect(viewModel.progress.currentImageIndex == 0)
    #expect(viewModel.progress.fractionComplete == 0)
    #expect(viewModel.progressDisplay == "0%")
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
    #expect(viewModel.adjacentFailureMessage == "Could not open next chapter in Reader.")
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

    func homeSnapshot() async -> HomeSnapshot { .init(continueReading: [], recentlyUpdated: [], library: []) }
    func librarySnapshot() async -> LibrarySnapshot { .init(series: []) }
    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? { nil }
    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {
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
