# Series Detail Instant Entry and Fixed Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve DEF-029 and implement Stories 11.43 and 11.44 so Series Detail preserves known cover artwork, re-enters instantly from local hydrated state, and keeps the series header/Continue action visible while chapters scroll.

**Architecture:** Keep Series Detail local-first: `LibrarySeriesSummary` remains a visual seed, `SeriesDetailSnapshot` remains the source of truth for Continue and chapter rows, and opportunistic chapter-index refresh stays background-only. Add a narrow in-memory detail cache at `LibraryView` routing scope, pass cached detail into `SeriesDetailView`, and restructure only the Series Detail SwiftUI layout so the hydrated header is outside the chapter `ScrollView`.

**Tech Stack:** Swift 6, SwiftUI `NavigationStack`, Swift Testing, ToonEdge `LibrarySeriesSummary`, `SeriesDetailSnapshot`, `AppDependencies`, and existing Library repository/service protocols.

## Global Constraints

- Implement only DEF-029, Story 11.43, and Story 11.44.
- Do not change persistence schema unless DEF-029 investigation proves current fields are not populated from existing data.
- Do not change Reader detection, Browser behavior, chapter parsing, update checks, save-to-library grouping, Library filters, or Library grid/list layouts.
- Do not make `LibrarySeriesSummary` the source of truth for Continue.
- Do not infer new chapter URLs from summary labels.
- Do not preload full Series Detail snapshots for every Library row.
- Do not block Series Detail rendering on network refresh.
- Use TDD: add/update tests first, verify they fail for the expected reason, implement the smallest changes, then run focused and full tests.

---

## Files

- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - DEF-029: keep seeded and hydrated cover layout driven by known local cover URLs.
  - Story 11.43: add an in-memory `SeriesDetailSnapshot` cache in `LibraryView`; pass cached detail and hydration callback into `SeriesDetailView`.
  - Story 11.44: split hydrated Series Detail into fixed header and independently scrolling chapter content.
- Diagnose, then modify only if cover metadata is lost in mapping: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
  - Only touch if repository summaries or detail snapshots lose already stored cover URLs.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add layout/cache/entry-state tests.
- Modify only if DEF-029 diagnosis requires repository coverage: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
  - Add cover propagation regression tests for saved/recent summary/detail paths.
- Modify: `docs/defects.md`
  - Mark DEF-029 implemented after verification.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Stories 11.43 and 11.44 implemented after verification.

---

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

## Task 2: Story 11.43 Local-Ready Instant Entry

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Interfaces:**
- Consumes:

```swift
struct SeriesDetailSnapshot {
    var primaryChapter: ChapterSummary? { get }
    var primaryActionTitle: String { get }
}
```

- Produces:

```swift
struct SeriesDetailEntryLayout: Equatable, Sendable {
    enum VisibleState: Equatable, Sendable {
        case hydratedDetail
        case seededShell
        case loading
        case unavailable
    }

    var visibleState: VisibleState
    var exposesContinueAction: Bool
    var startsBackgroundRefresh: Bool

    init(cachedDetail: SeriesDetailSnapshot?, seedSummary: LibrarySeriesSummary?, hasLoaded: Bool)
}
```

`SeriesDetailView` initializer becomes:

```swift
init(
    seriesID: UUID,
    seedSummary: LibrarySeriesSummary? = nil,
    cachedDetail: SeriesDetailSnapshot? = nil,
    dependencies: AppDependencies,
    router: Binding<AppRouter>,
    onDetailHydrated: @escaping @MainActor (SeriesDetailSnapshot?) -> Void = { _ in }
)
```

- [ ] **Step 1: Add entry-state tests**

Add these tests near the Series Detail startup/refresh tests in `LibraryExperienceTests.swift`:

```swift
@Test func seriesDetailEntryUsesCachedHydratedDetailBeforeSeedShell() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "100", readState: .read),
            ChapterSummary.mock(chapterLabel: "101", readState: .unread)
        ]
    )
    let seed = LibrarySeriesSummary.mock(title: detail.title)

    let layout = SeriesDetailEntryLayout(
        cachedDetail: detail,
        seedSummary: seed,
        hasLoaded: false
    )

    #expect(layout.visibleState == .hydratedDetail)
    #expect(layout.exposesContinueAction)
    #expect(layout.startsBackgroundRefresh)
}
```

```swift
@Test func seriesDetailEntryIsActionableWhenLocalIndexHasNextChapter() {
    let chapters = (1...200).map { number in
        ChapterSummary.mock(
            chapterLabel: "\(number)",
            chapterNumber: Double(number),
            readState: number <= 100 ? .read : .unread
        )
    }
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)

    let layout = SeriesDetailEntryLayout(
        cachedDetail: detail,
        seedSummary: nil,
        hasLoaded: false
    )

    #expect(detail.primaryActionTitle == "Start Chapter 101")
    #expect(detail.primaryChapter?.chapterLabel == "101")
    #expect(layout.visibleState == .hydratedDetail)
    #expect(layout.exposesContinueAction)
}
```

```swift
@Test func seriesDetailEntryContinuesForwardInProgressChapterFromLocalIndex() {
    let chapters = (1...200).map { number in
        ChapterSummary.mock(
            chapterLabel: "\(number)",
            chapterNumber: Double(number),
            readState: number < 100 ? .read : (number == 100 ? .inProgress(progressPercent: 0.42) : .unread)
        )
    }
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)

    #expect(detail.primaryActionTitle == "Continue Chapter 100")
    #expect(detail.primaryChapter?.chapterLabel == "100")
}
```

```swift
@Test func seriesDetailEntryCanShowAllReadWhileEdgeRefreshRunsInBackground() {
    let chapters = (1...200).map { number in
        ChapterSummary.mock(
            chapterLabel: "\(number)",
            chapterNumber: Double(number),
            readState: .read
        )
    }
    let detail = SeriesDetailSnapshot.mock(chapters: chapters)
    let layout = SeriesDetailEntryLayout(
        cachedDetail: detail,
        seedSummary: nil,
        hasLoaded: false
    )

    #expect(detail.primaryActionTitle == "All Chapters Read")
    #expect(detail.primaryChapter == nil)
    #expect(layout.visibleState == .hydratedDetail)
    #expect(!layout.exposesContinueAction)
    #expect(layout.startsBackgroundRefresh)
}
```

- [ ] **Step 2: Run red tests**

Run:

```bash
swift test --package-path app --filter seriesDetailEntry
```

Expected: compile failure because `SeriesDetailEntryLayout` does not exist.

- [ ] **Step 3: Add entry layout helper**

In `LibraryView.swift`, add near `SeriesDetailStartupPlan`:

```swift
struct SeriesDetailEntryLayout: Equatable, Sendable {
    enum VisibleState: Equatable, Sendable {
        case hydratedDetail
        case seededShell
        case loading
        case unavailable
    }

    var visibleState: VisibleState
    var exposesContinueAction: Bool
    var startsBackgroundRefresh: Bool

    init(
        cachedDetail: SeriesDetailSnapshot?,
        seedSummary: LibrarySeriesSummary?,
        hasLoaded: Bool
    ) {
        if let cachedDetail {
            self.visibleState = .hydratedDetail
            self.exposesContinueAction = cachedDetail.primaryChapter != nil
            self.startsBackgroundRefresh = true
        } else if seedSummary != nil {
            self.visibleState = .seededShell
            self.exposesContinueAction = false
            self.startsBackgroundRefresh = false
        } else if hasLoaded {
            self.visibleState = .unavailable
            self.exposesContinueAction = false
            self.startsBackgroundRefresh = false
        } else {
            self.visibleState = .loading
            self.exposesContinueAction = false
            self.startsBackgroundRefresh = false
        }
    }
}
```

- [ ] **Step 4: Add in-memory detail cache to LibraryView**

In `LibraryView`, add state next to `navigationPath`:

```swift
@State private var seriesDetailCache: [UUID: SeriesDetailSnapshot] = [:]
```

Update the navigation destination:

```swift
.navigationDestination(for: LibrarySeriesDetailRoute.self) { route in
    SeriesDetailView(
        seriesID: route.seriesID,
        seedSummary: route.seedSummary,
        cachedDetail: seriesDetailCache[route.seriesID],
        dependencies: dependencies,
        router: $router,
        onDetailHydrated: { hydratedDetail in
            if let hydratedDetail {
                seriesDetailCache[route.seriesID] = hydratedDetail
            } else {
                seriesDetailCache.removeValue(forKey: route.seriesID)
            }
        }
    )
}
```

- [ ] **Step 5: Seed SeriesDetailView state from cached detail**

Change `SeriesDetailView` properties:

```swift
let onDetailHydrated: @MainActor (SeriesDetailSnapshot?) -> Void
```

Change the initializer to:

```swift
init(
    seriesID: UUID,
    seedSummary: LibrarySeriesSummary? = nil,
    cachedDetail: SeriesDetailSnapshot? = nil,
    dependencies: AppDependencies,
    router: Binding<AppRouter>,
    onDetailHydrated: @escaping @MainActor (SeriesDetailSnapshot?) -> Void = { _ in }
) {
    self.seriesID = seriesID
    self.seedSummary = seedSummary
    self.dependencies = dependencies
    self._router = router
    self.onDetailHydrated = onDetailHydrated
    self._detail = State(initialValue: cachedDetail)
}
```

Keep `SeriesDetailSnapshot` as the only source of truth for Continue.

- [ ] **Step 6: Cache hydrated detail after every local reload**

Update `reloadDetail()`:

```swift
private func reloadDetail() async {
    let loadedDetail = await dependencies.libraryService.seriesDetail(for: seriesID)
    detail = loadedDetail
    hasLoaded = true
    await MainActor.run {
        onDetailHydrated(loadedDetail)
    }
}
```

If `SeriesDetailView` is already main-actor isolated by SwiftUI and the compiler rejects `MainActor.run`, replace the last block with:

```swift
onDetailHydrated(loadedDetail)
```

- [ ] **Step 7: Ensure cached detail starts background refresh**

Keep the existing background refresh task:

```swift
.task(id: detail?.id) {
    guard detail != nil else { return }
    await refreshChapterIndexIfAvailable()
}
```

Expected behavior: when `detail` starts from `cachedDetail`, this task can run immediately, but the page is already actionable from local data.

- [ ] **Step 8: Run Story 11.43 focused tests**

Run:

```bash
swift test --package-path app --filter seriesDetailEntry
swift test --package-path app --filter seriesDetailPrimaryAction
```

Expected: pass.

---

## Task 3: Story 11.44 Fixed Header and Independent Chapter Scroller

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Interfaces:**
- Produces:

```swift
struct SeriesDetailPageLayout: Equatable, Sendable {
    enum StateKind: Equatable, Sendable {
        case hydrated
        case seeded
        case loading
        case unavailable
    }

    var stateKind: StateKind
    var keepsHeaderFixed: Bool
    var scrollsChaptersIndependently: Bool
    var keepsPrimaryActionVisible: Bool

    init(detail: SeriesDetailSnapshot?, seedSummary: LibrarySeriesSummary?, hasLoaded: Bool)
}
```

- [ ] **Step 1: Add fixed-layout tests**

Add these tests near the existing Series Detail layout tests:

```swift
@Test func hydratedSeriesDetailLayoutKeepsHeaderFixedAndChaptersScrollable() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "100", readState: .read),
            ChapterSummary.mock(chapterLabel: "101", readState: .unread)
        ]
    )

    let layout = SeriesDetailPageLayout(detail: detail, seedSummary: nil, hasLoaded: true)

    #expect(layout.stateKind == .hydrated)
    #expect(layout.keepsHeaderFixed)
    #expect(layout.scrollsChaptersIndependently)
    #expect(layout.keepsPrimaryActionVisible)
}
```

```swift
@Test func seededSeriesDetailLayoutKeepsSeedHeaderVisibleWithoutChapterScroller() {
    let summary = LibrarySeriesSummary.mock(title: "Past Life Returner")

    let layout = SeriesDetailPageLayout(detail: nil, seedSummary: summary, hasLoaded: false)

    #expect(layout.stateKind == .seeded)
    #expect(layout.keepsHeaderFixed)
    #expect(!layout.scrollsChaptersIndependently)
    #expect(!layout.keepsPrimaryActionVisible)
}
```

```swift
@Test func nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller() {
    let loading = SeriesDetailPageLayout(detail: nil, seedSummary: nil, hasLoaded: false)
    let unavailable = SeriesDetailPageLayout(detail: nil, seedSummary: nil, hasLoaded: true)

    #expect(loading.stateKind == .loading)
    #expect(!loading.scrollsChaptersIndependently)
    #expect(unavailable.stateKind == .unavailable)
    #expect(!unavailable.scrollsChaptersIndependently)
}
```

- [ ] **Step 2: Run red tests**

Run:

```bash
swift test --package-path app --filter SeriesDetailLayout
swift test --package-path app --filter nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller
```

Expected: compile failure because `SeriesDetailPageLayout` does not exist.

- [ ] **Step 3: Add page layout helper**

In `LibraryView.swift`, add near `SeriesDetailHeaderLayout`:

```swift
struct SeriesDetailPageLayout: Equatable, Sendable {
    enum StateKind: Equatable, Sendable {
        case hydrated
        case seeded
        case loading
        case unavailable
    }

    var stateKind: StateKind
    var keepsHeaderFixed: Bool
    var scrollsChaptersIndependently: Bool
    var keepsPrimaryActionVisible: Bool

    init(detail: SeriesDetailSnapshot?, seedSummary: LibrarySeriesSummary?, hasLoaded: Bool) {
        if let detail {
            self.stateKind = .hydrated
            self.keepsHeaderFixed = true
            self.scrollsChaptersIndependently = true
            self.keepsPrimaryActionVisible = detail.primaryChapter != nil
        } else if seedSummary != nil {
            self.stateKind = .seeded
            self.keepsHeaderFixed = true
            self.scrollsChaptersIndependently = false
            self.keepsPrimaryActionVisible = false
        } else if hasLoaded {
            self.stateKind = .unavailable
            self.keepsHeaderFixed = false
            self.scrollsChaptersIndependently = false
            self.keepsPrimaryActionVisible = false
        } else {
            self.stateKind = .loading
            self.keepsHeaderFixed = false
            self.scrollsChaptersIndependently = false
            self.keepsPrimaryActionVisible = false
        }
    }
}
```

- [ ] **Step 4: Split hydrated body into fixed header and chapter scroller**

Replace the top of `SeriesDetailView.body` with a state-specific builder:

```swift
var body: some View {
    content
        .navigationTitle("")
        .task {
            await reloadDetail()
        }
        .task(id: detail?.id) {
            guard detail != nil else { return }
            await refreshChapterIndexIfAvailable()
        }
        .onChange(of: router.presentedReader) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            Task {
                await reloadDetail()
            }
        }
        .sheet(item: $pendingSaveDetail) { detail in
            AddToLibraryStatePickerView(
                title: detail.title,
                selectedState: $saveState,
                context: .seriesDetail,
                confirm: { state in
                    confirmSave(detail, state: state)
                },
                cancel: {
                    pendingSaveDetail = nil
                }
            )
        }
        .toonEdgeScreen()
}
```

Add this `content` builder:

```swift
@ViewBuilder
private var content: some View {
    if let detail {
        hydratedContent(detail)
    } else if let seedSummary {
        ScrollView {
            seedShell(seedSummary)
                .padding(ToonEdgeSpacing.large)
        }
    } else if hasLoaded {
        ScrollView {
            TEBanner(
                title: "Series unavailable",
                message: "This saved title could not be loaded from the mock repository.",
                systemImage: "exclamationmark.triangle"
            )
            .padding(ToonEdgeSpacing.large)
        }
    } else {
        ScrollView {
            TEBanner(title: "Loading series", message: "Preparing chapter state.", systemImage: "hourglass")
                .padding(ToonEdgeSpacing.large)
        }
    }
}
```

- [ ] **Step 5: Add hydrated fixed-header content**

Add this method inside `SeriesDetailView`:

```swift
private func hydratedContent(_ detail: SeriesDetailSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            header(detail)
            cacheStatus
        }
        .padding(ToonEdgeSpacing.large)
        .background(ToonEdgeColor.background)

        Divider()
            .overlay(ToonEdgeColor.border)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                    chapterToolbar(detail)
                    chapterList(detail)
                }
                .padding(ToonEdgeSpacing.large)
                .padding(.bottom, ToonEdgeSpacing.large)
            }
            .task(id: detail.chapterListAnchorID) {
                guard let anchorID = detail.chapterListAnchorID else { return }
                try? await Task.sleep(for: .milliseconds(100))
                proxy.scrollTo(anchorID, anchor: .center)
            }
        }
    }
}
```

Remove the old outer `ScrollViewReader` wrapper and the old `.task(id: detail?.chapterListAnchorID)` from `body` so the anchor task belongs only to the chapter scroller.

- [ ] **Step 6: Run Story 11.44 focused tests**

Run:

```bash
swift test --package-path app --filter SeriesDetailLayout
swift test --package-path app --filter nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller
swift test --package-path app --filter seriesDetailEntry
```

Expected: pass.

---

## Task 4: Documentation Status and Verification

**Files:**
- Modify: `docs/defects.md`
- Modify: `docs/toonedge_epics_and_stories.md`

- [ ] **Step 1: Mark documentation implemented**

After code verification passes, update:

```markdown
## DEF-029 — Series Detail seeded shell can show placeholder cover despite visible Library artwork

**Status:** Implemented
```

```markdown
### Story 11.43 — Series Detail local-ready instant entry
**Status:** implemented
```

```markdown
### Story 11.44 — Series Detail fixed header with independently scrolling chapters
**Status:** implemented
```

- [ ] **Step 2: Run focused Library tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 3: Run persistence tests if Task 1 touched repository code**

Run:

```bash
swift test --package-path app --filter PersistenceLifecycleTests
```

Expected: pass. If repository code was not touched, this command is still recommended but not required for the defect.

- [ ] **Step 4: Run full test suite**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 5: Build the app**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual simulator check if available**

Open a saved Library series with known cover and local indexed chapters where the reader is not at the edge, for example `100/200`.

Expected:
- Series Detail does not show the `Loading series` banner for normal Library-origin navigation.
- If a hydrated snapshot was cached this session, Series Detail shows the full header and Continue immediately.
- If no hydrated snapshot was cached yet, the seed shell may appear briefly while local detail loads, but no network refresh blocks hydration.
- Cover artwork remains consistent between Library, seeded shell, and hydrated detail when a local cover URL exists.
- Header/Continue stay visible while chapter rows scroll.

---

## Execution Notes

- Implement in the order above. DEF-029 is first because the fixed header will make cover quality more prominent.
- Story 11.43 should not attempt to solve first-ever app-launch synchronous repository hydration. It should guarantee instant re-entry from the in-memory hydrated detail cache and immediate actionability once local detail exists, with no network refresh gating.
- Story 11.44 should be layout-only. If the fixed header exposes unrelated stale chapter-target behavior, stop and document that separately instead of folding it into this story.
