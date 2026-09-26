# Series Detail Seeded Shell from Library Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Story 11.42 so Library-origin Series Detail navigation renders an immediate seeded shell from the tapped Library row instead of a loading-only screen.

**Architecture:** Replace the Library `NavigationStack` path element from bare `UUID` to a small hashable route that carries `seriesID` plus an optional `LibrarySeriesSummary` seed. `SeriesDetailView` accepts the optional seed and renders a seed-only shell while `detail == nil`; hydrated `SeriesDetailSnapshot` remains the source of truth for Continue, chapter list, library mutation, cache actions, and background refresh.

**Tech Stack:** Swift 6, SwiftUI `NavigationStack`, Swift Testing, existing ToonEdge `LibrarySeriesSummary`, `SeriesDetailSnapshot`, and `AppRouter` pending Library destination flow.

## Global Constraints

- Implement only Story 11.42.
- Do not change persistence schema.
- Do not change Reader detection, Browser behavior, chapter-index fetching/parsing, update-check comparison, save-to-library grouping, or Library collection layout.
- Do not make `LibrarySeriesSummary` the source of truth for Continue.
- Do not infer chapter URLs from summary labels.
- Do not add new network requests before first render.
- Preserve router-driven navigation that only has a `seriesID`.
- Use TDD: add/update tests first, verify expected failure, then implement the smallest SwiftUI/layout change.

---

## Files

- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Add `LibrarySeriesDetailRoute`.
  - Change `navigationPath` from `[UUID]` to `[LibrarySeriesDetailRoute]`.
  - Pass a seeded route from visible Library cells.
  - Preserve pending-router `seriesID` navigation with an unseeded route.
  - Add a seed shell layout/view for `SeriesDetailView`.
  - Render seed shell when `detail == nil && seedSummary != nil`.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add route hashing/equality tests.
  - Add seed-shell layout tests.
  - Add hydration behavior tests for Continue remaining detail-sourced.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Story 11.42 implemented after verification.

---

## Task 1: Add Route and Seed Shell Behavior Tests

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Interfaces:**
- Produces:

```swift
struct LibrarySeriesDetailRoute: Hashable, Sendable {
    var seriesID: UUID
    var seedSummary: LibrarySeriesSummary?
}

struct SeriesDetailSeedShellLayout: Equatable, Sendable {
    var title: String
    var metadata: String
    var coverImageURL: URL?
    var status: String
    var hasUnreadUpdates: Bool
    var showsLoadingBanner: Bool
    var exposesContinueAction: Bool
}
```

- [ ] **Step 1: Add route identity test**

Add this test near other Library navigation/layout tests in `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`:

```swift
@Test func librarySeriesDetailRouteIdentityUsesSeriesIDAndCarriesOptionalSeed() {
    let seriesID = UUID(uuidString: "C8D607B4-91EC-4D18-B28B-0626E9A8C748")!
    let firstSeed = LibrarySeriesSummary.mock(
        id: seriesID,
        title: "The Extra's Academy Survival Guide",
        sourceDomain: "asurascans.com",
        currentChapterLabel: "101"
    )
    let refreshedSeed = LibrarySeriesSummary.mock(
        id: seriesID,
        title: "The Extra's Academy Survival Guide | Asura Scans",
        sourceDomain: "asurascans.com",
        currentChapterLabel: "102"
    )

    let firstRoute = LibrarySeriesDetailRoute(seriesID: seriesID, seedSummary: firstSeed)
    let refreshedRoute = LibrarySeriesDetailRoute(seriesID: seriesID, seedSummary: refreshedSeed)
    let unseededRoute = LibrarySeriesDetailRoute(seriesID: seriesID, seedSummary: nil)

    #expect(firstRoute == refreshedRoute)
    #expect(firstRoute == unseededRoute)
    #expect(firstRoute.seedSummary?.title == "The Extra's Academy Survival Guide")
}
```

- [ ] **Step 2: Add seed shell layout test**

Add this test near the Series Detail layout tests:

```swift
@Test func seriesDetailSeedShellShowsLibrarySummaryWithoutContinueAction() {
    let summary = LibrarySeriesSummary.mock(
        title: "Past Life Returner",
        sourceDomain: "vortexscans.org",
        progressPercent: 0.48,
        chaptersRead: 101,
        totalKnownChapters: 200,
        libraryState: .reading,
        hasUnreadUpdates: false,
        currentChapterLabel: "101"
    )

    let layout = SeriesDetailSeedShellLayout(summary: summary)

    #expect(layout.title == "Past Life Returner")
    #expect(layout.metadata == "vortexscans.org • 101/200 chapters")
    #expect(layout.status == "Reading")
    #expect(!layout.hasUnreadUpdates)
    #expect(!layout.showsLoadingBanner)
    #expect(!layout.exposesContinueAction)
}
```

- [ ] **Step 3: Add hydration-source test**

Add this test to make the Continue boundary explicit:

```swift
@Test func seededSeriesDetailUsesHydratedDetailForContinueAction() {
    let summary = LibrarySeriesSummary.mock(
        title: "Past Life Returner",
        sourceDomain: "vortexscans.org",
        chaptersRead: 101,
        totalKnownChapters: 200,
        currentChapterLabel: "101"
    )
    let chapter101 = ChapterSummary.mock(chapterLabel: "101", readState: .read)
    let chapter102 = ChapterSummary.mock(chapterLabel: "102", readState: .unread)
    let detail = SeriesDetailSnapshot.mock(chapters: [chapter101, chapter102])

    let seedLayout = SeriesDetailSeedShellLayout(summary: summary)
    let hydratedLayout = SeriesDetailHeaderLayout(snapshot: detail)

    #expect(!seedLayout.exposesContinueAction)
    #expect(hydratedLayout.primaryActionTitle == "Start Chapter 102")
}
```

- [ ] **Step 4: Run focused red tests**

Run:

```bash
swift test --package-path app --filter librarySeriesDetailRouteIdentityUsesSeriesIDAndCarriesOptionalSeed
swift test --package-path app --filter seriesDetailSeedShellShowsLibrarySummaryWithoutContinueAction
swift test --package-path app --filter seededSeriesDetailUsesHydratedDetailForContinueAction
```

Expected: compile failures because `LibrarySeriesDetailRoute`, `SeriesDetailSeedShellLayout`, and `LibrarySeriesSummary.mock` overloads do not exist yet.

- [ ] **Step 5: Add test fixture overload if needed**

If the existing `LibrarySeriesSummary.mock` test helper does not support every parameter used above, extend the helper at the bottom of `LibraryExperienceTests.swift`:

```swift
private extension LibrarySeriesSummary {
    static func mock(
        id: UUID = UUID(),
        title: String = "Moonlit Edge",
        sourceDomain: String = "example.com",
        canonicalURL: URL? = URL(string: "https://example.com/series/moonlit-edge"),
        coverImageURL: URL? = URL(string: "https://example.com/cover.jpg"),
        progressPercent: Double = 0.4,
        chaptersRead: Int = 4,
        totalKnownChapters: Int? = 10,
        lastReadAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
        libraryState: LibraryCollectionState = .reading,
        hasUnreadUpdates: Bool = false,
        isCompleted: Bool = false,
        latestChapterLabel: String? = nil,
        currentChapterLabel: String? = nil
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: id,
            title: title,
            sourceDomain: sourceDomain,
            canonicalURL: canonicalURL,
            coverImageURL: coverImageURL,
            progressPercent: progressPercent,
            chaptersRead: chaptersRead,
            totalKnownChapters: totalKnownChapters,
            lastReadAt: lastReadAt,
            libraryState: libraryState,
            hasUnreadUpdates: hasUnreadUpdates,
            isCompleted: isCompleted,
            latestChapterLabel: latestChapterLabel,
            currentChapterLabel: currentChapterLabel
        )
    }
}
```

- [ ] **Step 6: Implement route and seed layout**

In `LibraryView.swift`, add near the other Library layout helpers:

```swift
struct LibrarySeriesDetailRoute: Hashable, Sendable {
    var seriesID: UUID
    var seedSummary: LibrarySeriesSummary?

    init(seriesID: UUID, seedSummary: LibrarySeriesSummary? = nil) {
        self.seriesID = seriesID
        self.seedSummary = seedSummary
    }

    static func == (lhs: LibrarySeriesDetailRoute, rhs: LibrarySeriesDetailRoute) -> Bool {
        lhs.seriesID == rhs.seriesID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(seriesID)
    }
}

struct SeriesDetailSeedShellLayout: Equatable, Sendable {
    var title: String
    var metadata: String
    var coverImageURL: URL?
    var status: String
    var hasUnreadUpdates: Bool
    var showsLoadingBanner: Bool
    var exposesContinueAction: Bool

    init(summary: LibrarySeriesSummary) {
        self.title = summary.title
        self.metadata = "\(summary.sourceDomain) • \(summary.chapterSummaryText)"
        self.coverImageURL = summary.coverImageURL
        self.status = summary.libraryState.title
        self.hasUnreadUpdates = summary.hasUnreadUpdates
        self.showsLoadingBanner = false
        self.exposesContinueAction = false
    }
}
```

- [ ] **Step 7: Run focused tests**

Run the three focused filters from Step 4 again.

Expected: pass.

---

## Task 2: Pass Seeded Routes From Library Cells

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - `LibrarySeriesDetailRoute(seriesID:seedSummary:)`
- Produces:
  - `navigationPath: [LibrarySeriesDetailRoute]`
  - `NavigationLink(value: LibrarySeriesDetailRoute(seriesID: series.id, seedSummary: series))`
  - `.navigationDestination(for: LibrarySeriesDetailRoute.self)`

- [ ] **Step 1: Add route construction test**

Add:

```swift
@Test func librarySeriesDetailRouteUsesVisibleSeriesAsSeed() {
    let summary = LibrarySeriesSummary.mock(title: "The Extra's Academy Survival Guide", sourceDomain: "asurascans.com")
    let route = LibrarySeriesDetailRoute(summary: summary)

    #expect(route.seriesID == summary.id)
    #expect(route.seedSummary == summary)
}
```

- [ ] **Step 2: Run red test**

Run:

```bash
swift test --package-path app --filter librarySeriesDetailRouteUsesVisibleSeriesAsSeed
```

Expected: fail because `LibrarySeriesDetailRoute(summary:)` does not exist.

- [ ] **Step 3: Add summary initializer**

Add to `LibrarySeriesDetailRoute`:

```swift
init(summary: LibrarySeriesSummary) {
    self.seriesID = summary.id
    self.seedSummary = summary
}
```

- [ ] **Step 4: Update navigation path and destinations**

In `LibraryView.swift`, change:

```swift
@State private var navigationPath: [UUID] = []
```

to:

```swift
@State private var navigationPath: [LibrarySeriesDetailRoute] = []
```

Change router pending destinations:

```swift
navigationPath = [seriesID]
```

to:

```swift
navigationPath = [LibrarySeriesDetailRoute(seriesID: seriesID)]
```

Change `NavigationLink(value:)`:

```swift
NavigationLink(value: series.id) {
```

to:

```swift
NavigationLink(value: LibrarySeriesDetailRoute(summary: series)) {
```

Change destination:

```swift
.navigationDestination(for: UUID.self) { seriesID in
    SeriesDetailView(seriesID: seriesID, dependencies: dependencies, router: $router)
}
```

to:

```swift
.navigationDestination(for: LibrarySeriesDetailRoute.self) { route in
    SeriesDetailView(
        seriesID: route.seriesID,
        seedSummary: route.seedSummary,
        dependencies: dependencies,
        router: $router
    )
}
```

- [ ] **Step 5: Run focused navigation tests**

Run:

```bash
swift test --package-path app --filter librarySeriesDetailRoute
swift test --package-path app --filter AppRouterTests
```

Expected: pass. Router tests should remain green because router still stores pending `UUID`; only the view converts it to an unseeded route.

---

## Task 3: Render Seed Shell Before Hydration

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - `SeriesDetailSeedShellLayout(summary:)`
  - `SeriesDetailView(seedSummary:)`
- Produces:
  - Seed shell UI when `detail == nil && seedSummary != nil`.

- [ ] **Step 1: Update `SeriesDetailView` initializer surface**

Change `SeriesDetailView` stored properties:

```swift
let seriesID: UUID
let dependencies: AppDependencies
```

to:

```swift
let seriesID: UUID
let seedSummary: LibrarySeriesSummary?
let dependencies: AppDependencies
```

Add a defaulted initializer only if needed by previews/tests:

```swift
init(
    seriesID: UUID,
    seedSummary: LibrarySeriesSummary? = nil,
    dependencies: AppDependencies,
    router: Binding<AppRouter>
) {
    self.seriesID = seriesID
    self.seedSummary = seedSummary
    self.dependencies = dependencies
    self._router = router
}
```

- [ ] **Step 2: Add seed shell branch**

In `SeriesDetailView.body`, change the loading branch from:

```swift
} else if hasLoaded {
    TEBanner(...)
} else {
    TEBanner(title: "Loading series", message: "Preparing chapter state.", systemImage: "hourglass")
}
```

to:

```swift
} else if let seedSummary {
    seedShell(seedSummary)
} else if hasLoaded {
    TEBanner(...)
} else {
    TEBanner(title: "Loading series", message: "Preparing chapter state.", systemImage: "hourglass")
}
```

- [ ] **Step 3: Add the seed shell view**

Add inside `SeriesDetailView`:

```swift
private func seedShell(_ summary: LibrarySeriesSummary) -> some View {
    let layout = SeriesDetailSeedShellLayout(summary: summary)
    return VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
        HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
            CachedCoverArtwork(url: layout.coverImageURL) {
                MissingCoverView(title: layout.title)
            }
            .frame(width: 96, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
            .overlay(RoundedRectangle(cornerRadius: ToonEdgeRadius.small).stroke(ToonEdgeColor.border))

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                HStack(spacing: ToonEdgeSpacing.small) {
                    TEChip(layout.status, isActive: layout.hasUnreadUpdates)
                    TEChip("Saved")
                }

                Text(layout.title)
                    .font(ToonEdgeTypography.title)
                    .fixedSize(horizontal: false, vertical: true)

                Text(layout.metadata)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
            }
        }
    }
}
```

- [ ] **Step 4: Run focused shell tests**

Run:

```bash
swift test --package-path app --filter seriesDetailSeedShell
swift test --package-path app --filter seededSeriesDetailUsesHydratedDetailForContinueAction
```

Expected: pass.

---

## Task 4: Verify and Document Completion

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - Story 11.42 acceptance criteria.
- Produces:
  - Story 11.42 marked implemented after verification.

- [ ] **Step 1: Run focused suites**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
swift test --package-path app --filter AppRouterTests
```

Expected: pass.

- [ ] **Step 2: Run full package tests**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 3: Build app target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Mark Story 11.42 implemented**

In `docs/toonedge_epics_and_stories.md`, change:

```markdown
### Story 11.42 — Series Detail seeded shell from Library selection
**Status:** planned
```

to:

```markdown
### Story 11.42 — Series Detail seeded shell from Library selection
**Status:** implemented
```

---

## Verification Checklist

- `swift test --package-path app --filter librarySeriesDetailRouteIdentityUsesSeriesIDAndCarriesOptionalSeed`
- `swift test --package-path app --filter seriesDetailSeedShellShowsLibrarySummaryWithoutContinueAction`
- `swift test --package-path app --filter seededSeriesDetailUsesHydratedDetailForContinueAction`
- `swift test --package-path app --filter LibraryExperienceTests`
- `swift test --package-path app --filter AppRouterTests`
- `swift test --package-path app`
- `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build`

## Known Limitations

- The seeded shell intentionally does not expose Continue. It removes the loading-only screen while waiting for local detail hydration, but accurate chapter actions still require `SeriesDetailSnapshot`.
- Router-driven deep links and Reader back routes may still enter Series Detail with only a `seriesID`; those paths preserve the existing loading/unavailable behavior.
- If local detail hydration itself hangs indefinitely, this story prevents a blank/loading-only screen for Library-origin taps but does not fix the underlying repository latency.

## Self-Review

- Story 11.42 acceptance criteria map to Tasks 1-3.
- The plan does not change persistence, parser, update comparison, Browser, Reader detection, or Library layout behavior.
- The plan explicitly protects Continue accuracy by keeping summary seed data visual-only.
