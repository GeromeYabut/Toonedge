import Foundation

public struct MockLibraryService: LibraryProviding {
    public init() {}

    public func homeSnapshot() async -> HomeSnapshot {
        let library = await librarySnapshot()
        return HomeSnapshot(
            continueReading: HomeContinueReadingBuilder.summaries(from: library),
            recentlyUpdated: library.series.filter(\.hasUnreadUpdates).map(homeSummary),
            library: library.series.map(homeSummary)
        )
    }

    public func librarySnapshot() async -> LibrarySnapshot {
        LibrarySnapshot(series: Self.series)
    }

    public func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        Self.details[seriesID]
    }

    private func homeSummary(_ series: LibrarySeriesSummary) -> SeriesSummary {
        let subtitle: String
        if series.hasUnreadUpdates, let latestChapterLabel = series.latestChapterLabel {
            subtitle = "New Chapter \(latestChapterLabel)"
        } else if let currentChapterLabel = series.currentChapterLabel {
            subtitle = "Continue Chapter \(currentChapterLabel)"
        } else {
            subtitle = series.libraryState.title
        }

        return SeriesSummary(
            id: series.id,
            title: series.title,
            subtitle: subtitle,
            coverImageURL: series.coverImageURL,
            progressPercent: series.progressPercent,
            hasUnreadUpdates: series.hasUnreadUpdates
        )
    }

    private static let moonlitID = UUID(uuidString: "A4A029B1-778A-46DF-9B92-2E94378C8E11")!
    private static let signalID = UUID(uuidString: "E93350A5-63DC-4FA9-AE79-17D9B13C7642")!
    private static let glassID = UUID(uuidString: "B4E14CEF-1281-45A5-BBE9-9A6B4A08A712")!
    private static let courierID = UUID(uuidString: "6058E19A-6500-4DDC-B8E2-D1912CD29FCB")!
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    private static let series: [LibrarySeriesSummary] = [
        LibrarySeriesSummary(
            id: moonlitID,
            title: "Moonlit Edge",
            sourceDomain: "example.com",
            coverImageURL: nil,
            progressPercent: 0.62,
            chaptersRead: 12,
            totalKnownChapters: 19,
            lastReadAt: now.addingTimeInterval(-2_400),
            libraryState: .reading,
            hasUnreadUpdates: false,
            isCompleted: false,
            latestChapterLabel: "19",
            currentChapterLabel: "12"
        ),
        LibrarySeriesSummary(
            id: signalID,
            title: "Signal Tower",
            sourceDomain: "webtoons.com",
            coverImageURL: URL(string: "https://picsum.photos/seed/signal-tower/420/620"),
            progressPercent: 0.28,
            chaptersRead: 44,
            totalKnownChapters: 158,
            lastReadAt: now.addingTimeInterval(-7_200),
            libraryState: .reading,
            hasUnreadUpdates: true,
            isCompleted: false,
            latestChapterLabel: "158",
            currentChapterLabel: "44"
        ),
        LibrarySeriesSummary(
            id: glassID,
            title: "Glass Harbor",
            sourceDomain: "globalcomix.com",
            coverImageURL: nil,
            progressPercent: 0,
            chaptersRead: 0,
            totalKnownChapters: 19,
            lastReadAt: nil,
            libraryState: .planned,
            hasUnreadUpdates: true,
            isCompleted: false,
            latestChapterLabel: "19",
            currentChapterLabel: nil
        ),
        LibrarySeriesSummary(
            id: courierID,
            title: "North Star Courier",
            sourceDomain: "example.com",
            coverImageURL: URL(string: "https://picsum.photos/seed/north-star-courier/420/620"),
            progressPercent: 1,
            chaptersRead: 7,
            totalKnownChapters: 7,
            lastReadAt: now.addingTimeInterval(-86_400),
            libraryState: .reading,
            hasUnreadUpdates: false,
            isCompleted: true,
            latestChapterLabel: "7",
            currentChapterLabel: "7"
        )
    ]

    private static let details: [UUID: SeriesDetailSnapshot] = [
        moonlitID: SeriesDetailSnapshot(
            id: moonlitID,
            title: "Moonlit Edge",
            status: "Ongoing",
            synopsis: "A quiet swordswoman follows a lunar signal through border cities, hidden schools, and a conspiracy that keeps rewriting the map.",
            sourceDomain: "example.com",
            coverImageURL: nil,
            isSaved: true,
            libraryState: .reading,
            progressPercent: 0.62,
            chaptersRead: 12,
            totalKnownChapters: 19,
            hasUnreadUpdates: false,
            chapters: mockChapters(seriesSlug: "moonlit-edge", current: 12, latest: 19, downloaded: [10, 12])
        ),
        signalID: SeriesDetailSnapshot(
            id: signalID,
            title: "Signal Tower",
            status: "Ongoing",
            synopsis: "Operators climb a ruined broadcast tower where every floor receives tomorrow's disaster warning a few minutes too late.",
            sourceDomain: "webtoons.com",
            coverImageURL: URL(string: "https://picsum.photos/seed/signal-tower/420/620"),
            isSaved: true,
            libraryState: .reading,
            progressPercent: 0.28,
            chaptersRead: 44,
            totalKnownChapters: 158,
            hasUnreadUpdates: true,
            chapters: mockChapters(seriesSlug: "signal-tower", current: 44, latest: 158, downloaded: [44, 43])
        ),
        glassID: SeriesDetailSnapshot(
            id: glassID,
            title: "Glass Harbor",
            status: "Ongoing",
            synopsis: "A planned read about smugglers, sea spirits, and the city that appears only when the tide reflects the stars.",
            sourceDomain: "globalcomix.com",
            coverImageURL: nil,
            isSaved: true,
            libraryState: .planned,
            progressPercent: 0,
            chaptersRead: 0,
            totalKnownChapters: 19,
            hasUnreadUpdates: true,
            chapters: mockChapters(seriesSlug: "glass-harbor", current: nil, latest: 19, downloaded: [])
        ),
        courierID: SeriesDetailSnapshot(
            id: courierID,
            title: "North Star Courier",
            status: "Completed",
            synopsis: "A completed short series about a courier carrying letters across a winter continent after the compass constellations vanish.",
            sourceDomain: "example.com",
            coverImageURL: URL(string: "https://picsum.photos/seed/north-star-courier/420/620"),
            isSaved: true,
            libraryState: .completed,
            progressPercent: 1,
            chaptersRead: 7,
            totalKnownChapters: 7,
            hasUnreadUpdates: false,
            chapters: mockChapters(seriesSlug: "north-star-courier", current: 7, latest: 7, downloaded: [7])
        )
    ]

    private static func mockChapters(
        seriesSlug: String,
        current: Int?,
        latest: Int,
        downloaded: Set<Int>
    ) -> [ChapterSummary] {
        (1...latest).map { number in
            let state: ChapterReadState
            if let current, number < current {
                state = .read
            } else if let current, number == current {
                state = .inProgress(progressPercent: seriesSlug == "north-star-courier" ? 1 : 0.42)
            } else if number > max(latest - 2, 0) {
                state = .new
            } else {
                state = .unread
            }

            return ChapterSummary(
                title: "Chapter \(number)",
                chapterLabel: "\(number)",
                chapterNumber: Double(number),
                sourceURL: URL(string: "https://example.com/\(seriesSlug)/chapter-\(number)")!,
                readState: state,
                isDownloaded: downloaded.contains(number),
                publishedAt: now.addingTimeInterval(Double(number - latest) * 86_400)
            )
        }
    }
}

public struct MockSearchSuggestionProvider: SearchSuggestionProviding {
    private let clipboardURL: String?
    private let recentLinks: [String]
    private let recentSearches: [String]
    private let commonSites: [String]
    private let siteProfileRegistry: SiteProfileRegistry

    public init(
        clipboardURL: String? = "https://example.com/series/chapter-12",
        recentLinks: [String] = [
            "https://example.com/moonlit-edge/chapter-12",
            "https://webtoons.com/en/action/sample/list"
        ],
        recentSearches: [String] = [
            "new manhwa chapters",
            "moonlit edge chapter 13"
        ],
        commonSites: [String] = [
            "webtoons.com",
            "tapas.io",
            "globalcomix.com"
        ],
        siteProfileRegistry: SiteProfileRegistry = .default
    ) {
        self.clipboardURL = clipboardURL
        self.recentLinks = recentLinks
        self.recentSearches = recentSearches
        self.commonSites = commonSites
        self.siteProfileRegistry = siteProfileRegistry
    }

    public func suggestions(matching query: String) -> [SearchSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = trimmed.lowercased()

        func matches(_ value: String) -> Bool {
            normalizedQuery.isEmpty || value.lowercased().contains(normalizedQuery)
        }

        var suggestions: [SearchSuggestion] = []

        if let clipboardURL, clipboardURL.hasPrefix("http"), matches(clipboardURL) {
            suggestions.append(
                SearchSuggestion(
                    kind: .clipboardLink,
                    title: "Open copied link",
                    subtitle: clipboardURL,
                    value: clipboardURL,
                    systemImage: "doc.on.clipboard"
                )
            )
        }

        suggestions += recentLinks.filter(matches).map {
            SearchSuggestion(
                kind: .recentLink,
                title: displayHost(for: $0),
                subtitle: $0,
                value: $0,
                systemImage: "clock.arrow.circlepath"
            )
        }

        suggestions += recentSearches.filter(matches).map {
            SearchSuggestion(
                kind: .recentSearch,
                title: $0,
                subtitle: "Recent search",
                value: $0,
                systemImage: "magnifyingglass"
            )
        }

        suggestions += commonSites.filter(matches).map {
            let supportTier = supportTierForPromotedSuggestion($0)
            return SearchSuggestion(
                kind: .commonSite,
                title: $0,
                subtitle: supportTier == .enabledPublic ? "Supported reader source" : "Open site",
                value: $0,
                systemImage: supportTier == .enabledPublic ? "book.pages" : "globe",
                sourceSupportTier: supportTier
            )
        }

        if !trimmed.isEmpty {
            suggestions.append(
                SearchSuggestion(
                    kind: .searchAction,
                    title: "Search for \"\(trimmed)\"",
                    subtitle: "Search the web in ToonEdge",
                    value: trimmed,
                    systemImage: "arrow.right.circle"
                )
            )
        }

        return suggestions
    }

    private func displayHost(for value: String) -> String {
        URL(string: value)?.host() ?? value
    }

    private func supportTierForPromotedSuggestion(_ value: String) -> SiteProfileSupportTier? {
        let input = SearchInputClassifier.classify(value)
        guard case .url(let normalizedURL) = input.browserStartPoint,
              let url = URL(string: normalizedURL),
              let profile = siteProfileRegistry.profile(for: url),
              profile.supportTier == .enabledPublic else {
            return nil
        }

        return profile.supportTier
    }
}

public struct SearchHistoryBackedSuggestionProvider: SearchSuggestionProviding {
    private let baseProvider: any SearchSuggestionProviding
    private let history: [SearchHistoryEntry]

    public init(baseProvider: any SearchSuggestionProviding, history: [SearchHistoryEntry]) {
        self.baseProvider = baseProvider
        self.history = history.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    public func suggestions(matching query: String) -> [SearchSuggestion] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func matches(_ value: String) -> Bool {
            normalizedQuery.isEmpty || value.lowercased().contains(normalizedQuery)
        }

        let base = baseProvider.suggestions(matching: query)
        let nonHistoryBase = base.filter { $0.kind != .recentLink && $0.kind != .recentSearch }
        let baseHistory = base.filter { $0.kind == .recentLink || $0.kind == .recentSearch }

        let persistedSearches = history
            .filter { $0.kind == .searchQuery && matches($0.value) }
            .map {
                SearchSuggestion(
                    kind: .recentSearch,
                    title: $0.displayTitle,
                    subtitle: "Recent search",
                    value: $0.value,
                    systemImage: "magnifyingglass"
                )
            }
        let persistedLinks = history
            .filter { $0.kind == .link && matches($0.value) }
            .map {
                SearchSuggestion(
                    kind: .recentLink,
                    title: URL(string: $0.value)?.host() ?? $0.displayTitle,
                    subtitle: $0.value,
                    value: $0.value,
                    systemImage: "clock.arrow.circlepath"
                )
            }

        let clipboard = nonHistoryBase.filter { $0.kind == .clipboardLink }
        let others = nonHistoryBase.filter { $0.kind != .clipboardLink }
        return clipboard + persistedLinks + persistedSearches + baseHistory + others
    }
}

public struct MockDownloadService: DownloadProviding {
    public init() {}

    public func downloadSummary() async -> DownloadSummary {
        DownloadSummary(cachedItemCount: 0, storageDescription: "No cached chapters yet")
    }
}

public actor MockCacheMetadataService: CacheMetadataManaging {
    private var entriesBySourceURL: [URL: CacheMetadataEntry]

    public init(entries: [CacheMetadataEntry] = []) {
        self.entriesBySourceURL = Dictionary(uniqueKeysWithValues: entries.map { ($0.sourceURL, $0) })
    }

    public func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        let result = cacheActionResult(previous: entriesBySourceURL[input.sourceURL]?.retentionState, next: input.retentionState)
        entriesBySourceURL[input.sourceURL] = CacheMetadataEntry(
            sourceURL: input.sourceURL,
            seriesTitle: input.seriesTitle,
            chapterTitle: input.chapterTitle,
            chapterLabel: input.chapterLabel,
            imageCount: input.imageCount,
            estimatedStorageBytes: input.estimatedStorageBytes,
            retentionState: input.retentionState,
            cachedAt: input.cachedAt
        )
        return result
    }

    public func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        entriesBySourceURL.removeValue(forKey: sourceURL) == nil ? .notFound : .removed
    }

    public func updateCacheRetention(for sourceURL: URL, retentionState: CacheRetentionState, cachedAt: Date) async throws -> CacheActionResult {
        let result = cacheActionResult(previous: entriesBySourceURL[sourceURL]?.retentionState, next: retentionState)
        if let existing = entriesBySourceURL[sourceURL] {
            entriesBySourceURL[sourceURL] = CacheMetadataEntry(
                id: existing.id,
                sourceURL: existing.sourceURL,
                seriesTitle: existing.seriesTitle,
                chapterTitle: existing.chapterTitle,
                chapterLabel: existing.chapterLabel,
                imageCount: existing.imageCount,
                estimatedStorageBytes: existing.estimatedStorageBytes,
                retentionState: retentionState,
                cachedAt: cachedAt
            )
        } else {
            entriesBySourceURL[sourceURL] = CacheMetadataEntry(
                sourceURL: sourceURL,
                seriesTitle: "Unknown Series",
                chapterTitle: "Unknown Chapter",
                chapterLabel: nil,
                imageCount: 0,
                estimatedStorageBytes: 0,
                retentionState: retentionState,
                cachedAt: cachedAt
            )
        }
        return result
    }

    public func cacheMetadataEntries() async -> [CacheMetadataEntry] {
        entriesBySourceURL.values.sorted { lhs, rhs in
            lhs.cachedAt > rhs.cachedAt
        }
    }

    public func downloadSummary() async -> DownloadSummary {
        let entries = await cacheMetadataEntries()
        let recentCount = entries.filter { $0.retentionState == .recent }.count
        let retainedCount = entries.filter { $0.retentionState == .retained }.count
        let bytes = entries.map(\.estimatedStorageBytes).reduce(0, +)
        return DownloadSummary(
            cachedItemCount: entries.count,
            storageDescription: entries.isEmpty ? "No cached chapters yet" : DownloadSummary.storageDescription(for: bytes),
            recentItemCount: recentCount,
            retainedItemCount: retainedCount,
            totalEstimatedBytes: bytes
        )
    }

    private func cacheActionResult(
        previous: CacheRetentionState?,
        next: CacheRetentionState
    ) -> CacheActionResult {
        if previous == next {
            return .unchanged
        }

        switch next {
        case .recent:
            return .recent
        case .retained:
            return .retained
        }
    }
}

public struct MockLibraryUpdateRefreshService: LibraryUpdateRefreshing {
    private let result: LibraryUpdateRefreshResult

    public init(
        result: LibraryUpdateRefreshResult = LibraryUpdateRefreshResult(
            checkedCount: 0,
            updatedCount: 0,
            failedCount: 0
        )
    ) {
        self.result = result
    }

    public func refreshUpdates() async -> LibraryUpdateRefreshResult {
        result
    }
}

public struct MockSeriesLatestChapterFetcher: SeriesLatestChapterFetching {
    private let snapshotsBySeriesID: [UUID: SeriesLatestChapterSnapshot]

    public init(snapshotsBySeriesID: [UUID: SeriesLatestChapterSnapshot] = [:]) {
        self.snapshotsBySeriesID = snapshotsBySeriesID
    }

    public func latestChapterSnapshot(for series: LibrarySeriesSummary) async throws -> SeriesLatestChapterSnapshot? {
        snapshotsBySeriesID[series.id]
    }
}

public struct MockSettingsService: SettingsProviding {
    public init() {}

    public func currentSettings() -> ReaderSettings {
        .default
    }
}

public actor MockBrowserService: BrowserCoordinating {
    public private(set) var lastPreparedStartPoint: BrowserStartPoint?

    public init() {}

    public func prepare(_ startPoint: BrowserStartPoint) {
        lastPreparedStartPoint = startPoint
    }
}

public struct MockReaderService: ReaderSessionProviding {
    public init() {}

    public func mockSession(for chapter: MockChapter) async throws -> MockReaderSession {
        let chapterNumber = chapter.title
            .split(separator: " ")
            .last
            .flatMap { Int($0) }

        let previousChapter = chapterNumber.map { number in
            MockChapter(
                title: "Chapter \(max(1, number - 1))",
                sourceURL: URL(string: "https://example.com/series/chapter-\(max(1, number - 1))")!
            )
        }

        let nextChapter = chapterNumber.map { number in
            MockChapter(
                title: "Chapter \(number + 1)",
                sourceURL: URL(string: "https://example.com/series/chapter-\(number + 1)")!
            )
        }

        return MockReaderSession(
            seriesTitle: "Moonlit Edge",
            chapterTitle: chapter.title,
            sourceURL: chapter.sourceURL,
            imageURLs: MockReaderSession.sample.imageURLs.enumerated().map { index, _ in
                URL(string: "https://picsum.photos/seed/toonedge-\(chapter.title.replacingOccurrences(of: " ", with: "-"))-\(index + 1)/900/\(1200 + (index * 80))")!
            },
            previousChapter: previousChapter,
            nextChapter: nextChapter
        )
    }
}

public actor MockReaderProgressRepository: ReaderProgressStoring {
    private var storedProgress: [URL: ReaderProgress]

    public init(storedProgress: [URL: ReaderProgress] = [:]) {
        self.storedProgress = storedProgress
    }

    public func progress(for sourceURL: URL) -> ReaderProgress? {
        storedProgress[sourceURL]
    }

    public func save(_ progress: ReaderProgress, for sourceURL: URL) {
        storedProgress[sourceURL] = progress
    }
}
