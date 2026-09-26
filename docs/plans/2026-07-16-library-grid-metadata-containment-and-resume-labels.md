# Library Grid Metadata Containment and Resume Labels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement DEF-032, DEF-033, Story 11.47, and Story 11.48 so Library grid/list metadata is visually contained and chapter labels describe the reader's actual next/resume target instead of masquerading latest-known chapter metadata as current progress.

**Architecture:** Keep the change inside the Library presentation and existing repository summary projection. Use `LibrarySeriesCardLayout` for layout containment, `LibrarySeriesCardContent` for UI label semantics, and existing `LibrarySeriesSummary.resumeTarget` from the repository as the source of truth for next-reading labels. Do not change persistence schema, Reader, Browser, parsing, update checks, or save-to-library grouping.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing ToonEdge Library domain and repository models.

## Story Summary

- **Story 11.47 / DEF-032:** Comfortable Library grid cells must reserve enough height for cover, title, source domain, progress, and badge rows so chapter/update pills never overlap the next row's cover.
- **Story 11.48 / DEF-033:** Library chapter metadata must prefer the same resume/primary chapter semantics that Series Detail uses.
- **Dependency:** Story 11.48 depends on Story 11.45/11.46's existing `LibrarySeriesSummary.resumeTarget`.
- **Scope:** Library UI/card metadata and summary projection only. No persistence migration or source parsing.
- **Risk:** Some existing tests intentionally allow latest-known fallback; update them to distinguish latest/update labels from resume/current labels.

## File Map

- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Update `LibrarySeriesCardLayout.comfortable` heights/spacing.
  - Add a layout invariant helper if useful, such as `minimumRequiredHeight`.
  - Update `LibrarySeriesCardContent` to prefer `resumeTarget` labels consistently across comfortable, compact, and list modes.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add/adjust layout containment tests.
  - Add/adjust card metadata semantic tests.
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
  - Add a repository regression for indexed latest-known chapter diverging from first readable/resume chapter.
- Modify: `docs/defects.md`
  - Mark DEF-032 and DEF-033 implemented after verification.
- Modify: `docs/toonedge_epics_and_stories.md`
  - Mark Story 11.47 and Story 11.48 implemented after verification.

---

## Global Constraints

- Implement only DEF-032, DEF-033, Story 11.47, and Story 11.48.
- Do not change persistence schema.
- Do not change Reader detection, Browser behavior, chapter parsing, update checks, available-chapter indexing semantics, or save-to-library grouping.
- Do not infer chapter URLs from labels or source-specific URL patterns.
- Do not remove latest-known/update information; only prevent it from appearing as the user's current/resume chapter.
- Keep comfortable mode as a 2-column cover-first layout.
- Keep compact mode as a 4-column high-density layout.
- Keep list mode as the highest-density management view.
- Use TDD: add/update tests first, verify expected failure, implement the smallest change, then run focused and full test commands.

---

## Task 1: Add Layout Containment Regression for Comfortable Grid

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Current code:**
- `SeriesCard` renders fixed-height comfortable cells.
- `LibrarySeriesCardLayout.comfortable.fixedCardHeight` is `286`.
- Current metadata stack can exceed the fixed height when the title wraps and badge row is visible:
  - cover slot: `190`
  - title: `46`
  - source metadata: `18`
  - progress: `4`
  - badge row: `24`
  - four `VStack` spacings at `ToonEdgeSpacing.small`

- [ ] **Step 1: Write the failing layout invariant test**

Add a focused test near `librarySeriesCardLayoutKeepsFixedHeightForMixedContent()`:

```swift
@Test func libraryComfortableCardLayoutReservesFullMetadataStack() {
    let layout = LibrarySeriesCardLayout.comfortable

    #expect(layout.fixedCardHeight >= layout.minimumRequiredHeight)
    #expect(layout.badgeRowHeight >= 24)
    #expect(layout.progressHeight >= 4)
    #expect(layout.titleLineLimit == 2)
}
```

If adding `minimumRequiredHeight` is too implementation-specific, test the explicit sum:

```swift
let verticalSpacing = ToonEdgeSpacing.small * 4
let required = layout.coverSlotHeight
    + layout.titleHeight
    + layout.metadataHeight
    + layout.progressHeight
    + layout.badgeRowHeight
    + verticalSpacing
#expect(layout.fixedCardHeight >= required)
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --package-path app --filter libraryComfortableCardLayoutReservesFullMetadataStack
```

Expected: fail if `minimumRequiredHeight` does not exist, or fail because current fixed height does not reserve the full stack.

- [ ] **Step 3: Implement the smallest layout containment fix**

In `LibrarySeriesCardLayout`, add:

```swift
var verticalContentSpacing: CGFloat {
    ToonEdgeSpacing.small * 4
}

var minimumRequiredHeight: CGFloat {
    coverSlotHeight
        + titleHeight
        + metadataHeight
        + progressHeight
        + badgeRowHeight
        + verticalContentSpacing
}
```

Then update comfortable fixed height to at least `minimumRequiredHeight`, with a small breathing buffer. Likely target:

```swift
fixedCardHeight: 302
```

This preserves the 2-column cover-first visual style and avoids increasing compact density.

- [ ] **Step 4: Verify focused layout tests**

Run:

```bash
swift test --package-path app --filter 'libraryComfortableCardLayoutReservesFullMetadataStack|librarySeriesCardLayoutKeepsFixedHeightForMixedContent|libraryNativeCollectionLayoutsUseDistinctGridDensity'
```

Expected: pass.

---

## Task 2: Define a Single Reading Chapter Label Source for Library Cards

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Current code:**
- `LibrarySeriesCardContent.compactMetadata`, `comfortableBadgeMetadata`, and `listMetadata` use similar but separate fallback chains.
- Some paths still fall back to `latestChapterLabel`, which can display `Ch. 236` / `Ch. 237` even when Series Detail starts at chapter 1.
- `LibrarySeriesSummary.resumeTarget?.chapter` is the safest local source for next-reading chapter semantics.

- [ ] **Step 1: Write failing metadata tests**

Add tests near the existing metadata tests:

```swift
@Test func libraryCardMetadataPrefersResumeTargetOverLatestKnownChapter() {
    let resumeChapter = ChapterSummary(
        title: "First Chapter",
        chapterLabel: "1",
        chapterNumber: 1,
        sourceURL: URL(string: "https://example.com/series/chapter-1")!,
        readState: .inProgress(progressPercent: 0),
        isDownloaded: false,
        publishedAt: nil
    )
    let summary = LibrarySeriesSummary.mock(
        title: "The Shepherd Wizard | Asura Scans",
        currentChapterLabel: nil,
        latestChapterLabel: "236",
        resumeTarget: LibraryResumeTarget(chapter: resumeChapter)
    )
    let content = LibrarySeriesCardContent(series: summary)

    #expect(content.compactMetadata == "Ch. 1")
    #expect(content.comfortableBadgeMetadata == "Ch. 1")
    #expect(content.listMetadata == "Ch. 1")
}
```

Add a companion test for no safe resume target:

```swift
@Test func libraryCardMetadataDoesNotPresentLatestKnownAsCurrentWhenResumeTargetIsMissing() {
    let summary = LibrarySeriesSummary.mock(
        currentChapterLabel: nil,
        latestChapterLabel: "236",
        resumeTarget: nil
    )
    let content = LibrarySeriesCardContent(series: summary)

    #expect(content.compactMetadata != "Ch. 236")
    #expect(content.comfortableBadgeMetadata == nil)
}
```

If product decides latest-known should still appear in list mode, make it explicit as `"Latest Ch. 236"` rather than `"Ch. 236"` and adjust tests accordingly.

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --package-path app --filter 'libraryCardMetadataPrefersResumeTargetOverLatestKnownChapter|libraryCardMetadataDoesNotPresentLatestKnownAsCurrentWhenResumeTargetIsMissing'
```

Expected: fail because current `LibrarySeriesCardContent` falls back to `latestChapterLabel`.

- [ ] **Step 3: Implement shared semantic helpers**

In `LibrarySeriesCardContent`, add private helper properties/functions in the initializer scope or as static helpers:

```swift
private static func chapterBadgeLabel(from chapter: ChapterSummary?) -> String? {
    guard let chapter else { return nil }
    return chapterBadgeLabel(from: ChapterNumericLabelExtractor.label(for: chapter) ?? chapter.chapterLabel)
}
```

Since `ChapterNumericLabelExtractor` may not be visible if access control blocks it, fallback to `series.resumeTarget?.chapter.chapterLabel` and existing `chapterBadgeLabel(from:)`.

Recommended fallback order:

1. Completed series: `"Complete"` for comfortable badge, progress summary for non-badge metadata.
2. `resumeTarget?.chapter` numeric label.
3. `currentChapterLabel` numeric label, when non-completed.
4. `latestChapterLabel` only as an explicitly latest/update label if needed, not plain current chapter.
5. `series.chapterSummaryText`.

For Story 11.48, implement minimal visible behavior:

- `compactMetadata`: resume/current chapter, otherwise `series.chapterSummaryText`.
- `comfortableBadgeMetadata`: `"Complete"`, resume/current chapter, otherwise `nil` unless `hasUnreadUpdates` already shows `New`.
- `listMetadata`: resume/current chapter, otherwise existing `metadata`/summary text.

- [ ] **Step 4: Update existing expectations**

Update tests that currently expect latest fallback as current:

- `libraryCompactCardMetadataPrefersShortChapterLabel`
  - Change `noisyCurrentWithLatest` expectation away from `"Ch. 16"` unless it has a concrete `resumeTarget`.
- `libraryComfortableCardBadgePrefersCurrentChapterOverLatestChapter`
  - Change `planned` expectation from `"Ch. 237"` to `nil` or to an explicitly latest label if implemented.
- `libraryListMetadataPrefersNumericChapterLabelOverNoisyCurrentLabel`
  - Change noisy-current latest fallback away from `"Ch. 16"` unless supplied via `resumeTarget`.

- [ ] **Step 5: Verify focused metadata tests**

Run:

```bash
swift test --package-path app --filter 'libraryCardMetadata|libraryCompactCardMetadata|libraryComfortableCardBadge|libraryListMetadata'
```

Expected: pass.

---

## Task 3: Add Repository Regression for Indexed Latest Diverging from First Resume Target

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Implementation: likely none if Story 11.46 resume projection is correct.

**Purpose:** Prove DEF-033 is not only a UI fallback issue. The repository should provide a safe `resumeTarget` for a saved/indexed series whose latest-known chapter is much higher than the first readable chapter.

- [ ] **Step 1: Write repository regression**

Add near existing `librarySnapshotSummaryCarriesConcreteResumeTargetFromIndexedChapters`:

```swift
@MainActor
@Test func librarySummaryResumeTargetStartsAtFirstReadableChapterWhenLatestKnownIsHigher() async throws {
    let repository = try makeRepository()
    let seriesID = UUID()
    let chapter1ID = UUID()
    let chapter236ID = UUID()

    try await repository.addToLibrary(
        .mock(
            id: seriesID,
            title: "The Shepherd Wizard | Asura Scans",
            sourceDomain: "asurascans.com",
            latestKnownChapterLabel: "236",
            libraryState: .reading,
            chapters: [
                .mock(
                    id: chapter1ID,
                    title: "First Chapter",
                    chapterLabel: "1",
                    sourceURL: URL(string: "https://asurascans.com/series/shepherd/chapter/1")!
                ),
                .mock(
                    id: chapter236ID,
                    title: "Chapter 236",
                    chapterLabel: "236",
                    sourceURL: URL(string: "https://asurascans.com/series/shepherd/chapter/236")!
                )
            ]
        ),
        context: .reader
    )

    let summary = try #require(await repository.librarySnapshot().series.first { $0.id == seriesID })
    let detail = try #require(await repository.seriesDetail(for: seriesID))

    #expect(summary.latestChapterLabel == "236")
    #expect(summary.resumeTarget?.chapter.id == detail.primaryChapter?.id)
    #expect(summary.resumeTarget?.chapter.chapterLabel == "1")
    #expect(detail.primaryActionTitle == "Start Chapter 1")
}
```

If the current domain selector chooses newest unread chapter rather than first unread chapter for a never-started series, decide whether the correct product behavior is:

- **First unread:** safer for saved series with no progress, aligns with the screenshot expectation.
- **Newest unread:** useful for update chasing but wrong for new readers.

For this story, use **first unread when no progress exists** because Library and Series Detail should guide a new reader to the start.

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --package-path app --filter librarySummaryResumeTargetStartsAtFirstReadableChapterWhenLatestKnownIsHigher
```

Expected: may fail if `SeriesPrimaryChapterSelector` currently chooses newest unread chapter.

- [ ] **Step 3: Implement selector adjustment if needed**

If the test fails because primary selection chooses newest unread for no progress, update `SeriesPrimaryChapterSelector.primaryChapter(in:)`:

- If there is an in-progress chapter, keep most recent in-progress.
- If there is completed progress, keep the existing next-after-latest-completed behavior.
- If there is no completed/in-progress progress, choose the lowest numeric readable chapter, not the newest.

Keep generated placeholder/unopenable rows out of the primary target if existing selector already does that through `readState.isReadableNext` and stored summaries.

- [ ] **Step 4: Verify Series Detail primary action tests**

Run:

```bash
swift test --package-path app --filter 'seriesDetailPrimaryActionStartsFirstUnreadWhenNoProgressExists|librarySummaryResumeTargetStartsAtFirstReadableChapterWhenLatestKnownIsHigher|librarySummaryResumeTargetMatchesSeriesDetailPrimaryChapterWithoutDetailSnapshotConstruction'
```

Expected: pass.

---

## Task 4: Preserve Update Signaling Without Current-Chapter Confusion

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`

**Purpose:** Ensure removing latest-known fallback does not hide the existing `New` update signal.

- [ ] **Step 1: Add behavior test**

```swift
@Test func libraryCardMetadataKeepsNewUpdateSeparateFromResumeChapter() {
    let resumeChapter = ChapterSummary(
        title: "First Chapter",
        chapterLabel: "1",
        chapterNumber: 1,
        sourceURL: URL(string: "https://example.com/chapter-1")!,
        readState: .unread,
        isDownloaded: false,
        publishedAt: nil
    )
    let summary = LibrarySeriesSummary.mock(
        hasUnreadUpdates: true,
        currentChapterLabel: nil,
        latestChapterLabel: "236",
        resumeTarget: LibraryResumeTarget(chapter: resumeChapter)
    )
    let content = LibrarySeriesCardContent(series: summary)

    #expect(content.comfortableBadgeMetadata == "Ch. 1")
    #expect(content.compactMetadata == "Ch. 1")
}
```

The visible `New` chip is driven by `series.hasUnreadUpdates` in `SeriesCard`, so this test only needs to prove chapter metadata remains resume-based.

- [ ] **Step 2: Run focused test**

```bash
swift test --package-path app --filter libraryCardMetadataKeepsNewUpdateSeparateFromResumeChapter
```

Expected: pass after Task 2.

---

## Task 5: Final Documentation Status Updates

**Files:**
- Modify: `docs/defects.md`
- Modify: `docs/toonedge_epics_and_stories.md`

- [ ] **Step 1: After verification, mark DEF-032 implemented**

In `docs/defects.md`:

```markdown
**Status:** Implemented
```

for DEF-032.

- [ ] **Step 2: After verification, mark DEF-033 implemented**

In `docs/defects.md`:

```markdown
**Status:** Implemented
```

for DEF-033.

- [ ] **Step 3: After verification, mark Story 11.47 implemented**

In `docs/toonedge_epics_and_stories.md`:

```markdown
**Status:** implemented
```

for Story 11.47.

- [ ] **Step 4: After verification, mark Story 11.48 implemented**

In `docs/toonedge_epics_and_stories.md`:

```markdown
**Status:** implemented
```

for Story 11.48.

---

## Final Verification

Run focused tests:

```bash
swift test --package-path app --filter LibraryExperienceTests
swift test --package-path app --filter PersistenceLifecycleTests
```

Run full package tests:

```bash
swift test --package-path app
```

Build if possible:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Optional visual verification:

- Open Library comfortable mode on iPhone 16 simulator.
- Confirm top-row badges/progress do not overlap the next row covers.
- Switch to compact mode and confirm chapter labels show resume target such as `Ch. 1`, not latest-known `Ch. 236`, for the Shepherd Wizard example.
- Open Series Detail and confirm the primary action agrees with Library metadata.

## Expected Outcome

- Comfortable Library cells have enough fixed height/spacing for their metadata stack.
- Comfortable, compact, and list chapter metadata use the same resume-target semantics.
- Latest-known chapter labels no longer appear as current/resume chapter labels when no safe resume target exists.
- `New` update state remains visible and separate from chapter progress.
- No behavior changes outside Library card metadata/layout and existing summary target selection.
