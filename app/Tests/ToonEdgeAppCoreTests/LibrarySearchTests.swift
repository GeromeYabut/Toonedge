import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func librarySearchProjectionReturnsSavedSeriesSummary() async throws {
    let schema = Schema(ToonEdgePersistenceModels.all)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, modelContainer: container)
    let seriesID = UUID(uuidString: "7F51037B-97EE-4E45-A8E4-E488292211CE")!
    let coverURL = URL(string: "https://example.com/cover.jpg")!

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "The Hero Cannot Rest",
            canonicalURL: URL(string: "https://example.com/the-hero-cannot-rest")!,
            sourceDomain: "example.com",
            coverImageURL: coverURL,
            status: "Ongoing",
            synopsis: "Stored locally",
            latestKnownChapterLabel: "12",
            libraryState: nil,
            chapters: []
        ),
        context: .reader
    )

    let items = await repository.librarySearchItems()

    #expect(items.count == 1)
    #expect(items.first?.id == seriesID)
    #expect(items.first?.title == "The Hero Cannot Rest")
    #expect(items.first?.sourceDomain == "example.com")
    #expect(items.first?.libraryState == .reading)
    #expect(items.first?.currentChapterLabel == nil)
    #expect(items.first?.coverImageURL == coverURL)
}

@MainActor
@Test func librarySearchProjectionUsesSavedLastOpenedChapterLabel() async throws {
    let schema = Schema(ToonEdgePersistenceModels.all)
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, modelContainer: container)
    let chapterID = UUID(uuidString: "DC24E07A-DCCB-4D1E-897A-1CE733853CB2")!
    let chapterURL = URL(string: "https://example.com/series/chapter-7")!
    try await repository.addToLibrary(
        LibrarySeriesInput(
            title: "Chapter Progress",
            canonicalURL: URL(string: "https://example.com/series")!,
            sourceDomain: "example.com",
            coverImageURL: nil,
            status: "Ongoing",
            synopsis: "",
            latestKnownChapterLabel: "7",
            libraryState: nil,
            chapters: [LibraryChapterInput(
                id: chapterID,
                title: "Chapter 7",
                chapterLabel: "7",
                chapterNumber: 7,
                sourceURL: chapterURL,
                imageURLs: [],
                publishedAt: nil
            )]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 1, totalImageCount: 10),
        forChapterID: chapterID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let item = try #require(await repository.librarySearchItems().first)
    #expect(item.currentChapterLabel == "7")
}

@MainActor
@Test func librarySearchProjectionExcludesRecentOnlyAndPlaceholderSeries() async throws {
    let schema = Schema(ToonEdgePersistenceModels.all)
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, modelContainer: container)
    try await repository.recordRecentReading(RecentReadingInput(
        seriesID: UUID(),
        chapterID: UUID(),
        seriesTitle: "Recent Only",
        seriesURL: URL(string: "https://example.com/recent")!,
        sourceDomain: "example.com",
        chapterTitle: "Chapter 1",
        chapterLabel: "1",
        sourceURL: URL(string: "https://example.com/recent/chapter-1")!,
        imageURLs: [],
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
    ))
    try await repository.addToLibrary(
        LibrarySeriesInput(
            title: "placeholder.example",
            canonicalURL: URL(string: "https://placeholder.example/series")!,
            sourceDomain: "placeholder.example",
            coverImageURL: nil,
            status: "Ongoing",
            synopsis: "",
            latestKnownChapterLabel: nil,
            libraryState: nil,
            chapters: []
        ),
        context: .reader
    )

    #expect(await repository.librarySearchItems().isEmpty)
}

@Test func librarySearchItemAdapterKeepsOnlySearchFields() {
    let seriesID = UUID(uuidString: "37F14310-B07C-402E-9049-6D72DCA91084")!
    let coverURL = URL(string: "https://example.com/cover.png")!
    let summary = LibrarySeriesSummary(
        id: seriesID,
        title: "Saved Series",
        sourceDomain: "example.com",
        coverImageURL: coverURL,
        progressPercent: 0.5,
        chaptersRead: 8,
        totalKnownChapters: 16,
        lastReadAt: Date(timeIntervalSince1970: 1_700_000_000),
        libraryState: .completed,
        hasUnreadUpdates: true,
        isCompleted: true,
        latestChapterLabel: "16",
        currentChapterLabel: "8"
    )

    #expect(LibrarySearchItem(summary: summary) == LibrarySearchItem(
        id: seriesID,
        title: "Saved Series",
        sourceDomain: "example.com",
        libraryState: .completed,
        currentChapterLabel: "8",
        coverImageURL: coverURL
    ))
}

private func searchItem(_ suffix: Int, _ title: String) -> LibrarySearchItem {
    LibrarySearchItem(
        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!,
        title: title,
        sourceDomain: "example.com",
        libraryState: .reading,
        currentChapterLabel: nil,
        coverImageURL: nil
    )
}

@Test func libraryRankerOrdersExactPrefixOrderedTokenPrefixThenAllTokenContained() {
    let exact = searchItem(1, "Hero Rest")
    let prefix = searchItem(2, "Hero Rest Returns")
    let ordered = searchItem(3, "The Heroic Resting")
    let contained = searchItem(4, "The Resting Hero")
    let unrelated = searchItem(5, "Villain's Journey")

    let result = LibrarySuggestionRanker().rank(
        query: "hero rest",
        items: [contained, unrelated, ordered, prefix, exact],
        limit: 8
    )

    #expect(result.map(\.id) == [exact.id, prefix.id, ordered.id, contained.id])
}

@Test func libraryRankerNormalizesCaseDiacriticsPunctuationAndWhitespace() {
    let item = searchItem(1, "Héro—Returns")
    let ranker = LibrarySuggestionRanker()

    #expect(ranker.rank(query: "  HERO,   returns  ", items: [item], limit: 8) == [item])
    #expect(ranker.rank(query: "héro returns", items: [item], limit: 8) == [item])
}

@Test func libraryRankerBreaksTiesByNormalizedTitleThenSeriesID() {
    let zulu = searchItem(1, "Hero Zulu")
    let alphaLaterID = searchItem(3, "Hero Álpha")
    let alphaEarlierID = searchItem(2, "Hero Alpha")
    let ranker = LibrarySuggestionRanker()
    let items = [zulu, alphaLaterID, alphaEarlierID]
    let expected = [alphaEarlierID.id, alphaLaterID.id, zulu.id]

    #expect(ranker.rank(query: "hero", items: items, limit: 8).map(\.id) == expected)
    #expect(ranker.rank(query: "hero", items: items.reversed(), limit: 8).map(\.id) == expected)
}

@Test func libraryRankerDeduplicatesSavedSeriesIDAndHonorsLimit() {
    let best = searchItem(1, "Hero")
    let duplicate = searchItem(1, "The Hero")
    let second = searchItem(2, "Hero Returns")
    let ranker = LibrarySuggestionRanker()

    #expect(ranker.rank(query: "hero", items: [duplicate, second, best], limit: 8).map(\.id) == [best.id, second.id])
    #expect(ranker.rank(query: "hero", items: [second, best, duplicate], limit: 1) == [best])
    #expect(ranker.rank(query: "hero", items: [best], limit: 0).isEmpty)
    #expect(ranker.rank(query: "hero", items: [best], limit: -1).isEmpty)
}

@Test func libraryRankerReturnsNoResultsForEmptyOrPunctuationOnlyQueries() {
    let item = searchItem(1, "Hero")
    let ranker = LibrarySuggestionRanker()

    #expect(ranker.rank(query: "", items: [item], limit: 8).isEmpty)
    #expect(ranker.rank(query: "   ", items: [item], limit: 8).isEmpty)
    #expect(ranker.rank(query: "—?!", items: [item], limit: 8).isEmpty)
}

@Test func searchSuggestionDestinationsKeepBrowserAndSavedSeriesDistinct() {
    let item = searchItem(1, "Hero")

    #expect(SearchSuggestionDestination.browserInput("hero") != .librarySeries(item))
    #expect(SearchSuggestionDestination.librarySeries(item) == .librarySeries(item))
}

@Test func libraryRankerChoosesStableRepresentativeForEqualRankDuplicateIDs() {
    let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let nilChapter = LibrarySearchItem(
        id: id, title: "Hero", sourceDomain: "example.com", libraryState: .reading,
        currentChapterLabel: nil, coverImageURL: nil
    )
    let emptyChapter = LibrarySearchItem(
        id: id, title: "Hero", sourceDomain: "example.com", libraryState: .reading,
        currentChapterLabel: "", coverImageURL: nil
    )
    let ranker = LibrarySuggestionRanker()

    #expect(ranker.rank(query: "hero", items: [nilChapter, emptyChapter], limit: 1) == [nilChapter])
    #expect(ranker.rank(query: "hero", items: [emptyChapter, nilChapter], limit: 1) == [nilChapter])
}
