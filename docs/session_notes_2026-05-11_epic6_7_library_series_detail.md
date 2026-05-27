# ToonEdge Session Notes — 2026-05-11 — Epic 6/7 Series Detail and Library

## Session Goal
Implement the mock-backed Series Detail experience from Epic 6 and the Library / collection-management experience from Epic 7:
- Series Detail header and progress-aware primary CTA
- chapter list with explicit row states
- chapter row state system for New, Unread, In Progress, Read, and Downloaded
- Library screen shell
- segmented Library states: Recent, Reading, Planned
- reusable progress-aware series cards with badges
- missing-cover fallback

Persistence, real follow/save state, update checks, and real download/cache behavior were intentionally left for later epics.

## Repo Guidance
- Follow root `AGENTS.md`.
- Use docs in this priority order:
  1. Architecture for technical boundaries and module ownership
  2. PRD for product scope and MVP boundaries
  3. UX requirements for user-facing behavior and interaction states
  4. UX brief for intent and visual direction
  5. Epics/stories for delivery sequence
- UX requirements remain the behavioral source of truth unless they conflict with PRD scope.
- Library is a first-class collection-management surface, not a passive saved-items list.
- Series Detail should prioritize chapter utility over decorative presentation.

## Key Documents Read
- `docs/prd.md` and canonical `docs/toonedge_prd.md`
- `docs/ux-brief.md` and canonical `docs/toonedge_ux_brief.md`
- `docs/ux-requirements.md` and canonical `docs/toonedge_ux_requirements_doc.md`
- `docs/architecture.md` and canonical `docs/toonedge_architecture_doc.md`
- `docs/epics-and-stories.md` and canonical `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-11_epic4_detection_engine.md`

## Requirement Notes / Scope Decisions
- This was implemented as a mock-backed vertical slice to unblock UI and repository contracts before SwiftData persistence.
- `LibraryProviding` remains the repository-facing abstraction used by Home, Library, and Series Detail.
- `Recent` is currently derived from `lastReadAt` and unread updates, not stored as its own collection state.
- `Downloaded` is modeled as an orthogonal chapter property (`ChapterSummary.isDownloaded`), not as a read-status replacement.
- Chapter row visual styling does not rely on opacity alone; rows use labels, icons, background treatment, and downloaded indicator.
- The Series Detail primary CTA logic lives in `SeriesDetailSnapshot`, not in SwiftUI.
- Library segmentation and chapter sorting live in domain models, not in SwiftUI.
- The UI still owns presentation-only mappings such as row color/icon choices and banner copy.

## Stories Implemented
Epic 6:

1. Story 6.1 — Implement series detail header
   - `SeriesDetailView` shows cover/fallback, title, status, saved state, source/metadata, synopsis, and primary CTA.
   - `SeriesDetailSnapshot.primaryActionTitle` and `primaryChapter` compute progress-aware CTA behavior.
   - CTA opens a mock reader session for the selected chapter.

2. Story 6.2 — Implement chapter list
   - Series Detail renders chapters from `SeriesDetailSnapshot`.
   - `ChapterListSort` supports newest-first and oldest-first sorting.
   - Chapter rows are tappable and open mock reader sessions.
   - Loading, empty, and unavailable/error states are represented with `TEBanner`.

3. Story 6.3 — Implement chapter row state system
   - Added `ChapterReadState` with:
     - `new`
     - `unread`
     - `inProgress(progressPercent:)`
     - `read`
   - Added `ChapterSummary.isDownloaded` and `downloadLabel`.
   - `ChapterRow` shows state chip, state icon, state color, row background, and downloaded icon.

4. Story 6.4 — Implement chapter utilities
   - Added chapter sort segmented control.
   - Added save/follow state representation.
   - Added downloaded indicator/action shell; real downloads are deferred to Epic 9.

Epic 7:

1. Story 7.1 — Implement library data model changes
   - Added collection metadata to `LibrarySeriesSummary`:
     - `progressPercent`
     - `chaptersRead`
     - `totalKnownChapters`
     - `lastReadAt`
     - `libraryState`
     - `hasUnreadUpdates`
     - `isCompleted`
     - `latestChapterLabel`
     - `currentChapterLabel`
   - Repository interface now exposes `librarySnapshot()` and `seriesDetail(for:)`.

2. Story 7.2 — Implement Library screen shell
   - Replaced placeholder Library scaffold with a top bar, filter affordance shell, segmented control, summary banner, and grid.

3. Story 7.3 — Implement segmented Library states
   - Added `LibrarySegment`: `recent`, `reading`, `planned`.
   - `LibrarySnapshot.series(for:)` filters/sorts visible content.
   - Segment switching updates visible grid content.

4. Story 7.4 — Implement series card component
   - Added reusable `SeriesCard`.
   - Card supports title, cover, last/current reading metadata, progress bar, update badge, chapter badge, and completion badge.

5. Story 7.5 — Implement card badge and state system
   - Cards support New badge, completion badge, latest chapter badge, and missing-cover fallback.

6. Story 7.6 — Implement Library filtering and sorting shell
   - Filter affordance exists in the Library header.
   - Real filter/sort state expansion is deferred.

7. Story 7.7 — Implement library navigation behaviors
   - Tapping a Library card opens Series Detail through `NavigationStack`.
   - Segment changes keep navigation stable because card navigation uses series IDs.

## Files Changed
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Added `LibrarySegment`, `LibraryCollectionState`, `LibrarySeriesSummary`, `LibrarySnapshot`.
  - Added `ChapterListSort`, `ChapterReadState`, `ChapterSummary`, `SeriesDetailSnapshot`.
  - Added model-owned helpers for segmentation, chapter sorting, primary CTA selection, and display labels.

- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
  - Extended `LibraryProviding` with:
    - `librarySnapshot() async -> LibrarySnapshot`
    - `seriesDetail(for:) async -> SeriesDetailSnapshot?`

- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
  - Reworked `MockLibraryService` to provide shared mock library data.
  - Added mock details for:
    - `Moonlit Edge`
    - `Signal Tower`
    - `Glass Harbor`
    - `North Star Courier`
  - Added deterministic chapter data and read/download states.
  - Updated `homeSnapshot()` to derive Home data from the same library mock source.

- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Replaced the Library placeholder.
  - Added Library shell, segmented grid, summary banner, reusable `SeriesCard`, `MissingCoverView`, `SeriesDetailView`, and `ChapterRow`.

- `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Added tests for:
    - Library segmentation
    - Series Detail primary CTA selection
    - chapter sorting
    - chapter row state labels and downloaded label

- `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`
  - Updated mock library count expectation from 3 to 4.

## Current UX State
Verified complete:
- Library tab now shows segmented Recent / Reading / Planned states.
- Library cards show progress, metadata, update/completion/chapter badges, and cover fallback.
- Tapping a Library card opens Series Detail.
- Series Detail shows title, status, synopsis, saved state, progress-aware CTA, chapter sort, and chapter rows.
- Chapter rows represent New, Unread, In Progress, Read, and Downloaded states.
- CTA and chapter row taps open mock reader sessions.

## Epic 6/7 Completion Checklist
- Series Detail header: complete
- progress-aware primary CTA: complete
- chapter list: complete
- chapter sorting: complete
- chapter row states: complete
- downloaded state indicator: complete as shell
- Library screen shell: complete
- Recent / Reading / Planned segments: complete
- reusable progress-aware cards: complete
- card badges: complete
- missing-cover fallback: complete
- mock-backed repository contracts: complete

## Verification
Commands run successfully:

```bash
swift test --filter LibraryExperienceTests --jobs 1
```

Result:
- 5 Library experience tests passed
- 0 failures

```bash
swift test --jobs 1
```

Result:
- 55 tests passed
- 0 failures

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Result:
- `BUILD SUCCEEDED`
- The sandboxed environment printed CoreSimulator service warnings, but the app target compiled and linked successfully.

## Scope Guardrails Observed
Not implemented:
- SwiftData-backed series/chapter persistence
- add/remove library lifecycle
- real follow/save mutations
- real collection state transitions
- real continue-reading restoration from persisted chapter/progress state
- real recent activity writes
- real update checks
- real download/cache behavior
- UI automation for Library → Series Detail → Reader
- multi-page chapter stitching
- cloud sync
- recommendations/social/community features

## Known Gaps / Risks
- Persistence remains mock-backed. `MockLibraryService` should be replaced by SwiftData-backed repository implementations during Epic 8.
- `MockReaderSession` is still used when opening chapters from Series Detail. Epic 8 should either introduce a real `ReaderSession` / chapter payload path or keep a compatibility adapter while persistence stabilizes.
- The current `ReaderProgressStoring` keys progress by source URL. Epic 8 should decide whether persisted progress is keyed by `Chapter.id`, source URL, or both for migration/compatibility.
- `LibrarySnapshot.series(for:)` currently derives Recent from `lastReadAt` and unread updates. If the product later needs a distinct persisted Recent segment, that should be modeled explicitly.
- Follow/save and filter buttons are shells. They should not be wired to UI-local state; they should call repository methods once Epic 8 APIs exist.
- Downloaded state is an indicator only. Real retained/offline state belongs to Epic 9.
- `SeriesCard`, `SeriesDetailView`, and `ChapterRow` are currently private in `LibraryView.swift`. If Home should reuse `SeriesCard`, consider moving it into `Features/Library/Components` or `SharedUI`.
- Mock series/chapter content uses `example.com` and generated image URLs. Do not treat these as real source support.

## Epic 8 Handoff
Proceed to Epic 8 — Persistence, Follow State, and Reading Lifecycle.

Suggested first slice:
1. Re-read:
   - `docs/toonedge_architecture_doc.md`, especially Library / Persistence / Repository sections.
   - `docs/toonedge_prd.md`, sections 8.6, 8.7, 8.8, and 15.
   - `docs/toonedge_ux_requirements_doc.md`, sections 4.6 and 4.7.
   - `docs/toonedge_epics_and_stories.md`, Epic 8 stories.
   - this handoff.
2. Start with Story 8.1:
   - Add SwiftData models for Series, Chapter, Progress, and SearchHistory where appropriate.
   - Preserve existing app-facing structs (`LibrarySnapshot`, `LibrarySeriesSummary`, `SeriesDetailSnapshot`, `ChapterSummary`) as view/domain DTOs unless there is a compelling reason to rename.
   - Implement repository mapping from SwiftData models to existing DTOs.
   - Keep `LibraryProviding` as the app-facing protocol or split write operations into a separate lifecycle protocol if cleaner.
3. Add tests before implementation:
   - persisted series appears in `librarySnapshot()`
   - persisted chapters appear in `seriesDetail(for:)`
   - reading progress updates `ChapterReadState`
   - collection state transitions move series between Reading and Planned
   - recent activity updates `lastReadAt` and affects Recent segment
4. Then proceed to Stories 8.2–8.5:
   - add-to-library flow
   - state transitions
   - continue-reading restoration
   - recent activity metadata

## Recommended Next Agent Start Prompt
Implement Epic 8 — Persistence, Follow State, and Reading Lifecycle.

Read:
- `docs/toonedge_architecture_doc.md`
- `docs/toonedge_prd.md`
- `docs/toonedge_ux_requirements_doc.md`
- `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-11_epic6_7_library_series_detail.md`

Start with Story 8.1. Preserve the current `LibraryProviding` app-facing contract where practical, replace mock internals with SwiftData-backed repositories, and add tests for persisted library snapshots, series detail snapshots, progress mapping, and collection state transitions.
