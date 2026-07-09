import Foundation

public struct LibraryUpdateRefreshService: LibraryUpdateRefreshing {
    private let library: any LibraryLifecycleManaging
    private let updateChecker: any SeriesUpdateChecking
    private let chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    private let diagnosticsLogger: (any UpdateCacheDiagnosticsLogging)?

    public init(
        library: any LibraryLifecycleManaging,
        updateChecker: any SeriesUpdateChecking,
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)? = nil,
        diagnosticsLogger: (any UpdateCacheDiagnosticsLogging)? = nil
    ) {
        self.library = library
        self.updateChecker = updateChecker
        self.chapterIndexRefreshService = chapterIndexRefreshService
        self.diagnosticsLogger = diagnosticsLogger
    }

    public func refreshUpdates() async -> LibraryUpdateRefreshResult {
        let snapshot = await library.librarySnapshot()
        var updatedCount = 0
        var failedCount = 0

        for series in snapshot.series {
            do {
                if let chapterIndexRefreshService {
                    let outcome = await chapterIndexRefreshService.refreshChapterIndex(for: series)
                    if outcome.didRefresh {
                        if outcome.hasUnreadUpdates {
                            updatedCount += 1
                        }
                        continue
                    }
                }

                let result = try await updateChecker.checkForUpdates(series: series)
                try await library.recordUpdateCheckResult(
                    seriesID: result.seriesID,
                    latestChapterLabel: result.latestChapterLabel,
                    hasUnreadUpdates: result.hasUnreadUpdates,
                    checkedAt: result.checkedAt
                )
                if result.hasUnreadUpdates {
                    updatedCount += 1
                }
            } catch {
                failedCount += 1
            }
        }

        let result = LibraryUpdateRefreshResult(
            checkedCount: snapshot.series.count,
            updatedCount: updatedCount,
            failedCount: failedCount
        )
        await diagnosticsLogger?.log(
            .updateRefreshCompleted(
                checkedCount: result.checkedCount,
                updatedCount: result.updatedCount,
                failedCount: result.failedCount
            )
        )
        return result
    }
}
