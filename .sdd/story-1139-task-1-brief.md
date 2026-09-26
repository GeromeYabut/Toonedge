## Task 1: Replace Summary Card Layout Contract With Compact Controls Contract

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Interfaces:**
- Consumes:
  - `LibrarySegment`
  - `[LibrarySeriesSummary]`
  - `hasUpdateRefreshService: Bool`
  - `isRefreshing: Bool`
- Produces:
  - `LibraryCollectionControlsLayout: Equatable, Sendable`
  - `LibraryCollectionControlsLayout.countText: String`
  - `LibraryCollectionControlsLayout.refreshButtonIsVisible: Bool`
  - `LibraryCollectionControlsLayout.refreshSystemImage: String`
  - `LibraryCollectionControlsLayout.refreshAccessibilityLabel: String`
  - `LibraryCollectionControlsLayout.usesLargeSummaryCard: Bool`

- [ ] **Step 1: Update failing tests for the new compact controls model**

In `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`, replace `librarySummaryPillExposesRefreshOnlyWhenServiceExists` with:

```swift
@Test func libraryCollectionControlsExposeCountAndRefreshOnlyWhenServiceExists() {
    let series = [
        LibrarySeriesSummary.mock(title: "A"),
        LibrarySeriesSummary.mock(title: "B")
    ]

    let refreshable = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: false
    )
    let localOnly = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: false,
        isRefreshing: false
    )
    let singular = LibraryCollectionControlsLayout(
        visibleSeries: [LibrarySeriesSummary.mock(title: "Only")],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(refreshable.countText == "2 titles")
    #expect(singular.countText == "1 title")
    #expect(refreshable.refreshButtonIsVisible)
    #expect(!localOnly.refreshButtonIsVisible)
    #expect(!refreshable.usesLargeSummaryCard)
}
```

Replace `librarySummaryPillUsesUpdateCountAndRefreshIconState` with:

```swift
@Test func libraryCollectionControlsUseRefreshIconStateWithoutUpdateSummaryCopy() {
    let series = [
        LibrarySeriesSummary.mock(title: "A", hasUnreadUpdates: true),
        LibrarySeriesSummary.mock(title: "B", hasUnreadUpdates: false),
        LibrarySeriesSummary.mock(title: "C", hasUnreadUpdates: true)
    ]

    let idle = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: false
    )
    let refreshing = LibraryCollectionControlsLayout(
        visibleSeries: series,
        hasUpdateRefreshService: true,
        isRefreshing: true
    )

    #expect(idle.countText == "3 titles")
    #expect(idle.refreshSystemImage == "arrow.clockwise")
    #expect(refreshing.refreshSystemImage == "hourglass")
    #expect(idle.refreshAccessibilityLabel == "Check for new chapters")
}
```

Update `libraryChromeUsesRestrainedNativeCollectionStyling` to use `LibraryCollectionControlsLayout`:

```swift
@Test func libraryChromeUsesRestrainedNativeCollectionStyling() {
    let filter = LibraryFilterChipLayout(isSelected: true)
    let inactiveFilter = LibraryFilterChipLayout(isSelected: false)
    let controls = LibraryCollectionControlsLayout(
        visibleSeries: [LibrarySeriesSummary.mock()],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(filter.cornerRadius == 8)
    #expect(inactiveFilter.cornerRadius == 8)
    #expect(filter.usesCapsuleShape == false)
    #expect(!controls.usesLargeSummaryCard)
}
```

- [ ] **Step 2: Run focused tests and verify expected failure**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: fail because `LibraryCollectionControlsLayout` does not exist.

- [ ] **Step 3: Replace `LibrarySummaryPillLayout` with `LibraryCollectionControlsLayout`**

In `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`, replace the `LibrarySummaryPillLayout` type with:

```swift
struct LibraryCollectionControlsLayout: Equatable, Sendable {
    var countText: String
    var refreshButtonIsVisible: Bool
    var refreshSystemImage: String
    var refreshAccessibilityLabel: String
    var usesLargeSummaryCard: Bool

    init(
        visibleSeries: [LibrarySeriesSummary],
        hasUpdateRefreshService: Bool,
        isRefreshing: Bool
    ) {
        self.countText = "\(visibleSeries.count) \(visibleSeries.count == 1 ? "title" : "titles")"
        self.refreshButtonIsVisible = hasUpdateRefreshService
        self.refreshSystemImage = isRefreshing ? "hourglass" : "arrow.clockwise"
        self.refreshAccessibilityLabel = "Check for new chapters"
        self.usesLargeSummaryCard = false
    }
}
```

- [ ] **Step 4: Remove stale summary-card tests and compile errors**

Search for stale references:

```bash
rg "LibrarySummaryPillLayout|librarySummaryPill" app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift
```

Expected before Task 2: production may still contain `LibrarySummaryPill` view references. Test file should not contain stale `LibrarySummaryPillLayout` references.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: may still fail from production view references to `LibrarySummaryPillLayout`; Task 2 completes rendering migration.
