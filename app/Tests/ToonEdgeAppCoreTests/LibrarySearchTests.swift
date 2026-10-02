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
