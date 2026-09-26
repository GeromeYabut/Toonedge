# Home Reading Dashboard Visual Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine Home into a reading-dashboard-first screen where search stays immediately available and Continue Reading becomes the strongest content object.

**Architecture:** Keep this change inside the Home presentation layer and small testable layout models. Preserve the existing `HomeSnapshot`, `SeriesSummary`, search overlay routing, continue-reading routing, update refresh service, and persistence contracts. Use layout models in `HomeView.swift` so Swift Testing can verify visual intent without snapshot tests.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing ToonEdge design tokens and Home feature module.

## Global Constraints

- Work story by story and implement only Story 11.37.
- Preserve clean separation between SwiftUI view code, persistence, parsing, browser coordination, and repository logic.
- Do not change persistence schema, Reader detection, Browser behavior, chapter parsing, update checks, search classification, or save-to-library grouping behavior.
- Home must still include search, Continue Reading, Recently Updated, All Library, Settings access, refresh behavior, and empty state.
- Search must remain tappable and still call `router.presentSearch()`.
- Continue Reading must still call the existing `openContinueReading(_:)` path.
- Use cover artwork as the primary visual anchor for reading content; keep surrounding chrome minimal.
- Avoid adding new dependencies.

---

## Files

- Modify: `docs/toonedge_epics_and_stories.md`
  - Story 11.37 source of truth.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
  - Home layout models, search command bar styling, dashboard section ordering, card rendering, refresh/status styling.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Existing Home behavior/layout tests currently live in this file; add Story 11.37 layout model tests here to match local test organization.

## Design Decisions

- Use Option A: Current Read First.
- Home ordering remains search first, then Continue Reading, then Recently Updated, then All Library.
- Search is visually downgraded from capsule hero to compact command bar while retaining top placement and tap behavior.
- Continue Reading is visually upgraded: the first item is a current-read hero, and additional items can appear as compact cover-first tiles.
- Recently Updated and All Library should use compact cover-first treatments; Home should not duplicate the full Library management grid.
- Home reading cards should not use `TECard` as the outer container.
- Circular top accessory controls should become restrained rounded-rectangle icon buttons.
- Refresh feedback should become a compact inline status model, not a large `TEBanner`.
- Keep existing data contracts; no new Home data source or persistence model is needed.

## Task 1: Add Testable Home Dashboard Layout Contracts

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `HomeDashboardLayout`, a testable model that defines Home section priority and chrome placement.
- Produces: `HomeDashboardSection`, an enum used by `HomeDashboardLayout.contentPriority`.
- Produces: `HomeSearchEntryLayout`, a testable model for the compact command bar.
- Produces: `HomeTopAccessoryLayout`, a testable model for settings/refresh icon controls.
- Produces: `HomeRefreshStatusLayout`, a testable model for restrained refresh feedback.

- [ ] **Step 1: Write failing tests for dashboard priority and command-bar styling**

Add these tests near the existing Home tests in `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`:

```swift
@Test func homeReadingDashboardPrioritizesCurrentReadingAfterSearch() {
    let layout = HomeDashboardLayout()

    #expect(layout.contentPriority == [.search, .continueReading, .recentlyUpdated, .libraryPreview])
    #expect(layout.searchPlacement == .compactCommandBar)
    #expect(layout.refreshPlacement == .inlineStatus)
    #expect(layout.usesCircularTopAccessoryButtons == false)
}

@Test func homeSearchEntryUsesRestrainedBrowserCommandBarStyling() {
    let layout = HomeSearchEntryLayout()

    #expect(layout.placeholder == "Search the web or paste a chapter link")
    #expect(layout.height == 44)
    #expect(layout.cornerRadius == 10)
    #expect(layout.usesCapsuleShape == false)
    #expect(layout.horizontalPadding == ToonEdgeSpacing.medium)
}
```

- [ ] **Step 2: Write failing tests for accessory and refresh status styling**

Add this test near `homeSearchEntryUsesRestrainedBrowserCommandBarStyling`:

```swift
@Test func homeChromeUsesQuietDashboardControls() {
    let accessory = HomeTopAccessoryLayout()
    let status = HomeRefreshStatusLayout(message: "Checked 2, found 1 update.")

    #expect(accessory.size == 40)
    #expect(accessory.cornerRadius == 10)
    #expect(accessory.usesCircleShape == false)
    #expect(status.message == "Checked 2, found 1 update.")
    #expect(status.cornerRadius == 10)
    #expect(status.usesBannerContainer == false)
}
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: fails because `HomeDashboardLayout`, `HomeSearchEntryLayout`, `HomeTopAccessoryLayout`, and `HomeRefreshStatusLayout` do not exist.

- [ ] **Step 4: Add minimal layout model types**

In `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`, add these internal models near `HomeContinueReadingNavigation`:

```swift
struct HomeDashboardLayout: Equatable, Sendable {
    var contentPriority: [HomeDashboardSection]
    var searchPlacement: HomeSearchPlacement
    var refreshPlacement: HomeRefreshPlacement
    var usesCircularTopAccessoryButtons: Bool

    init() {
        self.contentPriority = [.search, .continueReading, .recentlyUpdated, .libraryPreview]
        self.searchPlacement = .compactCommandBar
        self.refreshPlacement = .inlineStatus
        self.usesCircularTopAccessoryButtons = false
    }
}

enum HomeDashboardSection: Equatable, Sendable {
    case search
    case continueReading
    case recentlyUpdated
    case libraryPreview
}

enum HomeSearchPlacement: Equatable, Sendable {
    case compactCommandBar
}

enum HomeRefreshPlacement: Equatable, Sendable {
    case inlineStatus
}

struct HomeSearchEntryLayout: Equatable, Sendable {
    var placeholder: String
    var height: CGFloat
    var cornerRadius: CGFloat
    var usesCapsuleShape: Bool
    var horizontalPadding: CGFloat

    init() {
        self.placeholder = "Search the web or paste a chapter link"
        self.height = 44
        self.cornerRadius = 10
        self.usesCapsuleShape = false
        self.horizontalPadding = ToonEdgeSpacing.medium
    }
}

struct HomeTopAccessoryLayout: Equatable, Sendable {
    var size: CGFloat
    var cornerRadius: CGFloat
    var usesCircleShape: Bool

    init() {
        self.size = 40
        self.cornerRadius = 10
        self.usesCircleShape = false
    }
}

struct HomeRefreshStatusLayout: Equatable, Sendable {
    var message: String
    var cornerRadius: CGFloat
    var usesBannerContainer: Bool

    init(message: String) {
        self.message = message
        self.cornerRadius = 10
        self.usesBannerContainer = false
    }
}
```

- [ ] **Step 5: Run focused tests and verify pass**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 2: Add Testable Home Reading Card Layout Contracts

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `HomeSeriesCardLayout`, a testable model mapping Home reading card style to size/chrome behavior.
- Produces: internal accessibility of `HomeSectionStyle` for tests by removing `private` from the enum.

- [ ] **Step 1: Write failing tests for current-read hero and compact preview density**

Add these tests near the existing Home tests in `LibraryExperienceTests.swift`:

```swift
@Test func homeReadingDashboardCardsUseCoverFirstNativeLayouts() {
    let featured = HomeSeriesCardLayout(style: .featured)
    let compact = HomeSeriesCardLayout(style: .compact)

    #expect(!featured.usesOuterCardContainer)
    #expect(!compact.usesOuterCardContainer)
    #expect(featured.coverWidth > compact.coverWidth)
    #expect(featured.coverHeight > compact.coverHeight)
    #expect(featured.progressHeight == 4)
    #expect(compact.progressHeight == 0)
    #expect(compact.titleLineLimit == 1)
}

@Test func homeReadingDashboardHeroHasProminentCurrentReadScale() {
    let featured = HomeSeriesCardLayout(style: .featured)

    #expect(featured.fixedHeight == 156)
    #expect(featured.coverWidth == 92)
    #expect(featured.coverHeight == 132)
    #expect(featured.cornerRadius == 6)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: fails because `HomeSeriesCardLayout` does not exist or `HomeSectionStyle` is not visible to tests.

- [ ] **Step 3: Add minimal card layout model**

In `HomeView.swift`, change:

```swift
private enum HomeSectionStyle {
    case featured
    case compact
}
```

to:

```swift
enum HomeSectionStyle {
    case featured
    case compact
}
```

Add this model near `HomeSearchEntryLayout`:

```swift
struct HomeSeriesCardLayout: Equatable, Sendable {
    var fixedHeight: CGFloat
    var coverWidth: CGFloat
    var coverHeight: CGFloat
    var cornerRadius: CGFloat
    var titleLineLimit: Int
    var progressHeight: CGFloat
    var usesOuterCardContainer: Bool

    init(style: HomeSectionStyle) {
        switch style {
        case .featured:
            self.fixedHeight = 156
            self.coverWidth = 92
            self.coverHeight = 132
            self.cornerRadius = 6
            self.titleLineLimit = 2
            self.progressHeight = 4
            self.usesOuterCardContainer = false
        case .compact:
            self.fixedHeight = 86
            self.coverWidth = 48
            self.coverHeight = 64
            self.cornerRadius = 5
            self.titleLineLimit = 1
            self.progressHeight = 0
            self.usesOuterCardContainer = false
        }
    }
}
```

- [ ] **Step 4: Run focused tests and verify pass**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 3: Refine Home Rendering to Match Reading Dashboard Layout

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes: `HomeDashboardLayout`, `HomeSearchEntryLayout`, `HomeTopAccessoryLayout`, `HomeRefreshStatusLayout`, `HomeSeriesCardLayout`.
- Produces: Home UI rendering that matches Story 11.37 while preserving existing routing.

- [ ] **Step 1: Update `topBar` to use compact command bar and quiet icon controls**

In `HomeView.topBar`, keep the existing `HStack` structure and existing button actions. In `searchEntry`, use `HomeSearchEntryLayout`:

```swift
private var searchEntry: some View {
    let layout = HomeSearchEntryLayout()

    return Button {
        router.presentSearch()
    } label: {
        HStack(spacing: ToonEdgeSpacing.small) {
            Image(systemName: "globe")
                .font(ToonEdgeTypography.body.weight(.semibold))
                .foregroundStyle(ToonEdgeColor.textSecondary)

            Text(layout.placeholder)
                .font(ToonEdgeTypography.body)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .frame(height: layout.height)
        .frame(maxWidth: .infinity)
        .background(ToonEdgeColor.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(ToonEdgeColor.border.opacity(0.55))
        )
    }
    .buttonStyle(.plain)
}
```

Update `settingsButton` and `refreshButton` to use `HomeTopAccessoryLayout` with rounded rectangles:

```swift
private var settingsButton: some View {
    let layout = HomeTopAccessoryLayout()

    return Button {
        router.selectedTab = .settings
    } label: {
        Image(systemName: "gearshape")
            .font(ToonEdgeTypography.body.weight(.semibold))
            .foregroundStyle(ToonEdgeColor.textSecondary)
            .frame(width: layout.size, height: layout.size)
            .background(ToonEdgeColor.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(ToonEdgeColor.border.opacity(0.5)))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Settings")
}
```

Use the same `HomeTopAccessoryLayout` pattern in `refreshButton`, preserving its existing action, disabled state, and accessibility label.

- [ ] **Step 2: Replace large refresh banner with inline status**

Replace `refreshStatus` with:

```swift
@ViewBuilder
private var refreshStatus: some View {
    if let refreshMessage {
        let layout = HomeRefreshStatusLayout(message: refreshMessage)

        HStack(spacing: ToonEdgeSpacing.small) {
            Image(systemName: "arrow.clockwise")
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.accent)

            Text(layout.message)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, ToonEdgeSpacing.medium)
        .padding(.vertical, ToonEdgeSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ToonEdgeColor.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: layout.cornerRadius).stroke(ToonEdgeColor.border.opacity(0.45)))
    }
}
```

- [ ] **Step 3: Make Continue Reading render a current-read hero first**

Update `continueReadingSection` populated state so the first item is featured and any remaining items are compact:

```swift
let featured = snapshot.continueReading.first
let remaining = Array(snapshot.continueReading.dropFirst())

VStack(spacing: ToonEdgeSpacing.small) {
    if let featured {
        Button {
            openContinueReading(featured)
        } label: {
            HomeSeriesCard(item: featured, style: .featured)
        }
        .buttonStyle(.plain)
    }

    if !remaining.isEmpty {
        VStack(spacing: ToonEdgeSpacing.xsmall) {
            ForEach(remaining) { item in
                Button {
                    openContinueReading(item)
                } label: {
                    HomeSeriesCard(item: item, style: .compact)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

Keep the existing `View All` action unchanged.

- [ ] **Step 4: Rewrite `HomeSeriesCard` without `TECard`**

Replace `HomeSeriesCard.body` with:

```swift
var body: some View {
    let layout = HomeSeriesCardLayout(style: style)

    Group {
        if style == .featured {
            featuredCard(layout: layout)
        } else {
            compactCard(layout: layout)
        }
    }
    .frame(height: layout.fixedHeight)
    .contentShape(Rectangle())
}
```

Change `featuredCard` and `compactCard` signatures and use the layout:

```swift
private func featuredCard(layout: HomeSeriesCardLayout) -> some View {
    HStack(alignment: .top, spacing: ToonEdgeSpacing.medium) {
        cover(cornerRadius: layout.cornerRadius)
            .frame(width: layout.coverWidth, height: layout.coverHeight)

        VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
            titleBlock(titleLineLimit: layout.titleLineLimit)
            Spacer(minLength: 0)
            ProgressView(value: item.progressPercent)
                .tint(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
                .frame(height: layout.progressHeight)
        }
        .frame(minHeight: layout.coverHeight)

        Spacer(minLength: 0)

        Image(systemName: "play.fill")
            .font(ToonEdgeTypography.caption)
            .foregroundStyle(ToonEdgeColor.textSecondary)
            .padding(.top, ToonEdgeSpacing.small)
    }
    .padding(.vertical, ToonEdgeSpacing.small)
}

private func compactCard(layout: HomeSeriesCardLayout) -> some View {
    HStack(spacing: ToonEdgeSpacing.medium) {
        cover(cornerRadius: layout.cornerRadius)
            .frame(width: layout.coverWidth, height: layout.coverHeight)

        titleBlock(titleLineLimit: layout.titleLineLimit)

        Spacer(minLength: ToonEdgeSpacing.small)

        Image(systemName: "chevron.right")
            .font(ToonEdgeTypography.caption)
            .foregroundStyle(ToonEdgeColor.textSecondary)
    }
    .padding(.vertical, ToonEdgeSpacing.xsmall)
}
```

Replace `cover` with a parameterized helper:

```swift
private func cover(cornerRadius: CGFloat) -> some View {
    CachedCoverArtwork(url: item.coverImageURL) {
        coverPlaceholder(cornerRadius: cornerRadius)
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(ToonEdgeColor.border.opacity(0.55))
    )
}
```

Replace `coverPlaceholder` with:

```swift
private func coverPlaceholder(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
        .fill(item.hasUnreadUpdates ? ToonEdgeColor.success.opacity(0.22) : ToonEdgeColor.accentSoft.opacity(0.82))
        .overlay {
            Image(systemName: item.hasUnreadUpdates ? "sparkle" : "book.pages")
                .foregroundStyle(item.hasUnreadUpdates ? ToonEdgeColor.success : ToonEdgeColor.accent)
        }
}
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 4: Full Verification

**Files:**
- Test-only verification across the package and app target.

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

Open the Home tab and verify:

- Search remains near the top and opens the search overlay.
- Continue Reading is the strongest content object after search.
- The first continue-reading item appears as a cover-first current-read hero.
- Remaining Home reading items use compact cover-first treatments.
- Home cards no longer sit inside repeated grey `TECard` boxes.
- Settings remains reachable.
- Refresh remains available through pull-to-refresh and the explicit icon button.
- Refresh feedback appears as quiet inline status rather than a large banner.

## Risks

- Removing `TECard` changes tap affordance. Use `.contentShape(Rectangle())` on Home reading cells so the full visual row remains tappable.
- A single current-read hero could feel sparse when cover art is missing. Keep the existing placeholder artwork path, but use smaller radii and restrained colors.
- Recently Updated and All Library card taps are not expanded in this visual story. This plan preserves existing routing behavior and avoids broad navigation changes.
- The plan keeps the explicit refresh icon for discoverability, even though pull-to-refresh remains available.

## Self-Review

- Story coverage: Story 11.37 acceptance criteria map to Tasks 1-4.
- Scope check: no persistence, detection, Browser, Reader, update-check comparison, search classification, or save-to-library changes are included.
- Type consistency: all new test-referenced layout types are defined in `HomeView.swift`.
- Placeholder scan: no implementation step depends on unresolved behavior or unspecified values.
