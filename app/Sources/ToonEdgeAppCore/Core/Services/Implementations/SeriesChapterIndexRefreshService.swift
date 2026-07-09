import Foundation

public struct SeriesChapterIndexRefreshService: SeriesChapterIndexRefreshing {
    private let library: any LibraryLifecycleManaging
    private let indexLibrary: any LibraryChapterIndexManaging
    private let fetcher: any SeriesChapterIndexFetching

    public init(
        library: any LibraryLifecycleManaging,
        indexLibrary: any LibraryChapterIndexManaging,
        fetcher: any SeriesChapterIndexFetching
    ) {
        self.library = library
        self.indexLibrary = indexLibrary
        self.fetcher = fetcher
    }

    public func refreshChapterIndex(for seriesID: UUID) async -> ChapterIndexRefreshOutcome? {
        let snapshot = await library.librarySnapshot()
        guard let series = snapshot.series.first(where: { $0.id == seriesID }) else {
            return nil
        }

        return await refreshChapterIndex(for: series)
    }

    public func refreshChapterIndex(for series: LibrarySeriesSummary) async -> ChapterIndexRefreshOutcome {
        do {
            guard let snapshot = try await fetcher.chapterIndexSnapshot(for: series) else {
                return ChapterIndexRefreshOutcome(
                    seriesID: series.id,
                    indexedChapterCount: 0,
                    latestChapterLabel: series.latestChapterLabel,
                    hasUnreadUpdates: false,
                    didRefresh: false
                )
            }

            try await indexLibrary.recordAvailableChapters(
                snapshot.entries,
                for: series.id,
                indexedAt: snapshot.checkedAt
            )

            let latestChapterLabel = snapshot.latestChapterLabel ?? series.latestChapterLabel
            let comparison = ChapterUpdateComparison.compare(
                storedLatest: series.latestChapterLabel,
                fetchedLatest: snapshot.latestChapterLabel
            )
            let hasUnreadUpdates = comparison != .same

            try await library.recordUpdateCheckResult(
                seriesID: series.id,
                latestChapterLabel: latestChapterLabel,
                hasUnreadUpdates: hasUnreadUpdates,
                checkedAt: snapshot.checkedAt
            )

            return ChapterIndexRefreshOutcome(
                seriesID: series.id,
                checkedAt: snapshot.checkedAt,
                indexedChapterCount: snapshot.entries.count,
                latestChapterLabel: latestChapterLabel,
                hasUnreadUpdates: hasUnreadUpdates,
                didRefresh: true
            )
        } catch {
            return ChapterIndexRefreshOutcome(
                seriesID: series.id,
                indexedChapterCount: 0,
                latestChapterLabel: series.latestChapterLabel,
                hasUnreadUpdates: false,
                didRefresh: false
            )
        }
    }
}
