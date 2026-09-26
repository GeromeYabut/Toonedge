## Task 1: DEF-029 Cover Propagation Regression

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify only if Step 6 finds repository cover loss: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Modify only if Step 6 finds repository cover loss: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`

**Interfaces:**
- Consumes:

```swift
struct SeriesDetailSeedShellLayout {
    init(summary: LibrarySeriesSummary)
    var coverImageURL: URL?
}

struct SeriesDetailHeaderLayout {
    init(snapshot: SeriesDetailSnapshot)
}
```

- Produces:

```swift
struct SeriesDetailCoverLayout: Equatable, Sendable {
    var coverImageURL: URL?
    var usesPlaceholder: Bool

    init(coverImageURL: URL?)
}
```

- [ ] **Step 1: Add failing seed-shell cover test**

Add this test near the existing seed-shell tests in `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`:

```swift
@Test func seriesDetailSeedShellPreservesKnownLibraryCoverURL() {
    let coverURL = URL(string: "https://asurascans.com/covers/extras-academy.jpg")!
    let summary = LibrarySeriesSummary.mock(
        title: "The Extra's Academy Survival Guide | Asura Scans",
        sourceDomain: "asurascans.com",
        coverImageURL: coverURL,
        chaptersRead: 4,
        totalKnownChapters: 122
    )

    let layout = SeriesDetailSeedShellLayout(summary: summary)
    let cover = SeriesDetailCoverLayout(coverImageURL: layout.coverImageURL)

    #expect(layout.coverImageURL == coverURL)
    #expect(cover.coverImageURL == coverURL)
    #expect(!cover.usesPlaceholder)
}
```

- [ ] **Step 2: Extend the SeriesDetailSnapshot test helper for cover tests**

Update the `SeriesDetailSnapshot.mock` helper at the bottom of `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift` from:

```swift
static func mock(synopsis: String = "A compact mock synopsis.", chapters: [ChapterSummary]) -> SeriesDetailSnapshot {
    SeriesDetailSnapshot(
        id: UUID(),
        title: "Moonlit Edge",
        status: "Ongoing",
        synopsis: synopsis,
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
```

to:

```swift
static func mock(
    title: String = "Moonlit Edge",
    synopsis: String = "A compact mock synopsis.",
    sourceDomain: String = "example.com",
    coverImageURL: URL? = nil,
    chapters: [ChapterSummary]
) -> SeriesDetailSnapshot {
    SeriesDetailSnapshot(
        id: UUID(),
        title: title,
        status: "Ongoing",
        synopsis: synopsis,
        sourceDomain: sourceDomain,
        coverImageURL: coverImageURL,
        isSaved: true,
        libraryState: .reading,
        progressPercent: 0.35,
        chaptersRead: chapters.filter { $0.readState == .read }.count,
        totalKnownChapters: chapters.count,
        hasUnreadUpdates: chapters.contains { $0.readState == .new },
        chapters: chapters
    )
}
```

- [ ] **Step 3: Add failing hydrated-cover continuity test**

Add this test near `seededSeriesDetailUsesHydratedDetailForContinueAction`:

```swift
@Test func hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail() {
    let coverURL = URL(string: "https://asurascans.com/covers/extras-academy.jpg")!
    let detail = SeriesDetailSnapshot.mock(
        title: "The Extra's Academy Survival Guide | Asura Scans",
        coverImageURL: coverURL,
        chapters: [
            ChapterSummary.mock(chapterLabel: "101", readState: .read),
            ChapterSummary.mock(chapterLabel: "102", readState: .unread)
        ]
    )

    let cover = SeriesDetailCoverLayout(coverImageURL: detail.coverImageURL)

    #expect(cover.coverImageURL == coverURL)
    #expect(!cover.usesPlaceholder)
}
```

- [ ] **Step 4: Run red tests**

Run:

```bash
swift test --package-path app --filter seriesDetailSeedShellPreservesKnownLibraryCoverURL
swift test --package-path app --filter hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail
```

Expected: compile failure because `SeriesDetailCoverLayout` does not exist yet. If these tests pass after adding only the helper, continue to Step 6 to diagnose repository data loss with the simulator/user case before touching persistence.

- [ ] **Step 5: Add minimal cover layout helper**

In `LibraryView.swift`, add near `SeriesDetailSeedShellLayout`:

```swift
struct SeriesDetailCoverLayout: Equatable, Sendable {
    var coverImageURL: URL?
    var usesPlaceholder: Bool

    init(coverImageURL: URL?) {
        self.coverImageURL = coverImageURL
        self.usesPlaceholder = coverImageURL == nil
    }
}
```

- [ ] **Step 6: Diagnose whether summaries lose cover URLs**

Inspect `SwiftDataLibraryRepository.seriesSummary(_:)`, `seriesDetail(for:)`, and recent-reading reconciliation paths. Use `rg -n "coverImageURLString|seriesSummary|seriesDetail|recordRecentReading" app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`.

Expected finding to resolve:
- If `StoredSeries.coverImageURLString` is populated but `LibrarySeriesSummary.coverImageURL` or `SeriesDetailSnapshot.coverImageURL` is nil, fix the mapper.
- If recent-reading has a cover but the matching saved series does not, propagate the non-nil recent cover into the saved series only through existing cover fields.
- If no local cover exists, leave placeholder behavior unchanged.

- [ ] **Step 7: Add repository regression only if a mapper/reconciliation loss is found**

If Step 6 finds cover loss in persistence mapping, add a focused test to `PersistenceLifecycleTests.swift` using the existing repository test setup pattern:

```swift
@MainActor
@Test func savedSeriesSummaryAndDetailPreserveCoverURL() async throws {
    let repository = try makeRepository()
    let coverURL = URL(string: "https://asurascans.com/covers/extras-academy.jpg")!
    let seriesID = UUID(uuidString: "9E8D4E31-4179-41E9-9F72-07D4149E1F01")!

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "The Extra's Academy Survival Guide | Asura Scans",
            canonicalURL: URL(string: "https://asurascans.com/series/extras-academy")!,
            sourceDomain: "asurascans.com",
            coverImageURL: coverURL,
            status: "Reading",
            synopsis: "",
            latestKnownChapterLabel: "102",
            libraryState: .reading,
            chapters: [
                LibraryChapterInput(
                    id: UUID(),
                    title: "Chapter 102",
                    chapterLabel: "102",
                    chapterNumber: 102,
                    sourceURL: URL(string: "https://asurascans.com/series/extras-academy/chapter/102")!,
                    previousChapterURL: nil,
                    nextChapterURL: nil,
                    imageURLs: [],
                    publishedAt: nil
                )
            ]
        ),
        context: .reader
    )

    let snapshot = await repository.librarySnapshot()
    let summary = try #require(snapshot.series.first { $0.id == seriesID })
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(summary.coverImageURL == coverURL)
#expect(detail.coverImageURL == coverURL)
}
```

- [ ] **Step 8: Implement the smallest cover propagation fix**

Use one of these exact minimal changes based on Step 6:

```swift
// Mapper loss fix: preserve existing stored series cover.
coverImageURL: series.coverImageURLString.flatMap(URL.init(string:))
```

```swift
// Recent-to-saved reconciliation fix: only fill missing saved cover.
if series.coverImageURLString == nil, let coverImageURL = input.coverImageURL {
    series.coverImageURLString = coverImageURL.absoluteString
}
```

Do not add network metadata fetching before first render.

- [ ] **Step 9: Run DEF-029 focused tests**

Run:

```bash
swift test --package-path app --filter seriesDetailSeedShellPreservesKnownLibraryCoverURL
swift test --package-path app --filter hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail
swift test --package-path app --filter savedSeriesSummaryAndDetailPreserveCoverURL
```

Expected: relevant tests pass. If `savedSeriesSummaryAndDetailPreserveCoverURL` was not needed or not added, skip that command and note why in the final report.

---

