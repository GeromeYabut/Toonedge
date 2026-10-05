import Foundation
import Testing
@testable import ToonEdgeAppCore

struct LibrarySourceFilteringTests {
    @Test func librarySourcesComposeUnionWithSegmentAndTitleOrder() {
        let a = item(1, title: "Zulu", source: " A.EXAMPLE.TEST ")
        let b = item(2, title: "Alpha", source: "b.example.test")
        let c = item(3, title: "Excluded", source: "c.example.test")
        let planned = item(4, title: "Planned", source: "a.example.test", state: .planned)
        let snapshot = LibrarySnapshot(series: [a, c, planned, b])
        let query = LibraryCollectionQuery(segment: .reading, sortKey: .title, sortDirection: .ascending,
            selectedSourceDomains: ["a.example.test", " B.EXAMPLE.TEST "])
        #expect(query.apply(to: snapshot).map(\.id) == [b.id, a.id])
        #expect(snapshot.series == [a, c, planned, b])
    }

    @Test func librarySourcesDefaultAndBlankDomains() {
        let blank = item(1, title: "Blank", source: " \n")
        let known = item(2, title: "Known", source: "a.example.test")
        let snapshot = LibrarySnapshot(series: [blank, known])
        var query = LibraryCollectionQuery(segment: .reading, sortKey: .title, sortDirection: .ascending)
        #expect(LibraryCollectionQuery.default.selectedSourceDomains.isEmpty)
        #expect(query.apply(to: snapshot).map(\.id) == [blank.id, known.id])
        query.selectedSourceDomains = [" A.EXAMPLE.TEST ", "", " \n", "a.example.test"]
        #expect(query.selectedSourceDomains == ["a.example.test"])
        #expect(query.apply(to: snapshot).map(\.id) == [known.id])
        query.selectedSourceDomains = [" "]
        #expect(query.apply(to: snapshot).map(\.id) == [blank.id, known.id])
    }

    @Test func librarySourcesOptionsUseCompleteSavedSnapshot() {
        let snapshot = LibrarySnapshot(series: [
            item(1, title: "One", source: " Z.EXAMPLE.TEST "),
            item(2, title: "Two", source: "a.example.test", state: .planned),
            item(3, title: "Three", source: "z.example.test", state: .completed),
            item(4, title: "Blank", source: " ")
        ], recentReadSeries: [item(5, title: "History", source: "history.example.test")])
        let options = LibraryCollectionQuery.sourceOptions(in: snapshot)
        #expect(options == [LibrarySourceOption(domain: "a.example.test", titleCount: 1),
            LibrarySourceOption(domain: "z.example.test", titleCount: 2)])
        #expect(options.map(\.id) == ["a.example.test", "z.example.test"])
    }

    @Test func librarySourcesAllSortsRetainSelectionAndOrder() {
        let older = item(1, title: "Zulu", source: "a.example.test", activity: 10)
        let newer = item(2, title: "Alpha", source: "a.example.test", activity: 20, unread: true)
        let excluded = item(3, title: "Excluded", source: "b.example.test", activity: 30)
        let snapshot = LibrarySnapshot(series: [excluded, older, newer])
        let policies: [(LibrarySortKey, LibrarySortDirection, [UUID])] = [
            (.activity, .ascending, [older.id, newer.id]), (.activity, .descending, [newer.id, older.id]),
            (.title, .ascending, [newer.id, older.id]), (.title, .descending, [older.id, newer.id]),
            (.unreadUpdates, .descending, [newer.id, older.id])]
        for (key, direction, ids) in policies {
            let query = LibraryCollectionQuery(segment: .reading, sortKey: key, sortDirection: direction,
                selectedSourceDomains: [" A.EXAMPLE.TEST "])
            #expect(query.selectedSourceDomains == ["a.example.test"])
            #expect(query.apply(to: snapshot).map(\.id) == ids)
        }
    }

    @Test func librarySourcesRepairPreservesOtherFieldsAndSnapshot() {
        let snapshot = LibrarySnapshot(series: [item(1, title: "One", source: "a.example.test", state: .planned)])
        let original = snapshot
        let query = LibraryCollectionQuery(segment: .completed, sortKey: .title, sortDirection: .ascending,
            selectedSourceDomains: [" A.EXAMPLE.TEST ", "obsolete.example.test"])
        let repaired = query.repairingSources(in: snapshot)
        #expect(repaired.selectedSourceDomains == ["a.example.test"])
        #expect(repaired.segment == query.segment)
        #expect(repaired.sortKey == query.sortKey)
        #expect(repaired.sortDirection == query.sortDirection)
        #expect(query.selectedSourceDomains == ["a.example.test", "obsolete.example.test"])
        #expect(snapshot == original)
        var obsolete = query
        obsolete.selectedSourceDomains = ["obsolete.example.test"]
        #expect(obsolete.repairingSources(in: snapshot).selectedSourceDomains.isEmpty)
        #expect(LibraryCollectionQuery.default.repairingSources(in: snapshot) == .default)
    }

    @Test func librarySourcesPreferencesRoundTripAndDeterministicStorage() throws {
        let (defaults, name) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = LibraryViewPreferences(userDefaults: defaults)
        let query = LibraryCollectionQuery(segment: .planned, sortKey: .title, sortDirection: .ascending,
            selectedSourceDomains: [" Z.EXAMPLE.TEST ", "a.example.test", ""])
        preferences.save(collectionQuery: query)
        #expect(LibraryViewPreferences(userDefaults: defaults).collectionQuery == query)
        #expect(defaults.stringArray(forKey: "ToonEdge.Library.selectedSourceDomains") == ["a.example.test", "z.example.test"])
    }

    @Test func librarySourcesPreferencesMissingAndCorruptTypes() throws {
        let (defaults, name) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = LibraryViewPreferences(userDefaults: defaults)
        #expect(preferences.collectionQuery == .default)
        for corrupt: Any in [42, true, "a.example.test", ["domain": "a.example.test"], [1, 2]] {
            defaults.set(corrupt, forKey: "ToonEdge.Library.selectedSourceDomains")
            #expect(preferences.collectionQuery.selectedSourceDomains.isEmpty)
        }
        defaults.set([" A.EXAMPLE.TEST ", "a.example.test", " "], forKey: "ToonEdge.Library.selectedSourceDomains")
        #expect(preferences.collectionQuery.selectedSourceDomains == ["a.example.test"])
    }

    @Test(arguments: LibraryViewMode.allCases)
    func librarySourcesResetPreservesDensity(mode: LibraryViewMode) throws {
        let (defaults, name) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = LibraryViewPreferences(userDefaults: defaults)
        preferences.selectedViewMode = mode
        preferences.save(collectionQuery: LibraryCollectionQuery(segment: .planned, sortKey: .title,
            sortDirection: .ascending, selectedSourceDomains: ["a.example.test"]))
        #expect(preferences.collectionQuery.segment == .planned)
        #expect(preferences.collectionQuery.sortKey == .title)
        #expect(preferences.collectionQuery.sortDirection == .ascending)
        preferences.resetOrganization()
        #expect(preferences.collectionQuery == .default)
        #expect(preferences.selectedViewMode == mode)
    }

    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let name = "LibrarySourceFilteringTests.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    private func item(_ id: Int, title: String, source: String, state: LibraryCollectionState = .reading,
                      activity: TimeInterval = 10, unread: Bool = false) -> LibrarySeriesSummary {
        LibrarySeriesSummary(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            title: title, sourceDomain: source, coverImageURL: nil, progressPercent: 0,
            chaptersRead: 0, totalKnownChapters: nil, lastReadAt: Date(timeIntervalSince1970: activity),
            libraryState: state, hasUnreadUpdates: unread, isCompleted: state == .completed,
            latestChapterLabel: nil, currentChapterLabel: nil)
    }
}
