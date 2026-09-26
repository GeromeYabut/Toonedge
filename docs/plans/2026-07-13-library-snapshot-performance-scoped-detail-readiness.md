# Library Snapshot Performance and Scoped Detail Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement DEF-031 and Story 11.46 so Home-to-Library navigation, Library filter changes, and opening a toon remain responsive with local sample data and many indexed chapters.

**Architecture:** Restore Library and Home snapshots to lightweight summary projections. Keep `LibrarySeriesSummary.resumeTarget`, but compute it through a targeted local projection instead of constructing full `SeriesDetailSnapshot`s for every saved series. Remove automatic per-visible-row detail prewarming and optimize SwiftData repository lookup paths with targeted predicates and bounded normalization.

**Tech Stack:** Swift, SwiftUI, Swift Testing, SwiftData, existing ToonEdge repository/service protocols.

## Global Constraints

- Implement only DEF-031 and Story 11.46.
- Do not change persistence schema.
- Do not change Reader detection, Browser behavior, chapter parsing, update checks, save-to-library grouping, Library visual layout, available-chapter indexing semantics, or Series Detail background refresh behavior.
- Do not remove seeded Continue actions introduced by Story 11.45.
- Do not add speculative network refreshes or source parsing to Library tab entry.
- Use TDD: add/update tests first, verify targeted failure, implement the smallest change, then run focused and full test commands.

---

## File Map

- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Remove automatic visible-row detail prewarming.
  - Keep `seriesDetailCache` for hydrated navigation results only.
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
  - Add targeted SwiftData fetch descriptors.
  - Add lightweight resume-target projection for `LibrarySeriesSummary`.
  - Avoid duplicate normalization during every snapshot render.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add/adjust layout policy tests proving automatic prewarm is disabled for segment changes.
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
  - Add regression tests for resume target parity and duplicate-normalization guard.
- Modify: `docs/defects.md`
  - Mark DEF-031 implemented after verification.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Story 11.46 implemented after verification.

---

## Task 1: Disable Automatic Visible-Row Detail Prewarming

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `LibraryDetailPrewarmPolicy.automaticallyPrewarmsVisibleRows`
- Consumes: existing `seriesDetailCache` for navigation-destination cached detail.

- [ ] **Step 1: Write the failing policy test**

Add near existing Library collection/layout tests:

```swift
@Test func libraryDetailPrewarmPolicyDoesNotAutomaticallyPrewarmVisibleRows() {
    let policy = LibraryDetailPrewarmPolicy()

    #expect(!policy.automaticallyPrewarmsVisibleRows)
    #expect(policy.prewarmTrigger == .navigationOnly)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path app --filter libraryDetailPrewarmPolicy
```

Expected: fails because `LibraryDetailPrewarmPolicy` does not exist.

- [ ] **Step 3: Implement the policy and remove the visible-row task**

In `LibraryView.swift`, remove:

```swift
@State private var preloadingSeriesDetailIDs: Set<UUID> = []
```

Remove this modifier from the Library `NavigationLink`:

```swift
.task(id: series.id) {
    await prewarmSeriesDetailIfNeeded(series.id)
}
```

Remove `prewarmSeriesDetailIfNeeded(_:)` and `SeriesDetailPreloadPolicy`.

Add this model near the other Library layout models:

```swift
struct LibraryDetailPrewarmPolicy: Equatable, Sendable {
    enum Trigger: Equatable, Sendable {
        case navigationOnly
    }

    var automaticallyPrewarmsVisibleRows: Bool { false }
    var prewarmTrigger: Trigger { .navigationOnly }
}
```

- [ ] **Step 4: Update obsolete tests**

Remove or replace `seriesDetailPreloadPolicySkipsAlreadyCachedAndInFlightSeries()` because automatic visible-row prewarming is no longer intended behavior.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter 'libraryDetailPrewarmPolicy|LibraryExperienceTests'
```

Expected: pass.

---

## Task 2: Add Targeted SwiftData Fetch Helpers

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Interfaces:**
- Produces targeted helpers:
  - `fetchSeries(id:)`
  - `fetchSeries(canonicalURLString:)`
  - `fetchChapters(seriesID:)`
  - `fetchChapter(id:)`
  - `fetchChapter(sourceURLString:)`
  - `fetchProgress(sourceURLString:)`
  - `fetchRecentReading(seriesID:)`
  - `fetchRecentReading(seriesURLString:)`

- [ ] **Step 1: Add behavior-preservation tests for targeted lookup paths**

Add to `PersistenceLifecycleTests.swift` near existing repository lookup tests:

```swift
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
                .mock(id: chapter101ID, chapterLabel: "101", sourceURL: chapter101URL, imageURLs: []),
                .mock(id: chapter102ID, chapterLabel: "102", sourceURL: chapter102URL, imageURLs: [])
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
```

- [ ] **Step 2: Run test before implementation**

Run:

```bash
swift test --package-path app --filter swiftDataRepositoryTargetedLookupsPreserveSeriesDetailAndProgress
```

Expected: passes before implementation. This is a behavior-preservation test for the refactor.

- [ ] **Step 3: Implement targeted fetch descriptors**

In `SwiftDataLibraryRepository.swift`, update SwiftData branches to use predicates:

```swift
private func fetchSeries(id: UUID) -> StoredSeries? {
    if usesModelContextIO {
        var descriptor = FetchDescriptor<StoredSeries>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
    return seriesStore[id]
}

private func fetchChapters(seriesID: UUID) -> [StoredChapter] {
    if usesModelContextIO {
        let descriptor = FetchDescriptor<StoredChapter>(
            predicate: #Predicate { $0.seriesID == seriesID },
            sortBy: [SortDescriptor(\.chapterNumber), SortDescriptor(\.chapterLabel)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    return chapterStore.values.filter { $0.seriesID == seriesID }.sorted(by: chapterOrder)
}
```

Apply the same targeted pattern to chapter ID/source URL, progress source URL, and recent reading ID/URL. If SwiftData sort descriptors cannot exactly match `chapterOrder` for nil chapter numbers, fetch by predicate and keep the existing in-memory `sorted(by: chapterOrder)` for that series only.

- [ ] **Step 4: Run targeted lookup tests**

Run:

```bash
swift test --package-path app --filter swiftDataRepositoryTargetedLookupsPreserveSeriesDetailAndProgress
```

Expected: pass.

---

## Task 3: Replace Detail-Level Summary Resume Target Computation

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Interfaces:**
- Produces: `resumeTarget(for:series:chapters:) -> LibraryResumeTarget?` as a private repository helper.
- Consumes: existing `SeriesDetailSnapshot.primaryChapter` semantics for parity.

- [ ] **Step 1: Add parity test for summary target versus detail target**

Add:

```swift
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
                .mock(id: chapter100ID, chapterLabel: "100", chapterNumber: 100, imageURLs: []),
                .mock(id: chapter101ID, chapterLabel: "101", chapterNumber: 101, imageURLs: [])
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
```

- [ ] **Step 2: Run parity test before implementation**

Run:

```bash
swift test --package-path app --filter librarySummaryResumeTargetMatchesSeriesDetailPrimaryChapter
```

Expected: pass before implementation; it locks behavior before the performance refactor.

- [ ] **Step 3: Replace temporary detail construction in `seriesSummary(_:)`**

Remove this work from `seriesSummary(_:)`:

```swift
let chapterSummaries = chapters.map(chapterSummary)
let detail = SeriesDetailSnapshot(...)
```

Add a private helper:

```swift
private func resumeTarget(for series: StoredSeries, chapters: [StoredChapter]) -> LibraryResumeTarget? {
    let candidates = chapters.map(chapterSummary)
    let detail = SeriesDetailSnapshot(
        id: series.id,
        title: series.title,
        status: series.status,
        synopsis: series.synopsis,
        sourceDomain: series.sourceDomain,
        coverImageURL: series.coverImageURLString.flatMap(URL.init(string:)),
        isSaved: true,
        libraryState: libraryState(for: series),
        progressPercent: 0,
        chaptersRead: 0,
        totalKnownChapters: chapters.count,
        hasUnreadUpdates: series.hasUnreadUpdates,
        chapters: candidates
    )
    return detail.primaryChapter.map(LibraryResumeTarget.init(chapter:))
}
```

Then refactor the helper further so it does not need full detail metadata. The final helper may still reuse `ChapterSummary` for the small set of chapters in one series, but `seriesSummary(_:)` must not compute synopsis/progress/detail fields solely to build a temporary detail snapshot.

- [ ] **Step 4: Run parity and Library tests**

Run:

```bash
swift test --package-path app --filter 'librarySummaryResumeTargetMatchesSeriesDetailPrimaryChapter|LibraryExperienceTests'
```

Expected: pass.

---

## Task 4: Bound Duplicate Normalization Away From Every Snapshot

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Interfaces:**
- Produces: repository-private `hasNormalizedDuplicateRecordsThisSession`.

- [ ] **Step 1: Add behavior test proving repeated snapshots are stable**

Add:

```swift
@MainActor
@Test func repeatedLibrarySnapshotsPreserveDeduplicatedVisibleResults() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()

    try await repository.addToLibrary(
        LibrarySeriesInput.mock(id: seriesID, title: "Repeated Snapshot"),
        context: .reader
    )

    let first = await repository.librarySnapshot()
    let second = await repository.librarySnapshot()

    #expect(first.series.map(\.id) == second.series.map(\.id))
    #expect(first.series(for: .reading).map(\.id) == second.series(for: .reading).map(\.id))
}
```

- [ ] **Step 2: Run behavior test before implementation**

Run:

```bash
swift test --package-path app --filter repeatedLibrarySnapshotsPreserveDeduplicatedVisibleResults
```

Expected: pass before implementation.

- [ ] **Step 3: Add session guard**

In the repository, add:

```swift
private var hasNormalizedDuplicateRecordsThisSession = false
```

Add:

```swift
private func normalizeDuplicateRecordsOnceIfNeeded() {
    guard !hasNormalizedDuplicateRecordsThisSession else { return }
    normalizeDuplicateRecordsIfNeeded()
    hasNormalizedDuplicateRecordsThisSession = true
}
```

Update `librarySnapshot()` to call `normalizeDuplicateRecordsOnceIfNeeded()` instead of `normalizeDuplicateRecordsIfNeeded()`.

In mutation paths that can create duplicates, either call `normalizeDuplicateRecordsIfNeeded()` directly after the mutation or reset `hasNormalizedDuplicateRecordsThisSession = false`. Keep the change conservative: do not remove existing duplicate-repair behavior, only stop running the full all-chapter grouping on every snapshot render.

- [ ] **Step 4: Run persistence tests**

Run:

```bash
swift test --package-path app --filter PersistenceLifecycleTests
```

Expected: pass.

---

## Task 5: Final Verification and Documentation

**Files:**
- Modify: `docs/defects.md`
- Modify: `docs/toonedge_epics_and_stories.md`

- [ ] **Step 1: Run focused Library tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 2: Run focused persistence tests**

Run:

```bash
swift test --package-path app --filter PersistenceLifecycleTests
```

Expected: pass.

- [ ] **Step 3: Run full test suite**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 5: Manual performance walkthrough**

With simulator sample data already present:
- Open Home.
- Tap Library.
- Switch `Recent` to `Reading`, then back.
- Tap a visible toon.

Expected:
- Library tab selection feels immediate.
- Segment switching does not visibly hang.
- Tapping a toon is not blocked by other visible rows loading detail.
- Seeded Continue action still appears when a safe local resume target exists.

- [ ] **Step 6: Mark docs implemented**

In `docs/defects.md`, mark DEF-031:

```markdown
**Status:** Implemented
```

In `docs/toonedge_epics_and_stories.md`, mark Story 11.46:

```markdown
**Status:** implemented
```

---

## Self-Review Notes

- Spec coverage: DEF-031 root causes map to Tasks 1-4; Story 11.46 acceptance criteria map to Tasks 1-5.
- Scope guard: no persistence schema change, no Reader/Browser/parser/update-check behavior changes, and no Library visual redesign.
- Test strategy: use behavior-preservation tests and work-shape policy tests rather than brittle wall-clock performance assertions.
