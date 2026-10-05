import Foundation
import Testing
@testable import ToonEdgeAppCore

struct LibraryCollectionQueryTests {
    @Test func defaultUsesRecentActivityNewest() {
        #expect(LibraryCollectionQuery.default.segment == .recent)
        #expect(LibraryCollectionQuery.default.sortKey == .activity)
        #expect(LibraryCollectionQuery.default.sortDirection == .descending)
    }

    @Test(arguments: [LibrarySortDirection.ascending, .descending])
    func activityOrdersKnownDatesBeforeUnknown(direction: LibrarySortDirection) {
        let older = item(1, title: "Older", activity: 10)
        let newer = item(2, title: "Newer", activity: 20)
        let unknown = item(3, title: "Unknown")
        let snapshot = LibrarySnapshot(series: [unknown, newer, older])
        let query = LibraryCollectionQuery(segment: .reading, sortKey: .activity, sortDirection: direction)
        #expect(query.apply(to: snapshot).map(\.id) == (direction == .ascending
            ? [older.id, newer.id, unknown.id] : [newer.id, older.id, unknown.id]))
    }

    @Test(arguments: [LibrarySortDirection.ascending, .descending])
    func activityTiesUseNormalizedTitleThenUUID(direction: LibrarySortDirection) {
        let beta = item(1, title: "Beta", activity: 10)
        let alphaHighID = item(3, title: "  ÁLPHA\t story  ", activity: 10)
        let alphaLowID = item(2, title: "alpha story", activity: 10)
        let unknownBeta = item(4, title: "Beta")
        let unknownAlpha = item(5, title: "Alpha")
        let snapshot = LibrarySnapshot(series: [unknownBeta, beta, alphaHighID, unknownAlpha, alphaLowID])
        let query = LibraryCollectionQuery(segment: .reading, sortKey: .activity, sortDirection: direction)
        #expect(query.apply(to: snapshot).map(\.id) == [alphaLowID.id, alphaHighID.id, beta.id, unknownAlpha.id, unknownBeta.id])
    }

    @Test(arguments: [LibrarySortDirection.ascending, .descending])
    func titleReversesTitleOnlyAndKeepsUUIDTiesStable(direction: LibrarySortDirection) {
        let alphaLowID = item(1, title: "alpha story", activity: 30)
        let alphaHighID = item(2, title: "  ÁLPHA\n story ", activity: 40)
        let beta = item(3, title: "Beta")
        let snapshot = LibrarySnapshot(series: [beta, alphaHighID, alphaLowID])
        let query = LibraryCollectionQuery(segment: .reading, sortKey: .title, sortDirection: direction)
        #expect(query.apply(to: snapshot).map(\.id) == (direction == .ascending
            ? [alphaLowID.id, alphaHighID.id, beta.id] : [beta.id, alphaLowID.id, alphaHighID.id]))
    }

    @Test(arguments: [LibrarySortDirection.ascending, .descending])
    func unreadFirstRetainsReadTitlesAndIgnoresDirection(direction: LibrarySortDirection) {
        let readNew = item(1, title: "Read newer", activity: 50)
        let readUnknown = item(2, title: "Read unknown")
        let unreadOld = item(3, title: "Unread older", activity: 10, unread: true)
        let unreadUnknown = item(4, title: "Unread unknown", unread: true)
        let unreadNew = item(5, title: "Unread newer", activity: 20, unread: true)
        let unreadAlphaHigh = item(7, title: "ÁLPHA", activity: 20, unread: true)
        let unreadAlphaLow = item(6, title: "alpha", activity: 20, unread: true)
        let snapshot = LibrarySnapshot(series: [readUnknown, unreadOld, readNew, unreadUnknown, unreadNew, unreadAlphaHigh, unreadAlphaLow])
        let query = LibraryCollectionQuery(segment: .reading, sortKey: .unreadUpdates, sortDirection: direction)
        #expect(query.apply(to: snapshot).map(\.id) == [unreadAlphaLow.id, unreadAlphaHigh.id, unreadNew.id, unreadOld.id, unreadUnknown.id, readNew.id, readUnknown.id])
    }

    @Test(arguments: [LibrarySortDirection.ascending, .descending])
    func titleWidthEquivalentTiesUseUUIDInBothDirections(direction: LibrarySortDirection) {
        // Both UUID assignments matter: reversing title must never reverse a normalized tie.
        let wideLow = item(1, title: "Ａｌｐｈａ")
        let narrowHigh = item(2, title: "Alpha")
        let narrowLow = item(3, title: "Alpha")
        let wideHigh = item(4, title: "Ａｌｐｈａ")
        let query = LibraryCollectionQuery(segment: .reading, sortKey: .title, sortDirection: direction)

        #expect(query.apply(to: LibrarySnapshot(series: [narrowHigh, wideLow])).map(\.id)
            == [wideLow.id, narrowHigh.id])
        #expect(query.apply(to: LibrarySnapshot(series: [wideHigh, narrowLow])).map(\.id)
            == [narrowLow.id, wideHigh.id])
    }

    @Test(arguments: [LibrarySortKey.activity, .unreadUpdates], [LibrarySortDirection.ascending, .descending])
    func activityAndUnreadWidthEquivalentTiesUseUUID(key: LibrarySortKey, direction: LibrarySortDirection) {
        let wideLow = item(1, title: "Ａｌｐｈａ", activity: 10, unread: true)
        let narrowHigh = item(2, title: "Alpha", activity: 10, unread: true)
        let query = LibraryCollectionQuery(segment: .reading, sortKey: key, sortDirection: direction)

        #expect(query.apply(to: LibrarySnapshot(series: [narrowHigh, wideLow])).map(\.id)
            == [wideLow.id, narrowHigh.id])
    }

    @Test(arguments: LibrarySegment.allCases)
    func composesExistingSegmentMembershipAndLeavesSnapshotUnchanged(segment: LibrarySegment) {
        let reading = item(1, title: "Zulu", activity: 10)
        let planned = item(2, title: "Beta", state: .planned)
        let dropped = item(3, title: "Gamma", state: .dropped)
        let completed = item(4, title: "Delta", state: .completed)
        let recent = item(5, title: "Alpha", activity: 20, state: .planned)
        let snapshot = LibrarySnapshot(series: [reading, planned, dropped, completed], recentReadSeries: [recent, reading])
        let original = snapshot
        let query = LibraryCollectionQuery(segment: segment, sortKey: .title, sortDirection: .ascending)
        let result = query.apply(to: snapshot)
        #expect(Set(result.map(\.id)) == Set(snapshot.series(for: segment).map(\.id)))
        #expect(result.count == snapshot.series(for: segment).count)
        if segment == .recent { #expect(result.map(\.id) == [recent.id, reading.id]) }
        #expect(snapshot == original)
    }

    private func item(
        _ id: Int, title: String, activity: TimeInterval? = nil,
        unread: Bool = false, state: LibraryCollectionState = .reading
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            title: title, sourceDomain: "example.test", coverImageURL: nil,
            progressPercent: 0, chaptersRead: 0, totalKnownChapters: nil,
            lastReadAt: activity.map { Date(timeIntervalSince1970: $0) },
            libraryState: state, hasUnreadUpdates: unread, isCompleted: state == .completed,
            latestChapterLabel: nil, currentChapterLabel: nil
        )
    }
}
