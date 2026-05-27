# QA Guide: Epic 9/10 Updates and Cache Hardening

**Date:** 2026-05-14  
**Area:** Updates, cache, downloads, reader-safe cache writes  
**Purpose:** Manual simulator pass for the Epic 9/10 hardening follow-up.

## Scope

This pass verifies:

- Manual update refresh from Home and Library
- Lightweight latest-chapter update behavior
- Reader cache retain feedback
- Series Detail cache retain feedback
- Downloads cache remove feedback
- File-backed cache storage summary
- Failure behavior when update checks or cache actions cannot complete
- Reader safety when progress and cache metadata are written

This pass does not verify:

- Sync
- Push notifications
- Recommendations
- Catalogs or source marketplace behavior
- Social features
- Browser tabs
- Multi-page chapter stitching

## Setup

From the repository root:

```bash
cd /Users/geromeyabut/Desktop/Toonedge
xcodebuild -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/ToonEdgeDerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

Open the project:

```bash
open app/ToonEdge.xcodeproj
```

In Xcode:

- Select the `ToonEdge` scheme.
- Select an iPhone simulator.
- Run with `Cmd+R`.

## Seed Data

Use the app normally to create local state:

1. Open Home.
2. Search for or paste a chapter URL.
3. Let the page open in Browser.
4. If Reader Mode auto-opens or the “Read in Clean Mode” CTA appears, open Reader.
5. Scroll enough to create progress.
6. Retain at least one chapter offline if the action is visible.
7. Confirm the series appears in Library or Continue Reading.

Minimum seed target:

- One in-progress chapter
- One saved or recently read series
- One retained/offline chapter candidate

## Pass 1: Home Manual Refresh

Steps:

1. Open Home.
2. Trigger update refresh with pull-to-refresh or the visible refresh action.
3. Keep interacting with the screen during or immediately after refresh.

Expected result:

- UI remains responsive.
- A non-blocking loading or completion state appears.
- Existing Continue Reading and Library content remain intact.
- Failed update checks do not clear unread/update state.
- Browser or Reader does not open automatically from refresh alone.

Record:

- Pass/fail
- Any stalled loading state
- Any unexpected navigation
- Any update state that disappeared unexpectedly

## Pass 2: Library Manual Refresh

Steps:

1. Open Library.
2. Check Recent, Reading, and Planned segments if available.
3. Trigger update refresh.
4. Navigate away and back after refresh completes.

Expected result:

- Loading state is visible but non-blocking.
- Existing series remain visible.
- Update badges only change when a newer latest chapter is detected.
- Refresh failure does not remove series, progress, or cached metadata.
- Segment selection and navigation remain stable.

Record:

- Pass/fail
- Segment tested
- Any missing series after refresh
- Any incorrect update badge behavior

## Pass 3: Reader Cache Feedback

Steps:

1. Open a Reader session.
2. Tap the retain/offline action.
3. Tap the retain/offline action again if still available.
4. Scroll after retaining.
5. Leave Reader and reopen the same chapter.

Expected result:

- Retain action shows visible, non-blocking feedback.
- Repeated retain action is stable and does not create duplicate state.
- Reader scroll remains smooth.
- Reading progress still saves and restores.
- The user can still use “View Original Page.”

Record:

- Pass/fail
- Feedback text shown
- Whether progress restored
- Any scroll hitch or repeated cache-write symptoms

## Pass 4: Series Detail Cache Feedback

Steps:

1. Open a saved series from Home or Library.
2. Locate a chapter row with cache/retain affordance.
3. Retain the chapter.
4. Return to Downloads.

Expected result:

- Series Detail shows success or failure feedback.
- The row state updates consistently.
- Downloads reflects the retained entry.
- Failure feedback does not block opening or reading the chapter.

Record:

- Pass/fail
- Whether Downloads reflected the retained chapter
- Any stale row state

## Pass 5: Downloads Remove Feedback

Steps:

1. Open Downloads.
2. Confirm retained or recent cache entries are listed.
3. Remove one cached chapter.
4. Return to Downloads after navigating away.

Expected result:

- Remove action shows success or failure feedback.
- Removed entry disappears or updates correctly.
- Storage summary updates.
- If removal fails, the user gets retryable failure feedback.

Record:

- Pass/fail
- Entry removed
- Feedback text shown
- Storage summary before and after

## Pass 6: Storage Summary

Steps:

1. Open Downloads.
2. Check total count and storage summary.
3. Remove an entry.
4. Reopen Downloads.

Expected result:

- If cached files exist, storage uses measured bytes.
- If only metadata exists, storage falls back to estimated bytes.
- Summary remains responsive with many entries.
- Removed files or metadata are not silently counted as retained content.

Record:

- Pass/fail
- Summary text before and after
- Any visible delay or stale count

## Pass 7: Original Page Safety

Steps:

1. Open Reader from Browser or Library.
2. Use “View Original Page.”
3. Navigate back to Reader if applicable.

Expected result:

- The original source page opens or remains available.
- Browser state is preserved when Reader was opened above Browser.
- Reader never traps the user away from the original page.

Record:

- Pass/fail
- Source URL/page restored
- Any lost browser state

## Pass 8: Network Failure Check

Steps:

1. In Simulator, disable network connectivity or test with an unreachable saved source.
2. Open Home or Library.
3. Trigger update refresh.

Expected result:

- Refresh completes with non-blocking failure or partial-completion feedback.
- Existing library and unread update state are preserved.
- No false “new chapter” state is created.
- App remains usable.

Record:

- Pass/fail
- Failure feedback shown
- Any lost update/library state

## Story 11.27 QA — Unseen adjacent chapter loading

1. Open a saved/recent Reader chapter with a valid `Next` link.
2. Confirm `Next` is enabled even if the next chapter has not been opened before.
3. Tap `Next`.
4. Confirm Reader stays visible and shows a lightweight loading state.
5. Confirm the next source chapter appears in Reader, not stock/sample images.
6. Confirm chapter label and progress reset.
7. Tap `Previous` and confirm the previous chapter can load similarly.
8. Try an unsafe/challenge page and confirm Reader remains on the current chapter with a failure message.
9. Tap Back and confirm it returns to the original native launch context.
10. Tap `View Original Page` and confirm it opens the exact currently displayed chapter URL.

## Pass Criteria

The pass is acceptable when:

- Home refresh, Library refresh, Reader retain, Series Detail retain, Downloads remove, storage summary, original-page return, and network failure handling all pass.
- No crash, freeze, silent destructive state change, or unwanted navigation occurs.
- Any failures are reproducible and captured with screen, step, expected result, and actual result.

## QA Report Template

```markdown
## Epic 9/10 Updates and Cache QA

Date:
Tester:
Simulator:
Build source/commit:

### Results
- Home manual refresh:
- Library manual refresh:
- Reader cache feedback:
- Series Detail cache feedback:
- Downloads remove feedback:
- Storage summary:
- Original page safety:
- Network failure check:

### Issues
- 

### Notes
- 
```
