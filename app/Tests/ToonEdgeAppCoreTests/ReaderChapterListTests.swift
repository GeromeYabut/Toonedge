import Foundation
import Testing
@testable import ToonEdgeAppCore

private func chapterURL(_ number: Int) -> URL {
    URL(string: "https://example.com/series/chapter-\(number)")!
}

private func summary(
    _ number: Int,
    state: ChapterReadState = .unread,
    isDownloaded: Bool = false,
    isOpenable: Bool = true
) -> ChapterSummary {
    ChapterSummary(
        title: "Chapter \(number)",
        chapterLabel: "\(number)",
        chapterNumber: Double(number),
        sourceURL: chapterURL(number),
        readState: state,
        isDownloaded: isDownloaded,
        publishedAt: nil,
        isOpenable: isOpenable
    )
}

private func detail(id: UUID = UUID(), chapters: [ChapterSummary]) -> SeriesDetailSnapshot {
    SeriesDetailSnapshot(
        id: id,
        title: "Moonlit Edge",
        status: "Reading",
        synopsis: "",
        sourceDomain: "example.com",
        coverImageURL: nil,
        isSaved: true,
        libraryState: .reading,
        progressPercent: 0,
        chaptersRead: 0,
        totalKnownChapters: nil,
        hasUnreadUpdates: false,
        chapters: chapters
    )
}

private func session(chapter number: Int) -> MockReaderSession {
    var session = MockReaderSession.sample
    session.chapterTitle = "Chapter \(number)"
    session.sourceURL = chapterURL(number)
    session.previousChapter = nil
    session.nextChapter = nil
    return session
}

@Test func chapterListShowsNewestFirstAndMarksCurrentChapterWithLiveProgress() {
    let seriesID = UUID()
    let model = ReaderChapterListModel(
        session: session(chapter: 12),
        progress: ReaderProgress(currentImageIndex: 16, totalImageCount: 26),
        detail: detail(id: seriesID, chapters: [
            summary(11, state: .read),
            summary(12, state: .inProgress(progressPercent: 0.1)),
            summary(13),
            summary(14, state: .new)
        ])
    )

    #expect(model.seriesDetailID == seriesID)
    #expect(model.rows.map(\.title) == ["Chapter 14", "Chapter 13", "Chapter 12", "Chapter 11"])
    #expect(model.rows.map(\.statusText) == ["New", "Unread", "Reading · 64%", "Read"])
    #expect(model.rows.map(\.isCurrent) == [false, false, true, false])
    #expect(model.currentRowID == model.rows[2].id)
}

@Test func chapterListRowsKnowWhichWayTheyJumpFromTheCurrentChapter() {
    let model = ReaderChapterListModel(
        session: session(chapter: 2),
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
        detail: detail(chapters: [summary(1), summary(2), summary(3)])
    )

    #expect(model.rows.map(\.direction) == [.next, nil, .previous])
}

@Test func chapterListKeepsDownloadedMarkerAndDisablesUnopenableChapters() {
    let model = ReaderChapterListModel(
        session: session(chapter: 2),
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
        detail: detail(chapters: [
            summary(1, isDownloaded: true),
            summary(2),
            summary(3, isOpenable: false)
        ])
    )

    #expect(model.rows.map(\.isEnabled) == [false, true, true])
    #expect(model.rows.map(\.statusText)[0] == "Unavailable")
    #expect(model.rows[2].isDownloaded)
    #expect(model.rows[2].accessibilityLabel == "Chapter 1, Unread, downloaded")
}

@Test func unsavedSeriesFallsBackToNeighborsWithoutSeriesDetailsLink() {
    var current = session(chapter: 5)
    current.previousChapter = MockChapter(title: "Chapter 4", sourceURL: chapterURL(4))
    current.nextChapter = MockChapter(title: "Chapter 6", sourceURL: chapterURL(6))

    let model = ReaderChapterListModel(
        session: current,
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 2),
        detail: nil
    )

    #expect(model.seriesDetailID == nil)
    #expect(model.seriesTitle == current.seriesTitle)
    #expect(model.rows.map(\.title) == ["Chapter 6", "Chapter 5", "Chapter 4"])
    #expect(model.rows.map(\.statusText) == [nil, "Reading · 0%", nil])
    #expect(model.rows.map(\.direction) == [.next, nil, .previous])
}

@Test func savedSeriesMissingTheCurrentChapterStillListsItInNumericOrder() {
    let model = ReaderChapterListModel(
        session: session(chapter: 3),
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
        detail: detail(chapters: [summary(1), summary(2), summary(5)])
    )

    let titles = model.rows.map(\.title)
    #expect(titles.filter { $0 == "Chapter 3" }.count == 1)
    #expect(titles.firstIndex(of: "Chapter 5")! < titles.firstIndex(of: "Chapter 3")!)
    #expect(titles.firstIndex(of: "Chapter 3")! < titles.firstIndex(of: "Chapter 2")!)
    #expect(model.rows.first { $0.title == "Chapter 3" }?.isCurrent == true)
}

@Test func savedSeriesKeepsSessionNeighborsItHasNotRecorded() {
    var current = session(chapter: 7)
    current.nextChapter = MockChapter(title: "Chapter 8", sourceURL: chapterURL(8))

    let model = ReaderChapterListModel(
        session: current,
        progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
        detail: detail(chapters: [summary(7)])
    )

    #expect(model.rows.map(\.title) == ["Chapter 8", "Chapter 7"])
}

@Test func readerChromeReplacesLibraryWithChapterList() {
    let layout = ReaderChromeLayout.actions(
        launchOrigin: .direct,
        isLibraryAvailable: true,
        isSavedToLibrary: false,
        canNavigatePrevious: false,
        canNavigateNext: false
    )

    #expect(layout.top == [.back, .chapterList, .more])
    #expect(layout.isEnabled(.chapterList))
    #expect(layout.identifier(for: .chapterList) == "reader.chapters")
}

@MainActor
@Test func openingAChapterKeepsLaunchOriginSoBackStillReturnsToSeriesDetail() async {
    var current = session(chapter: 2)
    let seriesID = UUID()
    current.launchOrigin = .library(seriesID: seriesID)
    var loaded = session(chapter: 9)
    loaded.imageURLs = [URL(string: "https://cdn.example.com/9.webp")!]
    loaded.launchOrigin = .direct

    let viewModel = ReaderViewModel(session: current)
    let opened = await viewModel.openChapter(
        MockChapter(title: "Chapter 9", sourceURL: chapterURL(9)),
        direction: .next,
        libraryLifecycleService: nil,
        adjacentLoader: ChapterListStubLoader(outcomes: [.success(loaded)])
    )

    #expect(opened)
    #expect(viewModel.session.sourceURL == chapterURL(9))
    #expect(viewModel.session.launchOrigin == .library(seriesID: seriesID))
}

@MainActor
@Test func retryAfterFailedJumpReloadsTheChosenChapterNotTheNeighbor() async {
    var current = session(chapter: 2)
    current.nextChapter = MockChapter(title: "Chapter 3", sourceURL: chapterURL(3))
    var loaded = session(chapter: 9)
    loaded.imageURLs = [URL(string: "https://cdn.example.com/9.webp")!]

    let loader = ChapterListStubLoader(outcomes: [.failure(URLError(.timedOut)), .success(loaded)])
    let viewModel = ReaderViewModel(session: current, adjacentRetryDelayNanoseconds: 0)

    let first = await viewModel.openChapter(
        MockChapter(title: "Chapter 9", sourceURL: chapterURL(9)),
        direction: .next,
        libraryLifecycleService: nil,
        adjacentLoader: loader
    )
    #expect(!first)
    #expect(viewModel.session.sourceURL == chapterURL(2))
    #expect(viewModel.adjacentFailure?.targetURL == chapterURL(9))

    let retried = await viewModel.retryAdjacentChapter(libraryLifecycleService: nil, adjacentLoader: loader)

    #expect(retried)
    #expect(await loader.requestedURLs == [chapterURL(9), chapterURL(9)])
    #expect(viewModel.session.sourceURL == chapterURL(9))
}

@MainActor
@Test func chapterListDetailPrefersLibraryOriginThenSessionThenStoredChapter() async {
    let originID = UUID()
    let storedID = UUID()
    var stored = session(chapter: 2)
    stored.seriesID = storedID

    var fromLibrary = session(chapter: 2)
    fromLibrary.launchOrigin = .library(seriesID: originID)
    let library = ChapterListStubLibrary(
        details: [originID: detail(id: originID, chapters: []), storedID: detail(id: storedID, chapters: [])],
        storedSessions: [chapterURL(2): stored]
    )
    let libraryDetail = await ReaderViewModel(session: fromLibrary, libraryLifecycleService: library).chapterListDetail()
    #expect(libraryDetail?.id == originID)

    // A browser-detected session carries a throwaway series ID, so the saved chapter identifies the series.
    let detectedDetail = await ReaderViewModel(session: session(chapter: 2), libraryLifecycleService: library).chapterListDetail()
    #expect(detectedDetail?.id == storedID)

    let unsavedDetail = await ReaderViewModel(session: session(chapter: 99), libraryLifecycleService: library).chapterListDetail()
    #expect(unsavedDetail == nil)
}

private actor ChapterListStubLoader: AdjacentReaderSessionLoading {
    private var outcomes: [Result<MockReaderSession, Error>]
    private(set) var requestedURLs: [URL] = []

    init(outcomes: [Result<MockReaderSession, Error>]) {
        self.outcomes = outcomes
    }

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        requestedURLs.append(url)
        return try outcomes.removeFirst().get()
    }
}

private actor ChapterListStubLibrary: LibraryLifecycleManaging {
    private let details: [UUID: SeriesDetailSnapshot]
    private let storedSessions: [URL: MockReaderSession]

    init(details: [UUID: SeriesDetailSnapshot], storedSessions: [URL: MockReaderSession]) {
        self.details = details
        self.storedSessions = storedSessions
    }

    func homeSnapshot() async -> HomeSnapshot { .init(continueReading: [], recentlyUpdated: [], library: []) }
    func librarySnapshot() async -> LibrarySnapshot { .init(series: []) }
    func librarySearchItems() async -> [LibrarySearchItem] { [] }
    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? { details[seriesID] }
    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {}
    func removeFromLibrary(seriesID: UUID) async throws {}
    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {}
    func recordUpdateCheckResult(seriesID: UUID, latestChapterLabel: String?, hasUnreadUpdates: Bool, checkedAt: Date) async throws {}
    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {}
    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? { nil }
    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? { nil }
    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? { storedSessions[sourceURL] }
    func isSaved(canonicalURL: URL) async -> Bool { false }
}
