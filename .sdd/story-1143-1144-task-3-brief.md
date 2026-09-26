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

