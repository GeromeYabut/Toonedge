# Series Detail Negligible Entry and Stable Position Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement DEF-030 and Story 11.45 so Library-origin Series Detail entry makes locally safe Continue actions, cached covers, and saved chapter positioning feel immediate.

**Architecture:** Keep the change local-first. Extend existing domain summaries with a concrete local resume target only when the repository already has a safe `ChapterSummary` source URL, use that target as an immediate route seed, and keep hydrated `SeriesDetailSnapshot` authoritative after local detail load. Improve perceived performance with visible-row detail prewarming, synchronous memory-cache cover startup, and no-animation initial chapter positioning.

**Tech Stack:** Swift, SwiftUI, Swift Testing, SwiftData-backed repository, existing ToonEdge Library feature module and shared UI primitives.

## Global Constraints

- Implement only DEF-030 and Story 11.45.
- Do not change persistence schema.
- Do not change Reader detection, Browser behavior, chapter parsing, update checks, save-to-library grouping, Library filters, Library layouts, or available-chapter indexing semantics.
- Do not infer chapter URLs from labels, titles, source-specific URL patterns, or latest-known metadata.
- Do not add visible refresh banners, loading copy, progress bars, or spinners to Series Detail.
- Use TDD: add or update tests first, verify targeted failure, implement the smallest change, then run focused and full test commands.

---

## File Map

- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Add a lightweight optional `resumeTarget` to `LibrarySeriesSummary`.
  - Add `LibraryResumeTarget` as a concrete, safe local action seed.
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
  - Populate `LibrarySeriesSummary.resumeTarget` from stored/indexed chapters and recent-reading rows.
  - Reuse existing `SeriesDetailSnapshot.primaryChapter` selection semantics where practical.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Render seed-state primary actions when `LibrarySeriesSummary.resumeTarget` exists.
  - Prewarm visible Library rows into `seriesDetailCache`.
  - Replace delayed chapter-list anchoring with no-animation initial positioning.
- Modify: `app/Sources/ToonEdgeAppCore/SharedUI/Components/ToonEdgePrimitives.swift`
  - Seed `CachedCoverArtwork` synchronously from `CoverArtworkMemoryCache`.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add layout/policy tests for seeded primary actions, prewarm policy, and no-delay initial scroll behavior.
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
  - Add repository tests proving summaries carry concrete resume targets only when safe chapter rows exist.
- Modify: `docs/defects.md`
  - Mark DEF-030 implemented after verification.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Story 11.45 implemented after verification.

---

## Task 1: Add Concrete Local Resume Target to Library Summaries

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `LibraryResumeTarget`
- Produces: `LibrarySeriesSummary.resumeTarget: LibraryResumeTarget?`
- Consumes: `SeriesDetailSnapshot.primaryChapter`

- [ ] **Step 1: Write failing domain/layout tests**

Add tests near existing Series Detail seed tests in `LibraryExperienceTests.swift`:

```swift
@Test func librarySummaryResumeTargetExposesConcreteStartAction() {
    let chapter = ChapterSummary.mock(
        chapterLabel: "101",
        chapterNumber: 101,
        sourceURL: URL(string: "https://example.com/chapter-101")!,
        readState: .unread
    )
    let target = LibraryResumeTarget(chapter: chapter)
    let summary = LibrarySeriesSummary.mock(
        title: "Moonlit Edge",
        currentChapterLabel: "100",
        latestChapterLabel: "200",
        resumeTarget: target
    )

    #expect(summary.resumeTarget?.chapter.id == chapter.id)
    #expect(summary.resumeTarget?.actionTitle == "Start Chapter 101")
    #expect(summary.resumeTarget?.chapter.sourceURL.absoluteString == "https://example.com/chapter-101")
}

@Test func librarySummaryResumeTargetExposesConcreteContinueAction() {
    let chapter = ChapterSummary.mock(
        chapterLabel: "100",
        chapterNumber: 100,
        sourceURL: URL(string: "https://example.com/chapter-100")!,
        readState: .inProgress(progressPercent: 0.42)
    )
    let target = LibraryResumeTarget(chapter: chapter)

    #expect(target.actionTitle == "Continue Chapter 100")
}
```

Update the private `LibrarySeriesSummary.mock(...)` helper in `LibraryExperienceTests.swift` to accept:

```swift
resumeTarget: LibraryResumeTarget? = nil
```

and pass it through to `LibrarySeriesSummary(...)`.

- [ ] **Step 2: Write failing repository tests**

Add these tests to `PersistenceLifecycleTests.swift` near existing Series Detail primary-action tests:

```swift
@Test func librarySnapshotSummaryCarriesConcreteResumeTargetFromIndexedChapters() async throws {
    let repository = try makeInMemoryLibraryRepository()
    let seriesID = UUID()
    let chapter100ID = UUID()
    let chapter101ID = UUID()

    try await repository.addToLibrary(
        LibrarySeriesInput(
            id: seriesID,
            title: "Moonlit Edge",
            sourceDomain: "example.com",
            canonicalURL: URL(string: "https://example.com/series/moonlit-edge")!,
            coverImageURL: nil,
            status: "Reading",
            synopsis: nil,
            latestKnownChapterLabel: "200",
            chapters: [
                LibraryChapterInput(
                    id: chapter100ID,
                    title: "Moonlit Edge Chapter 100",
                    chapterLabel: "100",
                    sourceURL: URL(string: "https://example.com/chapter-100")!,
                    imageURLs: [],
                    publishedAt: nil
                ),
                LibraryChapterInput(
                    id: chapter101ID,
                    title: "Moonlit Edge Chapter 101",
                    chapterLabel: "101",
                    sourceURL: URL(string: "https://example.com/chapter-101")!,
                    imageURLs: [],
                    publishedAt: nil
                )
            ],
            libraryState: .reading
        ),
        context: .reader
    )

    try await repository.recordProgress(
        ReaderProgressInput(
            chapterID: chapter100ID,
            seriesID: seriesID,
            currentImageIndex: 10,
            totalImageCount: 10,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    )

    let summary = try #require(await repository.librarySnapshot().series.first { $0.id == seriesID })

    #expect(summary.resumeTarget?.chapter.id == chapter101ID)
    #expect(summary.resumeTarget?.actionTitle == "Start Chapter 101")
}

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
```

- [ ] **Step 3: Verify targeted failure**

Run:

```bash
swift test --package-path app --filter 'librarySummaryResumeTarget|librarySnapshotSummary'
```

Expected: fails because `LibraryResumeTarget`, `LibrarySeriesSummary.resumeTarget`, and the new initializer/mock parameters do not exist.

- [ ] **Step 4: Implement the domain model**

In `AppModels.swift`, add this near `LibrarySeriesSummary`:

```swift
public struct LibraryResumeTarget: Equatable, Sendable {
    public var chapter: ChapterSummary

    public init(chapter: ChapterSummary) {
        self.chapter = chapter
    }

    public var actionTitle: String {
        let label = ChapterNumericLabelExtractor.label(for: chapter) ?? chapter.chapterLabel
        if case .inProgress = chapter.readState {
            return "Continue Chapter \(label)"
        }
        return "Start Chapter \(label)"
    }
}
```

Add to `LibrarySeriesSummary`:

```swift
public var resumeTarget: LibraryResumeTarget?
```

Add an initializer parameter at the end with a default:

```swift
resumeTarget: LibraryResumeTarget? = nil
```

and assign:

```swift
self.resumeTarget = resumeTarget
```

- [ ] **Step 5: Populate summaries from concrete local chapters**

In `SwiftDataLibraryRepository.seriesSummary(_:)`, compute chapter summaries once and set `resumeTarget` from the same primary chapter logic used by detail:

```swift
let chapters = fetchChapters(seriesID: series.id)
let chapterSummaries = chapters.map(chapterSummary)
let detail = SeriesDetailSnapshot(
    id: series.id,
    title: series.title,
    status: series.status,
    synopsis: series.synopsis,
    sourceDomain: series.sourceDomain,
    coverImageURL: series.coverImageURLString.flatMap(URL.init(string:)),
    isSaved: true,
    libraryState: libraryState(for: series),
    progressPercent: progressPercent(for: series, chapters: chapters),
    chaptersRead: chaptersRead(for: chapters),
    totalKnownChapters: chapters.count,
    hasUnreadUpdates: series.hasUnreadUpdates,
    chapters: chapterSummaries
)
let resumeTarget = detail.primaryChapter.map(LibraryResumeTarget.init(chapter:))
```

Then pass `resumeTarget: resumeTarget` to `LibrarySeriesSummary(...)`.

For recent-only summaries, build the existing recent `ChapterSummary` first, then pass:

```swift
resumeTarget: LibraryResumeTarget(chapter: recentChapter)
```

Only create a target from a real `ChapterSummary` with an existing `sourceURL`; do not use `latestChapterLabel` or `currentChapterLabel` by itself.

- [ ] **Step 6: Run targeted tests**

Run:

```bash
swift test --package-path app --filter 'librarySummaryResumeTarget|librarySnapshotSummary'
```

Expected: pass.

---

## Task 2: Render Seeded Continue Action Before Detail Hydration

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes: `LibrarySeriesSummary.resumeTarget`
- Produces: `SeriesDetailSeedShellLayout.primaryChapter`
- Produces: `SeriesDetailSeedShellLayout.primaryActionTitle`

- [ ] **Step 1: Write failing layout tests**

Replace the expectation in `seriesDetailSeedShellShowsLibrarySummaryWithoutContinueAction` so it still covers the no-target case:

```swift
#expect(!layout.exposesContinueAction)
#expect(layout.primaryChapter == nil)
#expect(layout.primaryActionTitle == nil)
```

Add:

```swift
@Test func seriesDetailSeedShellExposesContinueWhenSummaryHasConcreteResumeTarget() {
    let chapter = ChapterSummary.mock(
        chapterLabel: "101",
        chapterNumber: 101,
        sourceURL: URL(string: "https://example.com/chapter-101")!,
        readState: .unread
    )
    let summary = LibrarySeriesSummary.mock(
        title: "Moonlit Edge",
        sourceDomain: "example.com",
        resumeTarget: LibraryResumeTarget(chapter: chapter)
    )

    let layout = SeriesDetailSeedShellLayout(summary: summary)

    #expect(layout.exposesContinueAction)
    #expect(layout.primaryChapter == chapter)
    #expect(layout.primaryActionTitle == "Start Chapter 101")
}
```

- [ ] **Step 2: Verify targeted failure**

Run:

```bash
swift test --package-path app --filter 'seriesDetailSeedShell'
```

Expected: fails because `primaryChapter` and `primaryActionTitle` do not exist on `SeriesDetailSeedShellLayout`.

- [ ] **Step 3: Implement the seed layout**

In `SeriesDetailSeedShellLayout`, add:

```swift
var primaryChapter: ChapterSummary?
var primaryActionTitle: String?
```

and update `init(summary:)`:

```swift
self.primaryChapter = summary.resumeTarget?.chapter
self.primaryActionTitle = summary.resumeTarget?.actionTitle
self.exposesContinueAction = summary.resumeTarget != nil
```

- [ ] **Step 4: Render the seeded action**

In `SeriesDetailView.seedShell(_:)`, after the header `HStack`, add:

```swift
if let primaryChapter = layout.primaryChapter,
   let primaryActionTitle = layout.primaryActionTitle {
    TEButton(primaryActionTitle, systemImage: "play.fill") {
        open(primaryChapter)
    }
}
```

Do not render a disabled fake Continue button when `primaryChapter` is nil.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter 'seriesDetailSeedShell'
```

Expected: pass.

---

## Task 3: Prewarm Visible Library Rows Into the Existing Detail Cache

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes: `seriesDetailCache: [UUID: SeriesDetailSnapshot]`
- Produces: `SeriesDetailPreloadPolicy.shouldPreload(seriesID:cachedDetailIDs:inFlightIDs:)`

- [ ] **Step 1: Write failing policy tests**

Add to `LibraryExperienceTests.swift` near cache policy tests:

```swift
@Test func seriesDetailPreloadPolicySkipsAlreadyCachedAndInFlightSeries() {
    let cached = UUID()
    let inFlight = UUID()
    let fresh = UUID()

    #expect(!SeriesDetailPreloadPolicy.shouldPreload(
        seriesID: cached,
        cachedDetailIDs: [cached],
        inFlightIDs: []
    ))
    #expect(!SeriesDetailPreloadPolicy.shouldPreload(
        seriesID: inFlight,
        cachedDetailIDs: [],
        inFlightIDs: [inFlight]
    ))
    #expect(SeriesDetailPreloadPolicy.shouldPreload(
        seriesID: fresh,
        cachedDetailIDs: [cached],
        inFlightIDs: [inFlight]
    ))
}
```

- [ ] **Step 2: Verify targeted failure**

Run:

```bash
swift test --package-path app --filter seriesDetailPreloadPolicy
```

Expected: fails because `SeriesDetailPreloadPolicy` does not exist.

- [ ] **Step 3: Implement the preload policy**

Add near `SeriesDetailCachePolicy` in `LibraryView.swift`:

```swift
struct SeriesDetailPreloadPolicy: Equatable, Sendable {
    static func shouldPreload(
        seriesID: UUID,
        cachedDetailIDs: Set<UUID>,
        inFlightIDs: Set<UUID>
    ) -> Bool {
        !cachedDetailIDs.contains(seriesID) && !inFlightIDs.contains(seriesID)
    }
}
```

- [ ] **Step 4: Wire visible-row prewarming**

In `LibraryView`, add state:

```swift
@State private var preloadingSeriesDetailIDs: Set<UUID> = []
```

On each visible `NavigationLink` in `content`, add:

```swift
.task(id: series.id) {
    await prewarmSeriesDetailIfNeeded(series.id)
}
```

Add this method to `LibraryView`:

```swift
private func prewarmSeriesDetailIfNeeded(_ seriesID: UUID) async {
    guard SeriesDetailPreloadPolicy.shouldPreload(
        seriesID: seriesID,
        cachedDetailIDs: Set(seriesDetailCache.keys),
        inFlightIDs: preloadingSeriesDetailIDs
    ) else {
        return
    }

    preloadingSeriesDetailIDs.insert(seriesID)
    let detail = await dependencies.libraryService.seriesDetail(for: seriesID)
    if let detail {
        seriesDetailCache[seriesID] = detail
    }
    preloadingSeriesDetailIDs.remove(seriesID)
}
```

This prewarms only rows SwiftUI has made visible. It does not iterate through the entire Library snapshot.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter seriesDetailPreloadPolicy
```

Expected: pass.

---

## Task 4: Use Cached Cover Data on the First Rendered Frame

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/SharedUI/Components/ToonEdgePrimitives.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `CoverArtworkStartupPolicy.initialData(url:cache:)`
- Consumes: `CoverArtworkMemoryCache.data(for:)`

- [ ] **Step 1: Write failing cache startup test**

Add to `LibraryExperienceTests.swift`:

```swift
@MainActor
@Test func coverArtworkStartupPolicyUsesCachedDataSynchronously() {
    let cache = CoverArtworkMemoryCache()
    let url = URL(string: "https://example.com/cover.jpg")!
    let data = Data([0x01, 0x02, 0x03])
    cache.store(data, for: url)

    #expect(CoverArtworkStartupPolicy.initialData(url: url, cache: cache) == data)
    #expect(CoverArtworkStartupPolicy.initialData(url: nil, cache: cache) == nil)
    #expect(CoverArtworkStartupPolicy.initialData(url: URL(string: "https://example.com/missing.jpg")!, cache: cache) == nil)
}
```

- [ ] **Step 2: Verify targeted failure**

Run:

```bash
swift test --package-path app --filter coverArtworkStartupPolicy
```

Expected: fails because `CoverArtworkStartupPolicy` does not exist.

- [ ] **Step 3: Implement synchronous startup lookup**

In `ToonEdgePrimitives.swift`, add near `CoverArtworkMemoryCache`:

```swift
@MainActor
public struct CoverArtworkStartupPolicy: Equatable, Sendable {
    public static func initialData(url: URL?, cache: CoverArtworkMemoryCache) -> Data? {
        guard let url else { return nil }
        return cache.data(for: url)
    }
}
```

In `CachedCoverArtwork.init(...)`, seed the state:

```swift
self.url = url
self.cache = cache
self.placeholder = placeholder()
self._imageData = State(initialValue: CoverArtworkStartupPolicy.initialData(url: url, cache: cache))
```

Keep `.task(id: url)` so uncached covers still download normally.

- [ ] **Step 4: Run focused tests**

Run:

```bash
swift test --package-path app --filter coverArtworkStartupPolicy
```

Expected: pass.

---

## Task 5: Remove Delayed Chapter-List Jitter

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `SeriesDetailInitialScrollBehavior`
- Consumes: `SeriesDetailSnapshot.chapterListAnchorID`

- [ ] **Step 1: Write failing scroll behavior tests**

Add near `seriesDetailChapterListAnchorPrefersPrimaryChapterThenLatestReadChapter`:

```swift
@Test func seriesDetailInitialScrollBehaviorUsesNoDelayAndDisablesAnimation() {
    let anchorID = UUID()
    let behavior = SeriesDetailInitialScrollBehavior(anchorID: anchorID)
    let missing = SeriesDetailInitialScrollBehavior(anchorID: nil)

    #expect(behavior.shouldScroll)
    #expect(behavior.delayMilliseconds == 0)
    #expect(behavior.disablesAnimation)
    #expect(!missing.shouldScroll)
}
```

- [ ] **Step 2: Verify targeted failure**

Run:

```bash
swift test --package-path app --filter seriesDetailInitialScrollBehavior
```

Expected: fails because `SeriesDetailInitialScrollBehavior` does not exist.

- [ ] **Step 3: Implement the behavior model**

Add near other Series Detail layout models in `LibraryView.swift`:

```swift
struct SeriesDetailInitialScrollBehavior: Equatable, Sendable {
    var anchorID: UUID?
    var delayMilliseconds: Int
    var disablesAnimation: Bool

    init(anchorID: UUID?) {
        self.anchorID = anchorID
        self.delayMilliseconds = 0
        self.disablesAnimation = anchorID != nil
    }

    var shouldScroll: Bool {
        anchorID != nil
    }
}
```

- [ ] **Step 4: Replace the delayed scroll**

In `hydratedContent(_:)`, replace:

```swift
try? await Task.sleep(for: .milliseconds(100))
proxy.scrollTo(anchorID, anchor: .center)
```

with:

```swift
let behavior = SeriesDetailInitialScrollBehavior(anchorID: detail.chapterListAnchorID)
guard behavior.shouldScroll, let anchorID = behavior.anchorID else { return }
await Task.yield()
var transaction = Transaction()
transaction.disablesAnimations = behavior.disablesAnimation
transaction.animation = nil
withTransaction(transaction) {
    proxy.scrollTo(anchorID, anchor: .center)
}
```

Do not add a fast animation. The desired visual behavior is no visible movement.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter seriesDetailInitialScrollBehavior
```

Expected: pass.

---

## Task 6: Final Verification and Documentation

**Files:**
- Modify: `docs/defects.md`
- Modify: `docs/toonedge_epics_and_stories.md`

- [ ] **Step 1: Run Library-focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 2: Run persistence-focused tests touched by this plan**

Run:

```bash
swift test --package-path app --filter PersistenceLifecycleTests
```

Expected: pass.

- [ ] **Step 3: Run the full package test suite**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 4: Build the app**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 5: Manual simulator walkthrough**

Open a saved Library series with known local chapters and cover artwork.

Verify:
- The Series Detail header appears immediately.
- If the local summary has a concrete resume target, the primary action is tappable immediately.
- The cover does not flash to the placeholder when the same cover was already visible in Library during the current app session.
- The chapter list opens near the next/last-read target without a visible delayed jump.
- Opportunistic refresh may update the chapter count or target later, but does not block entry.

- [ ] **Step 6: Mark docs implemented**

In `docs/defects.md`, update:

```markdown
**Status:** Implemented
```

for DEF-030.

In `docs/toonedge_epics_and_stories.md`, update:

```markdown
**Status:** implemented
```

for Story 11.45.

---

## Self-Review Notes

- Spec coverage: DEF-030 is covered by Tasks 1, 2, 4, and 5. Story 11.45 is covered by all tasks.
- Type consistency: `LibraryResumeTarget` is introduced before any layout, repository, or mock code consumes it.
- Scope guard: the plan does not change persistence schema, Reader detection, Browser behavior, chapter parsing, update checks, save-to-library grouping, Library filters, or Library layouts.
- UX guard: the scroll fix uses no-animation initial positioning instead of a fast animated scroll because the target behavior is absence of visible jitter.
