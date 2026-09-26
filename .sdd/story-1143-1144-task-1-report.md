STATUS: DONE

Tests added:
- `seriesDetailSeedShellPreservesKnownLibraryCoverURL`
- `hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail`

Red test result and failure reason:
- `swift test --package-path app --filter seriesDetailSeedShellPreservesKnownLibraryCoverURL` failed as expected before implementation.
- `swift test --package-path app --filter hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail` failed as expected before implementation.
- Failure reason: compile failure, `cannot find 'SeriesDetailCoverLayout' in scope`.

Implementation summary:
- Added `SeriesDetailCoverLayout` with `coverImageURL` and `usesPlaceholder`.
- Extended `SeriesDetailSnapshot.mock` to accept `title`, `sourceDomain`, and `coverImageURL`, and to derive `chaptersRead` from read chapters.
- Inspected `SwiftDataLibraryRepository` cover mapping and reconciliation paths. Stored series and recent-reading summaries/details already preserve `coverImageURLString` via `URL.init(string:)`, and add/update paths already persist non-nil cover URLs, so no persistence regression or repository fix was added.

Commands run and pass/fail results:
- `swift test --package-path app --filter seriesDetailSeedShellPreservesKnownLibraryCoverURL` - FAIL before implementation, expected compile failure for missing `SeriesDetailCoverLayout`.
- `swift test --package-path app --filter hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail` - FAIL before implementation, expected compile failure for missing `SeriesDetailCoverLayout`.
- `rg -n "coverImageURLString|seriesSummary|seriesDetail|recordRecentReading" app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift` - PASS, inspection command completed.
- `swift test --package-path app --filter seriesDetailSeedShellPreservesKnownLibraryCoverURL` - PASS after implementation, 1 Swift Testing test passed.
- `swift test --package-path app --filter hydratedSeriesDetailKeepsKnownCoverURLFromStoredDetail` - PASS after implementation, 1 Swift Testing test passed.
- `swift test --package-path app --filter savedSeriesSummaryAndDetailPreserveCoverURL` - SKIPPED because the optional persistence mapper/reconciliation loss was not found.

Files changed:
- `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `.sdd/story-1143-1144-task-1-report.md`

Concerns:
- The checkout has broad pre-existing dirty changes in the owned files, so `git diff` against `HEAD` includes unrelated prior-story edits. I did not revert or modify unrelated changes.
