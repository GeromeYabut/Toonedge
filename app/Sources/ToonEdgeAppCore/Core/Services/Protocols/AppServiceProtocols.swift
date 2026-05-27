import Foundation

public struct HTTPDataResponse: Equatable, Sendable {
    public var data: Data
    public var statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPDataLoading: Sendable {
    func data(from url: URL) async throws -> HTTPDataResponse
}

public protocol LibraryProviding: Sendable {
    func homeSnapshot() async -> HomeSnapshot
    func librarySnapshot() async -> LibrarySnapshot
    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot?
}

public protocol LibraryLifecycleManaging: LibraryProviding {
    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws
    func removeFromLibrary(seriesID: UUID) async throws
    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws
    func recordUpdateCheckResult(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date
    ) async throws
    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws
    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget?
    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession?
    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession?
    func isSaved(canonicalURL: URL) async -> Bool
}

public protocol SearchHistoryRecording: Sendable {
    func recordSearchHistory(_ input: SearchHistoryInput) async throws
    func recentSearchHistory(limit: Int) async -> [SearchHistoryEntry]
}

public protocol RecentReadingRecording: Sendable {
    func recordRecentReading(_ input: RecentReadingInput) async throws
}

public protocol SearchSuggestionProviding: Sendable {
    func suggestions(matching query: String) -> [SearchSuggestion]
}

public protocol DownloadProviding: Sendable {
    func downloadSummary() async -> DownloadSummary
}

public protocol CacheMetadataManaging: DownloadProviding {
    func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult
    func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult
    func updateCacheRetention(for sourceURL: URL, retentionState: CacheRetentionState, cachedAt: Date) async throws -> CacheActionResult
    func cacheMetadataEntries() async -> [CacheMetadataEntry]
}

public protocol ChapterAssetCaching: Sendable {
    func chapterDirectory(for sourceURL: URL) -> URL
    func cachedAssetURL(for assetURL: URL, sourceURL: URL) -> URL?
}

public protocol CacheStorageMeasuring: Sendable {
    func summary(for entries: [CacheMetadataEntry]) -> DownloadSummary
}

public enum UpdateCacheDiagnosticEvent: Equatable, Sendable {
    case updateRefreshCompleted(checkedCount: Int, updatedCount: Int, failedCount: Int)
    case latestChapterParseCompleted(host: String, parser: String, found: Bool)
    case cacheRemoveFailed(sourceIdentity: String, operation: String)
}

public protocol UpdateCacheDiagnosticsLogging: Sendable {
    func log(_ event: UpdateCacheDiagnosticEvent) async
}

public protocol SeriesLatestChapterFetching: Sendable {
    func latestChapterSnapshot(for series: LibrarySeriesSummary) async throws -> SeriesLatestChapterSnapshot?
}

public protocol SeriesUpdateChecking: Sendable {
    func checkForUpdates(series: LibrarySeriesSummary) async throws -> SeriesUpdateCheckResult
}

public protocol LibraryUpdateRefreshing: Sendable {
    func refreshUpdates() async -> LibraryUpdateRefreshResult
}

public struct SeriesUpdateChecker: SeriesUpdateChecking {
    private let fetcher: any SeriesLatestChapterFetching

    public init(fetcher: any SeriesLatestChapterFetching) {
        self.fetcher = fetcher
    }

    public func checkForUpdates(series: LibrarySeriesSummary) async throws -> SeriesUpdateCheckResult {
        let snapshot = try await fetcher.latestChapterSnapshot(for: series)
        let comparison = ChapterUpdateComparison.compare(
            storedLatest: series.latestChapterLabel,
            fetchedLatest: snapshot?.latestChapterLabel
        )

        return SeriesUpdateCheckResult(
            seriesID: series.id,
            latestChapterLabel: snapshot?.latestChapterLabel ?? series.latestChapterLabel,
            hasUnreadUpdates: comparison != .same,
            checkedAt: snapshot?.checkedAt ?? Date(),
            comparison: comparison
        )
    }
}

public protocol SettingsProviding: Sendable {
    func currentSettings() -> ReaderSettings
}

public protocol BrowserCoordinating: Sendable {
    func prepare(_ startPoint: BrowserStartPoint) async
}

public protocol ReaderSessionProviding: Sendable {
    var supportsUnstoredAdjacentLoading: Bool { get }
    func mockSession(for chapter: MockChapter) async throws -> MockReaderSession
}

public extension ReaderSessionProviding {
    var supportsUnstoredAdjacentLoading: Bool { false }
}

public struct AdjacentReaderSessionLoadContext: Equatable, Sendable {
    public var currentSession: MockReaderSession
    public var direction: ReaderChapterDirection

    public init(currentSession: MockReaderSession, direction: ReaderChapterDirection) {
        self.currentSession = currentSession
        self.direction = direction
    }
}

public protocol AdjacentReaderSessionLoading: Sendable {
    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession
}

public protocol ReaderProgressStoring: Sendable {
    func progress(for sourceURL: URL) async -> ReaderProgress?
    func save(_ progress: ReaderProgress, for sourceURL: URL) async
}

public protocol ChapterPageDetecting: Sendable {
    func detect(page: DetectionPageAnalysis) -> DetectionResult
}
