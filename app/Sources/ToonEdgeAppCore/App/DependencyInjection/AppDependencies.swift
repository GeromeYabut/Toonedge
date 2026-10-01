import Foundation
import SwiftData

public struct AppDependencies: Sendable {
    public var persistenceContainer: ModelContainer?
    public var libraryService: any LibraryProviding
    public var libraryLifecycleService: (any LibraryLifecycleManaging)?
    public var searchSuggestionProvider: any SearchSuggestionProviding
    public var searchHistoryRecorder: (any SearchHistoryRecording)?
    public var recentReadingRecorder: (any RecentReadingRecording)?
    public var downloadService: any DownloadProviding
    public var cacheMetadataService: any CacheMetadataManaging
    public var cacheStorageMeasurementService: (any CacheStorageMeasuring)?
    public var chapterAssetCache: (any ChapterAssetCaching)?
    public var chapterAssetRetainer: (any ChapterAssetRetaining)?
    public var chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    public var updateRefreshService: (any LibraryUpdateRefreshing)?
    public var settingsService: any SettingsManaging
    public var interactionPreferences: any InteractionPreferencesManaging
    public var interactionFeedback: any InteractionFeedbackProviding
    public var browserService: any BrowserCoordinating
    public var readerService: any ReaderSessionProviding
    public var adjacentReaderSessionLoader: (any AdjacentReaderSessionLoading)?
    public var readerProgressRepository: any ReaderProgressStoring
    public var chapterDetector: any ChapterPageDetecting
    public var seriesMetadataService: (any SeriesMetadataFetching)?
    public var browserPresentationFixture: BrowserPresentationFixture?

    @MainActor
    public init(
        persistenceContainer: ModelContainer? = nil,
        libraryService: any LibraryProviding,
        libraryLifecycleService: (any LibraryLifecycleManaging)? = nil,
        searchSuggestionProvider: any SearchSuggestionProviding,
        searchHistoryRecorder: (any SearchHistoryRecording)? = nil,
        recentReadingRecorder: (any RecentReadingRecording)? = nil,
        downloadService: any DownloadProviding,
        cacheMetadataService: any CacheMetadataManaging,
        cacheStorageMeasurementService: (any CacheStorageMeasuring)? = nil,
        chapterAssetCache: (any ChapterAssetCaching)? = nil,
        chapterAssetRetainer: (any ChapterAssetRetaining)? = nil,
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)? = nil,
        updateRefreshService: (any LibraryUpdateRefreshing)? = nil,
        settingsService: any SettingsManaging,
        interactionPreferences: any InteractionPreferencesManaging,
        interactionFeedback: any InteractionFeedbackProviding,
        browserService: any BrowserCoordinating,
        readerService: any ReaderSessionProviding,
        adjacentReaderSessionLoader: (any AdjacentReaderSessionLoading)? = nil,
        readerProgressRepository: any ReaderProgressStoring,
        chapterDetector: any ChapterPageDetecting,
        seriesMetadataService: (any SeriesMetadataFetching)? = nil,
        browserPresentationFixture: BrowserPresentationFixture? = nil
    ) {
        self.persistenceContainer = persistenceContainer
        self.libraryService = libraryService
        self.libraryLifecycleService = libraryLifecycleService
        self.searchSuggestionProvider = searchSuggestionProvider
        self.searchHistoryRecorder = searchHistoryRecorder
        self.recentReadingRecorder = recentReadingRecorder
        self.downloadService = downloadService
        self.cacheMetadataService = cacheMetadataService
        self.cacheStorageMeasurementService = cacheStorageMeasurementService
        self.chapterAssetCache = chapterAssetCache
        self.chapterAssetRetainer = chapterAssetRetainer
        self.chapterIndexRefreshService = chapterIndexRefreshService
        self.updateRefreshService = updateRefreshService
        self.settingsService = settingsService
        self.interactionPreferences = interactionPreferences
        self.interactionFeedback = interactionFeedback
        self.browserService = browserService
        self.readerService = readerService
        self.adjacentReaderSessionLoader = adjacentReaderSessionLoader
        self.readerProgressRepository = readerProgressRepository
        self.chapterDetector = chapterDetector
        self.seriesMetadataService = seriesMetadataService
        self.browserPresentationFixture = browserPresentationFixture
    }

    @MainActor
    public static func mock(
        interactionPreferences: (any InteractionPreferencesManaging)? = nil,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil
    ) -> AppDependencies {
        let cacheMetadataService = MockCacheMetadataService()
        let assetCache = try? FileBackedChapterAssetCache(rootDirectory: defaultCacheDirectory())
        let cacheService: any CacheMetadataManaging = assetCache.map { cache -> any CacheMetadataManaging in
            CacheLifecycleService(metadata: cacheMetadataService, assets: cache)
        } ?? cacheMetadataService
        let resolvedInteractionPreferences = interactionPreferences ?? InMemoryInteractionPreferences()
        let resolvedInteractionFeedback = interactionFeedback
            ?? RecordingInteractionFeedback(preferences: resolvedInteractionPreferences)
        return AppDependencies(
            libraryService: MockLibraryService(),
            searchSuggestionProvider: MockSearchSuggestionProvider(),
            downloadService: cacheService,
            cacheMetadataService: cacheService,
            cacheStorageMeasurementService: assetCache.map(CacheStorageMeasurementService.init(assetCache:)),
            chapterAssetCache: assetCache,
            chapterAssetRetainer: assetCache.map { ChapterAssetRetentionService(assetCache: $0) },
            chapterIndexRefreshService: MockSeriesChapterIndexRefreshService(),
            updateRefreshService: MockLibraryUpdateRefreshService(),
            settingsService: MockSettingsService(),
            interactionPreferences: resolvedInteractionPreferences,
            interactionFeedback: resolvedInteractionFeedback,
            browserService: MockBrowserService(),
            readerService: MockReaderService(),
            readerProgressRepository: UserDefaultsReaderProgressRepository(),
            chapterDetector: ProfileAwareChapterDetector()
        )
    }

    @MainActor
    public static func persistent(
        inMemory: Bool = false,
        usesModelContextIO: Bool = true,
        modelStoreURL: URL? = nil,
        cacheRootDirectory: URL? = nil
    ) throws -> AppDependencies {
        let schema = Schema(ToonEdgePersistenceModels.all)
        let configuration: ModelConfiguration
        if let modelStoreURL {
            configuration = ModelConfiguration(schema: schema, url: modelStoreURL)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        let container = try ModelContainer(for: schema, configurations: configuration)
        let repository = SwiftDataLibraryRepository(
            modelContext: container.mainContext,
            modelContainer: container,
            usesModelContextIO: usesModelContextIO
        )
        let assetCache = try? FileBackedChapterAssetCache(
            rootDirectory: cacheRootDirectory ?? defaultCacheDirectory()
        )
        let cacheService: any CacheMetadataManaging = assetCache.map { cache -> any CacheMetadataManaging in
            CacheLifecycleService(metadata: repository, assets: cache)
        } ?? repository
        let diagnosticsLogger = UpdateCacheDiagnosticsLogger()
        let chapterIndexRefreshService = SeriesChapterIndexRefreshService(
            library: repository,
            indexLibrary: repository,
            fetcher: HTMLChapterIndexFetcher()
        )
        let interactionPreferences = UserDefaultsInteractionPreferences()
        #if canImport(UIKit)
        let interactionFeedback: any InteractionFeedbackProviding = SystemInteractionFeedback(
            preferences: interactionPreferences
        )
        #else
        let interactionFeedback: any InteractionFeedbackProviding = SilentInteractionFeedback()
        #endif

        return AppDependencies(
            persistenceContainer: container,
            libraryService: repository,
            libraryLifecycleService: repository,
            searchSuggestionProvider: MockSearchSuggestionProvider(),
            searchHistoryRecorder: repository,
            recentReadingRecorder: repository,
            downloadService: cacheService,
            cacheMetadataService: cacheService,
            cacheStorageMeasurementService: assetCache.map(CacheStorageMeasurementService.init(assetCache:)),
            chapterAssetCache: assetCache,
            chapterAssetRetainer: assetCache.map { ChapterAssetRetentionService(assetCache: $0) },
            chapterIndexRefreshService: chapterIndexRefreshService,
            updateRefreshService: LibraryUpdateRefreshService(
                library: repository,
                updateChecker: SeriesUpdateChecker(
                    fetcher: HTMLLatestChapterFetcher(diagnosticsLogger: diagnosticsLogger)
                ),
                chapterIndexRefreshService: chapterIndexRefreshService,
                diagnosticsLogger: diagnosticsLogger
            ),
            settingsService: UserDefaultsSettingsRepository(),
            interactionPreferences: interactionPreferences,
            interactionFeedback: interactionFeedback,
            browserService: MockBrowserService(),
            readerService: MockReaderService(),
            adjacentReaderSessionLoader: AdjacentReaderSessionLoader(
                detector: ProfileAwareChapterDetector(),
                pageLoader: HiddenWebViewAdjacentChapterPageLoader(),
                htmlLoader: URLSessionAdjacentChapterHTMLLoader()
            ),
            readerProgressRepository: repository,
            chapterDetector: ProfileAwareChapterDetector(),
            seriesMetadataService: HTMLSeriesMetadataFetcher()
        )
    }

    private static func defaultCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ToonEdgeChapterCache", isDirectory: true)
    }
}
