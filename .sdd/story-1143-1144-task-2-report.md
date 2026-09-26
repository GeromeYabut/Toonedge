STATUS: DONE_WITH_CONCERNS

Tests added:
- `seriesDetailEntryUsesCachedHydratedDetailBeforeSeedShell`
- `seriesDetailEntryIsActionableWhenLocalIndexHasNextChapter`
- `seriesDetailEntryContinuesForwardInProgressChapterFromLocalIndex`
- `seriesDetailEntryCanShowAllReadWhileEdgeRefreshRunsInBackground`

Red test result and failure reason:
- Command: `swift test --package-path app --filter seriesDetailEntry`
- Result: failed as expected.
- Failure reason: compile failure because `SeriesDetailEntryLayout` did not exist:
  - `cannot find 'SeriesDetailEntryLayout' in scope`
  - follow-on contextual inference errors for `.hydratedDetail` and `nil` arguments.

Implementation summary:
- Added `SeriesDetailEntryLayout` with hydrated detail, seed shell, loading, and unavailable visible states.
- Added an in-memory `seriesDetailCache` to `LibraryView`, keyed by series ID.
- Passed cached detail into `SeriesDetailView` from the library navigation destination.
- Added `onDetailHydrated` callback to update or clear the in-memory cache after `reloadDetail()`.
- Seeded `SeriesDetailView`'s local `detail` state from `cachedDetail` so cached local detail is actionable before the seed shell.
- Left `SeriesDetailSnapshot` as the source of truth for Continue; `LibrarySeriesSummary` remains seed-only.
- Did not change persistence schema, reader detection, browser behavior, chapter parsing, update checks, save grouping, or library filters/layout.

Commands run and pass/fail results:
- `swift test --package-path app --filter seriesDetailEntry`
  - First run: failed as expected before implementation because `SeriesDetailEntryLayout` was missing.
  - Final run: passed, 4 Swift Testing tests passed.
- `swift test --package-path app --filter seriesDetailPrimaryAction`
  - Final run: passed, 6 Swift Testing tests passed.

Files changed:
- `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `.sdd/story-1143-1144-task-2-report.md`

Concerns:
- The checkout already had dirty changes in the two owned source/test files before this task. I did not reset or revert them.
- The final `seriesDetailPrimaryAction` command observed another SwiftPM instance using `.build` and waited, then completed successfully.
