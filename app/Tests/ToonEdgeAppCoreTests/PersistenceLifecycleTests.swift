import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func recentReadingWriteCanonicalizesNoisyChapterIdentity() async throws {
    let schema = Schema([StoredSeries.self, StoredChapter.self, StoredProgress.self, StoredSearchHistory.self, StoredRecentReading.self, StoredCacheEntry.self])
    let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext, modelContainer: container)
    let sourceURL = try #require(URL(string: "https://manhuatop.org/manhua/sample/chapter-1/"))
    let input = RecentReadingInput(
        seriesID: UUID(),
        chapterID: UUID(),
        seriesTitle: "Sample",
        seriesURL: try #require(URL(string: "https://manhuatop.org/manhua/sample/")),
        sourceDomain: "manhuatop.org",
        chapterTitle: "Sample Manhwa - Chapter 1 - Manhwa Manhua Top",
        chapterLabel: "Top",
        sourceURL: sourceURL,
        imageURLs: [],
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
    )

    try await repository.recordRecentReading(input)
    let stored = try #require(container.mainContext.fetch(FetchDescriptor<StoredRecentReading>()).first)

    #expect(stored.chapterLabel == "1")
}

@MainActor
@Test func swiftDataRepositoryAddsSeriesAndBuildsLibrarySnapshots() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "5D2E0A55-B6DB-4667-9142-FD866E378B04")!
    let chapterID = UUID(uuidString: "0D5410E4-B585-4011-A705-74ACDE44C2E0")!

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "Persisted Edge",
            canonicalURL: URL(string: "https://example.com/persisted-edge")!,
            sourceDomain: "example.com",
            coverImageURL: nil,
            status: "Ongoing",
            synopsis: "A persisted local series.",
            latestKnownChapterLabel: "12",
            libraryState: nil,
            chapters: [
                LibraryChapterInput(
                    id: chapterID,
                    title: "Chapter 12",
                    chapterLabel: "12",
                    chapterNumber: 12,
                    sourceURL: URL(string: "https://example.com/persisted-edge/chapter-12")!,
                    imageURLs: [],
                    publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
                )
            ]
        ),
        context: .seriesDetail
    )

    let library = await repository.librarySnapshot()
    let summary = try #require(library.series.first)
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(summary.title == "Persisted Edge")
    #expect(summary.libraryState == .planned)
    #expect(summary.latestChapterLabel == "12")
    #expect(detail.chapters.map(\.chapterLabel) == ["12"])
    #expect(detail.isSaved)
}

@MainActor
@Test func swiftDataRepositoryAssignsReadingStateWhenAddingFromReader() async throws {
    let repository = try makeRepository()

    try await repository.addToLibrary(.mock(title: "Reader Save"), context: .reader)
    let summary = try #require(await repository.librarySnapshot().series.first)

    #expect(summary.libraryState == .reading)
}

@MainActor
@Test func swiftDataRepositoryPersistsLibraryStateTransitions() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "E0C1C05B-D3DA-4BD8-A96D-88B9F11267D3")!

    try await repository.addToLibrary(.mock(id: seriesID, title: "Stateful Title"), context: .seriesDetail)
    try await repository.updateLibraryState(.reading, for: seriesID)
    var summary = try #require(await repository.librarySnapshot().series.first)
    #expect(summary.libraryState == .reading)

    try await repository.updateLibraryState(.dropped, for: seriesID)
    summary = try #require(await repository.librarySnapshot().series.first)
    #expect(summary.libraryState == .dropped)

    try await repository.updateLibraryState(.completed, for: seriesID)
    summary = try #require(await repository.librarySnapshot().series.first)
    #expect(summary.libraryState == .completed)
    #expect(summary.isCompleted)
}

@MainActor
@Test func swiftDataRepositoryMergesSeriesSavedWithChapterIndexCanonicalURL() async throws {
    let repository = try makeRepository()
    let staleID = UUID(uuidString: "C26E6A90-524B-43A7-A503-2AC3359E2F20")!
    let correctedID = UUID(uuidString: "C26E6A90-524B-43A7-A503-2AC3359E2F21")!
    let seriesURL = URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241")!
    let staleCanonicalURL = URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter")!

    try await repository.addToLibrary(
        .mock(
            id: staleID,
            title: "The Cold-Blooded Warrior",
            canonicalURL: staleCanonicalURL,
            chapters: [
                .mock(
                    chapterLabel: "3",
                    sourceURL: URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/3")!,
                    imageURLs: [URL(string: "https://img.example.com/3.jpg")!]
                )
            ]
        ),
        context: .browser
    )
    try await repository.addToLibrary(
        .mock(
            id: correctedID,
            title: "The Cold-Blooded Warrior",
            canonicalURL: seriesURL,
            chapters: [
                .mock(
                    chapterLabel: "4",
                    sourceURL: URL(string: "https://asurascans.com/comics/the-cold-blooded-warrior-46f09241/chapter/4")!,
                    imageURLs: [URL(string: "https://img.example.com/4.jpg")!]
                )
            ]
        ),
        context: .reader
    )

    let snapshot = await repository.librarySnapshot()
    let summary = try #require(snapshot.series.first)

    #expect(snapshot.series.count == 1)
    #expect(summary.canonicalURL == seriesURL)
    #expect(summary.totalKnownChapters == 2)
}

@MainActor
@Test func swiftDataRepositoryPersistsUpdateCheckResultForHomeAndRecentLibrary() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "80149234-92BB-45D2-AB5F-73C7A41C74DF")!
    let checkedAt = Date(timeIntervalSince1970: 1_700_001_200)

    try await repository.addToLibrary(
        .mock(id: seriesID, title: "Update State", chapters: [.mock(chapterLabel: "12")]),
        context: .seriesDetail
    )
    try await repository.recordUpdateCheckResult(
        seriesID: seriesID,
        latestChapterLabel: "13",
        hasUnreadUpdates: true,
        checkedAt: checkedAt
    )

    let homeSnapshot = await repository.homeSnapshot()
    let librarySnapshot = await repository.librarySnapshot()
    let summary = try #require(librarySnapshot.series.first)
    let recentSeries = librarySnapshot.series(for: .recent)

    #expect(summary.hasUnreadUpdates)
    #expect(summary.latestChapterLabel == "13")
    #expect(homeSnapshot.recentlyUpdated.map(\.id) == [seriesID])
    #expect(recentSeries.map(\.id) == [seriesID])
    #expect(summary.lastReadAt == nil)
}

@MainActor
@Test func swiftDataRepositoryUsesIndexedNextChapterAsSeriesDetailPrimaryAction() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "6DB9FA17-D409-4FA3-A066-10368F5EB107")!
    let chapter106ID = UUID(uuidString: "6DB9FA17-D409-4FA3-A066-10368F5EB106")!
    let canonicalURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
    let chapter106URL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/106"))
    let chapter107URL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107"))

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "The Extra’s Academy Survival Guide | Asura Scans",
            canonicalURL: canonicalURL,
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            status: "Reading",
            synopsis: "Saved from Reader Mode.",
            latestKnownChapterLabel: "106",
            libraryState: .reading,
            chapters: [
                LibraryChapterInput(
                    id: chapter106ID,
                    title: "The Extra’s Academy Survival Guide Chapter 106 - Read Online | Asura Scans",
                    chapterLabel: "106",
                    chapterNumber: 106,
                    sourceURL: chapter106URL,
                    imageURLs: [try #require(URL(string: "https://img.example.com/chapter-106-1.jpg"))],
                    publishedAt: nil
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 10, totalImageCount: 10),
        forChapterID: chapter106ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    try await repository.recordAvailableChapters(
        [
            ChapterIndexEntry(
                title: "The Extra’s Academy Survival Guide Chapter 107 - Read Online | Asura Scans",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: chapter107URL,
                checkedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        ],
        for: seriesID,
        indexedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let detail = try #require(await repository.seriesDetail(for: seriesID))
    let chapter107 = try #require(detail.primaryChapter)
    let directSession = await repository.readerSession(forChapterID: chapter107.id)

    #expect(detail.primaryActionTitle == "Start Chapter 107")
    #expect(chapter107.chapterLabel == "107")
    #expect(directSession == nil)
    #expect(chapter107.sourceURL == chapter107URL)
    #expect(chapter107.isOpenable)
}

@MainActor
@Test func librarySnapshotSummaryCarriesConcreteResumeTargetFromIndexedChapters() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter100ID = UUID()
    let chapter101ID = UUID()

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "Moonlit Edge",
            canonicalURL: URL(string: "https://example.com/series/moonlit-edge")!,
            sourceDomain: "example.com",
            coverImageURL: nil,
            status: "Reading",
            synopsis: "Local chapter index.",
            latestKnownChapterLabel: "200",
            libraryState: .reading,
            chapters: [
                LibraryChapterInput(
                    id: chapter100ID,
                    title: "Moonlit Edge Chapter 100",
                    chapterLabel: "100",
                    chapterNumber: 100,
                    sourceURL: URL(string: "https://example.com/chapter-100")!,
                    imageURLs: [],
                    publishedAt: nil
                ),
                LibraryChapterInput(
                    id: chapter101ID,
                    title: "Moonlit Edge Chapter 101",
                    chapterLabel: "101",
                    chapterNumber: 101,
                    sourceURL: URL(string: "https://example.com/chapter-101")!,
                    imageURLs: [],
                    publishedAt: nil
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 10, totalImageCount: 10),
        forChapterID: chapter100ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let summary = try #require(await repository.librarySnapshot().series.first { $0.id == seriesID })

    #expect(summary.resumeTarget?.chapter.id == chapter101ID)
    #expect(summary.resumeTarget?.actionTitle == "Start Chapter 101")
    #expect(summary.resumeTarget?.chapter.sourceURL.absoluteString == "https://example.com/chapter-101")
}

@MainActor
@Test func librarySummaryResumeTargetStartsAtFirstReadableChapterWhenLatestKnownIsHigher() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter1ID = UUID()
    let chapter1URL = try #require(URL(string: "https://asurascans.com/series/shepherd/chapter/1"))
    let chapter236URL = try #require(URL(string: "https://asurascans.com/series/shepherd/chapter/236"))

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "The Shepherd Wizard | Asura Scans",
            canonicalURL: try #require(URL(string: "https://asurascans.com/series/shepherd")),
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            status: "Reading",
            synopsis: "Saved from indexed chapter list.",
            latestKnownChapterLabel: "236",
            libraryState: .reading,
            chapters: [
                .mock(
                    id: chapter1ID,
                    title: "First Chapter",
                    chapterLabel: "1",
                    sourceURL: chapter1URL
                )
            ]
        ),
        context: .seriesDetail
    )
    try await repository.recordAvailableChapters(
        [
            ChapterIndexEntry(
                title: "Chapter 236",
                chapterLabel: "236",
                chapterNumber: 236,
                sourceURL: chapter236URL
            )
        ],
        for: seriesID,
        indexedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let summary = try #require(await repository.librarySnapshot().series.first { $0.id == seriesID })
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(summary.latestChapterLabel == "236")
    #expect(summary.resumeTarget?.chapter.id == detail.primaryChapter?.id)
    #expect(summary.resumeTarget?.chapter.id == chapter1ID)
    #expect(summary.resumeTarget?.chapter.chapterLabel == "1")
    #expect(detail.primaryActionTitle == "Start Chapter 1")
}

@MainActor
@Test func librarySnapshotSummaryDoesNotInventResumeTargetWithoutSourceURL() async throws {
    let summary = LibrarySeriesSummary(
        title: "Label Only",
        sourceDomain: "example.com",
        coverImageURL: nil,
        progressPercent: 0.5,
        chaptersRead: 100,
        totalKnownChapters: 200,
        lastReadAt: Date(timeIntervalSince1970: 1_700_000_000),
        libraryState: .reading,
        hasUnreadUpdates: false,
        isCompleted: false,
        latestChapterLabel: "200",
        currentChapterLabel: "100",
        resumeTarget: nil
    )

    #expect(summary.resumeTarget == nil)
}

@MainActor
@Test func swiftDataRepositoryDoesNotEraseReaderPayloadWhenIndexRefreshSeesExistingChapter() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "AE80DD47-9D18-47EB-9DA7-0232898C5100")!
    let chapterID = UUID(uuidString: "AE80DD47-9D18-47EB-9DA7-0232898C5106")!
    let chapterURL = try #require(URL(string: "https://example.com/series/extras/chapter/106"))
    let imageURL = try #require(URL(string: "https://img.example.com/chapter-106-1.jpg"))

    try await repository.addToLibrary(
        .mock(
            id: seriesID,
            title: "The Extra’s Academy Survival Guide",
            canonicalURL: URL(string: "https://example.com/series/extras")!,
            chapters: [
                .mock(
                    id: chapterID,
                    title: "Chapter 106",
                    chapterLabel: "106",
                    sourceURL: chapterURL,
                    imageURLs: [imageURL]
                )
            ]
        ),
        context: .reader
    )

    try await repository.recordAvailableChapters(
        [
            ChapterIndexEntry(
                title: "Chapter 106",
                chapterLabel: "106",
                chapterNumber: 106,
                sourceURL: chapterURL
            )
        ],
        for: seriesID,
        indexedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let session = try #require(await repository.readerSession(forChapterID: chapterID))

    #expect(session.imageURLs == [imageURL])
}

@MainActor
@Test func swiftDataRepositorySavesProgressAndRestoresContinueReadingTarget() async throws {
    let repository = try makeRepository()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let seriesID = UUID(uuidString: "B1E86034-5203-4675-AE58-2EC75F81E4AE")!
    let chapterID = UUID(uuidString: "00AA69FE-A242-4C54-8860-2A6E90C67F35")!
    let chapterURL = URL(string: "https://example.com/restore/chapter-4")!

    try await repository.addToLibrary(
        .mock(
            id: seriesID,
            title: "Restore Title",
            chapters: [
                .mock(id: chapterID, chapterLabel: "4", sourceURL: chapterURL)
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 2, totalImageCount: 5),
        forChapterID: chapterID,
        at: now
    )

    let target = try #require(await repository.continueReadingTarget(for: seriesID))
    let detail = try #require(await repository.seriesDetail(for: seriesID))
    let librarySummary = try #require(await repository.librarySnapshot().series.first)

    #expect(target.seriesID == seriesID)
    #expect(target.chapterID == chapterID)
    #expect(target.sourceURL == chapterURL)
    #expect(target.progress.currentImageIndex == 2)
    #expect(detail.primaryChapter?.id == chapterID)
    #expect(librarySummary.lastReadAt == now)
    #expect(librarySummary.currentChapterLabel == "4")
}

@MainActor
@Test func swiftDataRepositoryBuildsStoredReaderSessionWhenChapterPayloadExists() async throws {
    let repository = try makeRepository()
    let chapterURL = URL(string: "https://example.com/moonlit-edge/chapter-12")!
    let imageURLs = [
        URL(string: "https://img.example.com/1.jpg")!,
        URL(string: "https://img.example.com/2.jpg")!
    ]
    let previousURL = URL(string: "https://example.com/moonlit-edge/chapter-11")!
    let nextURL = URL(string: "https://example.com/moonlit-edge/chapter-13")!
    let input = LibrarySeriesInput.mock(
        title: "Moonlit Edge",
        canonicalURL: URL(string: "https://example.com/moonlit-edge")!,
        chapters: [
            .mock(
                title: "Chapter 12",
                chapterLabel: "12",
                sourceURL: chapterURL,
                previousChapterURL: previousURL,
                nextChapterURL: nextURL,
                imageURLs: imageURLs
            )
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let session = try #require(await repository.readerSession(forChapterID: input.chapters[0].id))

    #expect(session.seriesTitle == "Moonlit Edge")
    #expect(session.seriesURL == input.canonicalURL)
    #expect(session.sourceURL == chapterURL)
    #expect(session.imageURLs == imageURLs)
    #expect(session.previousChapter?.sourceURL == previousURL)
    #expect(session.nextChapter?.sourceURL == nextURL)
}

@MainActor
@Test func swiftDataRepositoryDerivesAdjacentReaderControlsFromSavedChapterListWhenLinksAreMissing() async throws {
    let repository = try makeRepository()
    let input = LibrarySeriesInput.mock(
        title: "Moonlit Edge",
        canonicalURL: URL(string: "https://example.com/moonlit-edge")!,
        chapters: [
            .mock(
                title: "Chapter 1",
                chapterLabel: "1",
                sourceURL: URL(string: "https://example.com/moonlit-edge/chapter-1")!,
                imageURLs: [URL(string: "https://img.example.com/1.jpg")!]
            ),
            .mock(
                title: "Chapter 2",
                chapterLabel: "2",
                sourceURL: URL(string: "https://example.com/moonlit-edge/chapter-2")!,
                imageURLs: [URL(string: "https://img.example.com/2.jpg")!]
            )
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let firstSession = try #require(await repository.readerSession(forChapterID: input.chapters[0].id))
    let secondSession = try #require(await repository.readerSession(forChapterID: input.chapters[1].id))

    #expect(firstSession.previousChapter == nil)
    #expect(firstSession.nextChapter?.sourceURL == input.chapters[1].sourceURL)
    #expect(firstSession.nextChapter?.title == "Chapter 2")
    #expect(secondSession.previousChapter?.sourceURL == input.chapters[0].sourceURL)
    #expect(secondSession.nextChapter?.sourceURL == URL(string: "https://example.com/moonlit-edge/chapter-3")!)
    #expect(secondSession.nextChapter?.title == "Chapter 3")
}

@Test func chapterURLInferenceValidatesOnlyTheRequestedNumericIdentity() throws {
    let url = try #require(URL(string: "https://example.com/series/chapter-156"))
    #expect(ChapterURLInference.containsChapterNumber(156, in: url))
    #expect(!ChapterURLInference.containsChapterNumber(169, in: url))
    #expect(!ChapterURLInference.containsChapterNumber(15, in: url))
}

@MainActor
@Test func swiftDataRepositoryRejectsNonAdjacentExplicitLinkForNumericChapter() async throws {
    let repository = try makeRepository()
    let chapter169URL = URL(string: "https://example.com/series/chapter-169")!
    var chapter155 = LibraryChapterInput.mock(
        title: "Chapter 155",
        chapterLabel: "155",
        sourceURL: URL(string: "https://example.com/series/chapter-155")!,
        imageURLs: [URL(string: "https://images.example.test/155.png")!]
    )
    chapter155.previousChapterURL = URL(string: "https://example.com/series/chapter-1")!
    chapter155.nextChapterURL = chapter169URL
    let input = LibrarySeriesInput.mock(
        chapters: [
            .mock(chapterLabel: "1", sourceURL: URL(string: "https://example.com/series/chapter-1")!),
            chapter155,
            .mock(chapterLabel: "169", sourceURL: chapter169URL)
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let session = try #require(await repository.readerSession(forChapterID: chapter155.id))

    #expect(session.previousChapter?.sourceURL == URL(string: "https://example.com/series/chapter-154"))
    #expect(session.nextChapter?.sourceURL == URL(string: "https://example.com/series/chapter-156"))
    #expect(session.previousChapter?.sourceURL != input.chapters[0].sourceURL)
    #expect(session.nextChapter?.sourceURL != chapter169URL)
}

@MainActor
@Test func swiftDataRepositoryDerivesNumericAdjacentReaderControlsForSparseChapterLists() async throws {
    let repository = try makeRepository()
    let chapter155URL = URL(string: "https://manhuaus.com/manga/past-life-returner/chapter-155/")!
    let chapter169URL = URL(string: "https://manhuaus.com/manga/past-life-returner/chapter-169/")!
    let input = LibrarySeriesInput.mock(
        title: "Past Life Returner",
        canonicalURL: URL(string: "https://manhuaus.com/manga/past-life-returner/")!,
        chapters: [
            .mock(
                title: "Chapter 1",
                chapterLabel: "1",
                sourceURL: URL(string: "https://manhuaus.com/manga/past-life-returner/chapter-1/")!,
                imageURLs: [URL(string: "https://img.example.com/past-life-1.jpg")!]
            ),
            .mock(
                title: "Chapter 155",
                chapterLabel: "155",
                sourceURL: chapter155URL,
                imageURLs: [URL(string: "https://img.example.com/past-life-155.jpg")!]
            ),
            .mock(
                title: "Chapter 169",
                chapterLabel: "169",
                sourceURL: chapter169URL,
                imageURLs: [URL(string: "https://img.example.com/past-life-169.jpg")!]
            )
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let session = try #require(await repository.readerSession(forChapterID: input.chapters[1].id))

    #expect(session.previousChapter?.sourceURL == URL(string: "https://manhuaus.com/manga/past-life-returner/chapter-154/")!)
    #expect(session.nextChapter?.sourceURL == URL(string: "https://manhuaus.com/manga/past-life-returner/chapter-156/")!)
    #expect(session.nextChapter?.sourceURL != chapter169URL)
}

@MainActor
@Test func swiftDataRepositoryReconcilesRecentReadingWithSavedChapterContinueTarget() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter1ID = UUID()
    let chapter169ID = UUID()
    let seriesURL = URL(string: "https://vortexscans.org/series/past-life-returner/")!
    let chapter169URL = URL(string: "https://vortexscans.org/series/past-life-returner/chapter-169")!
    let input = LibrarySeriesInput.mock(
        id: seriesID,
        title: "Past Life Returner",
        canonicalURL: seriesURL,
        chapters: [
            .mock(
                id: chapter1ID,
                title: "Past Life Returner Chapter 1",
                chapterLabel: "1",
                sourceURL: URL(string: "https://vortexscans.org/series/past-life-returner/chapter-1")!,
                imageURLs: [URL(string: "https://img.example.com/past-life-1.jpg")!]
            ),
            .mock(
                id: chapter169ID,
                title: "Past Life Returner Chapter 169",
                chapterLabel: "169",
                sourceURL: chapter169URL,
                imageURLs: [URL(string: "https://img.example.com/past-life-169.jpg")!]
            )
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 0, totalImageCount: 4),
        forChapterID: chapter1ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try await repository.recordRecentReading(
        .mockRecent(
            seriesID: seriesID,
            chapterID: chapter169ID,
            seriesTitle: "Past Life Returner",
            seriesURL: seriesURL,
            chapterLabel: "169",
            sourceURL: chapter169URL,
            readAt: Date(timeIntervalSince1970: 1_700_001_000)
        )
    )

    let target = try #require(await repository.continueReadingTarget(for: seriesID))
    let session = try #require(await repository.readerSession(forChapterID: target.chapterID))

    #expect(target.chapterID == chapter169ID)
    #expect(target.sourceURL == chapter169URL)
    #expect(session.chapterTitle == "Past Life Returner Chapter 169")
    #expect(session.nextChapter?.sourceURL == URL(string: "https://vortexscans.org/series/past-life-returner/chapter-170")!)
}

@MainActor
@Test func seriesDetailContinueUsesDiscoveredChapterThreeImmediatelyAndAfterRepositoryReconstruction() async throws {
    let schema = Schema([
        StoredSeries.self,
        StoredChapter.self,
        StoredProgress.self,
        StoredSearchHistory.self,
        StoredRecentReading.self
    ])
    let container = try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let repository = SwiftDataLibraryRepository(
        modelContext: container.mainContext,
        modelContainer: container
    )
    let seriesID = UUID()
    let chapter1ID = UUID()
    let chapter3ID = UUID()
    let seriesURL = URL(string: "https://example.com/past-life-returner")!
    let chapter1URL = URL(string: "https://example.com/past-life-returner/chapter-1")!
    let chapter3URL = URL(string: "https://example.com/past-life-returner/chapter-3")!

    try await repository.addToLibrary(
        .mock(
            id: seriesID,
            title: "Past Life Returner",
            canonicalURL: seriesURL,
            chapters: [
                .mock(
                    id: chapter1ID,
                    chapterLabel: "1",
                    sourceURL: chapter1URL,
                    imageURLs: [URL(string: "https://img.example.com/chapter-1.jpg")!]
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 0, totalImageCount: 5),
        forChapterID: chapter1ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try await repository.recordRecentReading(
        .mockRecent(
            seriesID: seriesID,
            chapterID: chapter3ID,
            seriesTitle: "Past Life Returner",
            seriesURL: seriesURL,
            chapterLabel: "3",
            sourceURL: chapter3URL,
            readAt: Date(timeIntervalSince1970: 1_700_001_000)
        )
    )

    let immediateDetail = try #require(await repository.seriesDetail(for: seriesID))
    let immediateTarget = try #require(await repository.continueReadingTarget(for: seriesID))

    #expect(immediateDetail.primaryActionTitle == "Continue Chapter 3")
    #expect(immediateDetail.primaryChapter?.id == chapter3ID)
    #expect(immediateTarget.chapterID == chapter3ID)
    #expect(immediateTarget.sourceURL == chapter3URL)

    let reconstructedRepository = SwiftDataLibraryRepository(
        modelContext: container.mainContext,
        modelContainer: container
    )
    let reconstructedDetail = try #require(await reconstructedRepository.seriesDetail(for: seriesID))
    let reconstructedTarget = try #require(await reconstructedRepository.continueReadingTarget(for: seriesID))

    #expect(reconstructedDetail.primaryActionTitle == "Continue Chapter 3")
    #expect(reconstructedDetail.primaryChapter?.id == chapter3ID)
    #expect(reconstructedTarget.chapterID == chapter3ID)
    #expect(reconstructedTarget.sourceURL == chapter3URL)
}

@MainActor
@Test func librarySummaryResumeTargetMatchesSeriesDetailPrimaryChapterWithoutDetailSnapshotConstruction() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter100ID = UUID()
    let chapter101ID = UUID()

    try await repository.addToLibrary(
        LibrarySeriesInput.mock(
            id: seriesID,
            title: "Fast Summary",
            chapters: [
                .mock(id: chapter100ID, chapterLabel: "100"),
                .mock(id: chapter101ID, chapterLabel: "101")
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 1, totalImageCount: 1),
        forChapterID: chapter100ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let summary = try #require(await repository.librarySnapshot().series.first { $0.id == seriesID })
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(summary.resumeTarget?.chapter.id == detail.primaryChapter?.id)
    #expect(summary.resumeTarget?.actionTitle == detail.primaryActionTitle)
}

@MainActor
@Test func swiftDataRepositoryTargetedLookupsPreserveSeriesDetailAndProgress() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter101ID = UUID()
    let chapter102ID = UUID()
    let chapter101URL = URL(string: "https://example.com/moonlit/chapter-101")!
    let chapter102URL = URL(string: "https://example.com/moonlit/chapter-102")!

    try await repository.addToLibrary(
        LibrarySeriesInput.mock(
            id: seriesID,
            title: "Moonlit Edge",
            canonicalURL: URL(string: "https://example.com/moonlit")!,
            chapters: [
                .mock(
                    id: chapter101ID,
                    chapterLabel: "101",
                    sourceURL: chapter101URL,
                    imageURLs: []
                ),
                .mock(
                    id: chapter102ID,
                    chapterLabel: "102",
                    sourceURL: chapter102URL,
                    imageURLs: []
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 2, totalImageCount: 5),
        forChapterID: chapter102ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let detail = try #require(await repository.seriesDetail(for: seriesID))
    let summary = try #require(await repository.librarySnapshot().series.first { $0.id == seriesID })

    #expect(detail.chapters.map(\.id).contains(chapter101ID))
    #expect(detail.chapters.map(\.id).contains(chapter102ID))
    #expect(detail.primaryChapter?.id == chapter102ID)
    #expect(summary.currentChapterLabel == "102")
}

@MainActor
@Test func swiftDataRepositoryAddsRecentAdjacentChapterToSavedSeriesDetail() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter102ID = UUID()
    let chapter103ID = UUID()
    let seriesURL = URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-a80d257e")!
    let chapter102URL = URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-a80d257e/chapter/102")!
    let chapter103URL = URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-a80d257e/chapter/103")!

    try await repository.addToLibrary(
        LibrarySeriesInput.mock(
            id: seriesID,
            title: "The Extra’s Academy Survival Guide | Asura Scans",
            canonicalURL: seriesURL,
            chapters: [
                .mock(
                    id: chapter102ID,
                    title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                    chapterLabel: "Scans",
                    sourceURL: chapter102URL,
                    imageURLs: [URL(string: "https://img.example.com/extras-102.jpg")!]
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 1, totalImageCount: 1),
        forChapterID: chapter102ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )
    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: chapter103ID,
            seriesTitle: "The Extra’s Academy Survival Guide | Asura Scans",
            seriesURL: seriesURL,
            sourceDomain: "asurascans.com",
            chapterTitle: "The Extra’s Academy Survival Guide Chapter 103 - Read Online | Asura Scans",
            chapterLabel: "Scans",
            sourceURL: chapter103URL,
            imageURLs: [URL(string: "https://img.example.com/extras-103.jpg")!],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 8),
            readAt: Date(timeIntervalSince1970: 1_700_001_000)
        )
    )

    let detail = try #require(await repository.seriesDetail(for: seriesID))
    let session = try #require(await repository.readerSession(forChapterID: chapter103ID))

    #expect(detail.primaryActionTitle == "Continue Chapter 103")
    #expect(detail.chapters.contains { $0.id == chapter103ID })
    #expect(detail.totalKnownChapters == 2)
    #expect(session.sourceURL == chapter103URL)
    #expect(session.previousChapter?.sourceURL == chapter102URL)
}

@MainActor
@Test func swiftDataRepositoryRepairsExistingRecentAdjacentChapterWhenSeriesDetailLoads() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter102ID = UUID()
    let chapter103ID = UUID()
    let seriesURL = URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-a80d257e")!
    let chapter102URL = URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-a80d257e/chapter/102")!
    let chapter103URL = URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-a80d257e/chapter/103")!

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: chapter103ID,
            seriesTitle: "The Extra’s Academy Survival Guide | Asura Scans",
            seriesURL: seriesURL,
            sourceDomain: "asurascans.com",
            chapterTitle: "The Extra’s Academy Survival Guide Chapter 103 - Read Online | Asura Scans",
            chapterLabel: "Scans",
            sourceURL: chapter103URL,
            imageURLs: [URL(string: "https://img.example.com/extras-103.jpg")!],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 8),
            readAt: Date(timeIntervalSince1970: 1_700_001_000)
        )
    )
    try await repository.addToLibrary(
        LibrarySeriesInput.mock(
            id: seriesID,
            title: "The Extra’s Academy Survival Guide | Asura Scans",
            canonicalURL: seriesURL,
            chapters: [
                .mock(
                    id: chapter102ID,
                    title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                    chapterLabel: "Scans",
                    sourceURL: chapter102URL,
                    imageURLs: [URL(string: "https://img.example.com/extras-102.jpg")!]
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 1, totalImageCount: 1),
        forChapterID: chapter102ID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let detail = try #require(await repository.seriesDetail(for: seriesID))
    let session = try #require(await repository.readerSession(forChapterID: chapter103ID))

    #expect(detail.primaryActionTitle == "Continue Chapter 103")
    #expect(detail.totalKnownChapters == 2)
    #expect(session.sourceURL == chapter103URL)
}

@MainActor
@Test func swiftDataRepositoryPrefersStoredNumericAdjacentChapterWhenPayloadExists() async throws {
    let repository = try makeRepository()
    let input = LibrarySeriesInput.mock(
        title: "Moonlit Edge",
        canonicalURL: URL(string: "https://example.com/moonlit-edge")!,
        chapters: [
            .mock(
                title: "Chapter 155",
                chapterLabel: "155",
                sourceURL: URL(string: "https://example.com/moonlit-edge/chapter-155")!,
                imageURLs: [URL(string: "https://img.example.com/155.jpg")!]
            ),
            .mock(
                title: "Chapter 156",
                chapterLabel: "156",
                sourceURL: URL(string: "https://example.com/moonlit-edge/read/chapter-156")!,
                imageURLs: [URL(string: "https://img.example.com/156.jpg")!]
            ),
            .mock(
                title: "Chapter 169",
                chapterLabel: "169",
                sourceURL: URL(string: "https://example.com/moonlit-edge/chapter-169")!,
                imageURLs: [URL(string: "https://img.example.com/169.jpg")!]
            )
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let session = try #require(await repository.readerSession(forChapterID: input.chapters[0].id))

    #expect(session.nextChapter?.id == input.chapters[1].id)
    #expect(session.nextChapter?.sourceURL == input.chapters[1].sourceURL)
}

@MainActor
@Test func swiftDataRepositoryDoesNotJumpToSparseStoredChapterWhenNumericAdjacentURLIsUnsafe() async throws {
    let repository = try makeRepository()
    let chapter169URL = URL(string: "https://example.com/moonlit-edge/chapter-169")!
    let input = LibrarySeriesInput.mock(
        title: "Moonlit Edge",
        canonicalURL: URL(string: "https://example.com/moonlit-edge")!,
        chapters: [
            .mock(
                title: "Chapter 155",
                chapterLabel: "155",
                sourceURL: URL(string: "https://example.com/moonlit-edge/latest")!,
                imageURLs: [URL(string: "https://img.example.com/latest.jpg")!]
            ),
            .mock(
                title: "Chapter 169",
                chapterLabel: "169",
                sourceURL: chapter169URL,
                imageURLs: [URL(string: "https://img.example.com/169.jpg")!]
            )
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let session = try #require(await repository.readerSession(forChapterID: input.chapters[0].id))

    #expect(session.nextChapter == nil)
    #expect(session.nextChapter?.sourceURL != chapter169URL)
}

@MainActor
@Test func swiftDataRepositorySkipsStoredReaderSessionWhenChapterPayloadIsMissing() async throws {
    let repository = try makeRepository()
    let input = LibrarySeriesInput.mock(
        chapters: [.mock(imageURLs: [])]
    )

    try await repository.addToLibrary(input, context: .reader)

    #expect(await repository.readerSession(forChapterID: input.chapters[0].id) == nil)
}

@MainActor
@Test func swiftDataRepositoryPersistsReaderProgressBySourceURL() async throws {
    let repository = try makeRepository()
    let sourceURL = URL(string: "https://example.com/source-only/chapter-2")!
    let progress = ReaderProgress(currentImageIndex: 3, totalImageCount: 6)

    await repository.save(progress, for: sourceURL)
    let restored = await repository.progress(for: sourceURL)

    #expect(restored == progress)
}

@MainActor
@Test func swiftDataRepositoryUpdatesSeriesStateWhenSavingKnownAdjacentChapterProgressByURL() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "9F141418-431F-4F4B-B3D0-A8D4B0F39442")!
    let chapter102ID = UUID(uuidString: "E7A917D8-F946-4AF4-87E9-F9D6EDC8A102")!
    let chapter103ID = UUID(uuidString: "E7A917D8-F946-4AF4-87E9-F9D6EDC8A103")!
    let chapter104ID = UUID(uuidString: "E7A917D8-F946-4AF4-87E9-F9D6EDC8A104")!
    let chapter104URL = URL(string: "https://asurascans.com/comics/sample/chapter/104")!

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "Sample",
            canonicalURL: URL(string: "https://asurascans.com/comics/sample")!,
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            status: "Ongoing",
            synopsis: "Stored test series.",
            latestKnownChapterLabel: "104",
            libraryState: .reading,
            chapters: [
                .mock(
                    id: chapter102ID,
                    chapterLabel: "102",
                    sourceURL: URL(string: "https://asurascans.com/comics/sample/chapter/102")!,
                    imageURLs: [URL(string: "https://img.example.com/102.jpg")!]
                ),
                .mock(
                    id: chapter103ID,
                    chapterLabel: "103",
                    sourceURL: URL(string: "https://asurascans.com/comics/sample/chapter/103")!,
                    imageURLs: [URL(string: "https://img.example.com/103.jpg")!]
                ),
                .mock(
                    id: chapter104ID,
                    chapterLabel: "104",
                    sourceURL: chapter104URL,
                    imageURLs: [URL(string: "https://img.example.com/104.jpg")!]
                )
            ]
        ),
        context: .reader
    )

    await repository.save(ReaderProgress(currentImageIndex: 2, totalImageCount: 5), for: chapter104URL)

    let detail = try #require(await repository.seriesDetail(for: seriesID))
    let summary = try #require(await repository.librarySnapshot().series.first)
    let recent = detail.chapterList(for: .recent)

    #expect(summary.currentChapterLabel == "104")
    #expect(detail.primaryChapter?.id == chapter104ID)
    #expect(recent.map(\.chapterLabel) == ["104"])
    #expect(await repository.readerSession(forChapterID: chapter104ID) != nil)
}

@MainActor
@Test func swiftDataRepositoryOnlyBuildsDirectReaderSessionForStoredChapterPayloads() async throws {
    let repository = try makeRepository()
    let storedID = UUID(uuidString: "4B76B790-2E50-4418-B5C4-3FAF40FB5501")!
    let generatedID = UUID(uuidString: "4B76B790-2E50-4418-B5C4-3FAF40FB5502")!

    try await repository.addToLibrary(
        .mock(
            chapters: [
                .mock(
                    id: storedID,
                    chapterLabel: "1",
                    sourceURL: URL(string: "https://example.com/series/chapter-1")!,
                    imageURLs: [URL(string: "https://img.example.com/1.jpg")!]
                ),
                .mock(
                    id: generatedID,
                    chapterLabel: "2",
                    sourceURL: URL(string: "https://example.com/series/chapter-2")!,
                    imageURLs: []
                )
            ]
        ),
        context: .reader
    )

    #expect(await repository.readerSession(forChapterID: storedID) != nil)
    #expect(await repository.readerSession(forChapterID: generatedID) == nil)
}

@MainActor
@Test func swiftDataRepositoryStoresRecentSearchHistoryInPriorityOrder() async throws {
    let repository = try makeRepository()
    let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    let secondDate = firstDate.addingTimeInterval(60)

    try await repository.recordSearchHistory(
        SearchHistoryInput(kind: .searchQuery, value: "moonlit edge", displayTitle: "moonlit edge", createdAt: firstDate)
    )
    try await repository.recordSearchHistory(
        SearchHistoryInput(
            kind: .link,
            value: "https://example.com/chapter-1",
            displayTitle: "example.com",
            createdAt: secondDate
        )
    )

    let entries = await repository.recentSearchHistory(limit: 5)

    #expect(entries.map(\.kind) == [.link, .searchQuery])
    #expect(entries.map(\.value) == ["https://example.com/chapter-1", "moonlit edge"])
}

@MainActor
@Test func swiftDataRepositoryStoresUnsavedRecentReadingWithoutAddingToLibrary() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapterID = UUID()
    let sourceURL = URL(string: "https://example.com/recent/chapter-4")!
    let seriesURL = URL(string: "https://example.com/recent")!

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: chapterID,
            seriesTitle: "Recent Unsaved",
            seriesURL: seriesURL,
            sourceDomain: "example.com",
            chapterTitle: "Chapter 4",
            chapterLabel: "4",
            sourceURL: sourceURL,
            imageURLs: [URL(string: "https://img.example.com/4.jpg")!],
            progress: ReaderProgress(currentImageIndex: 1, totalImageCount: 3),
            readAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    )

    let library = await repository.librarySnapshot()
    let recent = library.series(for: .recent)

    #expect(await repository.seriesDetail(for: seriesID)?.isSaved == false)
    #expect(recent.map(\.title) == ["Recent Unsaved"])
    #expect(recent.first?.currentChapterLabel == "4")
}

@MainActor
@Test func savedLibrarySeriesDoesNotDuplicateMatchingRecentReadingEntry() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let sourceURL = URL(string: "https://example.com/saved/chapter-4")!
    let seriesURL = URL(string: "https://example.com/saved")!

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: UUID(),
            seriesTitle: "Saved Series",
            seriesURL: seriesURL,
            sourceDomain: "example.com",
            chapterTitle: "Chapter 4",
            chapterLabel: "4",
            sourceURL: sourceURL,
            imageURLs: [URL(string: "https://img.example.com/4.jpg")!],
            progress: ReaderProgress(currentImageIndex: 1, totalImageCount: 3),
            readAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    )
    try await repository.addToLibrary(
        .mock(id: seriesID, title: "Saved Series"),
        context: .reader
    )

    let recent = await repository.librarySnapshot().series(for: .recent)

    #expect(recent.map(\.title) == ["Saved Series"])
}

@MainActor
@Test func recentReadingMergesDifferentSessionIDsByCanonicalSeriesURL() async throws {
    let repository = try makeRepository()
    let seriesURL = URL(string: "https://example.com/past-life-returner")!

    try await repository.recordRecentReading(
        .mockRecent(
            seriesID: UUID(),
            chapterID: UUID(),
            seriesTitle: "Past Life Returner",
            seriesURL: seriesURL,
            chapterLabel: "1",
            sourceURL: URL(string: "https://example.com/past-life-returner/chapter-1")!,
            readAt: Date(timeIntervalSince1970: 10)
        )
    )
    try await repository.recordRecentReading(
        .mockRecent(
            seriesID: UUID(),
            chapterID: UUID(),
            seriesTitle: "Past Life Returner",
            seriesURL: seriesURL,
            chapterLabel: "166",
            sourceURL: URL(string: "https://example.com/past-life-returner/chapter-166")!,
            readAt: Date(timeIntervalSince1970: 20)
        )
    )

    let recent = await repository.librarySnapshot().series(for: .recent)

    #expect(recent.count == 1)
    #expect(recent.first?.currentChapterLabel == "166")
}

@MainActor
@Test func recentReadingDoesNotEraseExistingCoverWhenInputCoverIsNil() async throws {
    let repository = try makeRepository()
    let seriesURL = try #require(URL(string: "https://asurascans.com/comics/sample"))
    let firstChapterURL = try #require(URL(string: "https://asurascans.com/comics/sample/chapter/97"))
    let secondChapterURL = try #require(URL(string: "https://asurascans.com/comics/sample/chapter/98"))
    let coverURL = try #require(URL(string: "https://asurascans.com/uploads/sample-cover.webp"))
    let seriesID = UUID(uuidString: "7A627159-B4E9-45B1-9FBC-59C0BBA8C174")!

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: UUID(),
            seriesTitle: "Sample",
            seriesURL: seriesURL,
            sourceDomain: "asurascans.com",
            coverImageURL: coverURL,
            chapterTitle: "Chapter 97",
            chapterLabel: "97",
            sourceURL: firstChapterURL,
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
        )
    )

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: UUID(),
            seriesTitle: "Sample",
            seriesURL: seriesURL,
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            chapterTitle: "Chapter 98",
            chapterLabel: "98",
            sourceURL: secondChapterURL,
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
        )
    )

    let recent = await repository.librarySnapshot().series(for: .recent)
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(recent.first?.coverImageURL == coverURL)
    #expect(detail.coverImageURL == coverURL)
}

@MainActor
@Test func librarySnapshotSuppressesDomainPlaceholderWhenRealSeriesExists() async throws {
    let repository = try makeRepository()
    let placeholderID = UUID(uuidString: "D7054926-3B34-427C-A1E5-303F7A6E19C3")!
    let realID = UUID(uuidString: "2449BB74-22E1-481B-B51E-6B7F85D89C6F")!
    let seriesURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
    let coverURL = try #require(URL(string: "https://asurascans.com/uploads/extras-cover.webp"))

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: placeholderID,
            chapterID: UUID(),
            seriesTitle: "asurascans.com",
            seriesURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter")),
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            chapterTitle: "Chapter Scans",
            chapterLabel: "Scans",
            sourceURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/102")),
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
        )
    )

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: realID,
            title: "The Extra’s Academy Survival Guide",
            canonicalURL: seriesURL,
            sourceDomain: "asurascans.com",
            coverImageURL: coverURL,
            status: "Reading",
            synopsis: "Saved from Reader Mode.",
            latestKnownChapterLabel: "102",
            libraryState: .reading,
            chapters: [
                .mock(
                    title: "The Extra’s Academy Survival Guide Chapter 102",
                    chapterLabel: "102",
                    sourceURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/102"))
                )
            ]
        ),
        context: .reader
    )

    let snapshot = await repository.librarySnapshot()

    #expect(snapshot.series(for: .recent).map(\.title) == ["The Extra’s Academy Survival Guide"])
    #expect(snapshot.series(for: .reading).map(\.title) == ["The Extra’s Academy Survival Guide"])
    #expect(await repository.seriesDetail(for: placeholderID) == nil)
}

@MainActor
@Test func librarySnapshotMergesRealTitleRecentReadingWithSavedSeriesBySourceIdentity() async throws {
    let repository = try makeRepository()
    let recentID = UUID(uuidString: "424E0C78-6B00-419D-8C14-C2C9814F298A")!
    let savedID = UUID(uuidString: "4D0660FD-90F1-4B9F-982A-74B8D55F4896")!
    let coverURL = try #require(URL(string: "https://asurascans.com/uploads/extras-cover.webp"))
    let readAt = Date(timeIntervalSince1970: 1_700_000_500)

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: recentID,
            chapterID: UUID(),
            seriesTitle: "The Extra’s Academy Survival Guide | Asura Scans",
            seriesURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter")),
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            chapterTitle: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
            chapterLabel: "Scans",
            sourceURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/102")),
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 2, totalImageCount: 10),
            readAt: readAt
        )
    )

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: savedID,
            title: "The Extra’s Academy Survival Guide | Asura Scans",
            canonicalURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5")),
            sourceDomain: "asurascans.com",
            coverImageURL: coverURL,
            status: "Reading",
            synopsis: "Saved from Reader Mode.",
            latestKnownChapterLabel: "102",
            libraryState: .reading,
            chapters: [
                .mock(
                    title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                    chapterLabel: "Scans",
                    sourceURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/102"))
                )
            ]
        ),
        context: .reader
    )

    let recent = await repository.librarySnapshot().series(for: .recent)
    let summary = try #require(recent.first)

    #expect(recent.count == 1)
    #expect(summary.id == savedID)
    #expect(summary.coverImageURL == coverURL)
    #expect(summary.lastReadAt == readAt)
    #expect(summary.currentChapterLabel == "102")
    #expect(summary.progressPercent == ReaderProgress(currentImageIndex: 2, totalImageCount: 10).fractionComplete)
}

@MainActor
@Test func librarySnapshotDerivesCurrentChapterLabelFromNoisyStoredChapterTitle() async throws {
    let repository = try makeRepository()
    let seriesID = UUID(uuidString: "2B87B372-55E1-4C0E-8E09-454A94259534")!
    let chapterID = UUID(uuidString: "2B87B372-55E1-4C0E-8E09-454A94259535")!
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-46f09241/chapter/102"))

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "The Extra’s Academy Survival Guide | Asura Scans",
            canonicalURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-46f09241")),
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            status: "Reading",
            synopsis: "Saved from Reader Mode.",
            latestKnownChapterLabel: "237",
            libraryState: .reading,
            chapters: [
                .mock(
                    id: chapterID,
                    title: "The Extra’s Academy Survival Guide Chapter 102 - Read Online | Asura Scans",
                    chapterLabel: "Scans",
                    sourceURL: chapterURL,
                    imageURLs: [try #require(URL(string: "https://img.example.com/extras-102.jpg"))]
                )
            ]
        ),
        context: .reader
    )

    await repository.save(ReaderProgress(currentImageIndex: 2, totalImageCount: 10), for: chapterURL)

    let summary = try #require(await repository.librarySnapshot().series(for: .reading).first)
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(summary.latestChapterLabel == "237")
    #expect(summary.currentChapterLabel == "102")
    #expect(LibrarySeriesCardContent(series: summary).comfortableBadgeMetadata == "Ch. 102")
    #expect(detail.primaryActionTitle == "Continue Chapter 102")
}

@MainActor
@Test func homeSnapshotCarriesCoverArtworkForContinueReadingCards() async throws {
    let repository = try makeRepository()
    let coverURL = try #require(URL(string: "https://asurascans.com/uploads/extras-cover.webp"))
    let seriesID = UUID(uuidString: "E8DE89F2-DB57-45CE-A855-5193287CA882")!
    let chapterID = UUID(uuidString: "6E7200BA-D5BC-411C-B3A8-E5DC0A2540A7")!

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "The Extra’s Academy Survival Guide",
            canonicalURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5")),
            sourceDomain: "asurascans.com",
            coverImageURL: coverURL,
            status: "Reading",
            synopsis: "Saved from Reader Mode.",
            latestKnownChapterLabel: "102",
            libraryState: .reading,
            chapters: [
                .mock(
                    id: chapterID,
                    title: "Chapter 102",
                    chapterLabel: "102",
                    sourceURL: try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/102"))
                )
            ]
        ),
        context: .reader
    )
    try await repository.recordReadingProgress(
        ReaderProgress(currentImageIndex: 1, totalImageCount: 10),
        forChapterID: chapterID,
        at: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let home = await repository.homeSnapshot()

    #expect(home.continueReading.first?.coverImageURL == coverURL)
}

@MainActor
@Test func addingSameCanonicalSeriesWithSameChapterURLDoesNotDuplicateSeriesOrChapter() async throws {
    let repository = try makeRepository()
    let canonicalURL = URL(string: "https://example.com/past-life-returner")!
    let chapterURL = URL(string: "https://example.com/past-life-returner/chapter-1")!

    try await repository.addToLibrary(
        .mock(
            id: UUID(),
            title: "Past Life Returner",
            canonicalURL: canonicalURL,
            chapters: [.mock(id: UUID(), chapterLabel: "1", sourceURL: chapterURL)]
        ),
        context: .reader
    )
    try await repository.addToLibrary(
        .mock(
            id: UUID(),
            title: "Past Life Returner",
            canonicalURL: canonicalURL,
            chapters: [.mock(id: UUID(), chapterLabel: "1", sourceURL: chapterURL)]
        ),
        context: .reader
    )

    let snapshot = await repository.librarySnapshot()
    let seriesID = try #require(snapshot.series.first?.id)
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(snapshot.series.count == 1)
    #expect(detail.chapters.map(\.chapterLabel) == ["1"])
}

@MainActor
@Test func repeatedLibrarySnapshotsPreserveDeduplicatedVisibleResults() async throws {
    let repository = try makeRepository()
    let canonicalURL = URL(string: "https://example.com/repeated-snapshot")!
    let chapterURL = URL(string: "https://example.com/repeated-snapshot/chapter-1")!

    try await repository.addToLibrary(
        .mock(
            id: UUID(),
            title: "Repeated Snapshot",
            canonicalURL: canonicalURL,
            chapters: [.mock(id: UUID(), chapterLabel: "1", sourceURL: chapterURL)]
        ),
        context: .reader
    )
    try await repository.addToLibrary(
        .mock(
            id: UUID(),
            title: "Repeated Snapshot",
            canonicalURL: canonicalURL,
            chapters: [.mock(id: UUID(), chapterLabel: "1", sourceURL: chapterURL)]
        ),
        context: .reader
    )

    let first = await repository.librarySnapshot()
    let second = await repository.librarySnapshot()

    #expect(first.series.map(\.canonicalURL) == second.series.map(\.canonicalURL))
    #expect(second.series.count == 1)
    #expect(second.series.first?.title == "Repeated Snapshot")
}

@MainActor
private func makeRepository() throws -> SwiftDataLibraryRepository {
    let schema = Schema([
        StoredSeries.self,
        StoredChapter.self,
        StoredProgress.self,
        StoredSearchHistory.self
        ,StoredRecentReading.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: schema,
        configurations: configuration
    )
    return SwiftDataLibraryRepository(
        modelContext: container.mainContext,
        modelContainer: container,
        usesModelContextIO: false
    )
}

private extension LibrarySeriesInput {
    static func mock(
        id: UUID = UUID(),
        title: String = "Mock Persisted Series",
        canonicalURL: URL? = nil,
        chapters: [LibraryChapterInput] = [.mock()]
    ) -> LibrarySeriesInput {
        LibrarySeriesInput(
            id: id,
            title: title,
            canonicalURL: canonicalURL ?? URL(string: "https://example.com/\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")!,
            sourceDomain: "example.com",
            coverImageURL: nil,
            status: "Ongoing",
            synopsis: "Stored test series.",
            latestKnownChapterLabel: chapters.last?.chapterLabel,
            libraryState: nil,
            chapters: chapters
        )
    }
}

private extension LibraryChapterInput {
    static func mock(
        id: UUID = UUID(),
        title: String? = nil,
        chapterLabel: String = "1",
        sourceURL: URL = URL(string: "https://example.com/chapter-1")!,
        previousChapterURL: URL? = nil,
        nextChapterURL: URL? = nil,
        imageURLs: [URL] = []
    ) -> LibraryChapterInput {
        LibraryChapterInput(
            id: id,
            title: title ?? "Chapter \(chapterLabel)",
            chapterLabel: chapterLabel,
            chapterNumber: Double(chapterLabel),
            sourceURL: sourceURL,
            previousChapterURL: previousChapterURL,
            nextChapterURL: nextChapterURL,
            imageURLs: imageURLs,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

private extension RecentReadingInput {
    static func mockRecent(
        seriesID: UUID,
        chapterID: UUID,
        seriesTitle: String,
        seriesURL: URL,
        chapterLabel: String,
        sourceURL: URL,
        readAt: Date
    ) -> RecentReadingInput {
        RecentReadingInput(
            seriesID: seriesID,
            chapterID: chapterID,
            seriesTitle: seriesTitle,
            seriesURL: seriesURL,
            sourceDomain: seriesURL.host() ?? "example.com",
            chapterTitle: "Chapter \(chapterLabel)",
            chapterLabel: chapterLabel,
            sourceURL: sourceURL,
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 1, totalImageCount: 3),
            readAt: readAt
        )
    }
}
