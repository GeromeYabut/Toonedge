import SwiftUI

private enum ReaderHardeningFixtureScenario: String {
    case numericAdjacency = "numeric-adjacency"
    case numericAdjacencyUnsafe = "numeric-adjacency-unsafe"
    case continueTarget = "continue-target"
    case continueAdjacentDiscovery = "continue-adjacent-discovery"
    case adjacentTimeout = "adjacent-timeout"
    case adjacentChallenge = "adjacent-challenge"
    case adjacentUnavailable = "adjacent-unavailable"
    case adjacentLowConfidence = "adjacent-low-confidence"
    case adjacentNonviable = "adjacent-nonviable"
    case adjacentSuccess = "adjacent-success"

    static func from(arguments: [String]) -> Self? {
        guard let marker = arguments.firstIndex(of: "-readerHardeningFixture"),
              arguments.indices.contains(marker + 1) else {
            return arguments.contains("-seedAdjacentFailureReader") ? .adjacentChallenge : nil
        }
        return Self(rawValue: arguments[marker + 1])
    }

    var usesAdjacentOutcomeFixture: Bool {
        switch self {
        case .adjacentTimeout, .adjacentChallenge, .adjacentUnavailable,
             .adjacentLowConfidence, .adjacentNonviable, .adjacentSuccess:
            true
        default:
            false
        }
    }
}

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
        let hardeningFixture = ReaderHardeningFixtureScenario.from(arguments: arguments)
        guard arguments.contains("-uiTesting") else {
            return (try? AppDependencies.persistent()) ?? .mock()
        }

        var dependencies = AppDependencies.mock()
        if let marker = arguments.firstIndex(of: "-browserFixture"),
           arguments.indices.contains(marker + 1) {
            switch arguments[marker + 1] {
            case "high":
                dependencies.browserPresentationFixture = .highConfidence
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
        if arguments.contains("-seedSeriesMutationRetry") {
            let service = RetrySeriesMutationUITestLibraryService()
            dependencies.libraryService = service
            dependencies.libraryLifecycleService = service
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
        if let hardeningFixture, hardeningFixture.usesAdjacentOutcomeFixture {
            dependencies.adjacentReaderSessionLoader = UITestAdjacentOutcomeLoader(scenario: hardeningFixture)
        } else if hardeningFixture == .numericAdjacency {
            dependencies.adjacentReaderSessionLoader = UITestAdjacentSuccessLoader()
        }
        if let hardeningFixture,
           hardeningFixture == .continueTarget || hardeningFixture == .continueAdjacentDiscovery {
            let service = UITestContinueJourneyLibraryService(
                scenario: hardeningFixture,
                resetTestData: arguments.contains("-resetTestData")
            )
            dependencies.libraryService = service
            dependencies.libraryLifecycleService = service
            dependencies.recentReadingRecorder = service
            dependencies.readerProgressRepository = service
            dependencies.chapterIndexRefreshService = nil
            if hardeningFixture == .continueAdjacentDiscovery {
                dependencies.adjacentReaderSessionLoader = UITestContinueAdjacentDiscoveryLoader()
            }
            // Reserved domains never need a network response to exercise real Reader callbacks.
            if let cache = dependencies.chapterAssetCache {
                let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==")!
                for number in 1...3 {
                    let session = UITestContinueJourneyFixture.session(number)
                    for imageURL in session.imageURLs {
                        try? cache.store(data, for: imageURL, sourceURL: session.sourceURL)
                    }
                }
            }
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
        let hardeningFixture = ReaderHardeningFixtureScenario.from(arguments: arguments)
        if arguments.contains("-uiTesting"),
           let marker = arguments.firstIndex(of: "-openURL"),
           arguments.indices.contains(marker + 1) {
            return AppRouter(presentedBrowser: .url(arguments[marker + 1]))
        }
        if arguments.contains("-uiTesting"), arguments.contains("-browserFixture") {
            return AppRouter(presentedBrowser: .url("about:blank"))
        }
        if arguments.contains("-uiTesting"), hardeningFixture?.usesAdjacentOutcomeFixture == true {
            return AppRouter(presentedReader: adjacentOutcomeFixtureSession)
        }
        if arguments.contains("-uiTesting"), hardeningFixture == .numericAdjacency {
            return AppRouter(presentedReader: numericAdjacencyFixtureSession)
        }
        if arguments.contains("-uiTesting"), hardeningFixture == .numericAdjacencyUnsafe {
            return AppRouter(presentedReader: numericAdjacencyUnsafeFixtureSession)
        }
        if arguments.contains("-uiTesting"), hardeningFixture == .continueTarget {
            return AppRouter(selectedTab: .library)
        }
        if arguments.contains("-uiTesting"), hardeningFixture == .continueAdjacentDiscovery {
            let hasDiscoveredChapterThree = !arguments.contains("-resetTestData")
                && UITestContinueJourneyLibraryService.hasPersistedChapterThree(for: .continueAdjacentDiscovery)
            return AppRouter(
                selectedTab: .library,
                presentedReader: hasDiscoveredChapterThree ? nil : UITestContinueJourneyFixture.session(2),
                pendingLibrarySeriesID: UITestContinueJourneyFixture.seriesID
            )
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

private enum UITestContinueJourneyFixture {
    static let seriesID = UUID(uuidString: "DEF02100-0000-4000-8000-000000000001")!
    static let title = "Continue Journey Fixture"
    static let seriesURL = URL(string: "https://fixture.example/continue-journey")!
    static let seedDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let imageCount = 12

    static func chapterID(_ number: Int) -> UUID {
        UUID(uuidString: "DEF02100-0000-4000-8000-00000000000\(number + 1)")!
    }

    static func sourceURL(_ number: Int) -> URL {
        seriesURL.appendingPathComponent("chapter-\(number)")
    }

    static func session(_ number: Int) -> MockReaderSession {
        MockReaderSession(
            id: chapterID(number),
            seriesID: seriesID,
            seriesTitle: title,
            seriesURL: seriesURL,
            chapterTitle: "Chapter \(number)",
            sourceURL: sourceURL(number),
            imageURLs: (1...imageCount).map {
                URL(string: "https://images.example.test/continue-journey/\(number)/\($0).png")!
            },
            pageMetadata: (1...imageCount).map { _ in ReaderPageMetadata(pixelWidth: 1, pixelHeight: 1) },
            nextChapter: number == 2
                ? MockChapter(id: chapterID(3), title: "Chapter 3", sourceURL: sourceURL(3))
                : nil,
            launchOrigin: .library(seriesID: seriesID)
        )
    }
}

/// UI-test transport only. UserDefaults here is not production repository persistence coverage.
private actor UITestContinueJourneyLibraryService: LibraryLifecycleManaging, RecentReadingRecording, ReaderProgressStoring {
    private typealias Fixture = UITestContinueJourneyFixture

    private struct Checkpoint: Codable {
        var progress: ReaderProgress
        var readAt: Date
    }

    private struct State: Codable {
        var activeChapter: Int
        var checkpoints: [Int: Checkpoint]
    }

    private let defaults: UserDefaults
    private let stateKey: String
    private var state: State

    // Launch routing reads fixture state without creating a Reader that would record a new visit.
    static func hasPersistedChapterThree(for scenario: ReaderHardeningFixtureScenario) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey(for: scenario)),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return false }
        return state.checkpoints[3] != nil
    }

    private static func persistenceKey(for scenario: ReaderHardeningFixtureScenario) -> String {
        "ToonEdge.UITests.ReaderHardening.ContinueJourney.\(scenario.rawValue).v1"
    }

    init(scenario: ReaderHardeningFixtureScenario, resetTestData: Bool) {
        let defaults = UserDefaults.standard
        let key = Self.persistenceKey(for: scenario)
        if resetTestData {
            defaults.removeObject(forKey: key)
        }
        self.defaults = defaults
        self.stateKey = key
        let activeChapter = scenario == .continueAdjacentDiscovery ? 2 : 3
        self.state = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(State.self, from: $0) }
            ?? State(activeChapter: activeChapter, checkpoints: [
                1: Checkpoint(
                    progress: ReaderProgress(currentImageIndex: 1, totalImageCount: Fixture.imageCount),
                    readAt: Fixture.seedDate
                ),
                activeChapter: Checkpoint(
                    progress: ReaderProgress(currentImageIndex: 2, totalImageCount: Fixture.imageCount),
                    readAt: Fixture.seedDate.addingTimeInterval(60)
                )
            ])
    }

    func homeSnapshot() async -> HomeSnapshot {
        let summary = SeriesSummary(
            id: Fixture.seriesID,
            title: Fixture.title,
            subtitle: "Continue Chapter \(state.activeChapter)",
            progressPercent: activeCheckpoint.progress.fractionComplete,
            hasUnreadUpdates: false
        )
        return HomeSnapshot(continueReading: [summary], recentlyUpdated: [], library: [summary])
    }

    func librarySnapshot() async -> LibrarySnapshot {
        LibrarySnapshot(series: [LibrarySeriesSummary(
            id: Fixture.seriesID,
            title: Fixture.title,
            sourceDomain: "fixture.example",
            canonicalURL: Fixture.seriesURL,
            coverImageURL: nil,
            progressPercent: activeCheckpoint.progress.fractionComplete,
            chaptersRead: 0,
            totalKnownChapters: state.checkpoints.count,
            lastReadAt: activeCheckpoint.readAt,
            libraryState: .reading,
            hasUnreadUpdates: false,
            isCompleted: false,
            latestChapterLabel: String(state.checkpoints.keys.max() ?? 1),
            currentChapterLabel: String(state.activeChapter),
            resumeTarget: LibraryResumeTarget(chapter: chapterSummary(state.activeChapter))
        )])
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        guard seriesID == Fixture.seriesID else { return nil }
        return SeriesDetailSnapshot(
            id: Fixture.seriesID,
            title: Fixture.title,
            status: "Ongoing",
            synopsis: "Deterministic UI-test Continue journey.",
            sourceDomain: "fixture.example",
            coverImageURL: nil,
            isSaved: true,
            libraryState: .reading,
            progressPercent: activeCheckpoint.progress.fractionComplete,
            chaptersRead: 0,
            totalKnownChapters: state.checkpoints.count,
            hasUnreadUpdates: false,
            chapters: state.checkpoints.keys.sorted().map(chapterSummary)
        )
    }

    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? {
        guard seriesID == Fixture.seriesID else { return nil }
        return ContinueReadingTarget(
            seriesID: seriesID,
            chapterID: Fixture.chapterID(state.activeChapter),
            sourceURL: Fixture.sourceURL(state.activeChapter),
            progress: activeCheckpoint.progress
        )
    }

    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? {
        guard let number = state.checkpoints.keys.first(where: { Fixture.chapterID($0) == chapterID }) else { return nil }
        return Fixture.session(number)
    }

    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? {
        guard let number = state.checkpoints.keys.first(where: { Fixture.sourceURL($0) == sourceURL }) else { return nil }
        return Fixture.session(number)
    }

    func progress(for sourceURL: URL) async -> ReaderProgress? {
        guard let number = (1...3).first(where: { Fixture.sourceURL($0) == sourceURL }) else { return nil }
        return state.checkpoints[number]?.progress
    }

    func save(_ progress: ReaderProgress, for sourceURL: URL) async {
        guard let number = (1...3).first(where: { Fixture.sourceURL($0) == sourceURL }) else { return }
        try? await recordReadingProgress(progress, forChapterID: Fixture.chapterID(number), at: Date())
    }

    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {
        guard let number = (1...3).first(where: { Fixture.chapterID($0) == chapterID }),
              progress.totalImageCount > 0,
              date > (state.checkpoints[number]?.readAt ?? .distantPast) else { return }
        let latestActiveDate = activeCheckpoint.readAt
        state.checkpoints[number] = Checkpoint(progress: progress, readAt: date)
        if progress.fractionComplete < 1, date > latestActiveDate {
            state.activeChapter = number
        }
        defaults.set(try JSONEncoder().encode(state), forKey: stateKey)
    }

    func recordRecentReading(_ input: RecentReadingInput) async throws {
        guard input.seriesID == Fixture.seriesID,
              let number = (1...3).first(where: { Fixture.sourceURL($0) == input.sourceURL }),
              input.chapterID == Fixture.chapterID(number) else { return }
        try await recordReadingProgress(input.progress, forChapterID: input.chapterID, at: input.readAt)
    }

    func isSaved(canonicalURL: URL) async -> Bool { canonicalURL == Fixture.seriesURL }

    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {
        throw URLError(.unsupportedURL)
    }

    func removeFromLibrary(seriesID: UUID) async throws { throw URLError(.unsupportedURL) }
    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {
        throw URLError(.unsupportedURL)
    }

    func recordUpdateCheckResult(
        seriesID: UUID, latestChapterLabel: String?, hasUnreadUpdates: Bool, checkedAt: Date
    ) async throws {}

    private var activeCheckpoint: Checkpoint { state.checkpoints[state.activeChapter]! }

    private func chapterSummary(_ number: Int) -> ChapterSummary {
        let checkpoint = state.checkpoints[number]!
        return ChapterSummary(
            id: Fixture.chapterID(number),
            title: "Chapter \(number)",
            chapterLabel: String(number),
            chapterNumber: Double(number),
            sourceURL: Fixture.sourceURL(number),
            readState: checkpoint.progress.fractionComplete < 1
                ? .inProgress(progressPercent: checkpoint.progress.fractionComplete) : .read,
            isDownloaded: false,
            publishedAt: nil,
            lastReadAt: checkpoint.readAt
        )
    }
}

private struct UITestContinueAdjacentDiscoveryLoader: AdjacentReaderSessionLoading {
    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        guard context.currentSession.sourceURL == UITestContinueJourneyFixture.sourceURL(2),
              context.direction == .next,
              url == UITestContinueJourneyFixture.sourceURL(3) else {
            throw URLError(.unsupportedURL)
        }
        var session = UITestContinueJourneyFixture.session(3)
        session.launchOrigin = context.currentSession.launchOrigin
        return session
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

private let adjacentOutcomeFixtureTargetURL = URL(string: "https://fixture.example/series/chapter-2")!

private let adjacentOutcomeFixtureSession: MockReaderSession = {
    var session = MockReaderSession(
        seriesTitle: "Adjacent Outcome Fixture",
        seriesURL: URL(string: "https://fixture.example/series")!,
        chapterTitle: "Chapter 1",
        sourceURL: URL(string: "https://fixture.example/series/chapter-1")!,
        imageURLs: [URL(string: "https://images.example.test/adjacent/001.png")!],
        launchOrigin: .homeContinueReading
    )
    session.nextChapter = MockChapter(title: "Chapter 2", sourceURL: adjacentOutcomeFixtureTargetURL)
    return session
}()

private let numericAdjacencyFixtureSession: MockReaderSession = {
    var session = MockReaderSession(
        seriesTitle: "Numeric Adjacency Fixture",
        chapterTitle: "Chapter 155",
        sourceURL: URL(string: "https://fixture.example/series/chapter-155")!,
        imageURLs: [URL(string: "https://images.example.test/numeric/155.png")!]
    )
    session.previousChapter = MockChapter(
        title: "Chapter 154",
        sourceURL: URL(string: "https://fixture.example/series/chapter-154")!
    )
    session.nextChapter = MockChapter(
        title: "Chapter 156",
        sourceURL: URL(string: "https://fixture.example/series/chapter-156")!
    )
    return session
}()

private let numericAdjacencyUnsafeFixtureSession = MockReaderSession(
    seriesTitle: "Numeric Adjacency Fixture",
    chapterTitle: "Chapter 155",
    sourceURL: URL(string: "https://fixture.example/series/latest")!,
    imageURLs: [URL(string: "https://images.example.test/numeric/155.png")!]
)

private actor UITestAdjacentSuccessLoader: AdjacentReaderSessionLoading {
    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        let label = url.lastPathComponent.replacingOccurrences(of: "chapter-", with: "")
        var session = MockReaderSession(
            id: context.currentSession.id,
            seriesID: context.currentSession.seriesID,
            seriesTitle: context.currentSession.seriesTitle,
            seriesURL: context.currentSession.seriesURL,
            chapterTitle: "Chapter \(label)",
            sourceURL: url,
            imageURLs: [URL(string: "https://images.example.test/numeric/\(label).png")!]
        )
        session.launchOrigin = context.currentSession.launchOrigin
        return session
    }
}

private actor UITestAdjacentOutcomeLoader: AdjacentReaderSessionLoading {
    let scenario: ReaderHardeningFixtureScenario
    private var attempts = 0

    init(scenario: ReaderHardeningFixtureScenario) {
        self.scenario = scenario
    }

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        attempts += 1
        if scenario == .adjacentSuccess || (scenario == .adjacentChallenge && attempts > 1) {
            var session = MockReaderSession(
                id: context.currentSession.id,
                seriesID: context.currentSession.seriesID,
                seriesTitle: context.currentSession.seriesTitle,
                seriesURL: context.currentSession.seriesURL,
                chapterTitle: "Chapter 2",
                sourceURL: adjacentOutcomeFixtureTargetURL,
                imageURLs: [URL(string: "https://images.example.test/adjacent/002.png")!]
            )
            session.launchOrigin = context.currentSession.launchOrigin
            return session
        }

        switch scenario {
        case .adjacentTimeout:
            throw AdjacentReaderSessionLoadError(
                reason: .timeout,
                targetURL: adjacentOutcomeFixtureTargetURL
            )
        case .adjacentChallenge:
            throw AdjacentReaderSessionLoadError(
                reason: .challengeOrRateLimit,
                targetURL: adjacentOutcomeFixtureTargetURL,
                confidence: .low,
                parserPath: .browserSessionProfile,
                challengeSignals: ["http-status:429"]
            )
        case .adjacentUnavailable:
            throw AdjacentReaderSessionLoadError(
                reason: .unavailable,
                targetURL: adjacentOutcomeFixtureTargetURL
            )
        case .adjacentLowConfidence:
            throw AdjacentReaderSessionLoadError(
                reason: .lowConfidence,
                targetURL: adjacentOutcomeFixtureTargetURL,
                confidence: .medium,
                parserPath: .genericHeuristic
            )
        case .adjacentNonviable:
            throw AdjacentReaderSessionLoadError(
                reason: .nonViableImages,
                targetURL: adjacentOutcomeFixtureTargetURL,
                confidence: .high,
                parserPath: .genericHeuristic
            )
        default:
            throw AdjacentReaderSessionLoadError(
                reason: .unavailable,
                targetURL: adjacentOutcomeFixtureTargetURL
            )
        }
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

private actor RetrySeriesMutationUITestLibraryService: LibraryLifecycleManaging {
    private let base = MockLibraryService()
    private var updateAttempts = 0
    private var updatedStates: [UUID: LibraryCollectionState] = [:]

    func homeSnapshot() async -> HomeSnapshot {
        await base.homeSnapshot()
    }

    func librarySnapshot() async -> LibrarySnapshot {
        await base.librarySnapshot()
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        guard var detail = await base.seriesDetail(for: seriesID) else { return nil }
        if let updatedState = updatedStates[seriesID] {
            detail.libraryState = updatedState
        }
        return detail
    }

    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {
        throw URLError(.unsupportedURL)
    }

    func removeFromLibrary(seriesID: UUID) async throws {
        throw URLError(.unsupportedURL)
    }

    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {
        updateAttempts += 1
        guard updateAttempts > 1 else {
            throw URLError(.cannotWriteToFile)
        }
        updatedStates[seriesID] = state
    }

    func recordUpdateCheckResult(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date
    ) async throws {}

    func recordReadingProgress(
        _ progress: ReaderProgress,
        forChapterID chapterID: UUID,
        at date: Date
    ) async throws {}

    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? { nil }
    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? { nil }
    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? { nil }
    func isSaved(canonicalURL: URL) async -> Bool { true }
}
