# ToonEdge Session Notes — 2026-05-11 — Epic 4 Detection Engine

## Session Goal
Complete Epic 4 — Detection Engine:
- JavaScript page-analysis injection in `WKWebView`
- generic candidate image extraction from rendered DOM
- lazy-load and `srcset` normalization
- heuristic scoring and high / medium / low confidence mapping
- Browser confidence behavior
- manual “Read in Clean Mode” override
- site profile registry with support tiers
- initial site profiles
- structured detection diagnostics and OSLog logging

Multi-page chapter stitching and ML-based detection remained explicitly out of scope.

## Repo Guidance
- Follow root `AGENTS.md`.
- Use docs in this priority order:
  1. Architecture for technical boundaries and module ownership
  2. PRD for product scope and MVP boundaries
  3. UX requirements for user-facing behavior and interaction states
  4. UX brief for intent and visual direction
  5. Epics/stories for delivery sequence
- UX requirements remain the behavioral source of truth unless they conflict with PRD scope.
- False positives are worse than false negatives; high-confidence auto-open must remain conservative.
- Approved non-promoted sources may be extractable after user navigation, but must not be promoted in suggestions, onboarding, catalog/source lists, or recommendations.

## Key Documents Read
- `docs/prd.md` and canonical `docs/toonedge_prd.md`
- `docs/ux-requirements.md` and canonical `docs/toonedge_ux_requirements_doc.md`
- `docs/architecture.md` and canonical `docs/toonedge_architecture_doc.md`
- `docs/epics-and-stories.md` and canonical `docs/toonedge_epics_and_stories.md`
- `docs/session_notes_2026-05-08_epic3_browser_experience.md`
- `docs/session_notes_2026-05-08_epic5_reader_experience.md`

## Requirement Notes / Scope Decisions
- Detection now runs after `WKWebView` navigation finishes and a short stabilization delay.
- Browser owns WebKit, navigation, and presentation state. Detection owns page-analysis models, site profile policy, scoring, confidence, and diagnostics.
- Browser receives Detection through the `ChapterPageDetecting` protocol from `AppDependencies`.
- The current extracted reader payload still uses `MockReaderSession`, populated with real extracted image URLs. A future model cleanup should rename or replace it with a real reader/session payload.
- Generic detection is intentionally conservative:
  - high confidence requires score threshold and at least 5 usable candidates
  - medium confidence requires lower threshold and at least 2 usable candidates
  - low confidence produces no reader session
- Manual override currently appears through the medium-confidence `Read in Clean Mode` CTA when a usable reader payload exists.
- Site profiles currently use `SiteProfileExtractionStrategy.selectorHints(...)`. This is an extension point for future richer domain-specific extractors.
- Native row-level labeling for web search results was not added because search results are currently rendered by DuckDuckGo inside `WKWebView`. Supported-source treatment is currently applied to local common-site suggestions for enabled-public profiles only.

## Stories Implemented
Epic 4:

1. Story 4.1 — Implement JS injection framework
   - `BrowserWebView` runs `PageAnalysisScript.javaScript` after navigation finishes.
   - JS returns a JSON string containing page URL, title, document height, viewport width, and rendered image candidates.
   - Swift decodes the JSON into `DetectionPageAnalysis`.
   - JS failure degrades to low confidence and keeps Browser usable.

2. Story 4.2 — Implement generic candidate image extraction
   - `DetectionImageCandidate` captures image source data, lazy sources, `srcset`, dimensions, layout position, and DOM hint fields.
   - Lazy attributes such as `data-src`, `data-original`, `data-lazy-src`, and lazy `srcset` variants are collected.
   - `GenericChapterDetector` normalizes relative, protocol-relative, lazy, and `srcset` URLs.
   - Small/decorative assets are filtered using dimensions, aspect ratio, and hard-block hints such as avatar, logo, icon, ad, comment, thumbnail, and product.

3. Story 4.3 — Implement heuristic scoring engine
   - `GenericChapterDetector` scores:
     - count of large vertical images
     - candidate count
     - document height
     - single-column vertical flow
     - consistent image host
     - repeated image path shape
     - chapter-like URL/title hints
   - Confidence maps to high / medium / low.
   - Unit tests cover scoring and confidence behavior.

4. Story 4.4 — Implement browser confidence behaviors
   - High confidence sets `BrowserViewModel.pendingReaderSession`; `BrowserView` presents Reader.
   - Medium confidence sets `BrowserViewModel.showsCleanModeCTA`; Browser shows `Read in Clean Mode`.
   - Low confidence does not show CTA and does not present Reader.

5. Story 4.5 — Implement manual “Read in Clean Mode” override
   - Medium-confidence CTA calls `BrowserViewModel.enterCleanModeManually()`.
   - Manual override presents the detected reader session and hides the CTA.

6. Story 4.6 — Implement site profile registry
   - Added `SiteProfile`, `SiteProfileSupportTier`, `SiteProfileExtractionStrategy`, and `SiteProfileRegistry`.
   - Registry matches root domains and subdomains.
   - `ProfileAwareChapterDetector` chooses site profile behavior before generic fallback.
   - Browser-only profiles force low confidence with no extraction.

7. Story 4.7 — Add initial supported site profiles
   - Enabled-public profiles:
     - `webtoons.com`
     - `globalcomix.com`
   - Approved non-promoted profiles:
     - `asuracomic.net`
     - `asurascans.com`
     - `manhwatop.com`
   - Enabled-public profiles can be labeled in local common-site suggestions.
   - Approved non-promoted profiles are tested to remain absent from promoted suggestion labeling.

8. Story 4.8 — Add detection diagnostics
   - Added `DetectionDiagnostics` with confidence, score, parser path, profile domain, support tier, candidate count, and messages.
   - Added `DetectionDiagnosticsLogging`.
   - Added `OSLogDetectionDiagnosticsLogger`.
   - `ProfileAwareChapterDetector` logs each detection result.

## Files Changed
- `app/Sources/ToonEdgeAppCore/Features/Detection/Models/DetectionModels.swift`
  - Added detection confidence, parser path, page-analysis models, image candidate models, result model, and structured diagnostics.
- `app/Sources/ToonEdgeAppCore/Features/Detection/JavaScript/PageAnalysisScript.swift`
  - Added self-contained page-analysis JavaScript.
- `app/Sources/ToonEdgeAppCore/Features/Detection/Scoring/GenericChapterDetector.swift`
  - Added candidate normalization, filtering, scoring, confidence mapping, and reader payload creation.
- `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`
  - Added site profile models, support tiers, extraction strategy, registry, default profiles, and promoted-domain filtering.
- `app/Sources/ToonEdgeAppCore/Features/Detection/Services/ProfileAwareChapterDetector.swift`
  - Added profile-aware detection wrapper and browser-only suppression.
- `app/Sources/ToonEdgeAppCore/Features/Detection/Services/DetectionDiagnosticsLogger.swift`
  - Added diagnostics logging protocol and OSLog implementation.
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
  - Added `ChapterPageDetecting`.
- `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
  - Added `chapterDetector` dependency.
  - Mock dependencies use `ProfileAwareChapterDetector`.
- `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
  - Injects and evaluates page-analysis JavaScript.
  - Decodes page analysis and invokes the injected detector.
- `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
  - Added detection result state, CTA state, pending reader session, and manual override handling.
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
  - Added medium-confidence clean-mode CTA.
  - Presents Reader when high-confidence or manual override produces a pending reader session.
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
  - Added optional `sourceSupportTier` to `SearchSuggestion`.
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
  - Common-site suggestions label enabled-public profile domains only.
- `app/Sources/ToonEdgeAppCore/Features/Search/Views/SearchOverlayView.swift`
  - Displays enabled-public common-site suggestions as `Supported`.
- `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
  - Added Epic 4 coverage.
- `app/Tests/ToonEdgeAppCoreTests/SearchEntryModelTests.swift`
  - Added enabled-public-only suggestion labeling coverage.
- `app/ToonEdge.xcodeproj/project.pbxproj`
  - Added new Detection files to the app target.

## Current UX State
Verified complete:
- Browser loads pages through real `WKWebView`.
- Detection runs after page load.
- High-confidence chapter pages auto-open Reader.
- Medium-confidence pages show a non-blocking `Read in Clean Mode` CTA.
- Low-confidence pages stay in Browser.
- Manual clean-mode CTA opens Reader when a medium-confidence payload exists.
- Reader still provides `View Original Page` through Epic 5 routing behavior.
- Local common-site suggestions can label enabled-public supported reader sources.

## Epic 4 Completion Checklist
- JS injection running: complete
- extracted candidates coming back from page: complete
- lazy-load attribute normalization: complete
- heuristic scoring: complete
- confidence mapping: complete
- high confidence auto-open: complete
- medium confidence CTA: complete
- low confidence browser-only behavior: complete
- manual override path: complete
- site profile registry: complete
- initial support-tiered profiles: complete
- structured diagnostics: complete
- OSLog diagnostics: complete
- Browser / Detection separation: complete

## Verification
Commands run successfully:

```bash
swift test --filter DetectionEngineTests --jobs 1
```

Result:
- 16 Detection tests passed
- 0 failures

```bash
swift test --jobs 1
```

Result:
- 50 tests passed
- 0 failures

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination generic/platform=iOS\ Simulator -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO
```

Result:
- `BUILD SUCCEEDED`
- The sandboxed environment printed CoreSimulator service warnings, but the app target compiled and linked successfully.

## Scope Guardrails Observed
Not implemented:
- multi-page chapter stitching
- ML-based detection
- browser tabs
- hosted/curated source catalog
- native web search result rows
- promoted labels for approved non-promoted domains
- SwiftData-backed series/chapter persistence
- real update checks
- real cache/download behavior

## Known Gaps / Risks
- `MockReaderSession` is now used for real extracted payloads. This should be renamed or replaced with a real `ReaderSession` / `ExtractedChapterPayload` before persistence work hardens.
- Site profiles currently use selector hints, not custom per-site DOM parsers.
- Detection has strong unit coverage but no live simulator/manual QA against real websites yet.
- Search results are still DuckDuckGo inside `WKWebView`; native row-level supported-source labels are not possible without a native search-results service/screen.
- Reader progress still keys by source URL through `ReaderProgressStoring`, inherited from Epic 5.
- No SwiftData models/repositories exist yet for saved series, chapters, or chapter lists.
- No Series Detail screen exists yet.

## Epic 6 Status
Epic 6 has not started.

Epic 6 goal:
- Build a utility-first title detail screen that supports chapter selection and progress-aware continuation.

Stories to implement:
1. Story 6.1 — Implement series detail header
   - Screen shows title, status, synopsis/summary, and primary CTA.
   - Primary CTA is progress-aware, e.g. “Continue Chapter 142.”
2. Story 6.2 — Implement chapter list
   - Chapter list renders in correct sort order.
   - Chapter rows are tappable.
   - Basic loading/empty/error states exist.
3. Story 6.3 — Implement chapter row state system
   - Rows can represent New, Unread, In Progress, Read, Downloaded.
   - State styling does not rely on opacity alone.
   - State system matches UX requirements.
4. Story 6.4 — Implement chapter utilities
   - Sort control exists.
   - Download indicator/action shell exists.
   - Series follow/save state is represented.

## Recommended Next Agent Start For Epic 6
Proceed to Epic 6 — Series Detail Experience.

Suggested first slice:
1. Re-read:
   - `docs/toonedge_architecture_doc.md`, Library / Reader / Persistence module boundaries
   - `docs/toonedge_ux_requirements_doc.md`, Series Detail section 4.6 and chapter row state rules
   - `docs/toonedge_epics_and_stories.md`, Epic 6 and upcoming Epic 7 / Epic 8 dependencies
   - `docs/session_notes_2026-05-08_epic5_reader_experience.md`
   - this Epic 4 handoff
2. Add mock-backed Series Detail models before persistence:
   - `SeriesDetailSnapshot`
   - `ChapterSummary`
   - `ChapterListState`
   - `ChapterReadState`
   - follow/save state shell
3. Add a protocol-backed service:
   - `SeriesDetailProviding`
   - mock implementation in `MockServices.swift`
4. Add routing:
   - likely `AppRouter.presentedSeriesDetail` or navigation path from Home/Library cards
   - keep Reader opening through existing router/session patterns
5. Build the smallest complete vertical slice:
   - Home or Library card → Series Detail
   - detail header with progress-aware CTA
   - mock chapter list
   - tapping CTA/chapter opens Reader using existing `ReaderSessionProviding`
6. Add tests for:
   - progress-aware CTA copy
   - chapter sort order
   - row state mapping
   - unavailable/empty/error states if modeled
   - routing from Series Detail to Reader

## Suggested First Files To Inspect
- `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`
- `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
- `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

## Recommended Handoff Message
Start with:

```text
Read:
- AGENTS.md
- docs/prd.md
- docs/ux-requirements.md
- docs/architecture.md
- docs/epics-and-stories.md
- docs/session_notes_2026-05-11_epic4_detection_engine.md
- docs/session_notes_2026-05-08_epic5_reader_experience.md

Follow AGENTS.md.

Implement Epic 6 — Series Detail Experience.

Scope:
- mock-backed Series Detail screen
- progress-aware header CTA
- chapter list with New / Unread / In Progress / Read / Downloaded states
- sort control shell
- follow/save shell
- chapter tap and CTA route into existing Reader flow

Constraints:
- do not implement SwiftData persistence yet unless explicitly requested
- do not implement real update checks
- do not implement downloads/cache beyond UI shell state
- keep Series Detail utility-first and chapter-list focused
```
