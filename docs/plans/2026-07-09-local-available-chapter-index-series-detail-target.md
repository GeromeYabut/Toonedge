# Local Available-Chapter Index and Series Detail Reading Target Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Story 11.40 so refresh and Series Detail opening index available chapter links locally, allowing Series Detail to offer the next available chapter such as `Start Chapter 107` after chapter 106 is read.

**Architecture:** Reuse `StoredChapter` as the lightweight available-chapter index row: indexed chapters have title/label/source URL and empty `imageURLStrings` until Reader extraction stores a full payload. Add a focused chapter-index fetcher/parser service and a small refresh orchestrator that records indexed chapters through repository protocols. Series Detail renders from local data first, starts a background one-series index refresh on open, then reloads the local snapshot when indexing finishes.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, existing ToonEdge repository/service dependency injection.

## Global Constraints

- Implement only Story 11.40.
- Do not add a public catalog, recommendations, source browsing, or hosted content features.
- Do not add cloud sync or cross-device reading state.
- Do not download chapter images during index refresh.
- Do not require multi-page chapter stitching.
- Do not aggressively infer chapter URLs when the source index does not provide a link.
- Do not block Series Detail rendering on network refresh; use existing local data first and update when refresh completes.
- Do not remove existing update-check safeguards for unsupported, rate-limited, or challenge pages.
- Preserve existing Reader detection, Browser behavior, save-to-library grouping, Library filters, and local-first Library snapshots.

---

## Files

- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Add `ChapterIndexEntry`, `ChapterIndexSnapshot`, and `ChapterIndexRefreshOutcome`.
  - Add `SeriesDetailSnapshot.chapterListAnchorID`.
  - Keep `SeriesDetailSnapshot.primaryChapter` as the reading-target source of truth.
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
  - Add `SeriesChapterIndexFetching`, `LibraryChapterIndexManaging`, and `SeriesChapterIndexRefreshing`.
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLChapterIndexFetcher.swift`
  - Fetch a series page and parse all chapter-like anchors into `ChapterIndexSnapshot`.
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/SeriesChapterIndexRefreshService.swift`
  - Coordinate one-series index refresh and repository writes.
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/LibraryUpdateRefreshService.swift`
  - Prefer chapter-index refresh when available; fall back to existing latest-label update check.
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
  - Conform to `LibraryChapterIndexManaging`.
  - Upsert indexed chapters without erasing stored reader payloads.
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
  - Add and wire `chapterIndexRefreshService`.
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
  - Add mock/no-op chapter index refresh support for tests and previews.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Trigger opportunistic Series Detail refresh.
  - Remove `Recent` / `All` segmented chapter mode from Series Detail.
  - Scroll near the next reading target or latest read chapter.
- Modify: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
  - Add parser/fetcher tests for chapter index extraction.
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
  - Add repository/index persistence regression tests.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add Series Detail target and single-list layout tests.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Story 11.40 as implemented after verification.
- Modify: `docs/defects.md`
  - Add a short implemented defect entry for the reported `All Chapters Read` while chapter 107 exists case.

---

## Task 1: Add Chapter Index Domain Contracts and HTML Parser

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLChapterIndexFetcher.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Interfaces:**
- Produces:
  - `public struct ChapterIndexEntry: Equatable, Sendable, Identifiable`
  - `public struct ChapterIndexSnapshot: Equatable, Sendable`
  - `public struct ChapterIndexRefreshOutcome: Equatable, Sendable`
  - `public protocol SeriesChapterIndexFetching`
  - `public enum HTMLChapterIndexParser`
  - `public struct HTMLChapterIndexFetcher`

- [ ] **Step 1: Write failing parser tests**

Add these tests to `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift` near the latest-chapter parser tests:

```swift
@Test func chapterIndexParserExtractsOrderedChapterLinks() throws {
    let seriesID = UUID(uuidString: "6E13CFE1-D6BB-4F6A-9CF3-8A01A9E97E01")!
    let baseURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
    let html = """
    <main>
      <a href="/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107">The Extra's Academy Survival Guide Chapter 107 - Read Online</a>
      <a href="/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/106">Chapter 106</a>
      <a href="/privacy">Privacy Policy</a>
    </main>
    """

    let snapshot = HTMLChapterIndexParser.parse(
        html: html,
        baseURL: baseURL,
        seriesID: seriesID,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot.seriesID == seriesID)
    #expect(snapshot.entries.map(\.chapterLabel) == ["106", "107"])
    #expect(snapshot.entries.map(\.chapterNumber) == [106, 107])
    #expect(snapshot.entries[1].sourceURL.absoluteString == "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/107")
    #expect(snapshot.latestChapterLabel == "107")
}

@Test func chapterIndexParserDeduplicatesSameChapterURL() throws {
    let seriesID = UUID(uuidString: "CC308F48-53EF-4C5F-96A2-694CF89F10F1")!
    let baseURL = try #require(URL(string: "https://example.com/series/moonlit-edge"))
    let html = """
    <a href="/series/moonlit-edge/chapter-12">Chapter 12</a>
    <a href="/series/moonlit-edge/chapter-12">Read Chapter 12 Online</a>
    <a href="/series/moonlit-edge/chapter-13">Chapter 13</a>
    """

    let snapshot = HTMLChapterIndexParser.parse(html: html, baseURL: baseURL, seriesID: seriesID)

    #expect(snapshot.entries.map(\.chapterLabel) == ["12", "13"])
}
```

- [ ] **Step 2: Run parser tests and verify expected failure**

Run:

```bash
swift test --package-path app --filter chapterIndexParser
```

Expected: fail because `HTMLChapterIndexParser` and chapter index domain types do not exist.

- [ ] **Step 3: Add domain DTOs**

In `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`, add these types near `SeriesLatestChapterSnapshot`:

```swift
public struct ChapterIndexEntry: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var chapterLabel: String
    public var chapterNumber: Double?
    public var sourceURL: URL
    public var publishedAt: Date?
    public var checkedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        chapterLabel: String,
        chapterNumber: Double?,
        sourceURL: URL,
        publishedAt: Date? = nil,
        checkedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.chapterLabel = chapterLabel
        self.chapterNumber = chapterNumber
        self.sourceURL = sourceURL
        self.publishedAt = publishedAt
        self.checkedAt = checkedAt
    }
}

public struct ChapterIndexSnapshot: Equatable, Sendable {
    public var seriesID: UUID
    public var entries: [ChapterIndexEntry]
    public var checkedAt: Date

    public init(seriesID: UUID, entries: [ChapterIndexEntry], checkedAt: Date = Date()) {
        self.seriesID = seriesID
        self.entries = entries
        self.checkedAt = checkedAt
    }

    public var latestChapterLabel: String? {
        entries.max { lhs, rhs in
            (lhs.chapterNumber ?? -1) < (rhs.chapterNumber ?? -1)
        }?.chapterLabel
    }
}

public struct ChapterIndexRefreshOutcome: Equatable, Sendable {
    public var seriesID: UUID
    public var checkedAt: Date
    public var indexedChapterCount: Int
    public var latestChapterLabel: String?
    public var hasUnreadUpdates: Bool
    public var didRefresh: Bool

    public init(
        seriesID: UUID,
        checkedAt: Date = Date(),
        indexedChapterCount: Int,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        didRefresh: Bool
    ) {
        self.seriesID = seriesID
        self.checkedAt = checkedAt
        self.indexedChapterCount = indexedChapterCount
        self.latestChapterLabel = latestChapterLabel
        self.hasUnreadUpdates = hasUnreadUpdates
        self.didRefresh = didRefresh
    }
}
```

- [ ] **Step 4: Add service protocols**

In `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`, add:

```swift
public protocol SeriesChapterIndexFetching: Sendable {
    func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot?
}

public protocol LibraryChapterIndexManaging: Sendable {
    func recordAvailableChapters(
        _ chapters: [ChapterIndexEntry],
        for seriesID: UUID,
        indexedAt: Date
    ) async throws
}

public protocol SeriesChapterIndexRefreshing: Sendable {
    func refreshChapterIndex(for series: LibrarySeriesSummary) async -> ChapterIndexRefreshOutcome
    func refreshChapterIndex(for seriesID: UUID) async -> ChapterIndexRefreshOutcome?
}
```

- [ ] **Step 5: Implement `HTMLChapterIndexFetcher` and parser**

Create `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLChapterIndexFetcher.swift`:

```swift
import Foundation

public struct HTMLChapterIndexFetcher: SeriesChapterIndexFetching {
    private let httpClient: any HTTPDataLoading
    private let now: @Sendable () -> Date

    public init(
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.now = now
    }

    public func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot? {
        guard let url = series.canonicalURL,
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        let response = try await httpClient.data(from: url)
        guard (200..<300).contains(response.statusCode) else {
            return nil
        }

        let html = String(decoding: response.data, as: UTF8.self)
        let snapshot = HTMLChapterIndexParser.parse(
            html: html,
            baseURL: url,
            seriesID: series.id,
            checkedAt: now()
        )
        return snapshot.entries.isEmpty ? nil : snapshot
    }
}

public enum HTMLChapterIndexParser {
    public static func parse(
        html: String,
        baseURL: URL,
        seriesID: UUID,
        checkedAt: Date = Date()
    ) -> ChapterIndexSnapshot {
        let entriesByURL = Dictionary(
            anchors(in: html).compactMap { anchor -> (String, ChapterIndexEntry)? in
                guard let sourceURL = URL(string: anchor.href, relativeTo: baseURL)?.absoluteURL,
                      let number = chapterNumber(in: anchor.searchText) else {
                    return nil
                }

                let label = normalizedChapterLabel(from: number)
                let title = anchor.text.isEmpty ? "Chapter \(label)" : anchor.text
                return (
                    sourceURL.absoluteString,
                    ChapterIndexEntry(
                        title: title,
                        chapterLabel: label,
                        chapterNumber: number,
                        sourceURL: sourceURL,
                        checkedAt: checkedAt
                    )
                )
            },
            uniquingKeysWith: { existing, _ in existing }
        )

        let entries = entriesByURL.values.sorted {
            switch ($0.chapterNumber, $1.chapterNumber) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            default:
                return $0.sourceURL.absoluteString < $1.sourceURL.absoluteString
            }
        }

        return ChapterIndexSnapshot(seriesID: seriesID, entries: entries, checkedAt: checkedAt)
    }

    private static func anchors(in html: String) -> [Anchor] {
        let pattern = #"<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            return Anchor(
                href: String(html[hrefRange]),
                text: stripTags(String(html[textRange]))
            )
        }
    }

    private static func chapterNumber(in text: String) -> Double? {
        let pattern = #"\b(?:chapter|chap|ch)\.?\s*([0-9]+(?:[.-][0-9]+)?)\b|/chapter[-/]([0-9]+(?:[.-][0-9]+)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        for index in 1..<match.numberOfRanges {
            guard let tokenRange = Range(match.range(at: index), in: text) else {
                continue
            }
            return Double(String(text[tokenRange]).replacingOccurrences(of: "-", with: "."))
        }

        return nil
    }

    private static func normalizedChapterLabel(from number: Double) -> String {
        if number == number.rounded(.towardZero) {
            return "\(Int(number))"
        }
        return String(number)
    }

    private static func stripTags(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Anchor {
        var href: String
        var text: String

        var searchText: String {
            "\(text) \(href)"
        }
    }
}
```

- [ ] **Step 6: Run focused parser tests**

Run:

```bash
swift test --package-path app --filter chapterIndexParser
```

Expected: parser tests pass.

---

## Task 2: Persist Indexed Chapters Without Erasing Reader Payloads

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Interfaces:**
- Consumes:
  - `LibraryChapterIndexManaging.recordAvailableChapters(_:for:indexedAt:)`
  - `ChapterIndexEntry`
- Produces:
  - `SwiftDataLibraryRepository: LibraryChapterIndexManaging`
  - Lightweight `StoredChapter` rows with empty `imageURLStrings`

- [ ] **Step 1: Write failing repository test for next indexed chapter target**

Add this test to `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`:

```swift
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

    #expect(detail.primaryActionTitle == "Start Chapter 107")
    #expect(detail.primaryChapter?.chapterLabel == "107")
    #expect(detail.primaryChapter?.isOpenable == true)
}
```

- [ ] **Step 2: Write failing repository test that indexing preserves stored images**

Add:

```swift
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
            canonicalURL: try #require(URL(string: "https://example.com/series/extras")),
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

    #expect(session.pages.map(\.sourceURL) == [imageURL])
}
```

- [ ] **Step 3: Run repository tests and verify expected failures**

Run:

```bash
swift test --package-path app --filter swiftDataRepositoryUsesIndexedNextChapterAsSeriesDetailPrimaryAction
swift test --package-path app --filter swiftDataRepositoryDoesNotEraseReaderPayloadWhenIndexRefreshSeesExistingChapter
```

Expected: fail because `recordAvailableChapters` is not implemented.

- [ ] **Step 4: Conform repository to `LibraryChapterIndexManaging`**

Update the repository declaration in `SwiftDataLibraryRepository.swift`:

```swift
public final class SwiftDataLibraryRepository: LibraryLifecycleManaging, LibraryChapterIndexManaging, ReaderProgressStoring, SearchHistoryRecording, RecentReadingRecording, CacheMetadataManaging {
```

Add this public method near `recordUpdateCheckResult`:

```swift
public func recordAvailableChapters(
    _ chapters: [ChapterIndexEntry],
    for seriesID: UUID,
    indexedAt: Date
) async throws {
    guard let series = fetchSeries(id: seriesID) else {
        return
    }

    for chapter in chapters {
        upsertIndexedChapter(chapter, seriesID: seriesID, indexedAt: indexedAt)
    }

    if let latestLabel = chapters.max(by: { ($0.chapterNumber ?? -1) < ($1.chapterNumber ?? -1) })?.chapterLabel {
        series.latestKnownChapterLabel = latestLabel
    }
    series.updatedAt = indexedAt
    try saveContextIfNeeded()
}
```

Add this private helper near `upsertChapter`:

```swift
private func upsertIndexedChapter(_ input: ChapterIndexEntry, seriesID: UUID, indexedAt: Date) {
    let sourceURLString = input.sourceURL.absoluteString
    if let existing = fetchChapter(sourceURLString: sourceURLString) ?? fetchChapter(id: input.id) {
        existing.seriesID = seriesID
        existing.title = input.title
        existing.chapterLabel = input.chapterLabel
        existing.chapterNumber = input.chapterNumber
        existing.sourceURLString = sourceURLString
        existing.publishedAt = input.publishedAt ?? existing.publishedAt
        existing.updatedAt = indexedAt
        return
    }

    let chapter = StoredChapter(
        id: input.id,
        seriesID: seriesID,
        title: input.title,
        chapterLabel: input.chapterLabel,
        chapterNumber: input.chapterNumber,
        sourceURLString: sourceURLString,
        previousChapterURLString: nil,
        nextChapterURLString: nil,
        imageURLStrings: encodeURLStrings([]),
        isDownloaded: false,
        publishedAt: input.publishedAt,
        cachedAt: nil,
        updatedAt: indexedAt
    )
    chapterStore[chapter.id] = chapter
    insert(chapter)
}
```

- [ ] **Step 5: Run focused repository tests**

Run:

```bash
swift test --package-path app --filter swiftDataRepositoryUsesIndexedNextChapterAsSeriesDetailPrimaryAction
swift test --package-path app --filter swiftDataRepositoryDoesNotEraseReaderPayloadWhenIndexRefreshSeesExistingChapter
```

Expected: both tests pass.

---

## Task 3: Add Chapter Index Refresh Orchestration

**Files:**
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/SeriesChapterIndexRefreshService.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/LibraryUpdateRefreshService.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Interfaces:**
- Consumes:
  - `SeriesChapterIndexFetching.chapterIndexSnapshot(for:)`
  - `LibraryChapterIndexManaging.recordAvailableChapters(_:for:indexedAt:)`
  - `LibraryLifecycleManaging.recordUpdateCheckResult(...)`
- Produces:
  - `SeriesChapterIndexRefreshService`
  - `LibraryUpdateRefreshService` index-aware refresh behavior

- [ ] **Step 1: Add test doubles**

Add these helpers to `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift` near existing update refresh test doubles:

```swift
private final class StubChapterIndexFetcher: SeriesChapterIndexFetching, @unchecked Sendable {
    var snapshots: [UUID: ChapterIndexSnapshot] = [:]
    var requestedSeriesIDs: [UUID] = []

    func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot? {
        requestedSeriesIDs.append(series.id)
        return snapshots[series.id]
    }
}

private final class RecordingChapterIndexLibrary: LibraryLifecycleManaging, LibraryChapterIndexManaging, @unchecked Sendable {
    var snapshot: LibrarySnapshot
    var recordedIndexes: [(seriesID: UUID, chapters: [ChapterIndexEntry])] = []
    var updateResults: [(seriesID: UUID, latestChapterLabel: String?, hasUnreadUpdates: Bool)] = []

    init(snapshot: LibrarySnapshot) {
        self.snapshot = snapshot
    }

    func homeSnapshot() async -> HomeSnapshot {
        HomeSnapshot(continueReading: [], recentlyUpdated: [], library: [])
    }

    func librarySnapshot() async -> LibrarySnapshot {
        snapshot
    }

    func seriesDetail(for seriesID: UUID) async -> SeriesDetailSnapshot? {
        nil
    }

    func addToLibrary(_ input: LibrarySeriesInput, context: LibraryAddContext) async throws {}
    func removeFromLibrary(seriesID: UUID) async throws {}
    func updateLibraryState(_ state: LibraryCollectionState, for seriesID: UUID) async throws {}

    func recordUpdateCheckResult(
        seriesID: UUID,
        latestChapterLabel: String?,
        hasUnreadUpdates: Bool,
        checkedAt: Date
    ) async throws {
        updateResults.append((seriesID, latestChapterLabel, hasUnreadUpdates))
    }

    func recordReadingProgress(_ progress: ReaderProgress, forChapterID chapterID: UUID, at date: Date) async throws {}
    func continueReadingTarget(for seriesID: UUID) async -> ContinueReadingTarget? { nil }
    func readerSession(forChapterID chapterID: UUID) async -> MockReaderSession? { nil }
    func readerSession(forSourceURL sourceURL: URL) async -> MockReaderSession? { nil }
    func isSaved(canonicalURL: URL) async -> Bool { false }

    func recordAvailableChapters(
        _ chapters: [ChapterIndexEntry],
        for seriesID: UUID,
        indexedAt: Date
    ) async throws {
        recordedIndexes.append((seriesID, chapters))
    }
}
```

- [ ] **Step 2: Write failing service tests**

Add:

```swift
@Test func chapterIndexRefreshServiceRecordsIndexAndUpdateState() async throws {
    let seriesID = UUID(uuidString: "A2EDB8E4-7F21-4608-9C8C-5DCFE4B35531")!
    let series = LibrarySeriesSummary.updateCheckFixture(id: seriesID, latestChapterLabel: "106")
    let library = RecordingChapterIndexLibrary(snapshot: LibrarySnapshot(series: [series]))
    let fetcher = StubChapterIndexFetcher()
    fetcher.snapshots[seriesID] = ChapterIndexSnapshot(
        seriesID: seriesID,
        entries: [
            ChapterIndexEntry(
                title: "Chapter 107",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: URL(string: "https://example.com/chapter-107")!
            )
        ],
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let service = SeriesChapterIndexRefreshService(library: library, indexLibrary: library, fetcher: fetcher)

    let outcome = await service.refreshChapterIndex(for: series)

    #expect(outcome.didRefresh)
    #expect(outcome.latestChapterLabel == "107")
    #expect(outcome.hasUnreadUpdates)
    #expect(library.recordedIndexes.first?.chapters.map(\.chapterLabel) == ["107"])
    #expect(library.updateResults.first?.latestChapterLabel == "107")
    #expect(library.updateResults.first?.hasUnreadUpdates == true)
}

@Test func libraryUpdateRefreshUsesChapterIndexRefreshWhenAvailable() async throws {
    let seriesID = UUID(uuidString: "41B54FDE-23F9-4D68-8B4B-7A1E05C2AD30")!
    let series = LibrarySeriesSummary.updateCheckFixture(id: seriesID, latestChapterLabel: "106")
    let library = RecordingChapterIndexLibrary(snapshot: LibrarySnapshot(series: [series]))
    let fetcher = StubChapterIndexFetcher()
    fetcher.snapshots[seriesID] = ChapterIndexSnapshot(
        seriesID: seriesID,
        entries: [
            ChapterIndexEntry(
                title: "Chapter 107",
                chapterLabel: "107",
                chapterNumber: 107,
                sourceURL: URL(string: "https://example.com/chapter-107")!
            )
        ]
    )
    let indexRefresh = SeriesChapterIndexRefreshService(library: library, indexLibrary: library, fetcher: fetcher)
    let refresh = LibraryUpdateRefreshService(
        library: library,
        updateChecker: StaticSeriesUpdateChecker(result: .same),
        chapterIndexRefreshService: indexRefresh
    )

    let result = await refresh.refreshUpdates()

    #expect(result.checkedCount == 1)
    #expect(result.updatedCount == 1)
    #expect(result.failedCount == 0)
    #expect(fetcher.requestedSeriesIDs == [seriesID])
}
```

If `StaticSeriesUpdateChecker` does not exist in the test file, add:

```swift
private struct StaticSeriesUpdateChecker: SeriesUpdateChecking {
    var result: ChapterUpdateComparison

    func checkForUpdates(series: LibrarySeriesSummary) async throws -> SeriesUpdateCheckResult {
        SeriesUpdateCheckResult(
            seriesID: series.id,
            latestChapterLabel: series.latestChapterLabel,
            hasUnreadUpdates: result != .same,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            comparison: result
        )
    }
}
```

- [ ] **Step 3: Run tests and verify expected failures**

Run:

```bash
swift test --package-path app --filter chapterIndexRefreshServiceRecordsIndexAndUpdateState
swift test --package-path app --filter libraryUpdateRefreshUsesChapterIndexRefreshWhenAvailable
```

Expected: fail because `SeriesChapterIndexRefreshService` and the new `LibraryUpdateRefreshService` initializer parameter do not exist.

- [ ] **Step 4: Implement `SeriesChapterIndexRefreshService`**

Create `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/SeriesChapterIndexRefreshService.swift`:

```swift
import Foundation

public struct SeriesChapterIndexRefreshService: SeriesChapterIndexRefreshing {
    private let library: any LibraryLifecycleManaging
    private let indexLibrary: any LibraryChapterIndexManaging
    private let fetcher: any SeriesChapterIndexFetching

    public init(
        library: any LibraryLifecycleManaging,
        indexLibrary: any LibraryChapterIndexManaging,
        fetcher: any SeriesChapterIndexFetching
    ) {
        self.library = library
        self.indexLibrary = indexLibrary
        self.fetcher = fetcher
    }

    public func refreshChapterIndex(for seriesID: UUID) async -> ChapterIndexRefreshOutcome? {
        let snapshot = await library.librarySnapshot()
        guard let series = snapshot.series.first(where: { $0.id == seriesID }) else {
            return nil
        }

        return await refreshChapterIndex(for: series)
    }

    public func refreshChapterIndex(for series: LibrarySeriesSummary) async -> ChapterIndexRefreshOutcome {
        do {
            guard let snapshot = try await fetcher.chapterIndexSnapshot(for: series) else {
                return ChapterIndexRefreshOutcome(
                    seriesID: series.id,
                    checkedAt: Date(),
                    indexedChapterCount: 0,
                    latestChapterLabel: series.latestChapterLabel,
                    hasUnreadUpdates: false,
                    didRefresh: false
                )
            }

            try await indexLibrary.recordAvailableChapters(
                snapshot.entries,
                for: series.id,
                indexedAt: snapshot.checkedAt
            )

            let comparison = ChapterUpdateComparison.compare(
                storedLatest: series.latestChapterLabel,
                fetchedLatest: snapshot.latestChapterLabel
            )
            let hasUnreadUpdates = comparison != .same
            try await library.recordUpdateCheckResult(
                seriesID: series.id,
                latestChapterLabel: snapshot.latestChapterLabel ?? series.latestChapterLabel,
                hasUnreadUpdates: hasUnreadUpdates,
                checkedAt: snapshot.checkedAt
            )

            return ChapterIndexRefreshOutcome(
                seriesID: series.id,
                checkedAt: snapshot.checkedAt,
                indexedChapterCount: snapshot.entries.count,
                latestChapterLabel: snapshot.latestChapterLabel ?? series.latestChapterLabel,
                hasUnreadUpdates: hasUnreadUpdates,
                didRefresh: true
            )
        } catch {
            return ChapterIndexRefreshOutcome(
                seriesID: series.id,
                checkedAt: Date(),
                indexedChapterCount: 0,
                latestChapterLabel: series.latestChapterLabel,
                hasUnreadUpdates: false,
                didRefresh: false
            )
        }
    }
}
```

- [ ] **Step 5: Make Library refresh index-aware**

Modify `LibraryUpdateRefreshService`:

```swift
public struct LibraryUpdateRefreshService: LibraryUpdateRefreshing {
    private let library: any LibraryLifecycleManaging
    private let updateChecker: any SeriesUpdateChecking
    private let chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    private let diagnosticsLogger: (any UpdateCacheDiagnosticsLogging)?

    public init(
        library: any LibraryLifecycleManaging,
        updateChecker: any SeriesUpdateChecking,
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)? = nil,
        diagnosticsLogger: (any UpdateCacheDiagnosticsLogging)? = nil
    ) {
        self.library = library
        self.updateChecker = updateChecker
        self.chapterIndexRefreshService = chapterIndexRefreshService
        self.diagnosticsLogger = diagnosticsLogger
    }
```

Inside `refreshUpdates()`, replace the loop body with:

```swift
for series in snapshot.series {
    if let chapterIndexRefreshService {
        let outcome = await chapterIndexRefreshService.refreshChapterIndex(for: series)
        if outcome.didRefresh {
            if outcome.hasUnreadUpdates {
                updatedCount += 1
            }
            continue
        }
    }

    do {
        let result = try await updateChecker.checkForUpdates(series: series)
        try await library.recordUpdateCheckResult(
            seriesID: result.seriesID,
            latestChapterLabel: result.latestChapterLabel,
            hasUnreadUpdates: result.hasUnreadUpdates,
            checkedAt: result.checkedAt
        )
        if result.hasUnreadUpdates {
            updatedCount += 1
        }
    } catch {
        failedCount += 1
    }
}
```

- [ ] **Step 6: Run focused refresh tests**

Run:

```bash
swift test --package-path app --filter chapterIndexRefreshServiceRecordsIndexAndUpdateState
swift test --package-path app --filter libraryUpdateRefreshUsesChapterIndexRefreshWhenAvailable
```

Expected: both tests pass.

---

## Task 4: Wire Dependencies and Opportunistic Series Detail Refresh

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - `SeriesChapterIndexRefreshing.refreshChapterIndex(for seriesID:)`
- Produces:
  - `AppDependencies.chapterIndexRefreshService`
  - `SeriesDetailView.refreshChapterIndexIfAvailable()`

- [ ] **Step 1: Add dependency exposure test**

In `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`, add:

```swift
@MainActor
@Test func persistentDependenciesExposeChapterIndexRefreshService() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.chapterIndexRefreshService != nil)
}
```

- [ ] **Step 2: Run the dependency test and verify expected failure**

Run:

```bash
swift test --package-path app --filter persistentDependenciesExposeChapterIndexRefreshService
```

Expected: fail because `AppDependencies.chapterIndexRefreshService` does not exist.

- [ ] **Step 3: Add dependency property and persistent wiring**

In `AppDependencies`, add:

```swift
public var chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
```

Add it to the initializer parameter list:

```swift
chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)? = nil,
```

Assign it in the initializer:

```swift
self.chapterIndexRefreshService = chapterIndexRefreshService
```

In `persistent(...)`, create and wire one service instance before the return:

```swift
let chapterIndexRefreshService = SeriesChapterIndexRefreshService(
    library: repository,
    indexLibrary: repository,
    fetcher: HTMLChapterIndexFetcher()
)
```

Pass it into `AppDependencies`:

```swift
chapterIndexRefreshService: chapterIndexRefreshService,
updateRefreshService: LibraryUpdateRefreshService(
    library: repository,
    updateChecker: SeriesUpdateChecker(
        fetcher: HTMLLatestChapterFetcher(diagnosticsLogger: diagnosticsLogger)
    ),
    chapterIndexRefreshService: chapterIndexRefreshService,
    diagnosticsLogger: diagnosticsLogger
),
```

- [ ] **Step 4: Add a mock refresh service**

In `MockServices.swift`, add:

```swift
public final class MockSeriesChapterIndexRefreshService: SeriesChapterIndexRefreshing, @unchecked Sendable {
    public private(set) var refreshedSeriesIDs: [UUID] = []

    public init() {}

    public func refreshChapterIndex(for series: LibrarySeriesSummary) async -> ChapterIndexRefreshOutcome {
        refreshedSeriesIDs.append(series.id)
        return ChapterIndexRefreshOutcome(
            seriesID: series.id,
            indexedChapterCount: 0,
            latestChapterLabel: series.latestChapterLabel,
            hasUnreadUpdates: false,
            didRefresh: false
        )
    }

    public func refreshChapterIndex(for seriesID: UUID) async -> ChapterIndexRefreshOutcome? {
        refreshedSeriesIDs.append(seriesID)
        return ChapterIndexRefreshOutcome(
            seriesID: seriesID,
            indexedChapterCount: 0,
            latestChapterLabel: nil,
            hasUnreadUpdates: false,
            didRefresh: false
        )
    }
}
```

In `AppDependencies.mock()`, pass:

```swift
chapterIndexRefreshService: MockSeriesChapterIndexRefreshService(),
```

- [ ] **Step 5: Trigger opportunistic refresh from Series Detail**

In `SeriesDetailView` in `LibraryView.swift`, add state:

```swift
@State private var hasAttemptedChapterIndexRefresh = false
```

Replace the `.task` body with:

```swift
.task {
    await reloadDetail()
    await refreshChapterIndexIfAvailable()
}
```

Add the helper near `reloadDetail()`:

```swift
private func refreshChapterIndexIfAvailable() async {
    guard !hasAttemptedChapterIndexRefresh,
          let chapterIndexRefreshService = dependencies.chapterIndexRefreshService else {
        return
    }

    hasAttemptedChapterIndexRefresh = true
    let outcome = await chapterIndexRefreshService.refreshChapterIndex(for: seriesID)
    if outcome?.didRefresh == true {
        await reloadDetail()
    }
}
```

- [ ] **Step 6: Run dependency-focused tests**

Run:

```bash
swift test --package-path app --filter persistentDependenciesExposeChapterIndexRefreshService
swift test --package-path app --filter LibraryExperienceTests
```

Expected: both commands pass.

---

## Task 5: Replace Series Detail Recent/All With One Anchored All List

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces:
  - `SeriesDetailSnapshot.chapterListAnchorID: UUID?`
  - Single chapter list rendering using `detail.chapterList(for: .all)`

- [ ] **Step 1: Write failing anchor test**

Add this test to `LibraryExperienceTests.swift` near other Series Detail tests:

```swift
@Test func seriesDetailChapterListAnchorPrefersPrimaryChapterThenLatestReadChapter() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let chapter106 = ChapterSummary.mock(
        chapterLabel: "106",
        chapterNumber: 106,
        readState: .read,
        lastReadAt: now
    )
    let chapter107 = ChapterSummary.mock(
        chapterLabel: "107",
        chapterNumber: 107,
        readState: .unread
    )
    let withNextTarget = SeriesDetailSnapshot.mock(chapters: [chapter106, chapter107])

    #expect(withNextTarget.chapterListAnchorID == chapter107.id)

    let allRead = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(
                chapterLabel: "105",
                chapterNumber: 105,
                readState: .read,
                lastReadAt: now.addingTimeInterval(-60)
            ),
            chapter106
        ]
    )

    #expect(allRead.chapterListAnchorID == chapter106.id)
}
```

- [ ] **Step 2: Write failing layout test for single chapter section**

Add:

```swift
@Test func seriesDetailChapterSectionUsesSingleAllList() {
    let layout = SeriesDetailChapterSectionLayout()

    #expect(layout.showsSegmentedControl == false)
    #expect(layout.defaultMode == .all)
}
```

- [ ] **Step 3: Run tests and verify expected failures**

Run:

```bash
swift test --package-path app --filter seriesDetailChapter
```

Expected: fail because `chapterListAnchorID` and `SeriesDetailChapterSectionLayout` do not exist.

- [ ] **Step 4: Add anchor logic to `SeriesDetailSnapshot`**

In `AppModels.swift`, add:

```swift
public var chapterListAnchorID: UUID? {
    if let primaryChapter {
        return primaryChapter.id
    }

    return chapters
        .filter { $0.lastReadAt != nil }
        .sorted { lhs, rhs in
            switch (lhs.lastReadAt, rhs.lastReadAt) {
            case let (lhsDate?, rhsDate?):
                return lhsDate > rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return (numericChapterValue(for: lhs) ?? -1) > (numericChapterValue(for: rhs) ?? -1)
            }
        }
        .first?
        .id
}
```

- [ ] **Step 5: Add chapter-section layout contract**

In `LibraryView.swift`, near `SeriesDetailHeaderLayout`, add:

```swift
struct SeriesDetailChapterSectionLayout: Equatable, Sendable {
    var showsSegmentedControl: Bool
    var defaultMode: SeriesDetailChapterListMode

    init() {
        self.showsSegmentedControl = false
        self.defaultMode = .all
    }
}
```

- [ ] **Step 6: Remove segmented control rendering and use anchored all list**

In `SeriesDetailView`, remove:

```swift
@State private var chapterListMode: SeriesDetailChapterListMode = .recent
```

In `chapterToolbar(_:)`, remove:

```swift
TESegmentedControl(selection: $chapterListMode) { $0.title }
```

In `chapterList(_:)`, replace:

```swift
let chapters = detail.chapterList(for: chapterListMode)
```

with:

```swift
let chapters = detail.chapterList(for: .all)
```

Wrap the main `ScrollView` in `ScrollViewReader`:

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            // existing content
        }
        .padding(ToonEdgeSpacing.large)
    }
    .task(id: detail?.chapterListAnchorID) {
        guard let anchorID = detail?.chapterListAnchorID else { return }
        try? await Task.sleep(for: .milliseconds(100))
        proxy.scrollTo(anchorID, anchor: .center)
    }
}
```

Add an ID to each chapter row in `chapterList(_:)`:

```swift
.id(chapter.id)
```

- [ ] **Step 7: Run Series Detail layout tests**

Run:

```bash
swift test --package-path app --filter seriesDetailChapter
swift test --package-path app --filter LibraryExperienceTests
```

Expected: all matching tests pass.

---

## Task 6: Verify Indexed Chapters Open Through Existing Browser Fallback

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - `ChapterSummary.isOpenable`
  - `SeriesDetailView.open(_:)` existing behavior: direct reader session if stored payload exists, otherwise Browser URL.

- [ ] **Step 1: Add repository assertion for no direct reader session on index-only chapter**

Extend `swiftDataRepositoryUsesIndexedNextChapterAsSeriesDetailPrimaryAction` with:

```swift
let chapter107 = try #require(detail.primaryChapter)
let directSession = await repository.readerSession(forChapterID: chapter107.id)

#expect(directSession == nil)
#expect(chapter107.sourceURL == chapter107URL)
#expect(chapter107.isOpenable)
```

- [ ] **Step 2: Run focused persistence test**

Run:

```bash
swift test --package-path app --filter swiftDataRepositoryUsesIndexedNextChapterAsSeriesDetailPrimaryAction
```

Expected: pass, proving indexed chapters are openable by URL but not treated as stored reader payloads.

---

## Task 7: Documentation, Story Status, and Full Verification

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`
- Modify: `docs/defects.md`

**Interfaces:**
- Consumes:
  - Story 11.40 acceptance criteria
  - Reported user-visible defect: Series Detail says `All Chapters Read` while chapter 107 is available.

- [ ] **Step 1: Mark Story 11.40 implemented**

In `docs/toonedge_epics_and_stories.md`, change:

```markdown
### Story 11.40 — Local available-chapter index and Series Detail reading target
**Status:** proposed
```

to:

```markdown
### Story 11.40 — Local available-chapter index and Series Detail reading target
**Status:** implemented
```

- [ ] **Step 2: Add defect entry**

At the top of `docs/defects.md`, add:

```markdown
## DEF-028 — Series Detail can show all known local chapters read while the next source chapter exists

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-07-09  
**Area:** Series Detail primary action, update refresh, chapter availability indexing

### User-visible problem

After chapter 106 is fully read, Series Detail can show `All Chapters Read` even though chapter 107 is available on the source site. The app may have a latest-known label from update metadata, but no stored chapter URL for chapter 107.

### Expected behavior

- Refresh and Series Detail opening should index available chapter links when possible.
- If chapter 107 is indexed and chapter 106 is read, Series Detail should offer `Start Chapter 107`.
- If every indexed available chapter is read, Series Detail can show `All Chapters Read`.

### Resolution

- Added lightweight available-chapter indexing from source series pages.
- Manual Library refresh and opportunistic Series Detail loading update the local chapter index.
- Series Detail primary action now uses indexed chapter rows as openable reading targets without requiring cached reader image payloads.
```

- [ ] **Step 3: Run focused tests**

Run:

```bash
swift test --package-path app --filter UpdateCheckTests
swift test --package-path app --filter PersistenceLifecycleTests
swift test --package-path app --filter LibraryExperienceTests
```

Expected: all focused suites pass.

- [ ] **Step 4: Run full package tests**

Run:

```bash
swift test --package-path app
```

Expected: all tests pass.

- [ ] **Step 5: Build iPhone simulator target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`.

---

## Implementation Notes

- Reusing `StoredChapter` avoids a schema migration while still keeping indexed chapters lightweight. The implementation must not overwrite non-empty `imageURLStrings` when a later index refresh sees the same chapter URL.
- `HTMLChapterIndexParser` is intentionally generic and anchor-based. It should discover simple chapter links from supported series pages but should not attempt JavaScript execution or pagination in this story.
- `LibraryUpdateRefreshService` should use index refresh first when available, then fall back to the existing latest-label update checker when index refresh returns `didRefresh == false`.
- Series Detail should render immediately from `libraryService.seriesDetail(for:)`; the opportunistic refresh is a second pass that reloads the local detail only if indexing succeeds.
- The single Series Detail chapter list should continue to use generated placeholder rows from `chapterList(for: .all)`, but only stored/indexed rows with real source URLs should be enabled.

## Self-Review Checklist

- Story 11.40 manual Library refresh requirement maps to Task 3.
- Story 11.40 opportunistic Series Detail refresh requirement maps to Task 4.
- Story 11.40 lightweight local chapter storage requirement maps to Task 2.
- Story 11.40 `Start Chapter 107` requirement maps to Task 2 and Task 3 tests.
- Story 11.40 single `All` chapter section and anchor requirement maps to Task 5.
- Story 11.40 “do not download images during index refresh” boundary maps to Task 2 and Task 6.
- Story 11.40 failure non-destruction boundary maps to Task 2 preserving existing payloads and Task 3 outcome behavior.
