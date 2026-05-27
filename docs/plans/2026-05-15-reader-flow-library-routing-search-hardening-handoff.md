# Reader Flow, Library Routing, and Search Hardening Handoff

## User intent
Reader should become the primary experience once ToonEdge has a viable chapter, without trapping the user or making Library/search feel disconnected.

## Current behavior before this story
- Reader chrome could become awkward to dismiss after being shown.
- Reader save actions inferred series information from the chapter URL.
- Library relaunch rebuilt sessions instead of reusing persisted image payloads.
- Search history was stored but not surfaced in suggestions.
- Query search used DuckDuckGo.
- Generic extraction blocked some decorative assets but not enough large ad-like imagery.

## Target behavior
- Tap-to-show and tap-to-hide Reader chrome both work.
- `x` returns to the canonical source series/index URL.
- `View Original Page` returns to the exact chapter URL.
- `Add to Library` saves metadata only.
- `Open in Library` saves if needed and opens native Series Detail.
- Stored ordered image payloads launch Reader immediately.
- Missing stored payloads fall back to Browser/detection.
- Search queries use Google and persisted local history appears in suggestions.
- Obvious ad/banner/sidebar imagery is excluded from Clean Mode.

## Relevant modules
- `Core/Domain/AppModels.swift`
- `App/Routing/AppRouter.swift`
- `Core/Services/Protocols/AppServiceProtocols.swift`
- `Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- `Features/Reader/Views/ReaderView.swift`
- `Features/Home/Views/HomeView.swift`
- `Features/Library/Views/LibraryView.swift`
- `Features/Search/Views/SearchOverlayView.swift`
- `Features/Detection/Scoring/GenericChapterDetector.swift`

## Required tests
- Browser query routing uses Google
- Reader `x` opens series URL
- View Original keeps chapter URL semantics
- Open in Library routes to native detail after save
- Stored chapter payload reconstructs Reader session
- Missing payload returns no direct session
- Persisted history appears in suggestions
- Large ad-like imagery is excluded
- Existing browser-to-reader and challenge suppression tests remain green

## Open risks
- Generic detection can only provide best-effort canonical series URLs when a site profile does not expose richer metadata.
- `Open in Library` assumes Series Detail can be addressed by stored series ID after save; future unsaved-browser flows should preserve stable IDs consistently.
- Manual QA is still needed for runtime SwiftUI hit-testing and browser/reader presentation on simulator/device.

## Exact acceptance criteria
1. Reader content taps toggle chrome on and off.
2. Visible chrome does not permanently block returning to scroll interaction.
3. Reader `x` opens the source series/index URL.
4. `View Original Page` opens the exact chapter URL.
5. `Add to Library` does not imply offline download.
6. `Open in Library` saves unsaved content, then opens native Series Detail.
7. Library chapters with stored ordered image URLs open Reader directly.
8. Incomplete stored payloads fall back safely to Browser/detection.
9. Query searches route to Google.
10. Persisted search history appears in visible suggestions.
11. Large ad-like images are excluded while valid ordered page images remain.
