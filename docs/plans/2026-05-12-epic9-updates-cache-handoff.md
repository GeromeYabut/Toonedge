# Epic 9 Updates and Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement MVP update awareness and local cache metadata for ToonEdge without adding sync, recommendations, source marketplace behavior, push notifications, or multi-page stitching.

**Architecture:** Extend the existing protocol-backed persistence architecture from Epic 8. Keep update-checking, cache metadata, and UI presentation behind service/repository interfaces; do not let SwiftUI views directly read SwiftData models. Use small domain DTOs and mapping methods from repository models into Home, Library, Series Detail, and Downloads.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, existing ToonEdge feature modules and repository protocols.

---

## Context for the Implementing Agent

Read these first:
- `AGENTS.md`
- `docs/toonedge_architecture_doc.md`
- `docs/toonedge_prd.md`
- `docs/toonedge_ux_requirements_doc.md`
- `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-12_epic8_persistence_lifecycle.md`

Current relevant files:
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Models/ToonEdgePersistentModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

Important constraints:
- Do not implement sync.
- Do not implement push notifications.
- Do not implement recommendations, catalogs, social/community features, or source marketplace behavior.
- Do not implement multi-page chapter stitching.
- Do not hardcode piracy-oriented catalogs.
- Approved non-promoted sources must not be promoted in suggestions/onboarding/catalog surfaces.
- Keep update checks lightweight and user-initiated / foreground-safe for MVP.

Important technical note:
- App runtime uses SwiftData I/O through `AppDependencies.persistent()`.
- SwiftPM tests for repository lifecycle use `usesModelContextIO: false` because direct SwiftData `ModelContext` I/O traps in this CLI environment.
- Continue using that test pattern unless the environment changes.

---

## Task 1: Add Update Comparison Domain Logic

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Step 1: Write failing tests**

Create `UpdateCheckTests.swift` with tests for:
- numeric chapter labels compare by number
- decimal chapter labels compare by number
- non-numeric labels compare by normalized string only when changed
- same latest label does not mark update available
- missing stored label marks update available when fetched label exists

Example test shape:

```swift
import Testing
@testable import ToonEdgeAppCore

@Test func updateComparisonDetectsNewerNumericChapter() {
    let result = ChapterUpdateComparison.compare(storedLatest: "12", fetchedLatest: "13")

    #expect(result == .newerAvailable)
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- compile failure because `ChapterUpdateComparison` does not exist.

**Step 3: Implement minimal domain logic**

Add:
- `ChapterUpdateComparisonResult`
- `ChapterUpdateComparison.compare(storedLatest:fetchedLatest:)`

Keep parsing conservative:
- trim whitespace
- extract first number/decimal when present
- numeric comparison only when both labels contain parseable numbers
- string comparison only detects changed/unknown, not ordering

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- all update comparison tests pass.

---

## Task 2: Add Update Check Service Protocol and Mock Fetcher

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Step 1: Write failing tests**

Add tests for:
- an update checker asks a fetcher for latest chapter metadata
- service maps newer fetched chapter to `hasUnreadUpdates == true`
- same fetched chapter keeps `hasUnreadUpdates == false`

Use a protocol-driven mock, not network.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- compile failure for missing update-checking types.

**Step 3: Implement protocols and mock service**

Add protocols:
- `SeriesUpdateChecking`
- `SeriesLatestChapterFetching`

Add DTO:
- `SeriesLatestChapterSnapshot`

Implementation should not fetch real web pages yet. Use a mock fetcher for deterministic tests.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter UpdateCheckTests --jobs 1
```

Expected:
- update checker tests pass.

---

## Task 3: Persist Update State in Repository

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Step 1: Write failing tests**

Add tests for:
- marking update available sets `hasUnreadUpdates`
- latest known chapter label updates
- updated series appears in `homeSnapshot().recentlyUpdated`
- updated series appears in Recent segment even without `lastReadAt`

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PersistenceLifecycleTests --jobs 1
```

Expected:
- compile failure for missing repository update-state API.

**Step 3: Implement repository API**

Add to protocol:
- `recordUpdateCheckResult(seriesID:latestChapterLabel:hasUnreadUpdates:checkedAt:)`

Implement in `SwiftDataLibraryRepository`.

Keep fields minimal:
- `latestKnownChapterLabel`
- `hasUnreadUpdates`
- `updatedAt`

Do not add background refresh or notifications.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter PersistenceLifecycleTests --jobs 1
```

Expected:
- persistence lifecycle tests pass.

---

## Task 4: Add Cache Metadata Domain and Persistence

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Models/ToonEdgePersistentModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`

**Step 1: Write failing tests**

Create tests for:
- recording a recently opened chapter cache entry increments cached item count
- retained/manual download metadata is represented separately from recent cache
- removing cache metadata removes it from download summary
- storage description is stable and human-readable

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- compile failure for missing cache metadata types.

**Step 3: Implement minimal cache metadata**

Add:
- `CacheRetentionState` with `.recent` and `.retained`
- `CacheMetadataInput`
- `CacheMetadataEntry`
- `CacheMetadataManaging`

Add SwiftData model:
- `StoredCacheEntry`

Repository behavior:
- record/update cache entry
- remove cache entry
- produce `DownloadSummary`

Do not download images yet unless explicitly needed by the story. Epic 9 MVP can track metadata first.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- cache metadata tests pass.

---

## Task 5: Wire Downloads Screen to Cache Metadata

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- Test: existing tests plus optional `DownloadsExperienceTests.swift`

**Step 1: Write failing test**

Add a test that persistent dependencies expose a download/cache provider backed by the same repository or an explicit cache repository.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter AppDependenciesTests --jobs 1
```

Expected:
- failure until dependencies expose the cache-backed download service.

**Step 3: Implement dependency wiring**

Update persistent dependencies so Downloads uses cache metadata service instead of the mock download service.

Update `DownloadsView` only as much as needed to show:
- cached item count
- storage description
- empty state

Keep it utility-focused.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter AppDependenciesTests --jobs 1
```

Expected:
- dependencies tests pass.

---

## Task 6: Record Recent Cache Metadata from Reader Progress

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`

**Step 1: Write failing test**

Add a test that when reader progress is saved for a known session, cache metadata is recorded as recent.

Prefer injecting a `CacheMetadataManaging` test double into `ReaderViewModel` if practical.

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ReaderExperienceTests --jobs 1
```

Expected:
- compile failure or assertion failure until cache metadata dependency exists.

**Step 3: Implement minimal wiring**

When progress updates after restore:
- save reader progress as before
- record recent cache metadata for the source URL/session

Do not download images or retain offline content automatically.

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter ReaderExperienceTests --jobs 1
```

Expected:
- reader tests pass.

---

## Task 7: Add Manual Retain/Download Metadata Action Shell

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`

**Step 1: Write failing test**

Add a repository/cache test:
- marking a chapter retained changes its retention state to `.retained`
- `DownloadSummary` counts retained entries

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- failure until retention update API exists.

**Step 3: Implement shell**

Add action points:
- Series Detail chapter row/menu: retain chapter
- Reader chrome: retain current chapter

Behavior:
- update metadata only
- no network image download yet unless already available in the reader payload

**Step 4: Run test to verify pass**

Run:

```bash
swift test --filter CacheMetadataTests --jobs 1
```

Expected:
- retention metadata tests pass.

---

## Task 8: Final Verification

**Files:**
- All touched files

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

Note:
- In the current environment, SwiftData macro expansion may require running `xcodebuild` outside sandbox.

**Step 3: Update session notes**

Create:
- `docs/session_notes_YYYY-MM-DD_epic9_updates_cache.md`

Include:
- stories completed
- files changed
- verification results
- known gaps
- next epic handoff

---

## Definition of Done for Epic 9

Epic 9 is done when:
- update comparison logic is tested
- update-check service contracts exist
- repository can persist update check results
- Home/Library can surface unread update state from stored fields
- cache metadata is persisted locally
- Downloads screen reads cache/download summary from local metadata
- reader can record recent cache metadata
- manual retained/offline metadata shell exists if included in this slice
- no sync, push, source marketplace, or multi-page stitching is introduced
- `swift test --jobs 1` passes
- app target builds with `xcodebuild`
