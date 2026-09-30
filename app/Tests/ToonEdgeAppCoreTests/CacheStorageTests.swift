import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func persistentDownloadsRemovalDeletesChapterFilesAndRecalculatesStorage() async throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)
    let cache = try #require(dependencies.chapterAssetCache)
    let sourceURL = URL(string: "https://fixture.example/cache-removal/\(UUID().uuidString)")!
    let assetURL = URL(string: "https://fixture.example/panel.png")!
    let directory = cache.chapterDirectory(for: sourceURL)
    defer { try? FileManager.default.removeItem(at: directory) }
    try cache.store(Data([1, 2, 3, 4]), for: assetURL, sourceURL: sourceURL)
    _ = try await dependencies.cacheMetadataService.recordCacheMetadata(CacheMetadataInput(
        sourceURL: sourceURL, seriesTitle: "Removal Fixture", chapterTitle: "Chapter 1",
        chapterLabel: "1", imageCount: 1, estimatedStorageBytes: 99_999,
        retentionState: .retained, cachedAt: Date()
    ))
    let model = DownloadsViewModel(
        cacheMetadataManager: dependencies.cacheMetadataService,
        storageMeasurementService: dependencies.cacheStorageMeasurementService
    )
    await model.load()
    #expect(model.summary.cachedItemCount == 1)
    #expect(model.summary.totalMeasuredBytes == 4)

    await model.remove(sourceURL: sourceURL)

    #expect(!FileManager.default.fileExists(atPath: directory.path))
    #expect(await dependencies.cacheMetadataService.cacheMetadataEntries().isEmpty)
    #expect(model.entries.isEmpty)
    #expect(model.summary.cachedItemCount == 0)
    #expect(model.summary.totalMeasuredBytes == 0)
    #expect(model.summary.storageDescription == "No local storage tracked")
}

@Test func downloadsDoNotShowEmptyBeforeLoadCompletes() {
    #expect(DownloadsContentPhase(hasLoaded: false, entryCount: 0) == .loading)
    #expect(DownloadsContentPhase(hasLoaded: true, entryCount: 0) == .empty)
    #expect(DownloadsContentPhase(hasLoaded: true, entryCount: 1) == .content)
}

@MainActor
@Test func cacheFileRemovalFailureKeepsMetadataVisibleAndRetryable() async throws {
    let sourceURL = URL(string: "https://fixture.example/chapter-1")!
    let metadata = MockCacheMetadataService(entries: [cacheEntry(sourceURL: sourceURL, estimatedStorageBytes: 4)])
    let service = CacheLifecycleService(metadata: metadata, assets: FailingAssetRemoval())
    let model = DownloadsViewModel(cacheMetadataManager: service)
    await model.load()

    await model.remove(sourceURL: sourceURL)

    #expect(await metadata.cacheMetadataEntries().count == 1)
    #expect(model.entries.count == 1)
    #expect(model.failedRemovalURL == sourceURL)
    #expect(model.cacheFeedback == .failure("Could not remove cached chapter."))
}

@Test func cacheMetadataRemovalFailureCanRetryAfterFilesHaveBeenDeleted() async throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://fixture.example/chapter-1")!
    let assetURL = URL(string: "https://fixture.example/panel.png")!
    try cache.store(Data([1, 2, 3, 4]), for: assetURL, sourceURL: sourceURL)
    let metadata = FailingOnceRemovalMetadata(entry: cacheEntry(sourceURL: sourceURL, estimatedStorageBytes: 4))
    let service = CacheLifecycleService(metadata: metadata, assets: cache)

    await #expect(throws: URLError.self) { try await service.removeCacheMetadata(for: sourceURL) }
    #expect(!FileManager.default.fileExists(atPath: cache.chapterDirectory(for: sourceURL).path))
    #expect(await service.cacheMetadataEntries().count == 1)

    #expect(try await service.removeCacheMetadata(for: sourceURL) == .removed)
    #expect(await service.cacheMetadataEntries().isEmpty)
    #expect(try await service.removeCacheMetadata(for: sourceURL) == .notFound)
}

@Test func chapterRemovalPreservesOtherChapterDirectories() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let removed = URL(string: "https://fixture.example/chapter-1")!
    let preserved = URL(string: "https://fixture.example/chapter-2")!
    let assetURL = URL(string: "https://fixture.example/panel.png")!
    try cache.store(Data([1]), for: assetURL, sourceURL: removed)
    try cache.store(Data([2]), for: assetURL, sourceURL: preserved)

    try cache.removeAssets(for: removed)

    #expect(cache.cachedAssetURL(for: assetURL, sourceURL: removed) == nil)
    let preservedURL = try #require(cache.cachedAssetURL(for: assetURL, sourceURL: preserved))
    #expect(try Data(contentsOf: preservedURL) == Data([2]))
}

private struct FailingAssetRemoval: ChapterAssetRemoving {
    func removeAssets(for sourceURL: URL) throws { throw URLError(.cannotRemoveFile) }
}

private actor FailingOnceRemovalMetadata: CacheMetadataManaging {
    private let metadata: MockCacheMetadataService
    private var shouldFail = true

    init(entry: CacheMetadataEntry) { metadata = MockCacheMetadataService(entries: [entry]) }

    func removeCacheMetadata(for sourceURL: URL) async throws -> CacheActionResult {
        if shouldFail {
            shouldFail = false
            throw URLError(.cannotWriteToFile)
        }
        return try await metadata.removeCacheMetadata(for: sourceURL)
    }

    func recordCacheMetadata(_ input: CacheMetadataInput) async throws -> CacheActionResult {
        try await metadata.recordCacheMetadata(input)
    }

    func updateCacheRetention(for sourceURL: URL, retentionState: CacheRetentionState, cachedAt: Date) async throws -> CacheActionResult {
        try await metadata.updateCacheRetention(for: sourceURL, retentionState: retentionState, cachedAt: cachedAt)
    }

    func cacheMetadataEntries() async -> [CacheMetadataEntry] { await metadata.cacheMetadataEntries() }
    func downloadSummary() async -> DownloadSummary { await metadata.downloadSummary() }
}

@Test func fileBackedCacheMapsSourceURLToDeterministicChapterDirectory() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter-12?utm=reader")!

    let first = cache.chapterDirectory(for: sourceURL)
    let second = cache.chapterDirectory(for: sourceURL)

    #expect(first == second)
    #expect(first.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path)
}

@Test func fileBackedCacheSanitizesInvalidURLCharacters() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter:12?read=true&name=a/b")!

    let directoryName = cache.chapterDirectory(for: sourceURL).lastPathComponent

    #expect(!directoryName.contains(":"))
    #expect(!directoryName.contains("?"))
    #expect(!directoryName.contains("/"))
    #expect(!directoryName.contains("&"))
}

@Test func fileBackedCacheMissingFileReturnsCacheMiss() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter-12")!
    let assetURL = URL(string: "https://cdn.example.com/page-1.jpg")!

    let cached = cache.cachedAssetURL(for: assetURL, sourceURL: sourceURL)

    #expect(cached == nil)
}

@Test func fileBackedCacheStoresChapterAssetAtomically() throws {
    let cache = try FileBackedChapterAssetCache(rootDirectory: temporaryDirectory())
    let sourceURL = URL(string: "https://fixture.example/chapter-1")!
    let assetURL = URL(string: "https://images.example.test/chapter-1/001.png")!
    let data = Data([1, 2, 3, 4])

    try cache.store(data, for: assetURL, sourceURL: sourceURL)

    let storedURL = try #require(cache.cachedAssetURL(for: assetURL, sourceURL: sourceURL))
    #expect(try Data(contentsOf: storedURL) == data)
}

@Test func fileBackedCacheCanInitializeInTemporaryDirectory() throws {
    let root = try temporaryDirectory().appendingPathComponent("ToonEdgeCache")

    _ = try FileBackedChapterAssetCache(rootDirectory: root)

    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory)
    #expect(exists)
    #expect(isDirectory.boolValue)
}

@Test func storageMeasurementPrefersMeasuredBytesWhenFilesExist() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter-12")!
    let assetURL = URL(string: "https://cdn.example.com/page-1.jpg")!
    let fileURL = cache.intendedAssetURL(for: assetURL, sourceURL: sourceURL)
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data([1, 2, 3, 4]).write(to: fileURL)
    let service = CacheStorageMeasurementService(assetCache: cache)

    let summary = service.summary(for: [
        cacheEntry(sourceURL: sourceURL, estimatedStorageBytes: 99_999)
    ])

    #expect(summary.totalMeasuredBytes == 4)
    #expect(summary.storageDescription == "4 B measured")
}

@Test func storageMeasurementFallsBackToEstimatedBytesWhenFilesAreMissing() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter-12")!
    let service = CacheStorageMeasurementService(assetCache: cache)

    let summary = service.summary(for: [
        cacheEntry(sourceURL: sourceURL, estimatedStorageBytes: 1_024)
    ])

    #expect(summary.totalMeasuredBytes == 0)
    #expect(summary.totalEstimatedBytes == 1_024)
    #expect(summary.storageDescription == "1 KB estimated")
}

@Test func removingCachedFilesUpdatesMeasuredSummary() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter-12")!
    let assetURL = URL(string: "https://cdn.example.com/page-1.jpg")!
    let fileURL = cache.intendedAssetURL(for: assetURL, sourceURL: sourceURL)
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data([1, 2, 3, 4]).write(to: fileURL)
    let service = CacheStorageMeasurementService(assetCache: cache)
    let entries = [cacheEntry(sourceURL: sourceURL, estimatedStorageBytes: 1_024)]

    try FileManager.default.removeItem(at: fileURL)
    let summary = service.summary(for: entries)

    #expect(summary.totalMeasuredBytes == 0)
    #expect(summary.storageDescription == "1 KB estimated")
}

@Test func storageMeasurementIgnoresFilesOutsideCacheNamespace() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let unrelated = root.appendingPathComponent("unrelated.bin")
    try Data(repeating: 1, count: 2_048).write(to: unrelated)
    let service = CacheStorageMeasurementService(assetCache: cache)

    let summary = service.summary(for: [])

    #expect(summary.cachedItemCount == 0)
    #expect(summary.totalMeasuredBytes == 0)
    #expect(summary.storageDescription == "No local storage tracked")
}

@Test func cacheRemoveFailureDiagnosticUsesSanitizedSourceIdentity() {
    let sourceURL = URL(string: "https://example.com/private/chapter-1?token=secret")!

    let event = UpdateCacheDiagnosticsLogger.cacheRemoveFailureEvent(sourceURL: sourceURL)

    #expect(event == .cacheRemoveFailed(
        sourceIdentity: UpdateCacheDiagnosticsLogger.sanitizedSourceIdentity(for: sourceURL),
        operation: "remove"
    ))
    #expect(!String(describing: event).contains("token=secret"))
    #expect(!String(describing: event).contains("chapter-1"))
}

@Test func metadataWithMissingBackingFileIsSurfacedAsMissing() throws {
    let root = try temporaryDirectory()
    let cache = try FileBackedChapterAssetCache(rootDirectory: root)
    let sourceURL = URL(string: "https://example.com/series/chapter-12")!
    let service = CacheStorageMeasurementService(assetCache: cache)

    let state = service.storageState(for: cacheEntry(sourceURL: sourceURL, estimatedStorageBytes: 1_024))

    #expect(state == .metadataOnlyMissingFiles)
}

private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ToonEdgeCacheStorageTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func cacheEntry(
    sourceURL: URL,
    estimatedStorageBytes: Int64
) -> CacheMetadataEntry {
    CacheMetadataEntry(
        sourceURL: sourceURL,
        seriesTitle: "Measured Fixture",
        chapterTitle: "Chapter 12",
        chapterLabel: "12",
        imageCount: 1,
        estimatedStorageBytes: estimatedStorageBytes,
        retentionState: .retained,
        cachedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
