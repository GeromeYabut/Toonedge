STATUS: DONE

Tests added:
- `hydratedSeriesDetailLayoutKeepsHeaderFixedAndChaptersScrollable`
- `seededSeriesDetailLayoutKeepsSeedHeaderVisibleWithoutChapterScroller`
- `nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller`

Red test result and failure reason:
- `swift test --package-path app --filter SeriesDetailLayout`: failed before implementation with `cannot find 'SeriesDetailPageLayout' in scope`, plus contextual nil/member inference errors caused by that missing type.
- `swift test --package-path app --filter nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller`: failed before implementation with `cannot find 'SeriesDetailPageLayout' in scope`, plus contextual nil/member inference errors caused by that missing type.

Implementation summary:
- Added `SeriesDetailPageLayout` with hydrated, seeded, loading, and unavailable state mapping.
- Changed `SeriesDetailView.body` to delegate state rendering through `content`.
- Kept hydrated detail header and cache status outside the chapter scroller.
- Moved chapter toolbar/list and chapter-anchor scrolling into an inner `ScrollViewReader` and `ScrollView`.
- Left seeded, loading, and unavailable states as simple scroll shells without an empty chapter scroller.
- Preserved existing Task 2 entry/cache semantics and focused only on Story 11.44 layout behavior.

Commands run and pass/fail results:
- `swift test --package-path app --filter SeriesDetailLayout`: FAIL before implementation, expected missing `SeriesDetailPageLayout`; PASS after implementation, 2 Swift Testing tests passed.
- `swift test --package-path app --filter nonHydratedSeriesDetailStatesDoNotCreateEmptyChapterScroller`: FAIL before implementation, expected missing `SeriesDetailPageLayout`; PASS after implementation, 1 Swift Testing test passed.
- `swift test --package-path app --filter seriesDetailEntry`: PASS after implementation, 4 Swift Testing tests passed.

Files changed:
- `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `.sdd/story-1143-1144-task-3-report.md`

Concerns:
- None for the scoped Story 11.44 implementation.
