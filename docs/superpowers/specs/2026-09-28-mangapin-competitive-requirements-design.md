# MangaPin Competitive Review and ToonEdge Requirements

**Date:** 2026-09-28

**Status:** Approved product requirements

**Decision model:** Evidence-led selective parity

**Scope:** MVP recommendations plus a separate post-MVP opportunity backlog

## 1. Executive decision

ToonEdge should not pursue feature-count parity with MangaPin.

MangaPin validates the central ToonEdge premise: readers value a browser that can turn many web chapter pages into a consistent reading experience, remember progress, organize a personal library, and preserve access when a source changes. Its strongest competitive features are its broad reader controls, deep tracking metadata, source-aware library tools, offline chapter selection, and flexible organization.

ToonEdge already has a stronger foundation in several areas:

- conservative, explainable detection with explicit hard blocks;
- a native reader separated from browser and parsing responsibilities;
- origin-aware navigation and a reliable path back to the source page;
- local-first persistence without an account requirement;
- explicit site support tiers instead of an unsupported “works everywhere” promise;
- accessible native controls, Dynamic Type coverage, and reduced-motion behavior;
- typed failure handling and fixture-backed regression coverage.

The recommended MVP response is therefore narrow:

1. eliminate reader loading instability before adding more reader modes;
2. expose a safe manual Clean Mode fallback when automatic confidence is insufficient;
3. include saved-library matches in universal search;
4. add bounded pinch zoom without adding a large settings surface;
5. complete the already-required Library sorting and source filtering behavior;
6. add local search-history deletion controls.

Everything else observed in MangaPin belongs in the post-MVP backlog or should be deliberately rejected.

## 2. Research method and evidence

### 2.1 Hands-on review

MangaPin was reviewed through iPhone Mirroring on an iPhone 16 Pro on 2026-09-28. The following flows were exercised:

- Home and its configurable widgets
- universal search and search-result routing
- browser chrome and browser actions
- automatic/manual reader presentation
- long-strip reader behavior and settings
- Reading, Paused, Plan, Completed, and Dropped library states
- library sort and source filters
- entry information and tracking metadata
- per-entry chapter downloads
- global Downloads and Queue surfaces
- Upcoming Updates prediction
- Statistics, Notes, and Custom Lists
- premium sync affordances

The initial review intentionally did not purchase a subscription, create an account, delete user data, change reader defaults, or alter library membership. It added `solo leveling` to recent search history and refreshed the last-read timestamp for an existing title. A later user-authorized validation added one Asura title to the Reading library, as documented below.

One important observation requires qualification: manually invoking MangaPin reader mode on a Google results page produced a 15-image reader. Because the action was manually requested, this is not evidence that MangaPin would auto-open a false-positive result. It does demonstrate why ToonEdge's automatic hard blocks and a clearly labeled manual fallback should remain separate behaviors.

#### End-to-end Asura flow validation

A separate search-to-library flow was completed with the previously unsaved Asura title *The Hero Cannot Rest*:

1. The Asura series page was inspected first to confirm that MangaPin showed `Add to library`, rather than an existing saved state.
2. From MangaPin Home, the exact title was entered into universal search.
3. Search offered Google, Asura-specific search, and the exact Asura page from local history. The exact result opened the source series page. The Asura-specific search row did not activate through taps or Return during the mirrored session, so that interaction remains unverified rather than being classified as defective.
4. `First Chapter` opened Chapter 1. After the source page settled, MangaPin automatically entered Reader Mode with 36 detected images.
5. Reader initially showed unloaded/broken-image placeholders briefly before the first image resolved. The chapter then rendered in long-strip mode with page progress and reader controls.
6. The Reader add action opened a save form with lifecycle folder, translated language, current chapter, and start-date fields. Defaults were `Reading`, `English`, and `Ch.1`.
7. Saving immediately created the entry. The item detail showed Asura as the source, Chapter 1, Reading state, English, and the current date.
8. Home placed the cover first in its Library widget, and the Reading collection count increased from 48 to 49 with the title first in recent order.

This validates that MangaPin's core acquisition loop is cohesive: web discovery, automatic conversion, progress-aware save defaults, and immediate collection feedback all share one browser session. ToonEdge already implements the same essential lifecycle with fewer metadata decisions: Reader-originated saves default to Reading, canonical series identity is retained, progress persists, and the saved series routes into native Library/Series Detail. The remaining ToonEdge opportunity is not a new save model; it is making saved titles discoverable from universal search and maintaining stronger loading stability during conversion.

### 2.2 Public evidence

Sources reviewed:

- [MangaPin App Store listing](https://apps.apple.com/us/app/mangapin/id6466486279)
- [MangaPin product website and FAQ](https://mangapin.com/)
- App Store reviews and version history visible on 2026-09-28

The App Store listed MangaPin 6.11.0, a 4.9 rating from approximately 5.6K US ratings, iOS/iPadOS 15.6 support, and monthly and annual subscriptions. Public product claims include reader mode, library management, ad blocking, progress and update tracking, offline downloads, external trackers, import, bulk source migration, statistics, cloud backups, and multi-device sync.

Review evidence is directional rather than statistically complete. Recurring themes included:

- praise for browser-based access across multiple sites;
- praise for automatic progress, page-level resume, zoom, notes, and reader consistency;
- praise for surviving source changes through migration;
- complaints about reader-mode incompatibility on some pages;
- complaints about image-by-image flashes or delayed loading;
- reports of update/notification or chapter-order problems;
- a severe report of library loss during guest-to-premium migration.

### 2.3 ToonEdge baseline

The comparison used the repository at commit `0689970` and the following sources of truth:

1. `docs/toonedge_architecture_doc.md`
2. `docs/toonedge_prd.md`
3. `docs/toonedge_ux_requirements_doc.md`
4. `docs/toonedge_ux_brief.md`
5. `docs/toonedge_epics_and_stories.md`

Implementation claims were checked against production code and tests. `swift test` passed all 358 tests on 2026-09-28. A passing package suite is evidence for business logic and component contracts, not a substitute for final device UI, network, performance, or App Store review testing.

## 3. Capability comparison

Status meanings:

- **Verified:** present in current production code with relevant automated coverage.
- **Partial:** meaningful implementation exists, but the compared behavior is incomplete.
- **Specified:** required by product documents but not fully exposed in the current implementation.
- **Absent:** neither implemented nor required today.

| Capability | MangaPin observation | ToonEdge baseline | Assessment |
|---|---|---|---|
| Product model | Manga-focused web browser with reader, tracking, source shortcuts, account, and premium sync | Smart reading browser with a local-first personal library; not a catalog | Preserve ToonEdge's narrower positioning |
| Universal URL/query entry | Single top field; searches Google or a selected site | **Verified:** scoring-based URL/query classification and Google browser requests | Equivalent core behavior |
| Search suggestions | All, History, Sites, Library, and Recent categories; site-targeted search actions | **Verified:** clipboard/recent-link/recent-search/common-site/search-action model; no Library result type | Add local Library matches without adding source promotion |
| Browser | Back, forward, reload, home, reader action, per-site controls | **Verified:** single `WKWebView`, back/forward/reload, state preservation | ToonEdge intentionally excludes tabs and keeps one visible context |
| Ad/popup protection | User-visible ad blocker, redirect controls, per-site option | **Verified but quiet:** sanitizer script and third-party target-window popup policy | Do not build a full filter-list product for MVP; retain tested protection |
| Automatic reader detection | Broad automatic support claim with manual fallback | **Verified:** profile-first and generic heuristics, confidence thresholds, hard blocks, delayed SPA follow-up | ToonEdge is stronger on trust and explainability |
| Manual reader fallback | Browser command can force a reader attempt | **Partial:** medium-confidence CTA is implemented; no persistent low-confidence `Try Clean Mode` action | Close the gap with guarded manual fallback |
| Original-page escape | Reader can hide reader mode or open externally | **Verified:** exact original page plus origin-aware back behavior | ToonEdge is clearer and more deterministic |
| Long-strip reading | Supported, with continuous vertical mode | **Verified:** lazy native vertical strip with aspect-ratio placeholders | Equivalent core mode |
| Reader layout modes | Long strip, single page, double page; vertical, left-to-right, right-to-left | **Absent by design:** fit-width and fit-screen only; product is manhwa-first | Keep paginated modes post-MVP |
| Zoom | Pinch zoom, optional double-tap zoom, percentage control | **Absent:** fit modes only | Add bounded pinch zoom to MVP |
| Reader personalization | Global defaults plus per-title preferences, gap sizes, progress thickness, auto-next, hide-controls policy, tap zones, autoplay speed | **Verified core only:** canvas, fit, spacing, brightness; global persistence | Keep current simplicity; evaluate per-series overrides post-MVP |
| Reader loading stability | Existing-title sample loaded correctly; the fresh Asura flow briefly showed broken-image placeholders before resolving, and reviews report panel delays and flashes | **Partial:** aspect-ratio placeholders, retry, cache, and lazy loading exist; no bounded ahead-of-scroll prefetch coordinator | Add continuity/prefetch requirement before more reader modes |
| Progress and resume | Automatic chapter/page progress and recent reading | **Verified:** source-keyed progress, restoration, recent activity, throttled writes | Equivalent, with stronger repository tests in ToonEdge |
| Save from Reader | Reader action opens a progress-aware form; the tested Asura title defaulted to Reading, English, and Chapter 1 and appeared immediately in Library | **Verified:** Reader save defaults to Reading, persists canonical series/progress data, and supports native Library/Series Detail routing | Equivalent core lifecycle; ToonEdge is intentionally simpler |
| Adjacent chapters | Visible previous/next controls and chapter selector | **Verified:** explicit links, numeric fallback, hidden extraction, typed failure handling, preserved launch context | ToonEdge is stronger on safe fallback behavior |
| Library states | Reading, Paused, Plan, Completed, Dropped | **Verified:** Recent, Reading, Planned, Dropped, Completed; persisted lifecycle states | Equivalent; `Paused` is not required separately for MVP |
| Library density | Three-column grid and status tabs | **Verified:** comfortable, compact, and list modes | ToonEdge offers stronger native presentation flexibility |
| Library sort/filter | Name, recent, score, dates, ascending/descending, and source filters | **Specified/partial:** status segments and view modes exist; operational sort/source filtering does not | Complete existing Story 7.6 behavior |
| Series/entry details | Status, source, chapter, language, score, note, start/finish dates, rereads, tags | **Verified core:** source, cover, progress-aware primary action, chapter states, downloads; rich personal metadata absent | Notes/ratings/tags belong post-MVP |
| Offline downloads | Select chapters per entry, queue, total bytes, bulk selection | **Verified core/partial breadth:** retain current chapter, recent cache, storage measurement, removal, offline restoration; no batch queue | Current MVP meets scope; batch queue is post-MVP |
| Update tracking | Updates plus predicted upcoming release dates and notifications | **Verified core:** manual foreground checks, badges, failure preservation, latest-chapter comparison | Keep predictions/background notifications post-MVP |
| Notes | Per-entry notes plus notes manager | **Absent** | Post-MVP |
| Statistics | Chapters and reading hours plus state counts | **Absent** | Post-MVP; avoid vanity metrics in MVP |
| Custom organization | Lists, tags, pinned entries, editable title/cover | **Absent** | Post-MVP after core library scale warrants it |
| Source migration | Per-entry and bulk migration between sites | **Absent** | High-value post-MVP resilience feature |
| External trackers | Import and one-way sync with AniList, MyAnimeList, and MangaUpdates | **Absent** | Post-MVP; requires account, mapping, and conflict policy |
| Cloud backup/sync | Premium account, backup, and multi-device sync | Explicitly outside MVP; local-first persistence is **Verified** | Do not add until export, rollback, and migration integrity are proven |
| Home customization | Reorder/hide widgets and add shortcuts | **Absent**; ToonEdge Home hierarchy is intentionally fixed | Post-MVP at most; fixed search-first hierarchy is preferable now |
| Privacy | App Store disclosure includes linked contact info, user content, browsing history, and diagnostics | Local-first data model with no required account | ToonEdge differentiation; add local history deletion controls |
| Accessibility | App Store listing declares no supported accessibility features | **Verified foundation:** semantic labels, minimum action sizes, Dynamic Type and reduced-motion coverage | ToonEdge advantage; preserve across all additions |

## 4. Existing completed ToonEdge requirements

The following areas should not be reopened merely to mimic MangaPin. They already satisfy the product requirement or deliberately exceed the competitor behavior.

### 4.1 Search and browser

- URL/query classification is scoring-based and tested against schemes, domains, IPv4, localhost, spaced phrases, and malformed HTTP input.
- Google query routing and direct URL routing are implemented.
- Persisted recent searches and links are incorporated into local-first suggestions.
- Browser navigation state, back, forward, reload, and reader-over-browser preservation are implemented.
- Common ad and popup surfaces are sanitized, and third-party target-window popups are blocked by policy.
- Browser tabs remain explicitly outside MVP and should stay excluded.

### 4.2 Detection and trust

- Site-profile and generic detection paths are separate and testable.
- High, medium, and low confidence behaviors exist.
- Search, listing, challenge, paywall, protected-viewer, and stock-image false positives have defensive coverage.
- Approved non-promoted sites can work when explicitly opened without becoming a built-in catalog.
- Diagnostics record parser path and confidence without logging full sensitive URLs.

This is a meaningful advantage over MangaPin's broad compatibility promise. ToonEdge should market reliable boundaries rather than claim unlimited site support.

### 4.3 Reader and navigation

- Native long-strip rendering, canvas choices, fit modes, page spacing, and brightness aid are implemented.
- Chrome begins hidden and toggles from the reading surface.
- Exact source-page return and launch-origin-aware back behavior are implemented.
- Previous/next navigation uses stored payloads first, then guarded hidden extraction, with typed failures and safe original-page fallback.
- Progress is restored and persisted without advancing on unloaded placeholders.
- Aspect-ratio placeholders prevent large layout jumps when page dimensions are available.

### 4.4 Library, persistence, updates, and offline data

- SwiftData-backed series, chapter, progress, recent-reading, search-history, and cache metadata are wired through repository protocols.
- Reading, Planned, Dropped, and Completed state transitions persist.
- Continue Reading, Recently Updated, update badges, source metadata, and progress-aware Series Detail actions are implemented.
- Library supports comfortable, compact, and list presentations.
- Manual update checks preserve known state on partial failure and compare numeric and decimal chapter labels conservatively.
- Recent cache and retained offline data are distinct, measured, removable, and restorable.

### 4.5 Quality and accessibility

- The package suite currently passes 358 tests.
- Existing tests cover detection false positives, browser popup policy, persistence, progress restoration, adjacent chapters, update comparison, cache lifecycle, minimum hit targets, contrast, Dynamic Type-related layouts, and reduced motion.
- New requirements below must extend these guarantees rather than introduce alternate implementations around them.

## 5. MVP requirements

### MVP-1 — Reader visual continuity and bounded prefetch

**Priority:** P0

**Type:** New hardening requirement

**Affected modules:** Reader, Cache/Downloads, Shared loading infrastructure

#### Rationale

Reader consistency is the product's primary value. MangaPin reviews specifically identify delayed panel loading and full-screen flashes as reasons to abandon a reading session. ToonEdge already preserves placeholder geometry and retries failed pages, but each visible panel owns an independent lazy loader and there is no explicit ahead-of-scroll policy.

#### Requirements

- The Reader must prefetch and decode two pages ahead of the current visible page and retain one recently visible page behind it as the default window.
- No more than three page fetch/decode operations may be active concurrently; memory pressure may reduce the window but must not expand it.
- Prefetch work must occur off the main actor except when publishing UI state.
- The window must cancel or reprioritize when the user changes chapter, leaves Reader, reverses direction substantially, or memory pressure requires reduction.
- A loading transition must retain the selected reader canvas; it must never flash an unrelated white or black full-screen surface.
- Known page dimensions must reserve final layout height before decoded image display.
- A failed page must preserve its space, identify the page, and offer an isolated retry without resetting the chapter.
- Progress must continue to advance only after a successfully loaded page becomes visible.
- Prefetch must reuse retained or recent cached assets before requesting the network.

#### Acceptance criteria

- A fixture chapter with at least 25 images can be scrolled continuously without full-canvas flashes or scroll-position jumps.
- Network requests remain bounded to the configured visible-plus-prefetch window.
- Leaving the chapter cancels outstanding nonessential prefetch work.
- Cached pages do not issue duplicate network requests.
- Failure of one page does not blank, reload, or dismiss the reader.
- Unit tests cover ordering, cancellation, cache-first behavior, bounded concurrency, and isolated failure.
- A device UI/performance test covers rapid scrolling on the smallest supported iPhone class.

### MVP-2 — Guarded manual `Try Clean Mode` action

**Priority:** P0

**Type:** Completion/refinement of Epic 4 Story 4.5 and Architecture 9.5.4

**Affected modules:** Browser, Detection, Reader coordination

#### Rationale

MangaPin provides a manual fallback when automatic reader mode does not appear. ToonEdge currently exposes the medium-confidence CTA, but a low-confidence page with a viable candidate session has no persistent browser action. A guarded manual attempt improves recoverability without weakening automatic trust thresholds.

#### Requirements

- Browser tools must expose `Try Clean Mode` when detection produces a viable reader candidate in the existing manual-only score band of `45...54`.
- The action must be visually secondary and must not resemble an automatic recommendation.
- Manual attempts may use the existing lower manual threshold, but must never bypass challenge, authentication, paywall, DRM, canvas/blob, protected-reader, error-page, or other hard blocks.
- If no viable session can be created, Browser must remain on the exact page and show a non-blocking explanation.
- Automatic high-confidence and medium-confidence behavior must remain unchanged.
- The original browser page and navigation history must remain intact after both successful and failed attempts.

#### Acceptance criteria

- Scores in the configured manual-only band expose `Try Clean Mode` but do not show the primary CTA or auto-open Reader.
- Hard-blocked pages never expose or honor the manual action.
- A failed attempt leaves Browser usable and does not present an empty Reader.
- A successful attempt uses the same normalized `ReaderSession` and source escape hatch as automatic entry.
- Tests distinguish automatic, recommended, manual-only, and hard-blocked states.

### MVP-3 — Saved-library matches in universal search

**Priority:** P1

**Type:** New search requirement

**Affected modules:** Search, Library repository, App routing

#### Rationale

MangaPin's search can query web history, sites, recent activity, and the saved library from one field. ToonEdge's universal search is correctly web-first, but omitting saved titles makes users leave the highest-priority entry point to resume a known series.

#### Requirements

- Universal search must query saved series locally while the user types.
- Matching must be case-insensitive and support title prefix plus token containment.
- Results must be local-only, immediate, and independent of network availability.
- A library result must be visibly labeled as saved content and show useful context such as state and resume chapter.
- Selecting a library result must open native Series Detail. It must not silently submit a web search.
- Library results must not displace an exact clipboard-link action or remove the explicit web-search action.
- Site suggestions must continue to respect support tiers; approved non-promoted sources must not become promoted search shortcuts.
- The empty query state must stay restrained and must not turn Home search into a catalog.

#### Acceptance criteria

- An exact clipboard-link action remains first. Exact saved-title matches appear next, followed by prefix/token library matches and the existing history/site suggestions; the generic web-search action remains visible.
- Partial token queries return deterministic, deduplicated results.
- Selecting a result opens Series Detail using the existing seeded/local-first route.
- Offline search returns the same saved results.
- Unsaved web queries still route to Google exactly as today.
- Tests cover ranking, deduplication, offline operation, and routing.

### MVP-4 — Bounded pinch zoom in Reader

**Priority:** P1

**Type:** New reader interaction

**Affected modules:** Reader UI only; no persistence schema change

#### Rationale

MangaPin users explicitly praise zoom and landscape flexibility. ToonEdge's fit modes are useful defaults but do not help with small lettering or detail inspection. Zoom is a core reading interaction, not a reason to copy MangaPin's large preferences surface.

#### Requirements

- Reader content must support pinch zoom from `1x` through `3x`.
- Zoom must center on the gesture focal area.
- When zoomed above `1x`, the user must be able to pan without losing the chapter's vertical position.
- Returning to `1x` must restore normal vertical scrolling immediately.
- Double tap must toggle between `1x` and `2x`; a double tap while at any other scale resets to `1x`.
- Chapter changes and Reader dismissal must reset transient zoom.
- Zoom must not alter saved progress, reader settings, image order, or page aspect ratio.
- VoiceOver users must retain an accessible reset action.

#### Acceptance criteria

- Pinch, pan, vertical scroll, chrome toggling, and progress restoration do not conflict at `1x`.
- Zoom is bounded and cannot lose content permanently off-screen.
- Moving to an adjacent chapter begins at `1x`.
- UI tests cover zoom/reset behavior on long-strip content.

### MVP-5 — Operational Library sorting and source filtering

**Priority:** P1

**Type:** Completion of an existing requirement, not a new product direction

**Affected modules:** Library, repository query/snapshot logic, view preferences

#### Rationale

The PRD and Story 7.6 already call for sorting and optional source filtering. Current code provides lifecycle segments and three view densities but not user-controlled ordering or source filters. MangaPin demonstrates that these controls become valuable once a library contains dozens of titles.

#### Requirements

- Library must support at minimum:
  - recently read/updated;
  - title;
  - unread update first.
- The user must be able to choose ascending/descending order where it is meaningful.
- Source filters must be derived only from domains already present in the user's library.
- Source filters must not become source recommendations, branded discovery shortcuts, or a hardcoded catalog.
- Status segment, sort order, source filter, and view density must compose predictably.
- A clear/reset action must restore the default Recent ordering and all sources.
- Sort, source-filter, and view-density preferences must persist locally. An obsolete source value must fall back safely when the last matching series is removed.

#### Acceptance criteria

- Sorting does not mutate persisted series metadata.
- Source values are deduplicated and normalized by canonical host.
- Filters update immediately and preserve the current segment.
- Empty filtered results explain that filters are active and provide Reset.
- Tests cover combinations of segment, sort, source, updates, and removed-source fallback.

### MVP-6 — Local search-history controls

**Priority:** P1

**Type:** New privacy/control requirement

**Affected modules:** Search, Settings, persistence protocol/repository

#### Rationale

ToonEdge persists recent searches and links but exposes no deletion contract. MangaPin's App Store disclosure includes browsing history linked to identity; ToonEdge should make its local-first difference tangible through direct user control.

#### Requirements

- Users must be able to delete an individual recent search or recent link from Search.
- Settings must provide `Clear Search History` with confirmation.
- Clearing search history must delete only stored search/link history; it must not remove Library entries, reading progress, downloads, cookies, or website data.
- The result must update visible suggestions immediately.
- Empty history must fall back to clipboard, permitted common-site, and explicit search actions without canned personal data.
- The application must not add an account, analytics upload, or remote history store for this feature.

#### Acceptance criteria

- Individual deletion is persistent across relaunch.
- Clear-all removes every `StoredSearchHistory` record and nothing else.
- Canceling confirmation has no effect.
- Tests verify repository isolation and immediate UI-model refresh.

## 6. MVP guardrails retained after comparison

The competitive review does not change these locked decisions:

- no built-in manga catalog or piracy-oriented source directory;
- no promoted shortcuts for approved non-promoted sources;
- no browser tabs;
- no cloud sync or required account;
- no external tracker integration;
- no predicted release dates or background notification system;
- no multi-page chapter stitching;
- no ML-based detection;
- no aggressive automatic Reader entry;
- no single-page/double-page manga reader modes in the manhwa-first MVP;
- no claim of universal or unlimited website compatibility.

## 7. Post-MVP opportunity backlog

The order below reflects expected reader value, architectural fit, and risk. It is not an implementation commitment.

### Tier A — Strong next candidates

#### PM-1 — Source migration and source health

Allow a saved series to adopt a replacement canonical source while preserving local status, progress history, and any future personal metadata. Include preview, confirmation, rollback, and duplicate detection. This addresses a proven user concern when sites disappear, but requires identity matching and must never become a source marketplace.

#### PM-2 — Per-series reader preference overrides

Allow a title to override a small subset of global reader defaults, initially fit mode and page spacing. Store only the delta from global settings and expose `Use Global Defaults`. Do not begin with MangaPin's complete matrix of tap zones, autoplay delays, and control-hiding modes.

#### PM-3 — Batch chapter downloads and visible queue

Add chapter selection from Series Detail, explicit queued/downloading/failed/completed states, bounded concurrency, retry, and storage estimates. Reuse the existing retention and file-backed cache contracts rather than introducing a second download store.

#### PM-4 — Portable local backup/export

Before cloud sync, provide a user-controlled export/import format for library metadata, progress, state, and settings. Validate schema version, preview changes, avoid destructive replacement by default, and retain rollback data until import succeeds.

### Tier B — Valuable after collection scale is proven

#### PM-5 — Notes and personal ratings

Add optional per-series notes and a simple rating. Keep both local-first and searchable. Avoid social reviews, public profiles, or community data.

#### PM-6 — Custom lists and tags

Allow user-created organization beyond lifecycle state. A series may belong to multiple lists, but lifecycle status remains singular. Add only after sorting/filtering telemetry or user research shows the default organization is insufficient.

#### PM-7 — Reading statistics

Offer transparent local statistics such as chapters completed and estimated reading time. Explain calculation rules, allow reset/correction, and never optimize the product around streak pressure.

#### PM-8 — Update notifications

Explore background refresh and opt-in notifications for confirmed new chapters. Respect iOS scheduling limits, avoid speculative predictions in notifications, and degrade cleanly to manual refresh.

### Tier C — High complexity or external dependency

#### PM-9 — External tracker import/export

Support explicit, user-initiated mapping with AniList, MyAnimeList, or similar services. Define one-way versus two-way behavior, conflict resolution, rate limits, deletion semantics, and credential storage before implementation.

#### PM-10 — Cloud backup and multi-device sync

Consider only after local export/import and schema migration are proven. Requirements must include transactional migration, conflict resolution, encryption, rollback, account deletion, offline edits, and tests demonstrating that sign-in or subscription changes cannot erase a local library.

#### PM-11 — Additional reading modes

Single-page, double-page, left-to-right, and right-to-left modes could support conventional manga. This expands ToonEdge beyond its manhwa-first focus and should be treated as a deliberate product expansion, not a reader-settings enhancement.

#### PM-12 — Per-site browser protection controls

Expose site-specific sanitizer, popup, and redirect exceptions only if real compatibility data demonstrates the need. Maintain safe defaults and never ask users to disable protections globally to make one source work.

#### PM-13 — Home customization

Allow restrained show/hide or ordering of secondary Home sections while permanently keeping universal search first. Avoid shortcut grids that turn Home into a source launcher.

## 8. Features not recommended

- **A source marketplace or built-in piracy catalog:** conflicts with the product definition and support-tier policy.
- **Unlimited-site compatibility claims:** create a trust promise the heuristic system cannot guarantee.
- **MangaPin-scale reader settings in MVP:** increases cognitive and QA cost without serving the primary long-strip use case.
- **Predictive release dates in MVP:** lower value than confirmed update accuracy and likely to create confusing false expectations.
- **Cloud sync before safe portable backup:** introduces the highest-impact data-loss failure mode observed in competitor feedback.
- **Novel/text reader support:** expands the content and rendering model beyond ToonEdge's mission.
- **Public/community lists, recommendations, or social features:** explicitly outside product scope.
- **Browser tabs:** explicitly outside MVP and unnecessary for the intended single-session flow.

## 9. Architecture and interface impact

The MVP additions should preserve current module boundaries.

### Search and Library

- Add a read-only library-search protocol rather than exposing SwiftData to Search UI.
- Add a `librarySeries` suggestion kind or a separate typed destination so selection can route to Series Detail instead of Browser.
- Extend the search-history protocol with narrowly scoped individual and clear-all deletion methods.
- Represent Library sort and source filter as domain values independent of SwiftUI controls.

### Browser and Detection

- Add an explicit presentation state for `manualOnly` eligibility rather than inferring it in the view.
- Detection remains authoritative for hard blocks and viable normalized sessions.
- Manual entry must reuse the existing browser-owned Reader path.

### Reader and loading

- Introduce a chapter-scoped prefetch coordinator that owns bounded tasks and reuses `ChapterAssetCaching` and request context.
- Keep individual page load state isolated so one failure cannot invalidate the chapter.
- Keep transient zoom state in the Reader view layer; do not persist it into `ReaderSettings`.

No new cloud service, account model, remote database, browser-tab model, or external tracker dependency is required for the MVP recommendations.

## 10. Error handling and trust requirements

- Manual Clean Mode failure leaves the exact browser page visible.
- Prefetch errors stay page-local and never dismiss Reader.
- Sort/filter errors fall back to the default local snapshot without mutating data.
- History deletion errors retain existing history and provide retryable feedback.
- All user-facing source behavior must distinguish confirmed capability from attempted compatibility.
- Protected or authenticated content must remain in Browser.
- New diagnostics must avoid full URLs, query strings, titles, or reading-history content unless explicitly sanitized.

## 11. Testing requirements

At minimum, add automated coverage for:

- library-title search ranking, deduplication, offline behavior, and native routing;
- manual-only detection state, successful manual conversion, hard blocks, and failed fallback;
- prefetch ordering, bounded concurrency, cancellation, cache hits, decode failure, and chapter replacement;
- reader zoom bounds, reset, gesture coexistence, and adjacent-chapter reset;
- Library segment plus sort plus source-filter combinations;
- individual and clear-all history deletion without collateral data loss.

Add UI or integration coverage for:

- Home search to a saved Series Detail result;
- low-confidence Browser to guarded manual Clean Mode;
- rapid scrolling through delayed-image fixtures with stable placeholders;
- pinch zoom followed by continued vertical reading;
- filtered Library empty state and Reset;
- history deletion followed by relaunch.

Run existing detection, source-policy, navigation, progress, cache, update, accessibility, and reduced-motion suites unchanged as regression gates.

## 12. Recommended delivery order

Each item should be delivered as a separate thin vertical slice.

1. **MVP-1 Reader continuity and prefetch** — protects the core promise and addresses the most damaging competitor complaint.
2. **MVP-2 Guarded manual Clean Mode** — improves recovery while preserving conservative automatic behavior.
3. **MVP-3 Saved-library search matches** — increases daily utility of the existing primary entry point.
4. **MVP-4 Pinch zoom** — adds a high-value reading interaction without settings sprawl.
5. **MVP-5 Library sort/source filter** — completes an existing requirement for larger collections.
6. **MVP-6 Local history controls** — completes the local-first trust story before release.

## 13. Success criteria for this requirements revision

This revision is successful when:

- the six MVP recommendations are accepted, rejected, or amended individually;
- accepted work is added to the epic/story breakdown without changing locked MVP exclusions;
- completed ToonEdge capabilities are not rebuilt solely for competitive parity;
- post-MVP ideas remain visibly separate from release commitments;
- source promotion and protected-content guardrails remain intact;
- each accepted MVP item receives its own implementation design, plan, tests, and verification pass.
