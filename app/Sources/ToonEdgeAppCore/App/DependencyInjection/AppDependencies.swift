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
    public var chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    public var updateRefreshService: (any LibraryUpdateRefreshing)?
    public var settingsService: any SettingsProviding
    public var browserService: any BrowserCoordinating
    public var readerService: any ReaderSessionProviding
    public var adjacentReaderSessionLoader: (any AdjacentReaderSessionLoading)?
    public var readerProgressRepository: any ReaderProgressStoring
    public var chapterDetector: any ChapterPageDetecting
    public var seriesMetadataService: (any SeriesMetadataFetching)?

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
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)? = nil,
        updateRefreshService: (any LibraryUpdateRefreshing)? = nil,
        settingsService: any SettingsProviding,
        browserService: any BrowserCoordinating,
        readerService: any ReaderSessionProviding,
        adjacentReaderSessionLoader: (any AdjacentReaderSessionLoading)? = nil,
        readerProgressRepository: any ReaderProgressStoring,
        chapterDetector: any ChapterPageDetecting,
        seriesMetadataService: (any SeriesMetadataFetching)? = nil
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
        self.chapterIndexRefreshService = chapterIndexRefreshService
        self.updateRefreshService = updateRefreshService
        self.settingsService = settingsService
        self.browserService = browserService
        self.readerService = readerService
        self.adjacentReaderSessionLoader = adjacentReaderSessionLoader
        self.readerProgressRepository = readerProgressRepository
        self.chapterDetector = chapterDetector
        self.seriesMetadataService = seriesMetadataService
    }

    public static func mock() -> AppDependencies {
        let cacheMetadataService = MockCacheMetadataService()
        let assetCache = try? FileBackedChapterAssetCache(rootDirectory: defaultCacheDirectory())
        return AppDependencies(
            libraryService: MockLibraryService(),
            searchSuggestionProvider: MockSearchSuggestionProvider(),
            downloadService: cacheMetadataService,
            cacheMetadataService: cacheMetadataService,
            cacheStorageMeasurementService: assetCache.map(CacheStorageMeasurementService.init(assetCache:)),
            chapterIndexRefreshService: MockSeriesChapterIndexRefreshService(),
            updateRefreshService: MockLibraryUpdateRefreshService(),
            settingsService: MockSettingsService(),
            browserService: MockBrowserService(),
            readerService: MockReaderService(),
            readerProgressRepository: UserDefaultsReaderProgressRepository(),
            chapterDetector: ProfileAwareChapterDetector()
        )
    }

    @MainActor
    public static func persistent(
        inMemory: Bool = false,
        usesModelContextIO: Bool = true
    ) throws -> AppDependencies {
        let schema = Schema(ToonEdgePersistenceModels.all)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let repository = SwiftDataLibraryRepository(
            modelContext: container.mainContext,
            modelContainer: container,
            usesModelContextIO: usesModelContextIO
        )
        let assetCache = try? FileBackedChapterAssetCache(rootDirectory: defaultCacheDirectory())
        let diagnosticsLogger = UpdateCacheDiagnosticsLogger()
        let chapterIndexRefreshService = SeriesChapterIndexRefreshService(
            library: repository,
            indexLibrary: repository,
            fetcher: HTMLChapterIndexFetcher()
        )

        return AppDependencies(
            persistenceContainer: container,
            libraryService: repository,
            libraryLifecycleService: repository,
            searchSuggestionProvider: MockSearchSuggestionProvider(),
            searchHistoryRecorder: repository,
            recentReadingRecorder: repository,
            downloadService: repository,
            cacheMetadataService: repository,
            cacheStorageMeasurementService: assetCache.map(CacheStorageMeasurementService.init(assetCache:)),
            chapterIndexRefreshService: chapterIndexRefreshService,
            updateRefreshService: LibraryUpdateRefreshService(
                library: repository,
                updateChecker: SeriesUpdateChecker(
                    fetcher: HTMLLatestChapterFetcher(diagnosticsLogger: diagnosticsLogger)
                ),
                chapterIndexRefreshService: chapterIndexRefreshService,
                diagnosticsLogger: diagnosticsLogger
            ),
            settingsService: MockSettingsService(),
            browserService: MockBrowserService(),
            readerService: MockReaderService(),
            adjacentReaderSessionLoader: AdjacentReaderSessionLoader(
                detector: ProfileAwareChapterDetector(),
                pageLoader: HiddenWebViewAdjacentChapterPageLoader()
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
