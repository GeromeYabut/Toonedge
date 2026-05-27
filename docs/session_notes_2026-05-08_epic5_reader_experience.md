# ToonEdge Session Notes — 2026-05-08 — Epic 5 Reader Experience

## Session Goal
Complete the Epic 5 reader experience using mock extracted chapter payloads:
- vertical image-strip reader
- reader chrome show/hide
- reader progress UI
- reader settings
- explicit “View Original Page” action shell
- previous/next chapter shell using mock chapter links
- reader progress save/restore

Real detection, real DOM extraction, and multi-page chapter stitching were explicitly out of scope.

## Repo Guidance
- Follow root `AGENTS.md`.
- Use docs in this priority order:
  1. Architecture for technical boundaries and module ownership
  2. PRD for product scope and MVP boundaries
  3. UX requirements for user-facing behavior and interaction states
  4. UX brief for intent and visual direction
  5. Epics/stories for delivery sequence
- UX requirements are the behavioral source of truth unless they conflict with PRD scope.
- Reader work must preserve the user’s route back to the original browser page.

## Key Documents Read
- `docs/prd.md` and canonical `docs/toonedge_prd.md`
- `docs/ux-brief.md` and canonical `docs/toonedge_ux_brief.md`
- `docs/ux-requirements.md` and canonical `docs/toonedge_ux_requirements_doc.md`
- `docs/architecture.md` and canonical `docs/toonedge_architecture_doc.md`
- `docs/epics-and-stories.md` and canonical `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-08_epic3_browser_experience.md`

## Requirement Notes / Scope Decisions
- Epic 5 was implemented as a mock-backed reader slice because Epic 4 detection/extraction is still incomplete.
- Reader consumes `MockReaderSession` for now. This shape intentionally mirrors a future extracted chapter payload: series title, chapter title, source URL, ordered image URLs, previous chapter link, next chapter link, and reader settings.
- Progress persistence is protocol-backed. The current app dependency uses a small `UserDefaultsReaderProgressRepository` bridge so progress survives app relaunch before the broader SwiftData persistence layer is implemented.
- Progress is saved by source URL. This is sufficient for the mock slice, but the future SwiftData implementation should key progress by stable chapter identity once real `Chapter` persistence exists.
- `fitScreen` is currently a display mode in the vertical scroll reader, not a paged reader mode. The UX docs require the setting but do not define one-image-per-viewport behavior.
- Brightness aid is implemented as an in-reader dim overlay, not a system brightness mutation.

## Stories Implemented
Epic 5:

1. Story 5.1 — Build reader image strip rendering
   - Added `ReaderView`.
   - Renders the session image URL list in vertical order using `ScrollView` + `LazyVStack`.
   - Uses `AsyncImage` with placeholder/failure panels.

2. Story 5.2 — Implement reader chrome and controls
   - Reader starts with chrome hidden.
   - Tapping the reading surface toggles chrome visibility.
   - Chrome shows series title, chapter title, settings entry, previous/next actions, explicit original-page action, and progress.
   - Chrome avoids prominent ToonEdge/product branding.

3. Story 5.3 — Implement reader settings
   - Added `ReaderSettingsView`.
   - Supports fit width / fit screen, page spacing toggle, brightness aid slider, and canvas options.

4. Story 5.4 — Implement “View Original Page”
   - Reader exposes explicit `View Original Page`.
   - Action calls `AppRouter.viewOriginalPage()`.
   - If a browser is already presented behind Reader, Reader dismisses and preserves that browser state.
   - If no browser is present, the router opens the reader source URL in Browser.

5. Story 5.5 — Implement previous/next chapter shell
   - `MockReaderSession` includes `previousChapter` and `nextChapter`.
   - Reader has previous/next controls.
   - Unavailable links disable gracefully through `ReaderViewModel.canNavigatePrevious` / `canNavigateNext`.
   - Navigation replaces the current reader session with another mock session from `MockReaderService`.

6. Story 5.6 — Persist reader progress
   - Added `ReaderProgressStoring`.
   - Added `MockReaderProgressRepository` for tests.
   - Added `UserDefaultsReaderProgressRepository` for app-level local persistence bridge.
   - `ReaderViewModel` restores progress on open and saves progress as visible image changes.
   - Added a guard so initial SwiftUI `onAppear` events do not overwrite saved progress before restore completes.

## Files Changed
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Added `ReaderDisplayMode`.
  - Expanded `ReaderSettings`.
  - Made `ReaderProgress` codable.
  - Expanded `MockReaderSession` with series title, previous/next chapter links, settings, and longer mock image payload.
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
  - Added `ReaderProgressStoring`.
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
  - Expanded `MockReaderService`.
  - Added `MockReaderProgressRepository`.
- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/UserDefaultsReaderProgressRepository.swift`
  - Added durable local reader progress repository bridge.
- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
  - Added `readerProgressRepository`.
  - Mock app dependencies now use `UserDefaultsReaderProgressRepository`.
- `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
  - Presents `ReaderView` instead of `ReaderPlaceholderView`.
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
  - Added real reader UI.
- `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
  - Added reader session state, chrome state, progress restore/save, settings mutations, and previous/next availability.
- `app/Sources/ToonEdgeAppCore/Features/Reader/Settings/ReaderSettingsView.swift`
  - Added reader settings sheet.
- `app/Sources/ToonEdgeAppCore/Features/Settings/Views/SettingsView.swift`
  - Updated reader settings copy to use structured reader settings.
- `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
  - Added Reader behavior and progress persistence coverage.
- `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`
  - Updated mock reader image-count expectation.
- `app/ToonEdge.xcodeproj/project.pbxproj`
  - Added new Reader and progress repository source files to the app target.

## Current UX State
Verified complete:
- Real Reader screen is presented from app shell.
- Reader displays a vertical image strip from mock payload data.
- Reader chrome is hidden by default and toggled by tapping the reading surface.
- Reader shows progress with a bar and percentage.
- Reader settings sheet is available from chrome.
- Reader includes explicit `View Original Page`.
- Reader has mock previous/next chapter support.
- Reader chrome uses chapter context and controls rather than heavy product branding.
- Reader progress saves and restores for reopened chapters using the progress repository.

## Epic 5 Completion Checklist
- real reader screen: complete
- vertical strip rendering: complete
- chrome show/hide behavior: complete
- progress indicator: complete
- settings panel: complete
- explicit “View Original Page” action: complete
- mock previous/next chapter support: complete
- no product-brand-heavy reader chrome: complete
- progress save/restore: complete

## Verification
Commands run successfully:

```bash
swift test --filter ReaderExperienceTests --jobs 1
```

Result:
- 11 Reader tests passed
- 0 failures

```bash
swift test --jobs 1
```

Result:
- 33 tests passed
- 0 failures

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Result:
- `BUILD SUCCEEDED`
- The sandboxed environment printed CoreSimulator service warnings, but the app target compiled and linked successfully.

## Scope Guardrails Observed
Not implemented:
- real detection engine
- DOM extraction
- JavaScript page-analysis injection
- heuristic scoring
- confidence mapping
- browser medium-confidence CTA
- browser high-confidence auto-open
- site profile registry
- real extracted chapter payload handoff from Browser to Reader
- multi-page chapter stitching
- SwiftData-backed chapter/progress persistence
- real image cache/download behavior

## Known Gaps / Risks
- `ReaderPlaceholderView` still exists in the tree but is no longer presented by `AppShellView`. It can be removed in a cleanup pass once no tests or previews need it.
- Progress is currently keyed by source URL in `UserDefaultsReaderProgressRepository`. Real persistence should migrate this behind `ReaderProgressStoring` to SwiftData and likely key by chapter ID once `Chapter` models exist.
- Reader progress restore scrolls to the saved image index, not an exact pixel offset. Exact offset persistence is still future work.
- `AsyncImage` is acceptable for the mock slice, but long real chapters will need cache-aware/lazy image loading and likely retry/error policies.
- Previous/next navigation loads mock sessions. Real previous/next should come from detection output or stored chapter metadata.
- `fitScreen` behavior is conservative. If product wants a true one-image-per-screen reading mode, define it explicitly before implementation.

## Epic 4 Status
Epic 4 remains incomplete and should be picked up before Browser can automatically enter Reader from real pages.

Not yet done:
- Story 4.1 — JS injection framework
- Story 4.2 — generic candidate image extraction
- Story 4.3 — heuristic scoring engine
- Story 4.4 — browser confidence behaviors
- Story 4.5 — manual “Read in Clean Mode” override
- Story 4.6 — site profile registry
- Story 4.7 — initial supported site profiles
- Story 4.8 — detection diagnostics

## Recommended Next Agent Start For Epic 4
Proceed to Epic 4 — Detection Engine.

Suggested first slice:
1. Re-read:
   - `docs/toonedge_architecture_doc.md`, Detection and Reader sections
   - `docs/toonedge_ux_requirements_doc.md`, sections 4.4 and 4.5
   - `docs/toonedge_epics_and_stories.md`, Epic 4 and Epic 5
   - `docs/session_notes_2026-05-08_epic3_browser_experience.md`
   - this Epic 5 handoff
2. Add Detection module boundary before wiring behavior into Browser:
   - detection result models
   - candidate image models
   - confidence enum
   - detector protocol
   - mock/no-op detector for tests
3. Implement Story 4.1 first:
   - `BrowserWebView` can run page-analysis JavaScript after navigation finish and page stabilization.
   - JSON payload returns to Swift without SwiftUI owning parsing.
4. Implement Story 4.2/4.3 as pure services:
   - candidate extraction payload normalization
   - heuristic scoring
   - confidence mapping
   - tests for scoring thresholds and hard blocks
5. Only after confidence behavior is tested, wire Browser to Reader:
   - high confidence auto-opens `ReaderView` with extracted payload
   - medium confidence shows `Read in Clean Mode`
   - low confidence remains in Browser

Suggested first files to inspect:
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`
- `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`

## Recommended Handoff Message
Start with:

> Read `AGENTS.md`, `docs/toonedge_architecture_doc.md`, `docs/toonedge_ux_requirements_doc.md`, `docs/toonedge_epics_and_stories.md`, `docs/session_notes_2026-05-08_epic3_browser_experience.md`, and `docs/session_notes_2026-05-08_epic5_reader_experience.md`. Implement incomplete Epic 4 in thin vertical slices. Do not change Reader beyond the integration points needed to pass extracted chapter payloads into it. Do not implement multi-page stitching.
