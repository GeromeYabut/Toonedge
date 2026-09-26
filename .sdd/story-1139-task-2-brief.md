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
