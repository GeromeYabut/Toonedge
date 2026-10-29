import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

// DEF-047: authored chapter metadata and in-memory storage only; no network or artwork.
enum ResumedReaderStorageCase: String, CaseIterable {
    case recentOnly, savedWithEmptyImages, savedWithImages
}

private struct ResumeFixture {
    let repository: SwiftDataLibraryRepository
    let seriesID = UUID()
    let chapterID = UUID()
    let seriesURL = URL(string: "https://owned.toonedge.test/comics/navigation-fixture")!
    let images = [URL(string: "https://images.owned.toonedge.test/generated-page.jpg")!]

    @MainActor
    init() throws {
        let schema = Schema([StoredSeries.self, StoredChapter.self, StoredProgress.self,
                             StoredSearchHistory.self, StoredRecentReading.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        repository = SwiftDataLibraryRepository(modelContext: container.mainContext,
            modelContainer: container, usesModelContextIO: false)
    }

    func chapterURL(_ path: String) -> URL { seriesURL.appendingPathComponent(path) }

    func save(chapterPath: String, label: String, number: Double?,
              previousPath: String?, nextPath: String?, savedImages: [URL]) async throws {
        try await repository.addToLibrary(LibrarySeriesInput(
            id: seriesID, title: "Owned Navigation Fixture", canonicalURL: seriesURL,
            sourceDomain: "owned.toonedge.test", coverImageURL: nil, status: "Ongoing",
            synopsis: "Authored diagnostic fixture.", latestKnownChapterLabel: label,
            libraryState: nil, chapters: [
                LibraryChapterInput(id: chapterID, title: "Owned Chapter \(label)",
                    chapterLabel: label, chapterNumber: number, sourceURL: chapterURL(chapterPath),
                    previousChapterURL: previousPath.map(chapterURL), nextChapterURL: nextPath.map(chapterURL),
                    imageURLs: savedImages, publishedAt: nil)
            ]), context: .reader)
    }

    func recordRecent(chapterPath: String, label: String, title: String? = nil) async throws {
        try await repository.recordRecentReading(RecentReadingInput(
            seriesID: seriesID, chapterID: chapterID, seriesTitle: "Owned Navigation Fixture",
            seriesURL: seriesURL, sourceDomain: "owned.toonedge.test",
            chapterTitle: title ?? "Owned Chapter \(label)", chapterLabel: label,
            sourceURL: chapterURL(chapterPath), imageURLs: images,
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
            readAt: Date(timeIntervalSince1970: 1_900_000_000)))
    }

    func resumedSession() async throws -> MockReaderSession {
        let target = try #require(await repository.continueReadingTarget(for: seriesID))
        return try #require(await repository.readerSession(forChapterID: target.chapterID))
    }
}

private actor ResumeRecordingAdjacentLoader: AdjacentReaderSessionLoading {
    private let loaded: MockReaderSession
    private(set) var requestedURLs: [URL] = []

    init(loaded: MockReaderSession) {
        self.loaded = loaded
    }

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        requestedURLs.append(url)
        var session = loaded
        session.sourceURL = url
        return session
    }
}

@MainActor
@Test(arguments: ResumedReaderStorageCase.allCases)
func continueReadingResumeKeepsNumericAdjacentTargets(_ scenario: ResumedReaderStorageCase) async throws {
    let fixture = try ResumeFixture()
    if scenario != .recentOnly {
        try await fixture.save(chapterPath: "chapter/199", label: "199", number: 199,
            previousPath: "chapter/198", nextPath: "chapter/200",
            savedImages: scenario == .savedWithImages ? fixture.images : [])
    }
    try await fixture.recordRecent(chapterPath: "chapter/199", label: "199")

    let session = try await fixture.resumedSession()
    let model = ReaderViewModel(session: session)

    #expect(session.imageURLs == fixture.images)
    #expect(session.previousChapter?.sourceURL == fixture.chapterURL("chapter/198"))
    #expect(session.nextChapter?.sourceURL == fixture.chapterURL("chapter/200"))
    #expect(model.canNavigatePrevious)
    #expect(model.canNavigateNext)
}

@MainActor
@Test func savedEmptyImageResumeKeepsSavedMetadataWithRecentImages() async throws {
    let fixture = try ResumeFixture()
    try await fixture.save(chapterPath: "chapter/199", label: "199", number: 199,
        previousPath: "chapter/198", nextPath: "chapter/200", savedImages: [])
    try await fixture.recordRecent(chapterPath: "chapter/199", label: "199")

    let session = try await fixture.resumedSession()

    #expect(session.imageURLs == fixture.images)
    #expect(session.seriesID == fixture.seriesID)
    #expect(session.seriesStatus == "Ongoing")
    #expect(session.seriesSynopsis == "Authored diagnostic fixture.")
    #expect(session.sourceURL == fixture.chapterURL("chapter/199"))
}

@MainActor
@Test func recentOnlyFirstChapterResumeOffersNextWithoutInventingPrevious() async throws {
    let fixture = try ResumeFixture()
    try await fixture.recordRecent(chapterPath: "chapter/1", label: "1")

    let session = try await fixture.resumedSession()

    #expect(session.previousChapter == nil)
    #expect(session.nextChapter?.sourceURL == fixture.chapterURL("chapter/2"))
}

@MainActor
@Test func recentOnlyResumeWithoutChapterNumberInRouteInventsNoTargets() async throws {
    // A numeric label alone is not enough: the route must carry the number to rewrite.
    for (path, label, title) in [("read/episode-alpha", "199", "Owned Chapter 199"),
                                 ("read/side-story", "", "Side Story")] {
        let fixture = try ResumeFixture()
        try await fixture.recordRecent(chapterPath: path, label: label, title: title)

        let session = try await fixture.resumedSession()
        let model = ReaderViewModel(session: session)

        #expect(session.imageURLs == fixture.images, "\(path)")
        #expect(session.previousChapter == nil, "\(path)")
        #expect(session.nextChapter == nil, "\(path)")
        #expect(!model.canNavigatePrevious && !model.canNavigateNext, "\(path)")
    }
}

@MainActor
@Test(arguments: [ReaderChapterDirection.previous, .next])
func recentOnlyResumeTransitionsThroughTheAdjacentLoader(_ direction: ReaderChapterDirection) async throws {
    let fixture = try ResumeFixture()
    try await fixture.recordRecent(chapterPath: "chapter/199", label: "199")
    var session = try await fixture.resumedSession()
    session.launchOrigin = .homeContinueReading
    var loaded = session
    loaded.imageURLs = [URL(string: "https://images.owned.toonedge.test/generated-adjacent.jpg")!]
    loaded.previousChapter = nil
    loaded.nextChapter = nil
    let loader = ResumeRecordingAdjacentLoader(loaded: loaded)
    let expected = fixture.chapterURL(direction == .next ? "chapter/200" : "chapter/198")
    let model = ReaderViewModel(session: session)

    let transitioned = await model.navigateAdjacentChapter(
        direction, libraryLifecycleService: nil, adjacentLoader: loader)

    #expect(transitioned)
    #expect(await loader.requestedURLs == [expected])
    #expect(model.session.sourceURL == expected)
    #expect(model.session.imageURLs == loaded.imageURLs)
    #expect(model.session.launchOrigin == .homeContinueReading)
}

@MainActor
@Test func recentOnlyResumeMissesRatherThanGuessesAmbiguousRoutes() async throws {
    // The slug's "2" is rewritten first, so the target fails its own-number check; decimals never infer.
    for (path, label) in [("solo-2/chapter-2", "2"), ("chapter/12.5", "12.5")] {
        let fixture = try ResumeFixture()
        try await fixture.recordRecent(chapterPath: path, label: label)

        let session = try await fixture.resumedSession()

        #expect(session.imageURLs == fixture.images, "\(path)")
        #expect(session.previousChapter == nil, "\(path)")
        #expect(session.nextChapter == nil, "\(path)")
    }
}

@MainActor
@Test func recentOnlyChapterZeroResumeOffersNextOnly() async throws {
    let fixture = try ResumeFixture()
    try await fixture.recordRecent(chapterPath: "chapter/0", label: "0")

    let session = try await fixture.resumedSession()

    #expect(session.previousChapter == nil)
    #expect(session.nextChapter?.sourceURL == fixture.chapterURL("chapter/1"))
}

@MainActor
@Test func savedEmptyImageChapterDoesNotBorrowImagesFromAnotherRecentURL() async throws {
    let fixture = try ResumeFixture()
    try await fixture.save(chapterPath: "chapter/199", label: "199", number: 199,
        previousPath: "chapter/198", nextPath: "chapter/200", savedImages: [])
    try await fixture.recordRecent(chapterPath: "chapter/205", label: "205")

    let session = try #require(await fixture.repository.readerSession(forChapterID: fixture.chapterID))

    // Images, URL and neighbours all describe the recent page they came from.
    #expect(session.imageURLs == fixture.images)
    #expect(session.sourceURL == fixture.chapterURL("chapter/205"))
    #expect(session.previousChapter?.sourceURL == fixture.chapterURL("chapter/204"))
    #expect(session.nextChapter?.sourceURL == fixture.chapterURL("chapter/206"))
}

@MainActor
@Test func savedEmptyImageChapterResolvesBySourceURLWithSavedNeighbours() async throws {
    let fixture = try ResumeFixture()
    try await fixture.save(chapterPath: "chapter/199", label: "199", number: 199,
        previousPath: "chapter/198", nextPath: "chapter/200", savedImages: [])
    try await fixture.recordRecent(chapterPath: "chapter/199", label: "199")

    let session = try #require(await fixture.repository.readerSession(forSourceURL: fixture.chapterURL("chapter/199")))

    #expect(session.imageURLs == fixture.images)
    #expect(session.previousChapter?.sourceURL == fixture.chapterURL("chapter/198"))
    #expect(session.nextChapter?.sourceURL == fixture.chapterURL("chapter/200"))
}

@MainActor
@Test func savedEmptyImageChapterWithoutRecentImagesHasNoSession() async throws {
    let fixture = try ResumeFixture()
    try await fixture.save(chapterPath: "chapter/199", label: "199", number: 199,
        previousPath: "chapter/198", nextPath: "chapter/200", savedImages: [])

    #expect(await fixture.repository.readerSession(forChapterID: fixture.chapterID) == nil)
}
