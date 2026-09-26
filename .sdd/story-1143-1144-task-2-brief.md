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

