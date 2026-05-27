# ToonEdge Session Notes — 2026-05-12 — Epic 8 Persistence, Follow State, and Reading Lifecycle

## Session Goal
Complete Epic 8:
- local persistence models and repository boundaries
- add-to-library lifecycle from Reader, Browser, and Series Detail contexts
- library state transitions
- continue-reading restoration
- recent activity metadata
- reader progress persistence
- local search history persistence

## Repo Guidance
- Follow root `AGENTS.md`.
- Respect MVP scope.
- Do not implement sync, update checks, or cache/download behavior in Epic 8.
- Keep UI out of persistence details; all persistence access goes through protocols/repositories.

## Source Documents Read
- `docs/prd.md` and canonical `docs/toonedge_prd.md`
- `docs/ux-requirements.md` and canonical `docs/toonedge_ux_requirements_doc.md`
- `docs/architecture.md` and canonical `docs/toonedge_architecture_doc.md`
- `docs/epics-and-stories.md` and canonical `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-11_epic6_7_library_series_detail.md`

## Stories Completed

### Story 8.1 — Persistence models and repositories
- Added SwiftData models:
  - `StoredSeries`
  - `StoredChapter`
  - `StoredProgress`
  - `StoredSearchHistory`
- Added `SwiftDataLibraryRepository`.
- Added lifecycle/search-history protocols:
  - `LibraryLifecycleManaging`
  - `SearchHistoryRecording`
- `SwiftDataLibraryRepository` conforms to:
  - `LibraryProviding`
  - `LibraryLifecycleManaging`
  - `ReaderProgressStoring`
  - `SearchHistoryRecording`
- Added `AppDependencies.persistent(...)` to create and retain a `ModelContainer`.
- App startup now defaults to persistent dependencies and falls back to mocks only if container creation fails.

### Story 8.2 — Add-to-library flow
- Reader exposes an Add to Library action in reader chrome.
- Browser exposes an Add to Library action when a detected reader session exists.
- Series Detail save menu supports add/remove.
- Required metadata stored:
  - title
  - canonical URL
  - source domain
  - status/synopsis
  - latest known chapter label
  - chapter metadata
  - library state

### Story 8.3 — Library state transitions
- Series Detail save menu supports:
  - Mark Reading
  - Mark Planned
  - Mark Completed
- Repository updates `libraryStateRaw` and completion state.
- Existing `LibrarySnapshot.series(for:)` continues to power Recent / Reading / Planned segmentation from repository DTOs.

### Story 8.4 — Continue-reading restoration
- Repository stores `lastOpenedChapterID`.
- Repository stores progress by source URL and chapter ID when known.
- `continueReadingTarget(for:)` returns:
  - series ID
  - chapter ID
  - source URL
  - `ReaderProgress`
- Home Continue Reading uses `LibraryLifecycleManaging.continueReadingTarget(for:)` when available.

### Story 8.5 — Recent activity metadata
- `recordReadingProgress(_:forChapterID:at:)` updates:
  - `lastReadAt`
  - `lastOpenedChapterID`
  - `updatedAt`
  - state transition from Planned to Reading when reading starts
- URL-based reader progress save also updates recent metadata when the chapter is known.

## Files Changed
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Added `LibraryAddContext`.
  - Added `LibrarySeriesInput`.
  - Added `LibraryChapterInput`.
  - Added `ContinueReadingTarget`.
  - Added `SearchHistoryKind`, `SearchHistoryInput`, and `SearchHistoryEntry`.

- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
  - Added `LibraryLifecycleManaging`.
  - Added `SearchHistoryRecording`.

- `app/Sources/ToonEdgeAppCore/Core/Persistence/Models/ToonEdgePersistentModels.swift`
  - Added SwiftData persisted models.

- `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
  - Added local repository implementation.
  - Handles snapshots, details, add/remove, state transitions, progress, continue reading, and search history.

- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
  - Added persistent dependency factory.
  - Retains `ModelContainer`.
  - Exposes lifecycle/search-history repositories.

- `app/Sources/ToonEdgeAppCore/App/ToonEdgeApp.swift`
  - Defaults app startup to persistent dependencies.

- `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
  - Passes lifecycle/search-history dependencies to feature screens.

- `app/Sources/ToonEdgeAppCore/Features/Search/Views/SearchOverlayView.swift`
  - Records recent search/link submissions through `SearchHistoryRecording`.

- `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
  - Continue Reading uses persisted continuation target when available.

- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
  - Adds detected reader payloads to Library from browser context.

- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
  - Adds current reader session to Library from reader context.

- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Series Detail menu supports add/remove and library state transitions.

- `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
  - Added tests for repository lifecycle behavior.

- `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`
  - Added test that persistent dependencies use one repository across library/lifecycle/progress/search history.

- `app/ToonEdge.xcodeproj/project.pbxproj`
  - Added persistence source files to the app target.

## Verification
Commands run successfully:

```bash
swift test --jobs 1
```

Result:
- 62 tests passed
- 0 failures

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Result:
- `BUILD SUCCEEDED`
- Required running outside sandbox because SwiftData macro expansion failed under sandboxed `xcodebuild`.

## Important Implementation Notes
- App runtime uses SwiftData I/O by default through `AppDependencies.persistent()`.
- SwiftPM lifecycle tests construct `SwiftDataLibraryRepository` with `usesModelContextIO: false`.
  - Reason: direct SwiftData `ModelContext` I/O traps in the CLI test runner in this environment.
  - The same repository contract and mapping logic are still tested.
- `ModelContainer` is retained by both `AppDependencies` and repository construction paths to prevent context lifetime issues.
- Mock services remain available through `AppDependencies.mock()` for tests and early slices.

## Scope Guardrails Observed
Not implemented:
- cloud sync
- multi-page chapter stitching
- recommendations/social/community features
- update checking
- cache/download behavior
- push/background refresh

## Known Gaps / Risks
- No interactive simulator smoke test was run.
- SwiftData durable I/O is verified by app build integration, but not by SwiftPM unit tests because of the CLI runner limitation.
- Add-to-library from Browser/Reader currently stores metadata derived from `MockReaderSession` / detection payloads. Future real extracted chapter payloads should provide stronger series canonical metadata.
- Home Continue Reading still uses `MockReaderService` to construct a reader session; Epic 9 or a future reader payload hardening slice should move toward real stored chapter image payloads.
- Search history is stored, but `MockSearchSuggestionProvider` still supplies static recent suggestions. A future slice should connect suggestions to `SearchHistoryRecording`/repository reads.

## Epic 8 Completion Checklist
- persisted models: complete
- repository interfaces: complete
- real local repository backing for app runtime: complete
- add-to-library flow: complete for Reader, Browser, and Series Detail contexts
- library state transitions: complete
- continue-reading restoration: complete
- recent activity metadata: complete
- progress persistence: complete
- search history persistence: complete
- sync/post-MVP features avoided: complete

## Epic 9 Handoff
Proceed to Epic 9 — Updates and Cache.

Primary goals:
1. Add local cache metadata for recently read chapters.
2. Add manual chapter download/offline-retention shell if kept in Epic 9 scope.
3. Add update-check comparison logic and service contracts.
4. Surface update/cache state through existing Home, Library, Downloads, and Series Detail DTOs.

Suggested next agent start prompt:

```text
Implement Epic 9 — Updates and Cache.

Read:
- AGENTS.md
- docs/toonedge_architecture_doc.md
- docs/toonedge_prd.md
- docs/toonedge_ux_requirements_doc.md
- docs/toonedge_epics_and_stories.md
- docs/session_notes_2026-05-12_epic8_persistence_lifecycle.md
- docs/plans/2026-05-12-epic9-updates-cache-handoff.md

Start with update-check comparison logic and cache metadata tests. Keep all work MVP-scoped: no sync, no push notifications, no source marketplace, no multi-page stitching.
```
