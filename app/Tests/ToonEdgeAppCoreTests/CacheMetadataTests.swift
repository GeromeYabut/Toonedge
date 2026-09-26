import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

@Test func populatedDownloadsUseScrollableContentAndAccessibleActions() {
    let layout = DownloadsContentLayout(entryCount: 20)

    #expect(layout.usesScrollableContent)
    #expect(layout.minimumActionSize >= 44)
    #expect(layout.removalLabel(chapterTitle: "Chapter 20", seriesTitle: "Sample") == "Remove Sample, Chapter 20 from cache")
}

@MainActor
@Test func recordingRecentCacheMetadataIncrementsDownloadSummaryCount() async throws {
    let repository = try makeRepository()

    _ = try await repository.recordCacheMetadata(.fixture(retentionState: .recent))

    let summary = await repository.downloadSummary()

    #expect(summary.cachedItemCount == 1)
    #expect(summary.recentItemCount == 1)
    #expect(summary.retainedItemCount == 0)
}

@MainActor
@Test func retainedCacheMetadataIsRepresentedSeparatelyFromRecentCache() async throws {
    let repository = try makeRepository()

    _ = try await repository.recordCacheMetadata(.fixture(sourceURL: URL(string: "https://example.com/chapter-1")!, retentionState: .recent))
    _ = try await repository.recordCacheMetadata(.fixture(sourceURL: URL(string: "https://example.com/chapter-2")!, retentionState: .retained))

    let summary = await repository.downloadSummary()

    #expect(summary.cachedItemCount == 2)
    #expect(summary.recentItemCount == 1)
    #expect(summary.retainedItemCount == 1)
}

@MainActor
@Test func removingCacheMetadataRemovesItFromDownloadSummary() async throws {
    let repository = try makeRepository()
    let sourceURL = URL(string: "https://example.com/remove/chapter-1")!

    _ = try await repository.recordCacheMetadata(.fixture(sourceURL: sourceURL, retentionState: .retained))
    _ = try await repository.removeCacheMetadata(for: sourceURL)

    let summary = await repository.downloadSummary()

    #expect(summary.cachedItemCount == 0)
    #expect(summary.retainedItemCount == 0)
}

@MainActor
@Test func downloadSummaryStorageDescriptionIsStableAndHumanReadable() async throws {
    let repository = try makeRepository()

    _ = try await repository.recordCacheMetadata(
        .fixture(estimatedStorageBytes: 1_572_864, retentionState: .retained)
    )

    let summary = await repository.downloadSummary()

    #expect(summary.storageDescription == "1.5 MB estimated")
}

@MainActor
@Test func updatingCacheRetentionMarksChapterRetainedAndCountsOfflineEntry() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "9F9AC3B0-821F-4ED8-AD3A-68DD1C535370")!
    let chapterID = UUID(uuidString: "A9690992-82C9-4FC2-9866-B722DAA6FD10")!
    let sourceURL = URL(string: "https://example.com/retain/chapter-7")!
    let retainedAt = Date(timeIntervalSince1970: 1_700_004_000)

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "Retain Fixture",
            canonicalURL: URL(string: "https://example.com/retain")!,
            sourceDomain: "example.com",
            coverImageURL: nil,
            status: "Ongoing",
            synopsis: "Retain test.",
            latestKnownChapterLabel: "7",
            libraryState: .reading,
            chapters: [
                LibraryChapterInput(
                    id: chapterID,
                    title: "Chapter 7",
                    chapterLabel: "7",
                    chapterNumber: 7,
                    sourceURL: sourceURL,
                    imageURLs: [
                        URL(string: "https://example.com/image-1.jpg")!,
                        URL(string: "https://example.com/image-2.jpg")!
                    ],
                    publishedAt: nil
                )
            ]
        ),
        context: .seriesDetail
    )
    _ = try await repository.updateCacheRetention(for: sourceURL, retentionState: .retained, cachedAt: retainedAt)

    let summary = await repository.downloadSummary()
    let entry = try #require(await repository.cacheMetadataEntries().first)
    let chapter = try #require(await repository.seriesDetail(for: seriesID)?.chapters.first)

    #expect(entry.retentionState == .retained)
    #expect(entry.imageCount == 2)
    #expect(summary.retainedItemCount == 1)
    #expect(summary.cachedItemCount == 1)
    #expect(chapter.isDownloaded)
}

@MainActor
@Test func persistentCacheActionsReturnTypedResults() async throws {
    let repository = try makeRepository()
    let sourceURL = URL(string: "https://example.com/results/chapter-1")!

    let retained = try await repository.recordCacheMetadata(.fixture(sourceURL: sourceURL, retentionState: .retained))
    let unchanged = try await repository.recordCacheMetadata(.fixture(sourceURL: sourceURL, retentionState: .retained))
    let removed = try await repository.removeCacheMetadata(for: sourceURL)
    let missing = try await repository.removeCacheMetadata(for: sourceURL)

    #expect(retained == .retained)
    #expect(unchanged == .unchanged)
    #expect(removed == .removed)
    #expect(missing == .notFound)
}

@Test func mockCacheActionsReturnTypedResultsConsistently() async throws {
    let service = MockCacheMetadataService()
    let sourceURL = URL(string: "https://example.com/results/chapter-1")!

    let retained = try await service.recordCacheMetadata(.fixture(sourceURL: sourceURL, retentionState: .retained))
    let unchanged = try await service.updateCacheRetention(
        for: sourceURL,
        retentionState: .retained,
        cachedAt: Date(timeIntervalSince1970: 1_700_004_100)
    )
    let removed = try await service.removeCacheMetadata(for: sourceURL)
    let missing = try await service.removeCacheMetadata(for: sourceURL)

    #expect(retained == .retained)
    #expect(unchanged == .unchanged)
    #expect(removed == .removed)
    #expect(missing == .notFound)
}

@MainActor
@Test func downloadsViewModelRemoveActionRefreshesSummaryAfterSuccess() async throws {
    let sourceURL = URL(string: "https://example.com/downloads/chapter-1")!
    let service = MockCacheMetadataService()
    _ = try await service.recordCacheMetadata(.fixture(sourceURL: sourceURL, retentionState: .retained))
    let viewModel = DownloadsViewModel(cacheMetadataManager: service)

    await viewModel.load()
    await viewModel.remove(sourceURL: sourceURL)

    #expect(viewModel.summary.cachedItemCount == 0)
    #expect(viewModel.cacheFeedback?.result == .removed)
}

@MainActor
@Test func downloadsViewModelRemoveFailureProducesRetryableFeedback() async {
    let viewModel = DownloadsViewModel(cacheMetadataManager: FailingCacheMetadataService())

    await viewModel.remove(sourceURL: URL(string: "https://example.com/failure/chapter-1")!)

    #expect(viewModel.cacheFeedback?.isFailure == true)
}

@MainActor
@Test func largeCacheSummaryAggregatesCountsAndStorageInOnePass() async throws {
    let repository = try makeRepository()

    for index in 0..<1_000 {
        _ = try await repository.recordCacheMetadata(
            .fixture(
                sourceURL: URL(string: "https://example.com/large/chapter-\(index)")!,
                estimatedStorageBytes: 1_024,
                retentionState: index.isMultiple(of: 2) ? .recent : .retained
            )
        )
    }

    let summary = await repository.downloadSummary()

    #expect(summary.cachedItemCount == 1_000)
    #expect(summary.recentItemCount == 500)
    #expect(summary.retainedItemCount == 500)
    #expect(summary.totalEstimatedBytes == 1_024_000)
    #expect(summary.storageDescription == "1000 KB estimated")
}

@MainActor
private func makeRepository() throws -> SwiftDataLibraryRepository {
    let schema = Schema([
        StoredSeries.self,
        StoredChapter.self,
        StoredProgress.self,
        StoredSearchHistory.self,
        StoredCacheEntry.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    return SwiftDataLibraryRepository(
        modelContext: container.mainContext,
        modelContainer: container,
        usesModelContextIO: false
    )
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

private extension CacheMetadataInput {
    static func fixture(
        sourceURL: URL = URL(string: "https://example.com/series/chapter-1")!,
        estimatedStorageBytes: Int64 = 524_288,
        retentionState: CacheRetentionState
    ) -> CacheMetadataInput {
        CacheMetadataInput(
            sourceURL: sourceURL,
            seriesTitle: "Cache Fixture",
            chapterTitle: "Chapter 1",
            chapterLabel: "1",
            imageCount: 5,
            estimatedStorageBytes: estimatedStorageBytes,
            retentionState: retentionState,
            cachedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
