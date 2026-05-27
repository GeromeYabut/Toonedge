# Session Notes: Epic 9/10 Updates and Cache Hardening

Date: 2026-05-14

## Scope

Implemented the Epic 9/10 hardening follow-up from `docs/plans/2026-05-12-epic9-10-updates-cache-hardening.md`.

- Lightweight, source-agnostic latest-chapter fetcher for saved series canonical URLs.
- Manual update refresh actions on Home and Library.
- Typed cache retain/remove feedback in Reader, Series Detail, and Downloads.
- File-backed cache storage shell with deterministic chapter/source paths.
- Measured storage accounting with metadata fallback.
- Update/cache diagnostics hooks without full source URL logging.
- Failure-state QA coverage for fetch failures, missing files, remove failures, and parser misses.
- Reader-safe cache metadata write throttling.
- Large cache summary performance guard.

## Files Touched

- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLLatestChapterFetcher.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/LibraryUpdateRefreshService.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/CacheStorageMeasurementService.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/UpdateCacheDiagnosticsLogger.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- `app/ToonEdge.xcodeproj/project.pbxproj`
- `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`

## Data Model Notes

- `LibrarySeriesSummary` now carries optional `canonicalURL`.
- SwiftData repository maps canonical URLs from existing persisted series records.
- Cache metadata APIs now return typed `CacheActionResult` values.
- No new SwiftData model entity was added, but API behavior changed around cache action results.
- A production migration plan is still needed before shipping if existing persistent store compatibility becomes stricter.

## Known Gaps

- Latest-chapter fetching is intentionally generic and HTML-only. It does not implement source-specific profiles, authenticated flows, JavaScript rendering, catalogs, marketplace behavior, or recommendations.
- File-backed cache storage is a shell for local paths and measured accounting. It does not perform aggressive chapter downloads.
- Update refresh remains manual and foreground-scoped. No background sync, push notifications, or scheduled polling were added.
- Multi-page chapter stitching remains out of scope.

## Verification

- `swift test --jobs 1` passed: 113 tests.
- `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO` passed.

## Recommended Next Step

Run a short simulator QA pass through Home manual refresh, Library refresh, Reader retain feedback, Downloads remove feedback, and measured storage display using a seeded local library.
