import Foundation
import Testing
@testable import ToonEdgeAppCore

@Test func librarySnapshotFiltersSeriesBySegment() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let reading = LibrarySeriesSummary.mock(
        title: "Reading Title",
        libraryState: .reading,
        progressPercent: 0.42,
        lastReadAt: now.addingTimeInterval(-60)
    )
    let planned = LibrarySeriesSummary.mock(
        title: "Planned Title",
        libraryState: .planned,
        progressPercent: 0,
        lastReadAt: nil
    )
    let updated = LibrarySeriesSummary.mock(
        title: "Updated Title",
        libraryState: .reading,
        progressPercent: 0.8,
        hasUnreadUpdates: true,
        lastReadAt: now.addingTimeInterval(-3_600)
    )
    let snapshot = LibrarySnapshot(series: [planned, reading, updated])

    #expect(snapshot.series(for: .reading).map(\.title) == ["Reading Title", "Updated Title"])
    #expect(snapshot.series(for: .planned).map(\.title) == ["Planned Title"])
    #expect(snapshot.series(for: .recent).map(\.title) == ["Reading Title", "Updated Title"])
}

@Test func seriesDetailPrimaryActionContinuesInProgressChapter() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "141", readState: .read),
            ChapterSummary.mock(chapterLabel: "142", readState: .inProgress(progressPercent: 0.35)),
            ChapterSummary.mock(chapterLabel: "143", readState: .unread)
        ]
    )

    #expect(detail.primaryActionTitle == "Continue Chapter 142")
    #expect(detail.primaryChapter?.chapterLabel == "142")
}

@Test func seriesDetailPrimaryActionStartsFirstUnreadWhenNoProgressExists() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "144", readState: .new),
            ChapterSummary.mock(chapterLabel: "143", readState: .unread),
            ChapterSummary.mock(chapterLabel: "142", readState: .read)
        ]
    )

    #expect(detail.primaryActionTitle == "Start Chapter 144")
    #expect(detail.primaryChapter?.chapterLabel == "144")
}

@Test func chapterListSortsNewestAndOldest() {
    let chapters = [
        ChapterSummary.mock(chapterLabel: "1", chapterNumber: 1),
        ChapterSummary.mock(chapterLabel: "3", chapterNumber: 3),
        ChapterSummary.mock(chapterLabel: "2", chapterNumber: 2)
    ]
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)

    #expect(detail.chapters(sortedBy: .newestFirst).map(\.chapterLabel) == ["3", "2", "1"])
    #expect(detail.chapters(sortedBy: .oldestFirst).map(\.chapterLabel) == ["1", "2", "3"])
}

@Test func chapterRowStateExposesDistinctLabels() {
    #expect(ChapterReadState.new.displayLabel == "New")
    #expect(ChapterReadState.unread.displayLabel == "Unread")
    #expect(ChapterReadState.inProgress(progressPercent: 0.4).displayLabel == "40%")
    #expect(ChapterReadState.read.displayLabel == "Read")
    #expect(ChapterSummary.mock(isDownloaded: true).downloadLabel == "Downloaded")
}

@Test func homeContinueReadingUsesRecentDistinctSeriesOrderingAndLimit() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let duplicateOlder = LibrarySeriesSummary.mock(
        id: UUID(uuidString: "4B81C535-7563-4184-9975-09409E5B9876")!,
        title: "A Recent",
        canonicalURL: URL(string: "https://example.com/a")!,
        lastReadAt: now.addingTimeInterval(-90),
        currentChapterLabel: "4"
    )
    let duplicateNewer = LibrarySeriesSummary.mock(
        id: UUID(uuidString: "B7427A73-B65B-47CC-9B45-AE87DA647FF1")!,
        title: "A Recent",
        canonicalURL: URL(string: "https://example.com/a")!,
        lastReadAt: now,
        currentChapterLabel: "5"
    )
    let b = LibrarySeriesSummary.mock(title: "B Recent", lastReadAt: now.addingTimeInterval(-10), currentChapterLabel: "9")
    let c = LibrarySeriesSummary.mock(title: "C Recent", lastReadAt: now.addingTimeInterval(-20), currentChapterLabel: "2")
    let d = LibrarySeriesSummary.mock(title: "D Recent", lastReadAt: now.addingTimeInterval(-30), currentChapterLabel: "7")
    let e = LibrarySeriesSummary.mock(title: "E Recent", lastReadAt: now.addingTimeInterval(-40), currentChapterLabel: "1")
    let snapshot = LibrarySnapshot(series: [e, d, c, b, duplicateOlder], recentReadSeries: [duplicateNewer])

    let summaries = HomeContinueReadingBuilder.summaries(from: snapshot)

    #expect(summaries.map(\.title) == ["A Recent", "B Recent", "C Recent", "D Recent"])
    #expect(summaries.first?.subtitle == "Continue Chapter 5")
    #expect(summaries.count == 4)
}

@Test func homeContinueReadingViewAllAvailabilityTracksRecentEntries() {
    let populated = HomeSnapshot(
        continueReading: [SeriesSummary(title: "A", subtitle: "Continue Chapter 1", progressPercent: 0.2, hasUnreadUpdates: false)],
        recentlyUpdated: [],
        library: []
    )
    let empty = HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])

    #expect(populated.showsContinueReadingViewAll)
    #expect(!empty.showsContinueReadingViewAll)
}

private extension LibrarySeriesSummary {
    static func mock(
        id: UUID = UUID(),
        title: String = "Moonlit Edge",
        canonicalURL: URL? = nil,
        libraryState: LibraryCollectionState = .reading,
        progressPercent: Double = 0.5,
        hasUnreadUpdates: Bool = false,
        lastReadAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
        currentChapterLabel: String? = "42"
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: id,
            title: title,
            sourceDomain: "example.com",
            canonicalURL: canonicalURL,
            coverImageURL: nil,
            progressPercent: progressPercent,
            chaptersRead: Int(progressPercent * 100),
            totalKnownChapters: 100,
            lastReadAt: lastReadAt,
            libraryState: libraryState,
            hasUnreadUpdates: hasUnreadUpdates,
            isCompleted: progressPercent >= 1,
            latestChapterLabel: "100",
            currentChapterLabel: currentChapterLabel
        )
    }
}

private extension SeriesDetailSnapshot {
    static func mock(chapters: [ChapterSummary]) -> SeriesDetailSnapshot {
        SeriesDetailSnapshot(
            id: UUID(),
            title: "Moonlit Edge",
            status: "Ongoing",
            synopsis: "A compact mock synopsis.",
            sourceDomain: "example.com",
            coverImageURL: nil,
            isSaved: true,
            libraryState: .reading,
            progressPercent: 0.35,
            chaptersRead: 12,
            totalKnownChapters: chapters.count,
            hasUnreadUpdates: chapters.contains { $0.readState == .new },
            chapters: chapters
        )
    }
}

private extension ChapterSummary {
    static func mock(
        chapterLabel: String = "1",
        chapterNumber: Double? = 1,
        readState: ChapterReadState = .unread,
        isDownloaded: Bool = false
    ) -> ChapterSummary {
        ChapterSummary(
            id: UUID(),
            title: "Chapter \(chapterLabel)",
            chapterLabel: chapterLabel,
            chapterNumber: chapterNumber,
            sourceURL: URL(string: "https://example.com/chapter-\(chapterLabel)")!,
            readState: readState,
            isDownloaded: isDownloaded,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
