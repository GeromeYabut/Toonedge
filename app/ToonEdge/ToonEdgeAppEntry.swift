import SwiftUI

@main
struct ToonEdgeAppEntry: App {
    var body: some Scene {
        WindowGroup {
            ToonEdgeRootView(
                dependencies: launchDependencies(),
                initialRouter: launchRouter()
            )
        }
    }

    @MainActor
    private func launchDependencies() -> AppDependencies {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else {
            return (try? AppDependencies.persistent()) ?? .mock()
        }

        var dependencies = AppDependencies.mock()
        if let marker = arguments.firstIndex(of: "-browserFixture"),
           arguments.indices.contains(marker + 1) {
            switch arguments[marker + 1] {
            case "medium":
                dependencies.browserPresentationFixture = .mediumConfidence
            case "low":
                dependencies.browserPresentationFixture = .lowConfidence
            case "protected":
                dependencies.browserPresentationFixture = .protected
            case "nonviable":
                dependencies.browserPresentationFixture = .nonviable
            default:
                break
            }
        }
        if arguments.contains("-resetSettings") {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.readerCanvas)
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.displayMode)
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.pageSpacing)
            defaults.removeObject(forKey: UserDefaultsSettingsRepository.Key.brightnessAid)
            defaults.removeObject(forKey: UserDefaultsInteractionPreferences.hapticFeedbackEnabledKey)
        }
        dependencies.settingsService = UserDefaultsSettingsRepository()
        let interactionPreferences = UserDefaultsInteractionPreferences()
        dependencies.interactionPreferences = interactionPreferences
        dependencies.interactionFeedback = RecordingInteractionFeedback(preferences: interactionPreferences)
        if arguments.contains("-seedOfflineReader"), let cache = dependencies.chapterAssetCache {
            dependencies.chapterAssetRetainer = UITestFixtureAssetRetainer(assetCache: cache)
            if arguments.contains("-resetOfflineFixture") {
                let directory = cache.chapterDirectory(for: offlineFixtureSession.sourceURL)
                try? FileManager.default.removeItem(at: directory)
            }
        }
        if arguments.contains("-seedDelayedLibrary") {
            dependencies.libraryService = DelayedUITestLibraryService()
        }
        if arguments.contains("-seedDownloads20") {
            let entries = (1...20).map { number in
                CacheMetadataEntry(
                    sourceURL: URL(string: "https://fixture.example/chapter-\(number)")!,
                    seriesTitle: "Fixture Series",
                    chapterTitle: "Fixture Chapter \(number)",
                    chapterLabel: "\(number)",
                    imageCount: 1,
                    estimatedStorageBytes: 1_000,
                    retentionState: .recent,
                    cachedAt: Date(timeIntervalSince1970: Double(number))
                )
            }
            dependencies.cacheMetadataService = MockCacheMetadataService(entries: entries)
            dependencies.cacheStorageMeasurementService = nil
        }
        if arguments.contains("-seedDelayedDownloadsEmpty") {
            let service = DelayedUITestCacheMetadataService(entries: [])
            dependencies.downloadService = service
            dependencies.cacheMetadataService = service
            dependencies.cacheStorageMeasurementService = nil
        } else if arguments.contains("-seedDelayedDownloadsContent") {
            let service = DelayedUITestCacheMetadataService(entries: [
                CacheMetadataEntry(
                    sourceURL: URL(string: "https://fixture.example/delayed/chapter-7")!,
                    seriesTitle: "Delayed Fixture",
                    chapterTitle: "Delayed Chapter 7",
                    chapterLabel: "7",
                    imageCount: 1,
                    estimatedStorageBytes: 7_000,
                    retentionState: .recent,
                    cachedAt: Date(timeIntervalSince1970: 7)
                )
            ])
            dependencies.downloadService = service
            dependencies.cacheMetadataService = service
            dependencies.cacheStorageMeasurementService = nil
        } else if arguments.contains("-seedDownloadsRemovalRetry") {
            let service = RetryRemovalUITestCacheMetadataService(
                entry: CacheMetadataEntry(
                    sourceURL: URL(string: "https://fixture.example/retry/chapter-9")!,
                    seriesTitle: "Retry Fixture",
                    chapterTitle: "Retry Chapter 9",
                    chapterLabel: "9",
                    imageCount: 1,
                    estimatedStorageBytes: 9_000,
                    retentionState: .retained,
                    cachedAt: Date(timeIntervalSince1970: 9)
                )
            )
            dependencies.downloadService = service
            dependencies.cacheMetadataService = service
            dependencies.cacheStorageMeasurementService = nil
        }
        if arguments.contains("-seedAdjacentFailureReader") {
            dependencies.adjacentReaderSessionLoader = UITestAdjacentFailureLoader()
        }
        if arguments.contains("-seedUpdateSuccess") {
            dependencies.updateRefreshService = MockLibraryUpdateRefreshService(
                result: LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 1, failedCount: 0)
            )
        } else if arguments.contains("-seedUpdateFailure") {
            dependencies.updateRefreshService = MockLibraryUpdateRefreshService(
                result: LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 0, failedCount: 2)
            )
        } else if arguments.contains("-seedUpdateNoChange") {
            dependencies.updateRefreshService = MockLibraryUpdateRefreshService(
                result: LibraryUpdateRefreshResult(checkedCount: 3, updatedCount: 0, failedCount: 0)
            )
        }
        return dependencies
    }

    private func launchRouter() -> AppRouter {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting"),
           let marker = arguments.firstIndex(of: "-openURL"),
           arguments.indices.contains(marker + 1) {
            return AppRouter(presentedBrowser: .url(arguments[marker + 1]))
        }
        if arguments.contains("-uiTesting"), arguments.contains("-browserFixture") {
            return AppRouter(presentedBrowser: .url("about:blank"))
        }
        if arguments.contains("-uiTesting"), arguments.contains("-seedAdjacentFailureReader") {
            return AppRouter(presentedReader: adjacentFailureFixtureSession)
        }
        guard arguments.contains("-seedOfflineReader") else {
            return AppRouter()
        }
        let session = arguments.contains("-uncachedOfflineFixture")
            ? uncachedOfflineFixtureSession
            : offlineFixtureSession
        return AppRouter(presentedReader: session)
    }
}

private actor DelayedUITestCacheMetadataService: CacheMetadataManaging {
    private var entries: [CacheMetadataEntry]

    init(entries: [CacheMetadataEntry]) {
        self.entries = entries
    }

    func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        throw URLError(.unsupportedURL)
    }

    func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        let originalCount = entries.count
        entries.removeAll { $0.sourceURL == sourceURL }
        return entries.count == originalCount ? .notFound : .removed
    }

    func updateCacheRetention(
        for sourceURL: URL,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) async throws -> CacheActionResult {
        throw URLError(.unsupportedURL)
    }

    func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        try? await Task.sleep(for: .seconds(2))
        return entries
    }

    func downloadSummary() async -> DownloadSummary {
        summary(for: entries)
    }
}

private actor RetryRemovalUITestCacheMetadataService: CacheMetadataManaging {
    private var entry: CacheMetadataEntry?
    private var removalAttempts = 0

    init(entry: CacheMetadataEntry) {
        self.entry = entry
    }

    func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        throw URLError(.unsupportedURL)
    }

    func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        removalAttempts += 1
        if removalAttempts == 1 {
            throw URLError(.cannotRemoveFile)
        }
        guard entry?.sourceURL == sourceURL else { return .notFound }
        entry = nil
        return .removed
    }

    func updateCacheRetention(
        for sourceURL: URL,
        retentionState: CacheRetentionState,
        cachedAt: Date
    ) async throws -> CacheActionResult {
        throw URLError(.unsupportedURL)
    }

    func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        entry.map { [$0] } ?? []
    }

    func downloadSummary() async -> DownloadSummary {
        summary(for: entry.map { [$0] } ?? [])
    }
}

private func summary(for entries: [CacheMetadataEntry]) -> DownloadSummary {
    let estimatedBytes = entries.reduce(Int64(0)) { $0 + $1.estimatedStorageBytes }
    return DownloadSummary(
        cachedItemCount: entries.count,
        storageDescription: entries.isEmpty
            ? "No local storage tracked"
            : DownloadSummary.storageDescription(for: estimatedBytes),
        recentItemCount: entries.filter { $0.retentionState == .recent }.count,
        retainedItemCount: entries.filter { $0.retentionState == .retained }.count,
        totalEstimatedBytes: estimatedBytes
    )
}

private let adjacentFailureFixtureTargetURL = URL(string: "https://fixture.example/series/chapter-2")!

private let adjacentFailureFixtureSession: MockReaderSession = {
    var session = MockReaderSession(
        seriesTitle: "Adjacent Failure Fixture",
        chapterTitle: "Chapter 1",
        sourceURL: URL(string: "https://fixture.example/series/chapter-1")!,
        imageURLs: [URL(string: "https://images.example.test/adjacent/001.png")!]
    )
    session.nextChapter = MockChapter(title: "Chapter 2", sourceURL: adjacentFailureFixtureTargetURL)
    return session
}()

private actor UITestAdjacentFailureLoader: AdjacentReaderSessionLoading {
    private var attemptCount = 0

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        attemptCount += 1
        if attemptCount == 1 {
            throw AdjacentReaderSessionLoadError(
                reason: .challengeOrRateLimit,
                targetURL: url,
                confidence: .low,
                parserPath: .browserSessionProfile,
                challengeSignals: ["http-status:429"]
            )
        }

        var session = MockReaderSession(
            seriesTitle: context.currentSession.seriesTitle,
            chapterTitle: "Chapter 2",
            sourceURL: url,
            imageURLs: [URL(string: "https://images.example.test/adjacent/002.png")!]
        )
        session.launchOrigin = context.currentSession.launchOrigin
        return session
    }
}

private let offlineFixtureSession = MockReaderSession(
    seriesTitle: "Offline Fixture",
    chapterTitle: "Chapter 1",
    sourceURL: URL(string: "https://fixture.example/retained/chapter-1")!,
    imageURLs: (1...3).map { URL(string: "https://images.example.test/offline/00\($0).png")! },
    pageMetadata: (1...3).map { _ in ReaderPageMetadata(pixelWidth: 1, pixelHeight: 1) }
)

private let uncachedOfflineFixtureSession = MockReaderSession(
    seriesTitle: "Offline Fixture",
    chapterTitle: "Chapter 2",
    sourceURL: URL(string: "https://fixture.example/uncached/chapter-2")!,
    imageURLs: [URL(string: "https://images.example.test/uncached/001.png")!],
    pageMetadata: [ReaderPageMetadata(pixelWidth: 1, pixelHeight: 1)]
)

private struct UITestFixtureAssetRetainer: ChapterAssetRetaining {
    let assetCache: any ChapterAssetCaching

    func retainAssets(for session: MockReaderSession) async throws -> Int64 {
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==")!
        for imageURL in session.imageURLs {
            try assetCache.store(data, for: imageURL, sourceURL: session.sourceURL)
        }
        return Int64(data.count * session.imageURLs.count)
    }
}

private struct DelayedUITestLibraryService: LibraryProviding {
    func homeSnapshot() async -> HomeSnapshot { await MockLibraryService().homeSnapshot() }

    func librarySnapshot() async -> LibrarySnapshot {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        return await MockLibraryService().librarySnapshot()
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        await MockLibraryService().seriesDetail(for: seriesID)
    }
}
