# ToonEdge Session Notes — 2026-05-12 — Epic 9 Updates and Cache

## Session Goal
Implement Epic 9:
- update comparison logic and update-check service contracts
- persisted update state
- local cache metadata
- Downloads summary from local metadata
- recent cache metadata recording from Reader
- manual retained/offline metadata shell

## Source Documents Read
- `AGENTS.md`
- `docs/toonedge_architecture_doc.md`
- `docs/toonedge_prd.md`
- `docs/toonedge_ux_requirements_doc.md`
- `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-12_epic8_persistence_lifecycle.md`
- `docs/plans/2026-05-12-epic9-updates-cache-handoff.md`

## Scope Summary
Implemented metadata-only update/cache behavior for MVP.

Not implemented:
- sync
- push notifications
- recommendations, catalogs, source marketplace, or social features
- multi-page chapter stitching
- network image download or background refresh

## Stories Completed

### Task 1 — Update comparison domain logic
- Added `ChapterUpdateComparisonResult`.
- Added `ChapterUpdateComparison.compare(storedLatest:fetchedLatest:)`.
- Numeric and decimal labels compare numerically.
- Non-numeric changed labels are treated as changed, not ordered.
- Missing stored label with fetched label marks update available.

### Task 2 — Update-check service contracts
- Added `SeriesLatestChapterSnapshot`.
- Added `SeriesUpdateCheckResult`.
- Added `SeriesLatestChapterFetching`.
- Added `SeriesUpdateChecking`.
- Added protocol-backed `SeriesUpdateChecker`.
- Added deterministic `MockSeriesLatestChapterFetcher`.

### Task 3 — Persist update state
- Added repository API for `recordUpdateCheckResult(seriesID:latestChapterLabel:hasUnreadUpdates:checkedAt:)`.
- Reused existing `StoredSeries.latestKnownChapterLabel`, `hasUnreadUpdates`, and `updatedAt`.
- Home Recently Updated and Library Recent now surface stored unread update state.

### Task 4 — Cache metadata domain and persistence
- Added `CacheRetentionState`, `CacheMetadataInput`, and `CacheMetadataEntry`.
- Added `CacheMetadataManaging`.
- Added SwiftData model `StoredCacheEntry`.
- `SwiftDataLibraryRepository` now records, removes, lists, and summarizes cache metadata.
- `DownloadSummary` now includes recent count, retained count, total estimated bytes, and stable storage text.

### Task 5 — Downloads wiring
- Persistent dependencies now use `SwiftDataLibraryRepository` as the Downloads summary provider.
- Added `cacheMetadataService` dependency.
- Downloads screen now shows cached, retained, recent, and storage metadata from the dependency.

### Task 6 — Reader recent cache metadata
- `ReaderViewModel` records recent cache metadata when progress is saved after restore.
- Reader receives `CacheMetadataManaging` through app dependencies.

### Task 7 — Manual retain/offline metadata shell
- Reader chrome includes a metadata-only retain current chapter action.
- Series Detail chapter rows expose a context-menu retain action.
- Retained state updates cache metadata and marks known chapter rows downloaded.

## Files Changed
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Models/ToonEdgePersistentModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`

## Tests Added
- Update comparison tests for numeric, decimal, non-numeric, unchanged, and missing stored labels.
- Update checker tests for fetcher invocation and unread update mapping.
- Persistence tests for update result state in Home and Library.
- Cache metadata tests for recent counts, retained counts, removal, storage description, and retained chapter state.
- Dependency test for persistent cache-backed Downloads.
- Reader test for recent cache metadata recording.

## Verification
Commands run successfully:

```bash
swift test --jobs 1
```

Result:
- 78 tests passed
- 0 failures

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Result:
- `BUILD SUCCEEDED`

## Known Gaps / Risks
- Cache records are metadata-only. No reader images are downloaded or retained on disk yet.
- Storage usage is estimated metadata, not measured file bytes.
- Update checker contracts exist, but there is no real source page fetcher or scheduler yet.
- Manual retain actions do not present success/error UI.
- SwiftData schema changed with `StoredCacheEntry`; this initial MVP repo has no migration layer yet.
- No interactive simulator smoke test was run.

## Recommended Next Step
Proceed to a hardening slice before broader features:
- add a real but lightweight latest-chapter fetcher for saved series source pages
- add explicit user feedback for retain/remove cache actions
- add cache clearing controls and measured storage when actual files are cached

These are now captured in the canonical epic/story and architecture documents:
- Epic 9 Stories 9.6-9.10 cover lightweight latest-chapter fetching, manual update refresh, cache action feedback, file-backed cache shell, and measured storage accounting.
- Epic 10 Stories 10.5-10.7 cover diagnostics, failure-state QA, and update/cache performance hardening.
- Architecture sections 12 and 13 define the required service boundaries for update fetching, update refresh orchestration, asset caching, storage measurement, and typed cache action results.
