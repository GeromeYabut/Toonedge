# Competitive MVP Enhancements — Implementation Design

**Date:** 2026-09-28

**Status:** Approved; amended with capability-based validation stories

**Decision owner:** Product/engineering review

**Input:** [MangaPin Competitive Review and ToonEdge Requirements](./2026-09-28-mangapin-competitive-requirements-design.md)

**Scope:** Technical design for the six proposed MVP enhancements only. The epic, story breakdown, and per-story implementation plans are intentionally deferred until this design is approved.

## 1. Decision summary

Implement the competitive response as six product slices plus two release-validation slices within ToonEdge's existing local-first architecture:

1. chapter-scoped reader prefetch and decode coordination;
2. explicit, guarded manual Clean Mode eligibility;
3. saved-library matches in universal search;
4. transient bounded zoom over the existing long-strip reader;
5. composable Library sorting and source filtering;
6. individual and clear-all local search-history controls;
7. rendering-pattern fixture validation for generic best-effort compatibility;
8. live-device compatibility validation and evidence capture.

The design does not copy MangaPin's account, catalog, sync, tracker, social, prediction, or multi-mode reader surfaces. Existing ToonEdge behavior remains authoritative where it is already complete: URL/query classification, browser ownership, conservative detection, exact original-page escape, progress persistence, adjacent chapter loading, lifecycle states, update checking, and cache retention.

No new persistence model or schema migration is required. The only new persisted values are presentation preferences in `UserDefaults`; search-history deletion operates on the existing `StoredSearchHistory` model.

## 2. Goals

- Improve the reliability and recoverability of the core browser-to-reader flow.
- Add high-value reader interactions without broadening the manhwa-first product model.
- Make saved content easier to find from the existing primary search entry point.
- Complete the already-specified Library organization behavior.
- Make local-first privacy visible through direct history controls.
- Preserve feature-layer boundaries, dependency injection, and testable business logic.

## 3. Non-goals and retained guardrails

This design does not add:

- a source catalog, promoted non-public sources, or piracy-oriented discovery;
- browser tabs;
- cloud sync, accounts, or remote history;
- external tracker integration;
- background update prediction or notifications;
- multi-page chapter stitching;
- ML-based detection;
- automatic conversion below high confidence;
- single-page, double-page, or horizontal manga reading modes;
- persistent per-title zoom state;
- batch download queues or a second cache store.

Protected, authenticated, paywalled, challenged, browser-only, DRM/canvas/blob, unsupported paginated, and otherwise hard-blocked content remains in Browser. Every Reader entry path retains `View Original Page`.

## 4. Current baseline and required delta

| Area | Existing completed behavior | Required delta |
|---|---|---|
| Reader loading | Per-panel lazy loader, cache-first read, retry, metadata-sized placeholders, progress only after successful load | Coordinate the chapter as one bounded pipeline, prefetch ahead, decode off the main actor, cancel stale work, and retain page-local failure |
| Detection/browser | High auto-open, medium CTA, low remains in Browser, profile and challenge hard blocks, browser-owned Reader presentation | Represent automatic/recommended/manual/unavailable as an explicit detector output; expose a secondary manual action only for viable `45...54` results |
| Search | URL/query classification, clipboard/history/site suggestions, explicit web-search action | Add a lightweight local Library projection, deterministic ranking, and a typed native Series Detail destination |
| Reader interaction | Native vertical long strip, fit modes, spacing, canvas, brightness, tap-to-toggle chrome | Add transient `1x...3x` pinch/pan and double-tap behavior without changing the content or progress models |
| Library | Lifecycle segments, comfortable/compact/list density, local snapshots, native Series Detail routing | Add a pure collection query for sort/direction/source filters plus locally persisted view preferences |
| Search history | Existing `StoredSearchHistory`, record/update, recent read, suggestions | Add delete-one and clear-all repository operations, immediate Search refresh, and confirmed Settings action |

These additions extend existing contracts. They do not replace the browser, detector, Reader session, Library identity, progress, update, or cache models.

## 5. Architecture overview

The implementation remains feature-oriented, with domain values and protocols in App Core and concrete persistence/network work behind injected services.

| Feature | UI owner | State/business owner | Service boundary | Persistence |
|---|---|---|---|---|
| Reader continuity | `ReaderView` / page panel | `ReaderPagePipeline` | `HTTPDataLoading`, `ChapterAssetCaching`, image decoder | Existing file cache; chapter-scoped memory only for prefetched images |
| Manual Clean Mode | Browser tools | `BrowserViewModel` consumes detector disposition | `ChapterPageDetecting` | None |
| Library search | `SearchOverlayView` | `SearchOverlayViewModel`, pure ranker | `LibrarySearchProviding` | Existing Library store, read-only projection |
| Reader zoom | Reader surface | `ReaderZoomState` | None | None |
| Library organization | `LibraryView` | `LibraryCollectionQuery` | Existing `LibraryProviding` | `LibraryViewPreferences` in `UserDefaults` |
| History controls | Search and Settings | Search/Settings view models | `SearchHistoryManaging` | Existing `StoredSearchHistory` rows |
| Pattern validation | Test target and fixtures | Capability matrix | Existing detector/browser contracts | Sanitized fixture resources only |
| Device validation | QA harness and evidence | Release checklist | Existing Browser/Reader flows | Safe screenshots and logs only |

### Dependency direction

```text
SwiftUI views
    -> feature view models / pure policies
        -> App Core protocols
            -> SwiftData, file cache, URLSession, UserDefaults implementations
```

Search never receives a `ModelContext`, Reader never writes cache metadata directly, Browser never reimplements detection thresholds, and Library controls never mutate stored series to achieve presentation ordering.

## 6. Detailed design

### 6.1 Reader visual continuity and bounded prefetch

#### Current issue

Each `ReaderImagePanel` currently creates its own `ReaderPageImageLoader`. SwiftUI controls when those tasks start, so the chapter has no single place to prioritize visible work, cap concurrency, suppress duplicate requests, or cancel work after a chapter change. `UIImage(data:)` or `NSImage(data:)` is also called by the view during rendering.

#### Proposed components

**`ReaderPagePipeline`**

- A chapter-scoped actor created for one `MockReaderSession`.
- Owns page states, task priority, in-flight request deduplication, a decoded-image memory cache, and the configured prefetch policy.
- Accepts visibility updates from the Reader and publishes immutable page-state snapshots to a main-actor observable adapter.
- Default target window is the current page, two pages ahead, and one page behind.
- Runs no more than three fetch/decode operations concurrently.
- Reprioritizes when the visible index or scroll direction changes.
- Cancels work outside the target window when the session changes, Reader disappears, or memory pressure is received.

**`ReaderPageAssetLoading`**

- Encapsulates cache-first bytes lookup followed by an authenticated/contextual network request.
- Reuses `ChapterAssetCaching`, `ReaderImageRequestContext`, and `HTTPDataLoading`.
- Does not independently mark a network-prefetched page as retained offline. Prefetched network results live in chapter-scoped memory unless an existing cache policy explicitly stores them.

**`ReaderImageDecoding`**

- Validates and decodes image bytes away from the main actor using ImageIO/Core Graphics.
- Returns an immutable renderable asset plus pixel dimensions.
- Keeps platform image construction out of the SwiftUI `body` path.

**`ReaderPageState`**

- Uses independent states per index: idle, queued, loading, ready, and failed.
- A failed state contains a retryable, sanitized failure category, not a raw URL or response body.
- Retains known metadata dimensions throughout every state.

`ReaderImagePanel` becomes a renderer of injected state. It no longer owns network scheduling. A page retry asks the pipeline to reprioritize only that index.

#### Data flow

1. Reader opens a session and creates a pipeline keyed by `session.id`.
2. Progress restoration determines the initial visible index.
3. Reader reports the current visible index and direction.
4. Pipeline calculates the bounded target window and checks decoded memory, then file cache, then network.
5. Each successful fetch is decoded off the main actor and published as a page-local ready state.
6. The page reports successful visibility to `ReaderViewModel`; only then can progress advance.
7. Session replacement or dismissal cancels remaining nonessential tasks and releases the memory cache.

#### Memory and lifecycle policy

- At most three pages fetch/decode concurrently.
- Ready assets outside the one-behind/two-ahead working set may be evicted under pressure; visible assets are preferred.
- A memory warning reduces the speculative window to the visible page and clears nonvisible decoded assets.
- Duplicate URLs within a session share an in-flight request but still publish state to every referenced page index.
- Chapter changes create a new pipeline identity, preventing late results from the previous chapter from updating the new Reader.

#### Failure behavior

- Network, HTTP, empty-data, and decode failures remain isolated to one page.
- Retry resets only the failed page and preserves the chapter scroll position.
- The reader canvas and reserved page geometry remain visible during loading/failure.
- Cancellation is not presented as an error.
- Missing cache data falls through to network; a corrupt cached asset is ignored for the current load and reported through sanitized diagnostics.

### 6.2 Guarded manual `Try Clean Mode`

#### Source-of-truth discrepancy

The Architecture document defines:

- automatic: score `>= 78` plus high-confidence candidate and negative-signal constraints;
- recommended: score `55...77` plus medium-confidence viability constraints;
- manual-only: score `45...54`, no hard block, with a viable normalized session;
- unavailable: lower score, nonviable output, or any hard block.

The Architecture §9.5.1 global candidate minimum applies before all three entry bands: at least four candidates, or exactly three whose combined actual rendered height reaches 3.5 viewport heights. One or two images never qualify, regardless of natural size. The three-image exception requires finite positive viewport height and actual rendered measurements for all three candidates; missing legacy geometry cannot establish it. Per-band candidate/height constraints still apply after this global gate.

The current `GenericChapterDetector` defaults to high `>= 85` and medium `>= 45`, and it creates no Reader session for low confidence. That implementation cannot distinguish the architecture's manual-only band. This design treats the Architecture document as authoritative and includes threshold/policy alignment in this slice. Thresholds must live in one policy type and must not be duplicated in Browser UI.

This also conflicts with planned Epic 12 Story 12.3 wording that all low-confidence pages never expose Clean Mode. The story should be amended to distinguish ordinary/hard-blocked low confidence from architecture-approved manual-only eligibility.

#### Proposed model

Add an explicit detector result value:

```swift
public enum ReaderEntryDisposition: Equatable, Sendable {
    case automatic
    case recommended
    case manual
    case unavailable
}
```

`DetectionResult` retains score, confidence, candidates, diagnostics, and optional normalized session, and adds `readerEntryDisposition`. The disposition is authoritative for presentation:

| Disposition | Session | Browser behavior |
|---|---|---|
| `automatic` | Required and viable | Auto-present through existing browser-owned Reader path |
| `recommended` | Required and viable | Show primary `Read in Clean Mode` CTA |
| `manual` | Required and viable | Show secondary `Try Clean Mode` browser-tool action |
| `unavailable` | Nil | No Reader action |

The detector, including profile-aware hard-block handling, assigns the disposition. Browser does not infer eligibility from score or diagnostics strings.

#### Hard-block policy

All hard blocks resolve to `.unavailable` before scoring can grant entry. At minimum this includes:

- challenge/interstitial signals;
- browser-only profile;
- unsupported paginated profile;
- login, authentication, paywall, and error-page classifications;
- protected viewer, DRM, canvas, blob, or other nonextractable content;
- missing or nonviable normalized image session.

Hard-block diagnostics may use a typed internal reason, but user-facing copy stays generic and does not reveal bypass-oriented detail.

#### Browser behavior

- `BrowserViewModel` exposes a single presentation model derived from disposition rather than parallel booleans for every action.
- The existing medium CTA remains the primary recommendation.
- Manual-only eligibility appears in Browser tools as `Try Clean Mode`, visually secondary to navigation.
- Both actions call the existing `enterCleanModeManually()`/browser-owned presentation path with the detector-produced session.
- Preflight failure leaves the exact page and WebView history intact and presents nonblocking feedback.
- Navigation start clears the prior disposition and pending session so stale eligibility cannot carry to a new page.

### 6.3 Saved-library matches in universal search

#### Proposed boundaries

**`LibrarySearchProviding`**

Returns a lightweight local projection when Search opens:

```swift
public struct LibrarySearchItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let sourceDomain: String
    public let libraryState: LibraryCollectionState
    public let currentChapterLabel: String?
    public let coverImageURL: URL?
}

public protocol LibrarySearchProviding: Sendable {
    func librarySearchItems() async -> [LibrarySearchItem]
}
```

The SwiftData repository implements this as a read-only summary projection. Search does not load Series Detail or chapter collections for matching.

**`LibrarySuggestionRanker`**

- Pure, synchronous, locale-stable matching over the loaded projection.
- Normalizes case, punctuation, diacritics, and repeated whitespace.
- Supports exact title, title prefix, ordered token prefix, then all-token containment.
- Uses normalized title then stable series ID as deterministic tie-breakers.
- Returns a bounded number of saved results so the explicit web-search action remains visible.

**Typed destinations**

Replace the assumption that every suggestion is browser input with a typed destination:

```swift
public enum SearchSuggestionDestination: Equatable, Sendable {
    case browserInput(String)
    case librarySeries(LibrarySearchItem)
}
```

Existing clipboard, history, site, and search actions use `.browserInput`. Saved results use `.librarySeries`, allowing `AppRouter` to dismiss Search, select Library, and open the existing seeded Series Detail route without browser classification.

#### Search state and ranking

`SearchOverlayViewModel` owns query, validation, recent history, library projection, and composed results. On presentation it loads history and Library items concurrently. Query changes rerank in memory; no network request or SwiftData fetch occurs per keystroke.

Priority is:

1. exact clipboard link action;
2. exact saved-title match;
3. prefix/token saved-title matches;
4. existing recent link/search and permitted site suggestions;
5. explicit web-search action.

Ordinary saved, history, and site results are deduplicated by typed destination identity, not display text. The final explicit web action is a utility action exempt from ordinary-result deduplication. If the query exactly matches a copied URL, keep both `Open copied link` first and the explicit web action last, even when both have the same browser-input destination; duplicate ordinary rows for that destination remain suppressed. This exception was approved on 2026-10-02 and does not change URL/query classification or history-recording behavior.

Empty query behavior remains limited to the current restrained suggestions and history; it does not list the Library as a catalog.

#### Failure behavior

- Library projection failure or absence degrades to today's search suggestions.
- Offline operation is unchanged because matching is local.
- A removed series selected from a stale result attempts the normal local route; if no detail exists, Library shows its existing recoverable state rather than opening a web search.
- Search-history recording applies only to browser inputs. Opening a saved Library result does not create a fake web-history row.

### 6.4 Bounded pinch zoom in the long-strip Reader

#### Chosen approach

Keep the existing SwiftUI `ScrollView` and `LazyVStack` as the sole vertical-scroll owner. Add a `ReaderZoomState` and a focused `ZoomableReaderContent` modifier around the rendered strip rather than nesting a second `UIScrollView` or replacing the Reader with a nonlazy hosted stack.

This choice preserves lazy page creation, progress visibility callbacks, stable scroll restoration, and the current reader chrome. A full UIKit collection/zoom rewrite would be disproportionate to the MVP interaction.

#### State model

`ReaderZoomState` owns only transient interaction state:

- committed scale and in-progress magnification;
- gesture focal anchor;
- committed and in-progress translation;
- viewport and rendered-content geometry used for clamping.

Scale is clamped to `1x...3x`. Translation is clamped so content cannot be permanently moved beyond the viewport. The model is pure and unit-testable.

#### Gesture behavior

- At `1x`, the existing vertical ScrollView remains enabled and owns drag gestures.
- A magnify gesture uses its start anchor to keep the focal area under the user's fingers.
- Above `1x`, normal chapter scrolling is temporarily disabled and drag pans the scaled content in both axes.
- Returning to `1x` zeroes translation and immediately restores vertical scrolling at the prior chapter position.
- A spatial double tap at `1x` zooms to `2x` around the tap location.
- A double tap at any zoomed scale returns to `1x`.
- The single-tap chrome gesture is made mutually exclusive with double tap so one double tap does not toggle chrome twice.
- Changing `session.id`, navigating to an adjacent chapter, or dismissing Reader resets zoom.

Zoom applies to the rendered strip only. Reader chrome remains fixed and usable. Canvas, page order, placeholder aspect ratios, settings, and progress data are unchanged.

#### Accessibility and reduced motion

- When zoom is above `1x`, chrome exposes an accessibility-labeled `Reset Zoom` action.
- VoiceOver users do not need to perform a pinch to recover the default view.
- Reset animation is disabled under Reduce Motion.
- Zoom state changes do not post reading progress or settings writes.

### 6.5 Operational Library sorting and source filtering

#### Domain model

Add presentation-only values:

```swift
public enum LibrarySortKey: String, CaseIterable, Sendable {
    case activity
    case title
    case unreadUpdates
}

public enum LibrarySortDirection: String, CaseIterable, Sendable {
    case ascending
    case descending
}

public struct LibraryCollectionQuery: Equatable, Sendable {
    public var segment: LibrarySegment
    public var sortKey: LibrarySortKey
    public var sortDirection: LibrarySortDirection
    public var sourceDomains: Set<String>
}
```

`LibraryCollectionQuery.apply(to:)` is a pure function that:

1. obtains the existing segment projection;
2. normalizes and applies selected source domains;
3. applies a stable sort;
4. uses normalized title and UUID as deterministic tie-breakers.

Activity uses the best available `lastReadAt`/update signal without writing a synthetic date. Title supports both directions. Unread Updates defaults to unread-first; the direction control is hidden for that key because a reversed “read first” order has no clear user value.

#### Source values

- Available filters are derived from normalized `sourceDomain` values in the complete current Library snapshot, not a built-in list.
- Display labels retain readable host text while identity uses the existing domain normalizer.
- Multi-select is supported; an empty set means All Sources.
- When a stored source no longer exists, it is removed from the effective query and persisted preferences are repaired on the next write.

#### Preferences and UI

Extend `LibraryViewPreferences` to persist:

- selected segment;
- sort key;
- direction where applicable;
- selected normalized source domains;
- existing view density.

The default is Recent, activity descending, all sources, and the user's current density. A Reset action restores those values without changing any Library record.

Library controls present sort and source filters as secondary collection tools that compose with lifecycle segments and density. If the unfiltered segment contains items but the query produces none, the empty state explains that filters are active and exposes Reset. A genuinely empty segment retains the existing empty-state semantics.

#### Repository boundary

Sorting and filtering occur over the lightweight `LibrarySnapshot` in the feature/domain layer for this MVP. No new repository query API is needed. This keeps behavior identical for persistent and mock repositories and avoids persisting view concerns into series records.

### 6.6 Local search-history controls

#### Protocol evolution

Replace the narrowly named injected dependency with a management contract:

```swift
public protocol SearchHistoryManaging: SearchHistoryRecording {
    func removeSearchHistory(id: UUID) async throws
    func clearSearchHistory() async throws
}
```

`AppDependencies.searchHistoryRecorder` becomes `searchHistoryManager`. The SwiftData repository and an in-memory mock implement the full contract. Call sites that only record may still accept `SearchHistoryRecording` where appropriate.

#### Repository behavior

- `removeSearchHistory(id:)` deletes exactly the matching `StoredSearchHistory` row.
- `clearSearchHistory()` fetches and deletes only `StoredSearchHistory` rows, then performs one save.
- Neither operation touches series, chapters, progress, recent reading, cache metadata, files, cookies, or website data.
- In-memory repository behavior mirrors persistent behavior for tests and previews.
- If save fails, the operation throws and the UI retains/reloads the previous visible state.

No schema migration is required because existing records already have UUID identifiers.

#### Search UI

`SearchOverlayViewModel` exposes delete only for persisted recent-link and recent-search results. A visible trailing action and the equivalent accessibility action remove one item. After success, local state updates immediately and suggestions are recomposed. On failure, the row remains and inline nonblocking feedback offers retry.

Clipboard, common-site, Library, and generic search suggestions cannot be deleted as history.

#### Settings UI

Settings receives the same `SearchHistoryManaging` dependency and adds a Local Data section with `Clear Search History`. The destructive action requires confirmation and clearly states that Library, progress, downloads, cookies, and website data are unaffected. Success/failure feedback is local to the section. Cancel performs no operation.

### 6.7 Rendering-pattern compatibility validation

Best-effort support is validated by capability class, not by accumulating named-site promises. Add a maintained compatibility matrix and sanitized fixtures for embedded HTML, lazy/hydrated DOM, browser-session hydration, relative and protocol-relative sources, `srcset`, CDN/request-context delivery, advertisement and thumbnail negatives, challenge/auth/paywall/error hard blocks, protected canvas/blob viewers, and unsupported pagination.

Each fixture must declare its expected parser path, entry disposition, ordered candidate count, adjacent-link behavior, and whether Reader presentation is allowed. Fixture tests run through the same `PageAnalysisScript` payload model, `ProfileAwareChapterDetector`, and Browser presentation policy used by production. Unknown fixture domains must demonstrate that the generic path is the default rather than a named-profile allowlist.

The matrix records `covered`, `partial`, or `unsupported-by-policy` per capability. It must not claim that a passing fixture guarantees an entire live domain.

### 6.8 Live-device compatibility validation

Use a bounded, replaceable sample of user-opened long-strip pages to validate the production Browser → Detection → Reader → View Original Page flow on a supported iPhone. The sample is chosen for rendering diversity, not brand coverage. Record the observation date, capability class, result, failure category, image-order/loading result, navigation preservation, and whether a sanitized regression fixture was captured.

Live findings may identify domains in the internal research catalog and QA evidence, but named sites do not enter the PRD, Search suggestions, onboarding, or product claims. Authentication, paywalls, anti-bot challenges, protected viewers, and paginated chapters remain Browser-only. Any discovered failure must be classified as a generic extractor gap, an adapter opportunity, an unsupported policy case, or an external/transient failure before code changes are proposed.

## 7. Cross-cutting interface changes

The expected contract changes are:

- `DetectionResult.readerEntryDisposition: ReaderEntryDisposition`
- one centralized detection threshold/policy value used by generic and profile-aware paths;
- `LibrarySearchProviding.librarySearchItems()`
- `SearchSuggestionDestination` and a saved-library suggestion kind/presentation;
- `SearchHistoryManaging` plus dependency-injection rename;
- `ReaderPageAssetLoading`, `ReaderImageDecoding`, and chapter-scoped `ReaderPagePipeline`;
- `LibraryCollectionQuery`, sort types, and expanded `LibraryViewPreferences`;
- transient `ReaderZoomState` with no persistence dependency.
- a capability-matrix fixture manifest consumed by parameterized detection/browser tests; no production dependency on the manifest.

Compatibility initializers/defaults may be retained temporarily for tests and previews, but production composition must inject the new complete contracts. No view may instantiate a SwiftData repository or URLSession-specific implementation directly.

## 8. Persistence and migration

### SwiftData

No model schema changes are planned.

- Library search reads projections from existing series records.
- History deletion deletes existing `StoredSearchHistory` rows.
- Reader prefetch does not introduce a database record.
- Zoom has no persisted state.

### UserDefaults

Library preference keys are additive and namespaced under `ToonEdge.Library`. Missing or invalid values fall back independently rather than invalidating the entire preference set. Source-domain arrays are sanitized against the current snapshot.

### File cache

The existing file-backed chapter cache remains the only persistent image store. Prefetch does not imply offline retention. Explicit Retain Chapter behavior remains unchanged.

## 9. Concurrency and performance

- `ReaderPagePipeline` is an actor; page-state publication crosses to the main actor in bounded updates.
- Fetch/decode concurrency is capped at three per chapter, including retries.
- Search loads Library and history projections concurrently once per overlay presentation and ranks in memory.
- Library sort/filter is linear filtering plus `O(n log n)` stable sorting over the lightweight snapshot; no detail hydration or per-cell tasks are introduced.
- Search-history writes remain serialized by the existing repository actor/main-context boundary.
- Chapter/session identity is checked before publishing asynchronous results to prevent stale updates.

Performance verification uses realistic 25+ image fixtures and a collection large enough to reveal ranking/filter regressions. Device verification targets the smallest supported iPhone class as well as iPhone 16 Pro.

## 10. Error handling and user trust

| Failure | Required outcome |
|---|---|
| One reader page fails | Preserve geometry and canvas; show page-local retry; keep other pages usable |
| Prefetch is canceled | No user-facing error and no stale state publication |
| Manual Clean Mode is unavailable or preflight fails | Keep exact browser page/history and show nonblocking explanation |
| Library search projection fails | Preserve existing web/history/site suggestions |
| Selected saved result disappears | Route to recoverable Library state; never silently web-search it |
| Zoom gesture ends outside bounds | Clamp to recoverable scale/translation; Reset always available |
| Stored source filter is obsolete | Drop obsolete value and show available collection |
| History deletion fails | Keep/reload visible history and provide retryable feedback |

Diagnostics must not log full URLs, query strings, search text, titles, cookie values, or reading-history content. Counts, page indexes, sanitized hosts already approved by diagnostics policy, disposition, failure category, and task timing are sufficient.

## 11. Testing strategy

### Unit tests

**Reader pipeline**

- visible/two-ahead/one-behind scheduling;
- maximum concurrency of three;
- priority reversal, session replacement, disappearance, and memory-pressure cancellation;
- decoded-memory then file-cache then network order;
- duplicate request coalescing;
- decode failure and isolated retry;
- no progress advance before ready content becomes visible.

**Detection and Browser**

- threshold boundaries at 44, 45, 54, 55, 77, and 78;
- candidate-count/height viability constraints;
- every hard-block class maps to unavailable;
- disposition-to-automatic/CTA/manual/no-action presentation;
- stale disposition reset on navigation;
- failed manual attempt preserves Browser state.

**Search**

- exact, prefix, token, diacritic, punctuation, and case normalization;
- ranking and deterministic tie-breaking;
- typed destination deduplication;
- Library routing versus browser routing;
- no history row for native Library selection;
- graceful behavior without Library data.

**Zoom**

- scale and translation bounds;
- focal-anchor calculation;
- double-tap transitions;
- `1x` scroll ownership;
- session-change reset;
- Reduce Motion reset behavior.

**Library**

- every segment/sort/source combination;
- stable ordering with nil dates and equal titles;
- multi-source normalization and obsolete-value repair;
- preference round trip and invalid-value fallback;
- active-filter versus genuine-empty semantics.

**History**

- delete-one and clear-all persistence;
- nonexistent-ID behavior;
- save failure behavior;
- proof that Library, progress, recent reading, cache metadata, and settings remain unchanged.

**Generic compatibility**

- parameterized positive fixtures for embedded, hydrated, and browser-session image delivery;
- relative URL, protocol-relative URL, `srcset`, lazy-attribute, ordering, and request-context cases;
- negative fixtures for ads, thumbnails, challenges, authentication/paywalls, errors, protected viewers, and pagination;
- generic unknown-domain routing without a registered profile;
- manifest completeness so every fixture declares an expected outcome.

### Integration and UI tests

- delayed 25+ page fixture: rapid scroll, stable placeholders, page-local failure, retry;
- manual-only Browser result: tool action, Reader presentation, View Original Page;
- hard-blocked fixture: no manual action;
- Home Search saved-title result to seeded/local-first Series Detail while offline;
- pinch, pan, reset, continued vertical reading, and adjacent-chapter reset;
- Library segment plus source filter with Reset from filtered empty state;
- individual history deletion and Settings clear-all after relaunch;
- capability-diverse live-device Browser → Reader → View Original flows with dated internal evidence;
- VoiceOver labels, Dynamic Type layouts, 44-point actions, contrast, and Reduce Motion regressions.

Existing detection false-positive, navigation, progress, cache, update, persistence, accessibility, and source-policy tests remain regression gates.

## 12. Delivery boundaries and dependency order

The later epic should keep one story per product slice and two separate validation stories. Within shared surfaces, use this order:

```text
Reader track:   continuity/prefetch -> zoom
Search track:   Library matches -> history controls
Browser track:  manual Clean Mode (independent)
Library track:  sort/source filter (independent)
Validation:     pattern fixture matrix -> live-device evidence
```

Reader prefetch comes before zoom because zoom must render pipeline-owned page state. Library search comes before history controls because both introduce `SearchOverlayViewModel` and typed suggestion composition; doing them in that order avoids building the overlay state owner twice.

Pattern validation should land after the manual Clean Mode disposition is available so fixtures can assert the complete entry policy. Live-device validation is the final release gate after all six product slices and the fixture matrix are complete.

No story may be called complete until its vertical behavior, error state, protocol/mock wiring, unit tests, integration coverage where feasible, and regression suite are all present.

## 13. Alternatives considered

### Keep independent per-page loaders

Rejected. It cannot reliably enforce chapter-wide priority, duplicate suppression, cancellation, or concurrency limits.

### Persist every prefetched page to the offline cache

Rejected. Speculative reading and explicit offline retention have different user intent and lifecycle rules. Prefetch remains memory-scoped unless an existing recent-cache policy owns persistence.

### Let Browser infer manual eligibility from score

Rejected. Browser would duplicate detection policy and could accidentally bypass hard blocks. Detector output must be authoritative.

### Search SwiftData on every keystroke

Rejected for MVP. A lightweight projection loaded once gives immediate local ranking and avoids query churn while the user types.

### Wrap the existing long strip in a second zooming `UIScrollView`

Rejected. Nested scroll ownership creates gesture conflicts and risks defeating `LazyVStack` behavior. The proposed transform keeps one vertical-scroll owner.

### Sort/filter in the repository

Deferred. The current local snapshot is already the correct lightweight boundary, and presentation sorting requires no database mutation or detail fetch. Repository predicates can be introduced later if measured collection scale requires them.

### Clear all browser website data with search history

Rejected. The requirement is deliberately narrow. Cookies and website data have different consequences and must not be silently coupled to personal search-history deletion.

## 14. Review decisions requested

Approval is requested for the following implementation decisions:

1. Align detector entry thresholds with the Architecture document (`>=78`, `55...77`, `45...54`) and make disposition explicit.
2. Use a chapter-scoped actor with three-operation concurrency and a default current/two-ahead/one-behind working set.
3. Keep network-prefetched images memory-scoped rather than treating them as explicit offline downloads.
4. Load a lightweight Library search projection once per Search presentation and rank it locally.
5. Implement zoom as a transient transform around the existing lazy strip, with vertical scroll paused only while zoomed.
6. Apply Library sort/filter in a pure snapshot query and persist only the presentation preferences.
7. Limit history clearing strictly to `StoredSearchHistory`.
8. Validate best-effort compatibility by rendering pattern; keep named-domain observations internal and out of product claims.

After this design is approved or amended, the next deliverable will be one epic, eight appropriately scoped stories, and a separate executable implementation plan for each story.
