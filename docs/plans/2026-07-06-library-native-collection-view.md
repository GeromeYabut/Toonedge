# Library Native Collection View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the Library into a cover-first native collection view where comfortable, compact, and list modes are visually distinct and scalable for dozens of saved manhwas.

**Architecture:** Keep the change inside the Library presentation layer and layout models. Preserve the existing `LibraryViewMode`, `LibraryViewPreferences`, grouping, save-state picker, persistence, and navigation contracts. Add small layout model properties that tests can verify without snapshot testing.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing ToonEdge design tokens and Library feature module.

## Global Constraints

- Work story by story and implement only Story 11.36.
- Preserve clean separation between SwiftUI view code, persistence, parsing, browser coordination, and repository logic.
- Do not change persistence schema, Reader detection, chapter parsing, update checks, or save-to-library grouping behavior.
- Use cover artwork as the primary visual anchor; keep surrounding chrome minimal.
- Compact mode must fit 4 entries per iPhone-sized row.
- Avoid adding new dependencies.

---

## Files

- Modify: `docs/toonedge_epics_and_stories.md`
  - Story 11.36 source of truth.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Library grid column selection, grid item rendering, layout model values, filter/control styling.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Layout model tests for native collection styling and compact 4-column behavior.

## Design Decisions

- Comfortable and compact grid items should not use `TECard`; that primitive can remain for other screens.
- Comfortable grid should use 2 flexible columns on iPhone widths.
- Compact grid should use exactly 4 flexible columns on iPhone widths.
- List mode should use a single column and keep its row shape, with reduced background emphasis if touched during implementation.
- Compact metadata should prefer latest/current chapter over progress detail:
  - Use `Ch. <latestChapterLabel>` when available.
  - Fall back to `Continue Ch. <currentChapterLabel>` only when latest chapter is unavailable.
  - Fall back to `series.chapterSummaryText` when neither chapter label exists.

## Task 1: Add Testable Library Layout Contracts

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `LibraryGridLayout`, a testable model that maps `LibraryViewMode` to grid behavior.
- Produces: `LibrarySeriesCardLayout.usesOuterCardContainer`.
- Produces: `LibrarySeriesCardContent.compactMetadata`.

- [ ] **Step 1: Write failing tests for mode density and card-container removal**

Add this test near `libraryViewModesExposeIncreasingDensityLayouts`:

```swift
@Test func libraryNativeCollectionLayoutsUseDistinctGridDensity() {
    let comfortableGrid = LibraryGridLayout(mode: .comfortable)
    let compactGrid = LibraryGridLayout(mode: .compact)
    let listGrid = LibraryGridLayout(mode: .list)

    #expect(comfortableGrid.columnStyle == .fixedCount(2))
    #expect(compactGrid.columnStyle == .fixedCount(4))
    #expect(listGrid.columnStyle == .adaptiveMinimum(320))
    #expect(compactGrid.itemSpacing < comfortableGrid.itemSpacing)
    #expect(compactGrid.horizontalContentPadding <= comfortableGrid.horizontalContentPadding)
}

@Test func libraryGridCardsAvoidOuterGeneratedCardContainer() {
    #expect(!LibrarySeriesCardLayout.comfortable.usesOuterCardContainer)
    #expect(!LibrarySeriesCardLayout.compact.usesOuterCardContainer)
    #expect(LibrarySeriesCardLayout.compact.fixedCardHeight <= 150)
    #expect(LibrarySeriesCardLayout.compact.coverAspectRatio == 1)
    #expect(LibrarySeriesCardLayout.compact.titleLineLimit == 1)
    #expect(LibrarySeriesCardLayout.compact.progressHeight == 0)
    #expect(LibrarySeriesCardLayout.compact.badgeRowHeight == 0)
}
```

- [ ] **Step 2: Write failing tests for compact metadata**

Add this test near `librarySeriesCardMetadataShowsOnlyCurrentChapterNextToContinue`:

```swift
@Test func libraryCompactCardMetadataPrefersShortChapterLabel() {
    let latest = LibrarySeriesSummary.mock(
        latestChapterLabel: "237",
        currentChapterLabel: "3"
    )
    let currentOnly = LibrarySeriesSummary.mock(
        latestChapterLabel: nil,
        currentChapterLabel: "3"
    )
    let noChapter = LibrarySeriesSummary.mock(
        currentChapterLabel: nil,
        latestChapterLabel: nil
    )

    #expect(LibrarySeriesCardContent(series: latest).compactMetadata == "Ch. 237")
    #expect(LibrarySeriesCardContent(series: currentOnly).compactMetadata == "Continue Ch. 3")
    #expect(LibrarySeriesCardContent(series: noChapter).compactMetadata == "50/100 chapters")
}
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: fails because `LibraryGridLayout`, `usesOuterCardContainer`, and `compactMetadata` do not exist or still have old values.

- [ ] **Step 4: Add minimal layout model and properties**

In `LibraryView.swift`, add near `LibraryContentLayout`:

```swift
struct LibraryGridLayout: Equatable, Sendable {
    var columnStyle: LibraryGridColumnStyle
    var itemSpacing: CGFloat
    var horizontalContentPadding: CGFloat

    init(mode: LibraryViewMode) {
        switch mode {
        case .comfortable:
            self.columnStyle = .fixedCount(2)
            self.itemSpacing = ToonEdgeSpacing.large
            self.horizontalContentPadding = ToonEdgeSpacing.large
        case .compact:
            self.columnStyle = .fixedCount(4)
            self.itemSpacing = ToonEdgeSpacing.small
            self.horizontalContentPadding = ToonEdgeSpacing.medium
        case .list:
            self.columnStyle = .adaptiveMinimum(320)
            self.itemSpacing = ToonEdgeSpacing.small
            self.horizontalContentPadding = ToonEdgeSpacing.large
        }
    }

    var columns: [GridItem] {
        switch columnStyle {
        case .fixedCount(let count):
            return Array(
                repeating: GridItem(.flexible(), spacing: itemSpacing, alignment: .top),
                count: count
            )
        case .adaptiveMinimum(let minimum):
            return [GridItem(.adaptive(minimum: minimum), spacing: itemSpacing, alignment: .top)]
        }
    }
}

enum LibraryGridColumnStyle: Equatable, Sendable {
    case fixedCount(Int)
    case adaptiveMinimum(CGFloat)
}
```

Update `LibrarySeriesCardContent`:

```swift
struct LibrarySeriesCardContent: Equatable, Sendable {
    var metadata: String
    var compactMetadata: String

    init(series: LibrarySeriesSummary) {
        if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            self.metadata = "Continue Ch. \(currentChapterLabel)"
        } else {
            self.metadata = series.chapterSummaryText
        }

        if let latestChapterLabel = series.latestChapterLabel {
            self.compactMetadata = "Ch. \(latestChapterLabel)"
        } else if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            self.compactMetadata = "Continue Ch. \(currentChapterLabel)"
        } else {
            self.compactMetadata = series.chapterSummaryText
        }
    }
}
```

Update `LibrarySeriesCardLayout` by adding:

```swift
var usesOuterCardContainer: Bool
```

Set both grid layouts to `false`:

```swift
usesOuterCardContainer: false
```

Set compact sizing to:

```swift
fixedCardHeight: 142,
coverAspectRatio: 1,
coverHeight: 76,
coverSlotHeight: 76,
titleLineLimit: 1,
titleHeight: 22,
metadataLineLimit: 1,
metadataHeight: 16,
progressHeight: 0,
badgeRowHeight: 0,
cornerRadius: 4,
usesOuterCardContainer: false
```

Keep comfortable 2-column browsing scale:

```swift
fixedCardHeight: 286,
coverAspectRatio: 0.72,
coverHeight: 190,
coverSlotHeight: 190,
titleLineLimit: 2,
titleHeight: 46,
metadataLineLimit: 1,
metadataHeight: 18,
progressHeight: 4,
badgeRowHeight: 24,
cornerRadius: 4,
usesOuterCardContainer: false
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 2: Replace Card Grid Rendering With Cover-First Cells

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes: `LibraryGridLayout(mode:)`, `LibrarySeriesCardLayout.usesOuterCardContainer`, and `LibrarySeriesCardContent.compactMetadata`.
- Produces: visually distinct comfortable and compact Library cells.

- [ ] **Step 1: Update the grid to use `LibraryGridLayout`**

Replace the current `LazyVGrid` in `content` with:

```swift
let gridLayout = LibraryGridLayout(mode: selectedViewMode)

LazyVGrid(
    columns: gridLayout.columns,
    spacing: gridLayout.itemSpacing
) {
    ForEach(visible) { series in
        NavigationLink(value: series.id) {
            switch selectedViewMode {
            case .comfortable:
                SeriesCard(series: series, layout: .comfortable)
            case .compact:
                SeriesCompactTile(series: series, layout: .compact)
            case .list:
                SeriesListRow(series: series)
            }
        }
        .buttonStyle(.plain)
    }
}
```

Remove the old `gridMinimumWidth` computed property if nothing else uses it.

- [ ] **Step 2: Rewrite `SeriesCard` without `TECard`**

Replace the `SeriesCard.body` with this cover-first layout:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
        coverSlot

        Text(series.title)
            .font(ToonEdgeTypography.body.weight(.semibold))
            .lineLimit(layout.titleLineLimit)
            .multilineTextAlignment(.leading)
            .frame(height: layout.titleHeight, alignment: .topLeading)

        Text(content.metadata)
            .font(ToonEdgeTypography.caption)
            .foregroundStyle(ToonEdgeColor.textSecondary)
            .lineLimit(layout.metadataLineLimit)
            .frame(height: layout.metadataHeight, alignment: .leading)

        ProgressView(value: series.progressPercent)
            .tint(progressTint)
            .frame(height: layout.progressHeight)

        HStack(spacing: ToonEdgeSpacing.xsmall) {
            if series.hasUnreadUpdates {
                TEChip("New", isActive: true)
            }

            if series.isCompleted {
                TEChip("Complete")
            } else if let latestChapterLabel = series.latestChapterLabel {
                TEChip("Ch. \(latestChapterLabel)")
            }
        }
        .frame(height: layout.badgeRowHeight, alignment: .leading)
    }
    .frame(height: layout.fixedCardHeight, alignment: .top)
    .contentShape(Rectangle())
}
```

- [ ] **Step 3: Add `SeriesCompactTile`**

Add this private view near `SeriesCard`:

```swift
private struct SeriesCompactTile: View {
    let series: LibrarySeriesSummary
    let layout: LibrarySeriesCardLayout
    private var content: LibrarySeriesCardContent {
        LibrarySeriesCardContent(series: series)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
            CachedCoverArtwork(url: series.coverImageURL) {
                MissingCoverView(title: series.title)
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: layout.coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(ToonEdgeColor.border.opacity(0.45))
            )

            Text(series.title)
                .font(ToonEdgeTypography.caption.weight(.semibold))
                .lineLimit(1)
                .frame(height: layout.titleHeight, alignment: .topLeading)

            Text(content.compactMetadata)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(series.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.textSecondary)
                .lineLimit(1)
                .frame(height: layout.metadataHeight, alignment: .leading)
        }
        .frame(height: layout.fixedCardHeight, alignment: .top)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 3: Reduce Library Chrome Roundness

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: smaller, less pill-heavy Library filter and control layout models where testable.

- [ ] **Step 1: Add a testable filter style model**

Add this test:

```swift
@Test func libraryChromeUsesRestrainedNativeCollectionStyling() {
    let filter = LibraryFilterChipLayout(isSelected: true)
    let inactiveFilter = LibraryFilterChipLayout(isSelected: false)
    let summary = LibrarySummaryPillLayout(
        segment: .recent,
        visibleSeries: [LibrarySeriesSummary.mock()],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(filter.cornerRadius == 8)
    #expect(inactiveFilter.cornerRadius == 8)
    #expect(filter.usesCapsuleShape == false)
    #expect(summary.cornerRadius == 12)
}
```

- [ ] **Step 2: Add layout properties**

In `LibraryView.swift`, add:

```swift
struct LibraryFilterChipLayout: Equatable, Sendable {
    var cornerRadius: CGFloat
    var usesCapsuleShape: Bool
    var backgroundOpacity: Double

    init(isSelected: Bool) {
        self.cornerRadius = 8
        self.usesCapsuleShape = false
        self.backgroundOpacity = isSelected ? 1 : 0.72
    }
}
```

Add to `LibrarySummaryPillLayout`:

```swift
var cornerRadius: CGFloat
```

Set in its initializer:

```swift
self.cornerRadius = 12
```

- [ ] **Step 3: Update filter chips**

In `LibraryFilterRow`, replace the capsule background/overlay with:

```swift
let layout = LibraryFilterChipLayout(isSelected: selection == segment)

Text(segment.title)
    .font(ToonEdgeTypography.caption)
    .padding(.horizontal, ToonEdgeSpacing.medium)
    .padding(.vertical, ToonEdgeSpacing.small)
    .background(
        selection == segment ? ToonEdgeColor.accentSoft : ToonEdgeColor.panel.opacity(layout.backgroundOpacity),
        in: RoundedRectangle(cornerRadius: layout.cornerRadius)
    )
    .overlay(
        RoundedRectangle(cornerRadius: layout.cornerRadius)
            .stroke(selection == segment ? ToonEdgeColor.accent.opacity(0.45) : ToonEdgeColor.border.opacity(0.5))
    )
```

- [ ] **Step 4: Update summary pill**

In `LibrarySummaryPill`, replace the capsule shape with:

```swift
.background(ToonEdgeColor.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
.overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(ToonEdgeColor.border.opacity(0.55)))
```

- [ ] **Step 5: Keep view mode control compact**

Keep the existing trailing control, but reduce its visual weight:

```swift
.background(ToonEdgeColor.elevated.opacity(0.72), in: RoundedRectangle(cornerRadius: ToonEdgeRadius.small))
```

This keeps the mode control discoverable without adding another large capsule to the screen.

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 4: Full Verification

**Files:**
- Test-only verification across the package.

- [ ] **Step 1: Run the full Swift package test suite**

Run:

```bash
swift test --package-path app
```

Expected: all tests pass.

- [ ] **Step 2: Build the app target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 3: Manual visual check in Simulator**

Open the Library tab and verify:

- Comfortable shows 2 cover-first columns.
- Compact shows 4 smaller square entries per row.
- List still shows dense rows.
- Grid items no longer sit inside grey rounded card boxes.
- Group filters still include Recent, Reading, Planned, Dropped, and Completed.
- Tapping a Library item still opens Series Detail.

## Risks

- Four-column compact mode leaves little room for long titles. The plan intentionally limits compact titles to one line and uses chapter metadata as the second line.
- Removing `TECard` changes tap affordance. The plan uses `contentShape(Rectangle())` so the full cell remains tappable.
- Existing screenshots may still show roundness in tab chrome and other screens. This story targets the Library grid and Library controls only.

## Self-Review

- Story coverage: Story 11.36 acceptance criteria map to Tasks 1-4.
- Scope check: no persistence, detection, Reader, Browser, or update-check behavior changes are included.
- Type consistency: new layout types are defined in `LibraryView.swift` and used by `LibraryExperienceTests`.
- Placeholder scan: no implementation step depends on unresolved behavior.
