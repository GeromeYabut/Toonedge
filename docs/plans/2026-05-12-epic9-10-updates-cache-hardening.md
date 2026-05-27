# Epic 9/10 Updates and Cache Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the follow-up MVP update/cache hardening slice by adding lightweight real update fetching, manual refresh UI, cache action feedback, file-backed cache shell, measured storage, diagnostics, failure-state tests, and reader-safe performance throttling.

**Architecture:** Keep update fetching, refresh orchestration, cache metadata, file-backed asset caching, and storage measurement behind protocols in `Core/Services`. SwiftUI views may trigger view-model actions but must not read SwiftData models, perform network parsing, write cache files, or measure filesystem state directly. MVP behavior remains foreground-safe and user-initiated; do not add sync, push notifications, catalogs, recommendations, source marketplace behavior, or multi-page stitching.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, URLSession, Foundation file APIs, OSLog-style diagnostics, Swift Testing, existing ToonEdge repository/service protocols.

---

## Context for the Implementing Agent

Read these first:
- `AGENTS.md`
- `docs/toonedge_architecture_doc.md`
- `docs/toonedge_prd.md`
- `docs/toonedge_ux_requirements_doc.md`
- `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-12_epic9_updates_cache.md`

Current relevant files:
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Models/ToonEdgePersistentModels.swift`
- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`

Important constraints:
- Do not implement sync.
- Do not implement push notifications.
- Do not implement recommendations, catalogs, source marketplace, or social features.
- Do not implement multi-page chapter stitching.
- Do not hardcode piracy-oriented catalogs.
- Approved non-promoted sources must not be promoted in suggestions/onboarding/catalog surfaces.
- Keep update checks lightweight and foreground-safe for MVP.

---

## Task 1: Add Latest-Chapter Fetcher Parsing Logic

**Story:** 9.6 — Implement lightweight latest-chapter fetcher

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLLatestChapterFetcher.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Step 1: Write the failing parser tests**

Add tests for:
- parser extracts the highest numeric chapter link from simple HTML
- parser extracts decimal chapter labels
- parser returns `nil` for HTML without chapter-like links
- parser does not require a known catalog/source domain

Example test shape:

```swift
@Test func latestChapterParserExtractsHighestNumericChapterLink() throws {
    let html = """
    <a href="/series/chapter-12">Chapter 12</a>
    <a href="/series/chapter-13">Chapter 13</a>
    """

    let snapshot = HTMLLatestChapterParser.parse(
        html: html,
        baseURL: URL(string: "https://example.com/series")!,
        seriesID: UUID(uuidString: "2A0FE80C-4790-47BD-94BD-900AF539B957")!,
        checkedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    #expect(snapshot?.latestChapterLabel == "13")
    #expect(snapshot?.sourceURL == URL(string: "https://example.com/series/chapter-13")!)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- compile failure because `HTMLLatestChapterParser` does not exist.

**Step 3: Implement minimal parser**

Implement:
- `HTMLLatestChapterParser`
- conservative anchor extraction using Foundation regex
- label normalization that reuses `ChapterUpdateComparison` numeric parsing behavior where practical
- absolute URL resolution using `URL(string:relativeTo:)`

Do not add network yet.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- latest-chapter parser tests pass.

---

## Task 2: Add URLSession Latest-Chapter Fetcher

**Story:** 9.6 — Implement lightweight latest-chapter fetcher

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLLatestChapterFetcher.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Step 1: Write the failing fetcher tests**

Add a mock HTTP client protocol test:
- fetcher asks client for the series canonical URL
- fetcher maps HTML parser result to `SeriesLatestChapterSnapshot`
- fetcher returns `nil` on network failure
- fetcher returns `nil` on non-HTTP URL or invalid response

Use a protocol-driven test double, not real network.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- compile failure for missing concrete fetcher/client types.

**Step 3: Implement minimal fetcher**

Add:
- `HTTPDataLoading` protocol
- `URLSessionHTTPDataLoader`
- `HTMLLatestChapterFetcher: SeriesLatestChapterFetching`

Behavior:
- fetch only `LibrarySeriesSummary` source URL if available from the repository DTO or a new lightweight input DTO
- do not follow chapter image URLs
- return `nil` for failures
- keep errors non-fatal for update refresh orchestration

If `LibrarySeriesSummary` does not carry a canonical URL, add the smallest domain DTO needed for update refresh input instead of overloading UI summary models.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- fetcher tests pass.

---

## Task 3: Add Manual Library Update Refresh Orchestrator

**Story:** 9.7 — Add manual update check action

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/LibraryUpdateRefreshService.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Step 1: Write the failing orchestrator tests**

Add tests for:
- refresh checks all saved series supplied by library snapshot
- refresh persists update results through `recordUpdateCheckResult`
- refresh returns checked count, updated count, failed count
- refresh does not clear existing update state when a fetch fails

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- compile failure for missing refresh service/result types.

**Step 3: Implement minimal orchestration**

Add:
- `LibraryUpdateRefreshResult`
- `LibraryUpdateRefreshing`
- `LibraryUpdateRefreshService`

The service should compose:
- `LibraryProviding`
- `SeriesUpdateChecking`
- `LibraryLifecycleManaging` or a narrower `UpdateStateRecording` protocol if introduced

Keep it sequential for MVP to avoid rate spikes.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- update refresh tests pass.

---

## Task 4: Wire Manual Refresh UI on Home and Library

**Story:** 9.7 — Add manual update check action

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift` if dependency propagation is needed
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`
- Optional Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Step 1: Write the failing dependency test**

Add a test that:
- persistent dependencies expose `LibraryUpdateRefreshing`
- mock dependencies expose a no-op/mock refresh service

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter AppDependenciesTests --jobs 1
```

Expected:
- compile failure until dependency exists.

**Step 3: Implement dependency wiring**

Add:
- `updateRefreshService` to `AppDependencies`
- mock refresh service
- persistent refresh service composed with repository and update checker

**Step 4: Add Home/Library UI shell**

Add:
- refresh button or pull-to-refresh action
- loading state
- success/partial-failure banner or small status text
- snapshot reload after refresh

Do not add background refresh or notifications.

**Step 5: Run tests**

Run:

```bash
swift test --filter AppDependenciesTests --jobs 1
swift test --filter LibraryExperienceTests --jobs 1
```

Expected:
- dependency tests pass
- existing Library tests pass

---

## Task 5: Add Typed Cache Action Results

**Story:** 9.8 — Add cache retain/remove feedback

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`

**Step 1: Write failing result tests**

Add tests for:
- retain returns `.retained`
- repeated retain returns `.unchanged`
- remove existing returns `.removed`
- remove missing returns `.notFound`
- mock and persistent services behave consistently

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- compile failure for missing action result types.

**Step 3: Implement result DTOs**

Add:
- `CacheActionResult`
- optionally `CacheActionStatus`

Update `CacheMetadataManaging` with result-returning methods. Preserve existing methods only if needed for backward compatibility inside the codebase.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- cache action result tests pass.

---

## Task 6: Show Retain/Remove Feedback in Reader, Series Detail, and Downloads

**Story:** 9.8 — Add cache retain/remove feedback

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`

**Step 1: Write failing view-model tests**

Add tests for:
- reader retain action publishes a feedback state
- retain failure publishes non-blocking failure state
- downloads remove action refreshes summary after success

Prefer view-model extraction for Downloads if the view currently owns too much action state.

**Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter ReaderExperienceTests --jobs 1
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- tests fail until feedback state exists.

**Step 3: Implement UI state**

Add lightweight state such as:
- `CacheActionFeedback`
- `@Published var cacheFeedback`
- non-blocking banner/toast in Reader and Downloads

Do not add blocking modals.

**Step 4: Run tests**

Run:

```bash
swift test --filter ReaderExperienceTests --jobs 1
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- feedback tests pass.

---

## Task 7: Add File-Backed Cache Storage Shell

**Story:** 9.9 — Add file-backed cache storage shell

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`

**Step 1: Write failing storage path tests**

Create `CacheStorageTests.swift` with tests for:
- cache maps a source URL to deterministic local chapter directory
- invalid URL characters are sanitized
- missing cached file returns cache miss, not crash
- file-backed cache can be initialized in a temporary test directory

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CacheStorageTests --jobs 1
```

Expected:
- compile failure for missing asset cache types.

**Step 3: Implement storage shell**

Add:
- `ChapterAssetCaching`
- `FileBackedChapterAssetCache`
- deterministic namespace function
- safe no-op/miss behavior

Do not aggressively download images in this task.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter CacheStorageTests --jobs 1
```

Expected:
- storage shell tests pass.

---

## Task 8: Add Measured Storage Accounting

**Story:** 9.10 — Add measured storage accounting

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/CacheStorageMeasurementService.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`

**Step 1: Write failing measurement tests**

Add tests for:
- measured bytes are preferred when files exist
- estimated bytes are used when files are missing
- removing cache updates measured summary
- measurement ignores unrelated files outside cache namespace

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CacheStorageTests --jobs 1
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- compile or assertion failure until measurement service exists.

**Step 3: Implement measurement service**

Add:
- `CacheStorageMeasuring`
- `CacheStorageMeasurementService`
- summary integration that avoids filesystem work in SwiftData models

Downloads should display measured storage if available and retain the current human-readable formatting.

**Step 4: Run tests**

Run:

```bash
swift test --filter CacheStorageTests --jobs 1
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- storage measurement tests pass.

---

## Task 9: Add Update and Cache Diagnostics

**Story:** 10.5 — Update/cache diagnostics pass

**Files:**
- Create: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/UpdateCacheDiagnosticsLogger.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/LibraryUpdateRefreshService.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`

**Step 1: Write failing diagnostics tests**

Add tests using a recording logger for:
- update refresh logs checked, updated, and failed counts
- latest-chapter fetch logs parser path without full URL
- cache remove failure logs operation and sanitized source identity

**Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
swift test --filter CacheStorageTests --jobs 1
```

Expected:
- failure until diagnostics logger exists.

**Step 3: Implement diagnostics logger**

Add:
- `UpdateCacheDiagnosticsLogging`
- default OSLog-backed logger or simple no-op if OSLog is not practical in package tests
- recording test double in tests

Sanitize URLs by logging host and a stable hash/path summary, not full URLs.

**Step 4: Run tests**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
swift test --filter CacheStorageTests --jobs 1
```

Expected:
- diagnostics tests pass.

---

## Task 10: Add Failure-State QA Coverage

**Story:** 10.6 — Update/cache failure-state QA

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`
- Modify implementation files only if tests reveal gaps

**Step 1: Add failing/edge-case tests**

Add tests for:
- failed latest-chapter fetch does not clear stored unread update flag
- missing latest label does not create false update
- invalid latest label maps to conservative changed/unknown result only when appropriate
- metadata exists but backing file missing is surfaced as repairable/missing
- remove failure produces retryable UI/service state

**Step 2: Run tests**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
swift test --filter CacheMetadataTests --jobs 1
swift test --filter CacheStorageTests --jobs 1
```

Expected:
- tests fail for any missing failure behavior.

**Step 3: Implement minimal fixes**

Keep fixes scoped to:
- typed results
- safe no-op behavior
- preserving existing update/cache state on partial failure

**Step 4: Run tests**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
swift test --filter CacheMetadataTests --jobs 1
swift test --filter CacheStorageTests --jobs 1
```

Expected:
- failure-state tests pass.

---

## Task 11: Add Reader-Safe Cache Write Throttling

**Story:** 10.7 — Storage and reader performance pass

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`

**Step 1: Write failing throttling test**

Add a test that:
- calls `updateProgress(visibleImageIndex:)` repeatedly for adjacent images
- verifies cache metadata recording is not invoked for every single call
- verifies final visible progress is still saved

Use a recording cache metadata manager.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ReaderExperienceTests --jobs 1
```

Expected:
- assertion failure because current reader path records too often.

**Step 3: Implement minimal throttling**

Options:
- record cache metadata once per session after restore
- or record only when source URL changes / retention state changes

Do not throttle critical progress persistence so aggressively that resume behavior becomes stale.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter ReaderExperienceTests --jobs 1
```

Expected:
- throttling test and existing reader tests pass.

---

## Task 12: Add Large-Collection Cache Summary Performance Guard

**Story:** 10.7 — Storage and reader performance pass

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift` only if needed

**Step 1: Write performance-oriented correctness test**

Add a test that:
- inserts at least 1,000 cache metadata entries with `usesModelContextIO: false`
- calls `downloadSummary()`
- verifies counts and storage totals are correct

Avoid brittle wall-clock assertions.

**Step 2: Run test**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- test passes or exposes inefficient/incorrect aggregation.

**Step 3: Optimize only if needed**

If needed, keep optimization simple:
- avoid repeated full scans inside loops
- aggregate in one pass
- keep sorting out of summary calculations

**Step 4: Run test**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- large summary test passes.

---

## Task 13: Final Verification and Notes

**Files:**
- All touched files
- Create: `docs/session_notes_YYYY-MM-DD_epic9_10_updates_cache_hardening.md`

**Step 1: Run full Swift package tests**

Run:

```bash
swift test --jobs 1
```

Expected:
- all tests pass.

**Step 2: Run app target build**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Expected:
- `BUILD SUCCEEDED`

**Step 3: Update session notes**

Create session notes with:
- stories completed
- files changed
- verification results
- known gaps
- next handoff

---

## Definition of Done

This follow-up slice is done when:
- Epic 9 Stories 9.6-9.10 have implementation coverage or explicit documented deferral
- Epic 10 Stories 10.5-10.7 have tests/diagnostics/performance guards
- update refresh remains foreground-safe and MVP-scoped
- cache actions provide visible feedback
- cache metadata, file storage, and storage measurement remain separate services
- no sync, push, recommendations, catalogs, source marketplace, social features, or multi-page stitching are introduced
- `swift test --jobs 1` passes
- app target builds with `xcodebuild`
