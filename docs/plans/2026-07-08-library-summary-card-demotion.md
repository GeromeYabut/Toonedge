# Library Summary Card Demotion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the large Library group summary card and replace it with a compact inline count/controls row that keeps refresh and view-mode controls available.

**Architecture:** Keep this change in the Library SwiftUI presentation layer. Reuse existing `LibraryViewMode`, `LibraryViewModeControl`, refresh state, and pull-to-refresh behavior. Do not change Library snapshots, grouping, repositories, update-check services, persistence, Reader, Browser, or chapter parsing.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing ToonEdge design tokens.

## Global Constraints

- Implement only Story 11.39.
- Do not change persistence schema, Reader detection, Browser behavior, chapter parsing, update checks, search classification, or save-to-library grouping behavior.
- Do not add sorting, bulk edit, custom shelves, or new persisted metadata.
- Remove the large `Recent Library` / segment summary card from the Library content flow.
- Keep the visible saved-title count available in a compact inline treatment.
- Keep manual refresh available only when `updateRefreshService` exists.
- Keep pull-to-refresh and floating refresh feedback behavior unchanged.
- Keep Library filters for `Recent`, `Reading`, `Planned`, `Dropped`, and `Completed`.
- Keep Library item selection opening Series Detail.

---

## Files

- Modify: `docs/toonedge_epics_and_stories.md`
  - Story 11.39 status should move from `planned` to `implemented` after verification.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Replace the large summary card layout/view with a compact collection controls layout/view.
  - Render the compact controls row between filters and collection content.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Update Library chrome/layout tests to assert the summary card is gone and compact controls preserve count, refresh, and view-mode behavior.

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

## Task 2: Replace the Large Summary Card With an Inline Controls Row

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - `LibraryCollectionControlsLayout`
  - `LibraryViewModeControl(selection:)`
  - `refreshUpdates()`
- Produces:
  - `LibraryCollectionControls: View`
  - `LibraryView.collectionControls: some View`

- [ ] **Step 1: Add a rendering contract test for compact inline controls**

Add this test to `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift` near the Library chrome tests:

```swift
@Test func libraryCollectionControlsKeepCountRefreshAndViewModesInline() {
    let controls = LibraryCollectionControlsLayout(
        visibleSeries: [
            LibrarySeriesSummary.mock(title: "A"),
            LibrarySeriesSummary.mock(title: "B"),
            LibrarySeriesSummary.mock(title: "C"),
            LibrarySeriesSummary.mock(title: "D")
        ],
        hasUpdateRefreshService: true,
        isRefreshing: false
    )

    #expect(controls.countText == "4 titles")
    #expect(controls.refreshButtonIsVisible)
    #expect(controls.refreshSystemImage == "arrow.clockwise")
    #expect(LibraryViewMode.allCases == [.comfortable, .compact, .list])
    #expect(!controls.usesLargeSummaryCard)
}
```

- [ ] **Step 2: Run focused tests and verify expected failure**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: fail until the view migration is complete.

- [ ] **Step 3: Replace the `summaryPill` and standalone view-mode control in `LibraryView.body`**

In `LibraryView.body`, replace:

```swift
LibraryFilterRow(selection: $selectedSegment)
summaryPill
LibraryViewModeControl(selection: $selectedViewMode)
content
```

with:

```swift
LibraryFilterRow(selection: $selectedSegment)
collectionControls
content
```

- [ ] **Step 4: Replace `summaryPill` computed property with `collectionControls`**

Replace the existing `private var summaryPill: some View` with:

```swift
private var collectionControls: some View {
    let visible = snapshot.series(for: selectedSegment)
    let layout = LibraryCollectionControlsLayout(
        visibleSeries: visible,
        hasUpdateRefreshService: dependencies.updateRefreshService != nil,
        isRefreshing: isRefreshingUpdates
    )

    return LibraryCollectionControls(layout: layout, selection: $selectedViewMode) {
        Task {
            await refreshUpdates()
        }
    }
}
```

- [ ] **Step 5: Replace the `LibrarySummaryPill` view with `LibraryCollectionControls`**

Replace the whole `private struct LibrarySummaryPill: View` with:

```swift
private struct LibraryCollectionControls: View {
    let layout: LibraryCollectionControlsLayout
    @Binding var selection: LibraryViewMode
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.small) {
            Text(layout.countText)
                .font(ToonEdgeTypography.caption.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: ToonEdgeSpacing.small)

            LibraryViewModeControl(selection: $selection)

            if layout.refreshButtonIsVisible {
                Button(action: refresh) {
                    Image(systemName: layout.refreshSystemImage)
                        .frame(width: 36, height: 36)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(layout.refreshSystemImage == "hourglass")
                .accessibilityLabel(layout.refreshAccessibilityLabel)
            }
        }
    }
}
```

- [ ] **Step 6: Remove stale production references**

Run:

```bash
rg "LibrarySummaryPill|summaryPill|Recent Library|Reading Library|Planned Library|Dropped Library|Completed Library" app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift
```

Expected: no matches for `LibrarySummaryPill`, `summaryPill`, or hardcoded segment summary-card labels.

- [ ] **Step 7: Run focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 3: Final Verification and Documentation Status

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`

**Interfaces:**
- Consumes:
  - Story 11.39 documentation.
  - Passing focused Library tests from Task 2.
- Produces:
  - Story 11.39 marked `implemented`.
  - Full verification results.

- [ ] **Step 1: Mark Story 11.39 implemented**

In `docs/toonedge_epics_and_stories.md`, change:

```markdown
### Story 11.39 — Library summary card demotion
**Status:** planned
```

to:

```markdown
### Story 11.39 — Library summary card demotion
**Status:** implemented
```

- [ ] **Step 2: Run focused Library tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 3: Run full package tests**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 4: Build the iPhone simulator target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: pass. If the build fails with `Operation timed out` while opening source files, rerun once with:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' -jobs 1 build
```

Expected: pass.

- [ ] **Step 5: Optional simulator visual check**

If simulator inspection is available, launch Library in the simulator and verify:

- No large summary card appears between filters and the collection.
- Count text appears inline above the collection.
- View-mode control remains reachable.
- Refresh icon appears only when update refresh service exists.
- More cover artwork is visible above the fold than before.

## Self-Review

- Spec coverage: Story 11.39 acceptance criteria map to Task 1 layout contract, Task 2 SwiftUI rendering migration, and Task 3 verification.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation steps remain.
- Type consistency: `LibraryCollectionControlsLayout` and `LibraryCollectionControls` names are used consistently across tests and production tasks.
