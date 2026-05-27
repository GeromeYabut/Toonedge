# ToonEdge Session Notes — 2026-05-08 — Epic 3 Browser Experience

## Session Goal
Complete the Epic 3 browser experience slice:
- real `WKWebView` browser shell
- direct URL load flow
- query-based search result load flow
- back / forward / refresh controls
- visible address/search display
- preserve browser state for later return from Reader Mode

Detection, parsing, supported-source result treatment, and Reader conversion behavior were explicitly out of scope.

## Repo Guidance
- Follow root `AGENTS.md`.
- Use docs in this priority order:
  1. Architecture for technical boundaries and module ownership
  2. PRD for product scope and MVP boundaries
  3. UX requirements for user-facing behavior and interaction states
  4. UX brief for intent and visual direction
  5. Epics/stories for delivery sequence
- Use `architecture.md` as the source of truth for module boundaries.
- UX requirements are the behavioral source of truth unless they conflict with PRD scope.

## Key Documents Read
- `docs/prd.md` and canonical `docs/toonedge_prd.md`
- `docs/ux-requirements.md` and canonical `docs/toonedge_ux_requirements_doc.md`
- `docs/architecture.md` and canonical `docs/toonedge_architecture_doc.md`
- `docs/epics-and-stories.md` and canonical `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-08_epic2_home_search.md`

## Requirement Notes / Scope Decisions
- PRD and UX docs say detection runs after page load, but the user explicitly constrained this session to avoid detection and parsing.
- Browser state preservation was implemented as in-memory session preservation while the browser full-screen cover remains active behind Reader Mode.
- Query-based search uses DuckDuckGo web results as a standard browser search-result page. This is not a catalog or promoted source surface.
- Supported-source labeling in search result rows belongs to Story 3.4 and was not implemented in this slice.
- No browser tabs were added.
- No multi-page stitching or reader extraction was added.

## Stories Implemented
Epic 3:

1. Story 3.1 — Build browser screen shell
   - Replaced the placeholder browser view with a real `BrowserView`.
   - Added `BrowserWebView`, a SwiftUI representable wrapper around `WKWebView`.
   - Browser chrome includes:
     - close button
     - visible address/search display
     - loading indicator
     - back control
     - forward control
     - refresh control

2. Story 3.2 — Support direct URL loads
   - Added `BrowserRequest`.
   - `.url(String)` start points are converted into a `URLRequest` and loaded in `WKWebView`.
   - Browser state updates from `WKNavigationDelegate` callbacks.

3. Story 3.3 — Support query-based search results
   - `.searchQuery(String)` start points build a DuckDuckGo search results URL.
   - The search results page loads inside the same `WKWebView`.
   - Tapping web results is handled naturally by WebKit navigation.

4. Story 3.5 — Preserve browser state for return from reader
   - Updated `AppRouter.viewOriginalPage()`.
   - If a browser session already exists behind Reader Mode, `viewOriginalPage()` now dismisses Reader and leaves the existing browser start point/session intact.
   - If no browser is active, `viewOriginalPage()` falls back to opening the reader source URL in Browser.

## Files Changed
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Added `BrowserRequest`.
  - Added `BrowserAction`.
  - Added `BrowserCommand`.
- `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
  - Added browser-owned state for initial request, current URL, page title, loading, back/forward availability, and pending browser commands.
- `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
  - Added `WKWebView` wrapper.
  - Loads the initial request once.
  - Applies back/forward/reload commands.
  - Updates `BrowserViewModel` from navigation delegate events.
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
  - Replaced the old placeholder shell with the real browser screen.
  - Added top address/search chrome and bottom controls.
- `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
  - Presents `BrowserView` instead of the old placeholder view.
- `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`
  - Preserves existing browser state when returning from Reader Mode.
- `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
  - Added Epic 3 browser behavior tests.
- `app/Tests/ToonEdgeAppCoreTests/AppRouterTests.swift`
  - Updated fallback original-page routing test for the new preservation behavior.
- `app/ToonEdge.xcodeproj/project.pbxproj`
  - Added new browser source files to the app target.

## Current UX State
Verified complete:
- Home/Search routes into a real browser presentation.
- Direct URL input opens the target page in `WKWebView`.
- Search query input opens a web search results page in `WKWebView`.
- Browser top chrome displays current host/search context and title/URL detail.
- Browser bottom controls expose back, forward, and refresh.
- Loading state is visible via a progress indicator.
- Reader “View Original Page” can return to the already-present browser session instead of recreating it.

## Manual QA Notes
- Open `app/ToonEdge.xcodeproj` in Xcode.
- Run the `ToonEdge` scheme on an iPhone Simulator.
- From Home, tap the search pill.
- Submit `example.com/chapter-12`.
  - Expected: Browser opens and loads `https://example.com/chapter-12`.
- Submit `best new manhwa chapters`.
  - Expected: Browser opens DuckDuckGo search results for that query.
- Tap web links from search results.
  - Expected: Destination pages load in the same browser.
- Use back / forward / refresh.
  - Expected: controls update based on WebKit navigation state.

## Verification
Commands run successfully:

```bash
swift test --filter BrowserExperienceTests --jobs 1
```

Result:
- 4 browser tests passed
- 0 failures

```bash
swift test --jobs 1
```

Result:
- 22 tests passed
- 0 failures

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Result:
- `BUILD SUCCEEDED`
- The sandboxed environment printed CoreSimulator service warnings, but the app target compiled and linked successfully.

## Scope Guardrails Observed
Not implemented:
- detection engine
- DOM extraction
- JavaScript page-analysis injection
- heuristic scoring
- confidence mapping
- medium-confidence CTA
- high-confidence auto-open
- supported-source result labels
- browser tabs
- multi-page chapter stitching
- persistent browser session restoration across app launches

## Known Gaps / Risks
- WebKit behavior is mostly integration/UI behavior; current automated tests cover deterministic request/state/routing logic, not live page navigation.
- Query search provider is currently hardcoded to DuckDuckGo in `BrowserRequest`; this can become a configurable search service later.
- Browser state preservation is in-memory only and tied to the current app presentation.
- There is no user-editable address bar inside Browser yet; new searches still begin from Home/Search overlay.
- No explicit network error UI exists yet beyond WebKit staying visible and loading state ending.

## Recommended Next Agent Start
Proceed to Epic 4 — Detection Engine.

Suggested first slice:
1. Re-read:
   - `docs/toonedge_architecture_doc.md`, Browser and Detection sections
   - `docs/toonedge_ux_requirements_doc.md`, sections 4.4 and detection behavior
   - `docs/toonedge_epics_and_stories.md`, Epic 4
   - this session note
2. Add a Detection module boundary before wiring behavior into Browser:
   - detection models
   - JS injection protocol/service
   - mock or no-op detector for tests
3. Implement Story 4.1 first:
   - WebView can run page-analysis scripts after navigation finish
   - JSON payload can be returned to native layer
4. Keep Browser UI from owning parsing/scoring logic.
5. Do not auto-open Reader Mode until high/medium/low confidence behavior is implemented and tested.

Suggested first files to inspect:
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`
- `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
