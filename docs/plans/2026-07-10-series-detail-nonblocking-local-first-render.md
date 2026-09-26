# Series Detail Non-Blocking Local First Render Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Story 11.41 so Series Detail renders existing local data before opportunistic chapter-index refresh work can affect the screen.

**Architecture:** Keep the current `SeriesDetailView` ownership and service boundaries. Split startup into two phases: one task loads the local `SeriesDetailSnapshot`, and a second background task starts the chapter-index refresh only after local detail exists. Refresh completion may reload local detail, but refresh failure must never clear or block the displayed snapshot.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, existing ToonEdge `AppDependencies`, `LibraryProviding`, and `SeriesChapterIndexRefreshing` protocols.

## Global Constraints

- Implement only Story 11.41.
- Do not change persistence schema.
- Do not change Reader detection, Browser behavior, chapter-index parsing, update-check comparison, save-to-library grouping, or Library collection layout.
- Do not add new visible Series Detail refresh copy, spinner, progress bar, or toast.
- Keep `SeriesDetailSnapshot.primaryChapter` as the Continue action source of truth.
- Keep refresh failures non-destructive: local detail remains visible when refresh returns `nil`, fails, or reports `didRefresh == false`.
- Use TDD: add/update tests first, verify expected failure, then implement the smallest SwiftUI/layout change.

---

## Files

- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Split initial local detail loading from opportunistic chapter-index refresh.
  - Add or update a small testable `SeriesDetailRefreshBehavior` helper so tests can assert refresh starts only after local detail exists.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add behavior tests for local-first refresh sequencing and non-destructive refresh reload rules.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Story 11.41 implemented after verification.
- Optional if needed: `docs/defects.md`
  - Add a defect entry only if implementation confirms the loading-only screen is a defect rather than a planned UX refinement.

---

## Task 1: Add Local-First Refresh Sequencing Tests

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Interfaces:**
- Consumes:
  - Existing `SeriesDetailRefreshBehavior.shouldAttemptRefresh(hasAttemptedChapterIndexRefresh:chapterIndexRefreshService:)`.
  - Existing `SeriesDetailRefreshBehavior.shouldReloadDetail(after:)`.
- Produces:
  - Updated helper signature:

```swift
static func shouldAttemptRefresh(
    detail: SeriesDetailSnapshot?,
    hasAttemptedChapterIndexRefresh: Bool,
    chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
) -> Bool
```

- [ ] **Step 1: Write failing sequencing test**

In `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`, replace `seriesDetailRefreshBehaviorAttemptsOnlyWhenServiceExistsAndNotYetTried` with:

```swift
@Test func seriesDetailRefreshBehaviorStartsOnlyAfterLocalDetailExists() {
    let detail = SeriesDetailSnapshot.mock(
        chapters: [
            ChapterSummary.mock(chapterLabel: "106", readState: .read),
            ChapterSummary.mock(chapterLabel: "107", readState: .unread)
        ]
    )

    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: nil,
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: detail,
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: detail,
        hasAttemptedChapterIndexRefresh: true,
        chapterIndexRefreshService: MockSeriesChapterIndexRefreshService()
    ))
    #expect(!SeriesDetailRefreshBehavior.shouldAttemptRefresh(
        detail: detail,
        hasAttemptedChapterIndexRefresh: false,
        chapterIndexRefreshService: nil
    ))
}
```

- [ ] **Step 2: Keep reload-rule coverage**

Leave `seriesDetailRefreshBehaviorReloadsOnlyWhenRefreshActuallyMutatesLocalData` in place. It already verifies that a refresh result only causes a reload when `didRefresh == true`.

- [ ] **Step 3: Run the focused failing test**

Run:

```bash
swift test --package-path app --filter seriesDetailRefreshBehaviorStartsOnlyAfterLocalDetailExists
```

Expected: compile failure because `SeriesDetailRefreshBehavior.shouldAttemptRefresh` does not accept `detail:`.

- [ ] **Step 4: Update the refresh behavior helper**

In `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`, replace the existing helper method with:

```swift
struct SeriesDetailRefreshBehavior {
    static func shouldAttemptRefresh(
        detail: SeriesDetailSnapshot?,
        hasAttemptedChapterIndexRefresh: Bool,
        chapterIndexRefreshService: (any SeriesChapterIndexRefreshing)?
    ) -> Bool {
        detail != nil && !hasAttemptedChapterIndexRefresh && chapterIndexRefreshService != nil
    }

    static func shouldReloadDetail(after outcome: ChapterIndexRefreshOutcome?) -> Bool {
        outcome?.didRefresh == true
    }
}
```

- [ ] **Step 5: Run the focused test**

Run:

```bash
swift test --package-path app --filter seriesDetailRefreshBehaviorStartsOnlyAfterLocalDetailExists
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift
git commit -m "Test local-first series detail refresh sequencing"
```

---

## Task 2: Split Series Detail Startup Tasks

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - `SeriesDetailRefreshBehavior.shouldAttemptRefresh(detail:hasAttemptedChapterIndexRefresh:chapterIndexRefreshService:)`.
  - `reloadDetail() async`.
  - `refreshChapterIndexIfAvailable() async`.
- Produces:
  - Local detail load runs in the initial `.task`.
  - Opportunistic refresh runs from a separate `.task(id:)` after `detail?.id` exists.

- [ ] **Step 1: Add a focused startup policy test**

Add this test near the Series Detail refresh behavior tests in `LibraryExperienceTests.swift`:

```swift
@Test func seriesDetailStartupKeepsLocalLoadAndBackgroundRefreshAsSeparatePhases() {
    let plan = SeriesDetailStartupPlan(localDetailLoaded: false, refreshAttempted: false)
    #expect(plan.nextPhase == .loadLocalDetail)

    let loadedPlan = SeriesDetailStartupPlan(localDetailLoaded: true, refreshAttempted: false)
    #expect(loadedPlan.nextPhase == .startBackgroundRefresh)

    let refreshedPlan = SeriesDetailStartupPlan(localDetailLoaded: true, refreshAttempted: true)
    #expect(refreshedPlan.nextPhase == .idle)
}
```

- [ ] **Step 2: Run the new test and verify failure**

Run:

```bash
swift test --package-path app --filter seriesDetailStartupKeepsLocalLoadAndBackgroundRefreshAsSeparatePhases
```

Expected: compile failure because `SeriesDetailStartupPlan` does not exist.

- [ ] **Step 3: Add the startup plan helper**

In `LibraryView.swift`, near `SeriesDetailRefreshBehavior`, add:

```swift
struct SeriesDetailStartupPlan: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case loadLocalDetail
        case startBackgroundRefresh
        case idle
    }

    var localDetailLoaded: Bool
    var refreshAttempted: Bool

    var nextPhase: Phase {
        if !localDetailLoaded {
            return .loadLocalDetail
        }

        if !refreshAttempted {
            return .startBackgroundRefresh
        }

        return .idle
    }
}
```

- [ ] **Step 4: Split the SwiftUI tasks**

In `SeriesDetailView.body`, replace:

```swift
.task {
    await reloadDetail()
    await refreshChapterIndexIfAvailable()
}
```

with:

```swift
.task {
    await reloadDetail()
}
.task(id: detail?.id) {
    guard detail != nil else { return }
    await refreshChapterIndexIfAvailable()
}
```

- [ ] **Step 5: Update `refreshChapterIndexIfAvailable` call site**

In `refreshChapterIndexIfAvailable()`, update the guard to pass `detail`:

```swift
guard SeriesDetailRefreshBehavior.shouldAttemptRefresh(
    detail: detail,
    hasAttemptedChapterIndexRefresh: hasAttemptedChapterIndexRefresh,
    chapterIndexRefreshService: dependencies.chapterIndexRefreshService
) else {
    return
}
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
swift test --package-path app --filter seriesDetailStartupKeepsLocalLoadAndBackgroundRefreshAsSeparatePhases
swift test --package-path app --filter seriesDetailRefreshBehavior
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift
git commit -m "Render series detail before background refresh"
```

---

## Task 3: Regression Verification and Documentation

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes:
  - Story 11.41 acceptance criteria.
  - Focused tests from Tasks 1 and 2.
- Produces:
  - Story 11.41 marked implemented after verification.

- [ ] **Step 1: Run focused Library experience tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 2: Run full package tests**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 3: Build the app target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Mark Story 11.41 implemented**

In `docs/toonedge_epics_and_stories.md`, change:

```markdown
### Story 11.41 — Series Detail non-blocking local first render
**Status:** planned
```

to:

```markdown
### Story 11.41 — Series Detail non-blocking local first render
**Status:** implemented
```

- [ ] **Step 5: Commit docs**

```bash
git add docs/toonedge_epics_and_stories.md docs/plans/2026-07-10-series-detail-nonblocking-local-first-render.md
git commit -m "Document series detail local-first render plan"
```

---

## Verification Checklist

- `swift test --package-path app --filter seriesDetailRefreshBehaviorStartsOnlyAfterLocalDetailExists`
- `swift test --package-path app --filter seriesDetailStartupKeepsLocalLoadAndBackgroundRefreshAsSeparatePhases`
- `swift test --package-path app --filter LibraryExperienceTests`
- `swift test --package-path app`
- `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build`

## Known Limitations

- This plan intentionally does not pass a prebuilt Library row summary into Series Detail. The local repository lookup may still briefly show the loading banner, but network refresh should not extend that loading-only state.
- If simulator data is corrupted or the series ID no longer maps to a local saved/recent record, the existing unavailable state remains correct.
- A later visual-polish story can add a placeholder detail shell from `LibrarySeriesSummary` if the local repository lookup itself is visibly slow.

## Self-Review

- Story 11.41 acceptance criteria map to Tasks 1 and 2.
- No persistence schema, parser, update-check comparison, Browser, or Reader changes are included.
- The plan keeps the implementation scoped to `SeriesDetailView` startup sequencing and tests.
- The plan has one explicit limitation: it fixes refresh blocking, not pre-rendering from grid summary data.
