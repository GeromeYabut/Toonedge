import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

@Suite @MainActor
struct SearchHistoryManagementTests {
    @Test func historyWriteDoesNotCommitPendingLibraryEdit() async throws {
        let schema = Schema(ToonEdgePersistenceModels.all)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let series = StoredSeries(id: UUID(), title: "Saved", canonicalURLString: "https://example.test/series", sourceDomain: "example.test", coverImageURLString: nil, status: "Ongoing", synopsis: "Synopsis", latestKnownChapterLabel: nil, hasUnreadUpdates: false, libraryStateRaw: "reading", isCompleted: false, lastOpenedChapterID: nil, lastReadAt: nil, createdAt: .distantPast, updatedAt: .distantPast)
        context.insert(series)
        try context.save()
        series.title = "Pending Library edit"
        let repository = SwiftDataLibraryRepository(modelContext: context, modelContainer: container)
        try await repository.recordSearchHistory(SearchHistoryInput(kind: .searchQuery, value: "query", displayTitle: "Query"))
        #expect(context.hasChanges)
        #expect(series.title == "Pending Library edit")
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<StoredSeries>()).first?.title == "Saved")
    }

    @Test(arguments: [true, false])
    func recordReadAndRerecordPreservesIdentity(persistent: Bool) async throws {
        let container = try makeContainer()
        let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, usesModelContextIO: persistent)
        try await checkRecording(repository)
    }

    @Test func actorRecordReadAndRerecordPreservesIdentity() async throws {
        try await checkRecording(InMemorySearchHistoryManager())
    }

    @Test(arguments: [true, false])
    func exactIDDeletionAndUnlimitedClear(persistent: Bool) async throws {
        let container = try makeContainer()
        let saves = HistorySaveProbe()
        let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, usesModelContextIO: persistent, historySave: saves.save)
        try await checkRemoval(repository)
        if persistent { #expect(saves.count == 18) }
    }

    @Test func actorExactIDDeletionAndUnlimitedClear() async throws {
        try await checkRemoval(InMemorySearchHistoryManager())
    }

    @Test func unchangedRerecordAndMissingMutationsDoNotSave() async throws {
        let container = try makeContainer()
        let saves = HistorySaveProbe()
        let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, historySave: saves.save)
        try await repository.removeSearchHistory(id: UUID())
        try await repository.clearSearchHistory()
        #expect(saves.count == 0)
        try await repository.recordSearchHistory(input("same"))
        try await repository.recordSearchHistory(input("same"))
        #expect(saves.count == 1)
    }

    @Test(arguments: [true, false])
    func deletionDistinguishesLinksWithSharedDestination(persistent: Bool) async throws {
        let container = try makeContainer()
        let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, usesModelContextIO: persistent)
        let values = ["example.test", "https://example.test"]
        for value in values {
            try await repository.recordSearchHistory(SearchHistoryInput(kind: .link, value: value, displayTitle: "Example", createdAt: .distantPast))
        }
        #expect(SearchInputClassifier.classify(values[0]).normalizedValue == SearchInputClassifier.classify(values[1]).normalizedValue)
        let entries = try await repository.recentSearchHistory(limit: 10)
        #expect(entries.count == 2)
        try await repository.removeSearchHistory(id: entries[0].id)
        #expect(try await repository.recentSearchHistory(limit: 10) == [entries[1]])
    }

    @Test func actorSeededHistoryOrdersTiesByUUID() async throws {
        let entries = tiedEntries()
        let manager = InMemorySearchHistoryManager(entries: entries.reversed())
        #expect(try await manager.recentSearchHistory(limit: 2) == entries)
        #expect(try await manager.recentSearchHistory(limit: 0).isEmpty)
        #expect(try await manager.recentSearchHistory(limit: -1).isEmpty)
    }

    @Test func persistentHistoryOrdersTiesByUUID() async throws {
        let container = try makeContainer()
        for entry in tiedEntries().reversed() {
            container.mainContext.insert(StoredSearchHistory(id: entry.id, kindRaw: entry.kind.rawValue, value: entry.value, displayTitle: entry.displayTitle, createdAt: entry.lastUsedAt, lastUsedAt: entry.lastUsedAt))
        }
        try container.mainContext.save()
        let repository = SwiftDataLibraryRepository(modelContext: container.mainContext)
        #expect(try await repository.recentSearchHistory(limit: 2) == tiedEntries())
    }

    @Test func diskReopenRetainsDeletionAndClear() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("toonedge-history-\(UUID()).store")
        let first = try makeContainer(url: url)
        let repository = SwiftDataLibraryRepository(modelContext: first.mainContext)
        for number in 0..<16 { try await repository.recordSearchHistory(input("query \(number)")) }
        let entries = try await repository.recentSearchHistory(limit: 100)
        try await repository.removeSearchHistory(id: entries[0].id)
        let second = try makeContainer(url: url)
        let reopened = SwiftDataLibraryRepository(modelContext: second.mainContext)
        #expect(try await reopened.recentSearchHistory(limit: 100).count == 15)
        #expect(try await reopened.recentSearchHistory(limit: 100).contains { $0.id == entries[0].id } == false)
        try await reopened.clearSearchHistory()
        let third = try makeContainer(url: url)
        #expect(try await SwiftDataLibraryRepository(modelContext: third.mainContext).recentSearchHistory(limit: 100).isEmpty)
    }

    @Test(arguments: ["delete", "clear", "insert", "update"])
    func failedSaveRollsBackHistoryAndRetrySucceeds(operation: String) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("toonedge-history-failure-\(UUID()).store")
        let container = try makeContainer(url: url)
        let context = container.mainContext
        context.autosaveEnabled = false
        try seedProtectedRecords(context)
        let beforeProtected = try protectedSnapshot(ModelContext(container))
        let saves = HistorySaveProbe()
        let repository = SwiftDataLibraryRepository(modelContext: context, historySave: saves.save)
        try await repository.recordSearchHistory(input("retained"))
        try await repository.recordSearchHistory(input("other"))
        let before = try await repository.recentSearchHistory(limit: 100)
        let retained = try #require(before.first { $0.value == "retained" })
        let series = try #require(context.fetch(FetchDescriptor<StoredSeries>()).first)
        series.title = "Pending Library edit"
        saves.shouldFail = true
        await #expect(throws: HistorySaveFailure.self) { try await mutate(repository, operation: operation, id: retained.id) }
        #expect(try await repository.recentSearchHistory(limit: 100) == before)
        let fresh = SwiftDataLibraryRepository(modelContext: ModelContext(container))
        #expect(try await fresh.recentSearchHistory(limit: 100) == before)
        let reopened = try makeContainer(url: url)
        #expect(try await SwiftDataLibraryRepository(modelContext: reopened.mainContext).recentSearchHistory(limit: 100) == before)
        #expect(try protectedSnapshot(ModelContext(container)) == beforeProtected)
        #expect(try protectedSnapshot(ModelContext(reopened)) == beforeProtected)
        #expect(context.hasChanges)
        #expect(series.title == "Pending Library edit")
        saves.shouldFail = false
        try await mutate(repository, operation: operation, id: retained.id)
        #expect(try await repository.recentSearchHistory(limit: 100) != before)
        #expect(try protectedSnapshot(ModelContext(container)) == beforeProtected)
        #expect(context.hasChanges)
        #expect(series.title == "Pending Library edit")
    }

    @Test func clearAndDeletePreserveAllProtectedFields() async throws {
        let container = try makeContainer()
        try seedProtectedRecords(container.mainContext)
        let before = try protectedSnapshot(ModelContext(container))
        let repository = SwiftDataLibraryRepository(modelContext: container.mainContext)
        try await repository.recordSearchHistory(input("one"))
        try await repository.recordSearchHistory(input("two"))
        let entries = try await repository.recentSearchHistory(limit: 100)
        try await repository.removeSearchHistory(id: entries[0].id)
        #expect(try protectedSnapshot(ModelContext(container)) == before)
        try await repository.clearSearchHistory()
        #expect(try protectedSnapshot(ModelContext(container)) == before)
    }

    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(ToonEdgePersistenceModels.all)
        let configuration: ModelConfiguration
        if let url { configuration = ModelConfiguration(schema: schema, url: url) }
        else { configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true) }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func input(_ value: String, date: Date = Date(timeIntervalSince1970: 100)) -> SearchHistoryInput {
        SearchHistoryInput(kind: .searchQuery, value: value, displayTitle: "Same display title", createdAt: date)
    }

    private func tiedEntries() -> [SearchHistoryEntry] {
        ["00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002"].map {
            SearchHistoryEntry(id: UUID(uuidString: $0)!, kind: .searchQuery, value: $0, displayTitle: "Same", lastUsedAt: .distantPast)
        }
    }

    private func checkRecording(_ manager: any SearchHistoryManaging) async throws {
        try await manager.recordSearchHistory(input("Exact"))
        let first = try #require(try await manager.recentSearchHistory(limit: 10).first)
        try await manager.recordSearchHistory(input("exact", date: Date(timeIntervalSince1970: 200)))
        try await manager.recordSearchHistory(SearchHistoryInput(kind: .link, value: "Exact", displayTitle: "Updated", createdAt: Date(timeIntervalSince1970: 300)))
        let all = try await manager.recentSearchHistory(limit: 10)
        #expect(all.count == 2)
        #expect(all[0].id == first.id)
        #expect(all[0].value == "Exact")
        #expect(all[0].kind == .link)
        #expect(all[0].displayTitle == "Updated")
        #expect(all[0].lastUsedAt == Date(timeIntervalSince1970: 300))
        #expect(try await manager.recentSearchHistory(limit: 1) == Array(all.prefix(1)))
        #expect(try await manager.recentSearchHistory(limit: 0).isEmpty)
        #expect(try await manager.recentSearchHistory(limit: -1).isEmpty)
    }

    private func checkRemoval(_ manager: any SearchHistoryManaging) async throws {
        for number in 0..<16 { try await manager.recordSearchHistory(input("query \(number)")) }
        let all = try await manager.recentSearchHistory(limit: 100)
        #expect(all.count == 16)
        #expect(all.map { $0.id.uuidString } == all.map { $0.id.uuidString }.sorted())
        try await manager.removeSearchHistory(id: UUID())
        #expect(try await manager.recentSearchHistory(limit: 100) == all)
        try await manager.removeSearchHistory(id: all[4].id)
        try await manager.removeSearchHistory(id: all[4].id)
        #expect(try await manager.recentSearchHistory(limit: 100) == all.filter { $0.id != all[4].id })
        try await manager.clearSearchHistory()
        try await manager.clearSearchHistory()
        #expect(try await manager.recentSearchHistory(limit: 100).isEmpty)
    }

    private func mutate(_ manager: any SearchHistoryManaging, operation: String, id: UUID) async throws {
        switch operation {
        case "delete": try await manager.removeSearchHistory(id: id)
        case "clear": try await manager.clearSearchHistory()
        case "insert": try await manager.recordSearchHistory(input("new"))
        default: try await manager.recordSearchHistory(SearchHistoryInput(kind: .link, value: "retained", displayTitle: "Changed", createdAt: .distantFuture))
        }
    }

    private func seedProtectedRecords(_ context: ModelContext) throws {
        let seriesID = UUID(), chapterID = UUID()
        let date = Date(timeIntervalSince1970: 42)
        context.insert(StoredSeries(id: seriesID, title: "Saved", canonicalURLString: "https://example.test/series", sourceDomain: "example.test", coverImageURLString: "cover", status: "Ongoing", synopsis: "Synopsis", latestKnownChapterLabel: "2", hasUnreadUpdates: true, libraryStateRaw: "reading", isCompleted: false, lastOpenedChapterID: chapterID, lastReadAt: date, createdAt: date, updatedAt: date))
        context.insert(StoredChapter(id: chapterID, seriesID: seriesID, title: "Chapter", chapterLabel: "1", chapterNumber: 1, sourceURLString: "chapter", previousChapterURLString: "previous", nextChapterURLString: "next", imageURLStrings: "images", isDownloaded: true, publishedAt: date, cachedAt: date, updatedAt: date))
        context.insert(StoredProgress(id: UUID(), chapterID: chapterID, sourceURLString: "chapter", currentImageIndex: 3, totalImageCount: 10, lastReadOffset: 4.5, updatedAt: date))
        context.insert(StoredRecentReading(seriesID: seriesID, chapterID: chapterID, seriesTitle: "Saved", seriesURLString: "series", sourceDomain: "example.test", coverImageURLString: "cover", chapterTitle: "Chapter", chapterLabel: "1", sourceURLString: "chapter", imageURLStrings: "images", currentImageIndex: 3, totalImageCount: 10, lastReadAt: date, updatedAt: date))
        context.insert(StoredCacheEntry(id: UUID(), sourceURLString: "chapter", seriesTitle: "Saved", chapterTitle: "Chapter", chapterLabel: "1", imageCount: 10, estimatedStorageBytes: 1024, retentionStateRaw: "retained", cachedAt: date, updatedAt: date))
        try context.save()
    }

    /// Every persisted field is captured explicitly; history operations must not alter any of them.
    private func protectedSnapshot(_ context: ModelContext) throws -> [[String]] {
        func strings(_ fields: Any?...) -> [String] { fields.map { String(describing: $0) } }
        let series = try context.fetch(FetchDescriptor<StoredSeries>()).map { strings($0.id, $0.title, $0.canonicalURLString, $0.sourceDomain, $0.coverImageURLString, $0.status, $0.synopsis, $0.latestKnownChapterLabel, $0.hasUnreadUpdates, $0.libraryStateRaw, $0.isCompleted, $0.lastOpenedChapterID, $0.lastReadAt, $0.createdAt, $0.updatedAt) }
        let chapters = try context.fetch(FetchDescriptor<StoredChapter>()).map { strings($0.id, $0.seriesID, $0.title, $0.chapterLabel, $0.chapterNumber, $0.sourceURLString, $0.previousChapterURLString, $0.nextChapterURLString, $0.imageURLStrings, $0.isDownloaded, $0.publishedAt, $0.cachedAt, $0.updatedAt) }
        let progress = try context.fetch(FetchDescriptor<StoredProgress>()).map { strings($0.id, $0.chapterID, $0.sourceURLString, $0.currentImageIndex, $0.totalImageCount, $0.lastReadOffset, $0.updatedAt) }
        let reading = try context.fetch(FetchDescriptor<StoredRecentReading>()).map { strings($0.seriesID, $0.chapterID, $0.seriesTitle, $0.seriesURLString, $0.sourceDomain, $0.coverImageURLString, $0.chapterTitle, $0.chapterLabel, $0.sourceURLString, $0.imageURLStrings, $0.currentImageIndex, $0.totalImageCount, $0.lastReadAt, $0.updatedAt) }
        let cache = try context.fetch(FetchDescriptor<StoredCacheEntry>()).map { strings($0.id, $0.sourceURLString, $0.seriesTitle, $0.chapterTitle, $0.chapterLabel, $0.imageCount, $0.estimatedStorageBytes, $0.retentionStateRaw, $0.cachedAt, $0.updatedAt) }
        return series + chapters + progress + reading + cache
    }
}

private struct HistorySaveFailure: Error {}

@MainActor private final class HistorySaveProbe {
    var count = 0
    var shouldFail = false
    func save(_ context: ModelContext) throws {
        count += 1
        if shouldFail { throw HistorySaveFailure() }
        try context.save()
    }
}
