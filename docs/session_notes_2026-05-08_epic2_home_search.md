# ToonEdge Session Notes — 2026-05-08 — Epic 2 Home and Search Entry

## Session Goal
Complete Epic 2 Home and Search Entry as a thin vertical slice:
- populated Home
- empty-state Home
- universal search / URL field
- focused, typing, and suggestions states
- local suggestions model using mock data
- input classification
- transition from Home search into the mock Browser route shell

Real web loading, real persistence, detection, parsing, and site profiles remained out of scope.

## Repo Guidance
- Follow root `AGENTS.md`.
- Use docs in this priority order:
  1. Architecture for technical boundaries and module ownership
  2. PRD for product scope and MVP boundaries
  3. UX requirements for user-facing behavior and interaction states
  4. UX brief for intent and visual direction
  5. Epics/stories for delivery sequence
- UX requirements are the behavioral source of truth unless they conflict with PRD scope.
- Mockups are visual/layout references only. If docs and mockups conflict, follow docs and call out the conflict.

## Key Documents Read
- `docs/prd.md` and canonical `docs/toonedge_prd.md`
- `docs/ux-brief.md` and canonical `docs/toonedge_ux_brief.md`
- `docs/ux-requirements.md` and canonical `docs/toonedge_ux_requirements_doc.md`
- `docs/architecture.md` and canonical `docs/toonedge_architecture_doc.md`
- `docs/epics-and-stories.md` and canonical `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-08_epic1_implementation.md`

## Requirement Notes / Ambiguities
- User initially referenced `docs/session-notes_2026_05_08_epic1_implementation.md`; actual repo file is `docs/session_notes_2026-05-08_epic1_implementation.md`.
- Epic 2.5 input classification was implemented during this session because browser-route handoff depends on classification output.
- Clipboard suggestions are mock-backed only. The app does not read the system clipboard yet.
- Search query routing remains `.searchQuery(String)` because real search-engine loading is Epic 3/browser work.
- Recently Updated and All Library rows are visual/navigation-ready only; Series Detail is not implemented yet.

## Stories Implemented
Epic 2:

1. Story 2.1 — Implement populated Home layout
   - Home now shows the hierarchy:
     1. search field / top bar
     2. Continue Reading
     3. Recently Updated
     4. All Library
   - Uses mock library data from `MockLibraryService`.
   - Search entry is visually first and sits at the top of Home.

2. Story 2.2 — Implement empty-state Home
   - `HomeSnapshot.isEmpty` drives empty-state rendering.
   - Empty state includes a banner and a search CTA.
   - Same search entry pattern is reused.

3. Story 2.3 — Implement search bar interaction states
   - Idle state: Home top search pill.
   - Focused state: search sheet input with focus ring and autofocus.
   - Typing state: custom placeholder disappears, clear button appears, label changes from `Suggestions` to `Open or search`.
   - Suggestions state: local suggestion list is shown immediately.
   - Search sheet title was removed after QA because SwiftUI large-title rendering overlapped the input.
   - Placeholder contrast was improved with a custom placeholder text layer.

4. Story 2.4 — Implement local suggestions model
   - Added `SearchSuggestion`, `SearchSuggestionKind`, and `SearchSuggestionProviding`.
   - Added `MockSearchSuggestionProvider`.
   - Suggestion order follows UX priority:
     1. clipboard link
     2. recent links
     3. recent searches
     4. common/recent sites
     5. explicit `Search for ...` action while typing

5. Story 2.5 — Implement input classification
   - Added `SearchInput`, `SearchInputKind`, and `SearchInputClassifier`.
   - Classifier is scoring-based rather than a simple contains-dot rule.
   - Classifier outputs `BrowserStartPoint` through `SearchInput.browserStartPoint`.
   - Covered:
     - `http://` and `https://` URLs
     - bare domains and paths
     - protocol-relative links
     - localhost and IPv4-style local URLs
     - spaced search queries
     - dotted natural-language phrases
     - unsupported schemes treated as search queries

6. Story 2.6 — Partial Home interactions
   - Home search opens the search sheet.
   - Search submit and suggestion taps open the mock Browser shell.
   - Continue Reading opens the existing mock Reader session.
   - Recently Updated and All Library rows show clickable affordances but do not yet route to Series Detail because Series Detail is later scope.

## Files Changed
- `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
  - Injects `dependencies.searchSuggestionProvider` into `SearchOverlayView`.
- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
  - Added `searchSuggestionProvider`.
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Added search input, classifier, suggestion models, and `HomeSnapshot.isEmpty`.
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
  - Added `SearchSuggestionProviding`.
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
  - Added `MockSearchSuggestionProvider`.
  - Existing `MockLibraryService` continues to provide Home mock data.
- `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
  - Reworked Home into top search pill plus settings icon.
  - Removed app-name/header/help text per user QA request.
  - Added populated and empty-state rendering.
- `app/Sources/ToonEdgeAppCore/Features/Search/Views/SearchOverlayView.swift`
  - Replaced scaffold with focused input, custom placeholder, clear button, local suggestions, and Browser routing.
  - Removed `navigationTitle("Search")` after it overlapped the search field in Simulator.
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserPlaceholderView.swift`
  - Displays route type as direct URL route or search results route.
- `app/Tests/ToonEdgeAppCoreTests/SearchEntryModelTests.swift`
  - Added classifier, suggestion ordering, typing suggestion, and Home empty-state tests.

## Current UX State
Verified complete:
- Home hierarchy:
  - search first
  - Continue Reading
  - Recently Updated
  - All Library
- Populated Home state
- Empty Home state
- Search field states:
  - idle
  - focused
  - typing
  - suggestions
- Local suggestion types:
  - clipboard
  - recent links
  - recent searches
  - common/recent sites
- Routing from search into mock Browser shell

## Manual QA Notes
- Open `app/ToonEdge.xcodeproj` in Xcode.
- Run the `ToonEdge` scheme on an iPhone Simulator.
- Home should show a long thin pill search bar at the top with a globe icon and text `Search or enter website`, with a settings icon to its right.
- Tapping the search pill opens a titleless search sheet with `Cancel`, a focused input, and local suggestions.
- In Simulator, if the software keyboard does not appear, disable `I/O > Keyboard > Connect Hardware Keyboard`.
- Submitting:
  - `example.com/chapter-12` opens mock Browser as a direct URL route.
  - `best new manhwa chapters` opens mock Browser as a search results route.

## Verification
Commands run successfully:

```bash
swift test --filter SearchEntryModelTests --jobs 1
```

Result:
- 12 tests passed
- 0 failures

```bash
swift test --jobs 1
```

Result:
- 18 tests passed
- 0 failures

## Scope Guardrails Observed
Not implemented:
- real `WKWebView` loading
- real search engine URL construction/loading
- real clipboard access
- real persistence / SwiftData
- real detection
- parsing or site profiles
- Series Detail routing
- browser tabs
- multi-page chapter stitching

## Known Gaps / Risks
- Xcode project manually references current Swift files. If new source files are added, update the Xcode project unless the project later shifts to generated project management.
- Repo still has no initial commit; `git status` reports everything as untracked.
- Current UI behavior is compiled and unit-tested, but there are no UI automation tests yet.
- Search overlay behavior is local and mock-backed. Epic 3 should preserve this entry flow while replacing the Browser placeholder with real browser state.

## Recommended Next Agent Start
Proceed to Epic 3 — Browser Experience.

Suggested first slice:
1. Re-read:
   - `docs/toonedge_architecture_doc.md`, Browser module section
   - `docs/toonedge_ux_requirements_doc.md`, sections 4.3 and 4.4
   - `docs/toonedge_epics_and_stories.md`, Epic 3
   - this session note
2. Implement the Browser shell before detection:
   - Browser view model/state for `BrowserStartPoint`
   - address/search bar area
   - back/forward/refresh control affordances
   - loading/empty/error placeholder states
   - route preservation for later Reader return
3. Keep real detection deferred until Epic 4 unless Epic 3 story explicitly asks for detection hooks.
4. Do not implement browser tabs or multi-page chapter stitching.

Suggested first files to inspect:
- `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserPlaceholderView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Search/Views/SearchOverlayView.swift`
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
