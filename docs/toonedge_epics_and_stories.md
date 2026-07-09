# ToonEdge Epics and Stories

**Product:** ToonEdge  
**Document Type:** Epics and Stories  
**Audience:** Codex agent, engineering planning  
**Version:** v1.1

## Planning principles
- Build in thin vertical slices
- Keep MVP boundaries strict
- Prefer working end-to-end slices over broad scaffolding
- Each story should be testable and reviewable on its own
- Favor stable interfaces and mock-backed flows before integrating real parsing/detection
- Treat Library as a first-class product surface, not just a saved-items list

---

## Epic 1 — Foundation and App Shell

### Goal
Create the base project structure, navigation shell, shared design system, and app scaffolding.

### Story 1.1 — Set up project structure
**Status:** resolved
**Acceptance criteria**
- App compiles and runs
- Feature modules/folders exist for Home, Browser, Reader, Library, Downloads, Settings
- Dependency injection pattern is in place
- Mock services can be injected cleanly

### Story 1.2 — Implement app shell and navigation
**Status:** resolved
**Acceptance criteria**
- Bottom navigation supports Home, Library, Downloads, Settings
- Navigation is stable
- Placeholder screens render correctly
- Browser/Reader full-screen presentation patterns are supported

### Story 1.3 — Implement design tokens and shared UI primitives
**Status:** resolved
**Acceptance criteria**
- Shared colors, spacing, typography, radius values are defined
- Reusable button, chip, card, segmented control, banner, and list row patterns exist
- Theme matches agreed dark-first direction

### Story 1.4 — Create root routing and modal presentation framework
**Status:** resolved
**Acceptance criteria**
- App can present full-screen Reader flow from Browser/Home/Library
- Search overlay presentation is supported
- Navigation state is centrally managed or clearly owned

---

## Epic 2 — Home and Search Entry

### Goal
Build the Home screen as a search-first reading hub.

### Story 2.1 — Implement populated Home layout
**Acceptance criteria**
- Home shows universal search bar, Continue Reading, Recently Updated, All Library
- Uses mock data
- Search bar is visually primary

### Story 2.2 — Implement empty-state Home
**Acceptance criteria**
- Empty-state layout prompts search or link paste
- Reuses same search entry pattern as populated Home

### Story 2.3 — Implement search bar interaction states
**Acceptance criteria**
- Idle, focused, typing, and suggestions states exist
- Keyboard and focus behavior are correct
- Search field visually communicates dual URL/search purpose

### Story 2.4 — Implement local suggestions model
**Status:** resolved
**Acceptance criteria**
- Suggestions show clipboard link, recent links, recent searches, and common/recent sites
- Suggestion ordering follows UX doc priority
- No network round-trip is required for base suggestions

### Story 2.5 — Implement input classification
**Status:** resolved
**Acceptance criteria**
- Input is classified as URL or search query
- Classification is tested
- Output is consumed by navigation flow

### Story 2.6 — Implement Home interactions
**Acceptance criteria**
- Tapping Continue Reading opens last-read chapter
- Tapping Recently Updated or library items opens Series Detail
- Pull-to-refresh hooks exist for later update integration

---

## Epic 3 — Browser Experience

### Goal
Create the in-app browser and route search/query inputs into it.

### Story 3.1 — Build browser screen shell
**Status:** resolved
**Acceptance criteria**
- Browser hosts `WKWebView`
- Back/forward/refresh work
- Address/search display is visible

### Story 3.2 — Support direct URL loads
**Status:** resolved
**Acceptance criteria**
- URL input opens correct page
- Navigation state updates properly

### Story 3.3 — Support query-based search results
**Status:** resolved
**Acceptance criteria**
- Query input opens search results in browser
- User can tap results and load destination page

### Story 3.4 — Implement supported-source result treatment
**Acceptance criteria**
- Search results can visually distinguish supported sources
- Unsupported sources remain openable
- Result rows match UX doc behavior

### Story 3.5 — Preserve browser state for return from reader
**Status:** resolved
**Acceptance criteria**
- Browser state remains available after Reader Mode opens
- Returning to original page is possible and stable

---

## Epic 4 — Detection Engine

### Goal
Detect chapter pages and convert them into structured reader payloads.

### Story 4.1 — Implement JS injection framework
**Status:** resolved
**Acceptance criteria**
- WebView can inject and run page-analysis scripts
- JSON payload can be returned to native layer

### Story 4.2 — Implement generic candidate image extraction
**Status:** resolved
**Acceptance criteria**
- Extract image candidates from rendered DOM
- Normalize lazy-loaded image sources
- Ignore obvious decorative/small assets

### Story 4.3 — Implement heuristic scoring engine
**Status:** resolved
**Acceptance criteria**
- Signals are scored
- Confidence is classified as high/medium/low
- Unit tests cover scoring logic

### Story 4.4 — Implement browser confidence behaviors
**Status:** resolved
**Acceptance criteria**
- High confidence auto-opens Reader Mode
- Medium confidence shows CTA
- Low confidence stays in browser

### Story 4.5 — Implement manual “Read in Clean Mode” override
**Status:** resolved
**Acceptance criteria**
- User can attempt reader conversion manually even when page is not high-confidence

### Story 4.6 — Implement site profile registry
**Status:** resolved
**Acceptance criteria**
- Site profiles can be registered by domain
- Browser/detector chooses site profile before generic parser
- Site profiles declare a support tier: enabled public, approved non-promoted, or browser-only

### Story 4.7 — Add initial supported site profiles
**Status:** resolved
**Acceptance criteria**
- Initial enabled-public launch domains are handled with profile-specific extraction
- Fallback to generic parser remains functional
- Popular manhwa reader sites such as Asura Scans and ManhwaTop are represented as approved non-promoted reader targets
- Approved non-promoted sources are not surfaced as suggestions, recommendations, onboarding examples, or catalog/source entries
- Browser-only domains remain openable in the in-app browser without extraction

### Story 4.8 — Add detection diagnostics
**Status:** resolved
**Acceptance criteria**
- Detection result exposes confidence and parser path for debugging
- High/medium/low transitions are loggable

---

## Epic 5 — Reader Experience

### Goal
Build a native reader that can consume extracted chapter payloads.

### Story 5.1 — Build reader image strip rendering
**Acceptance criteria**
- Reader renders image list in vertical order
- Scroll is smooth with mock payloads and real payloads

### Story 5.2 — Implement reader chrome and controls
**Acceptance criteria**
- Header/footer overlays can show/hide
- Reader displays chapter context and progress
- Controls match agreed UX priorities

### Story 5.3 — Implement reader settings
**Status:** resolved
**Acceptance criteria**
- Fit width / fit screen
- Page spacing toggle
- Brightness aid
- Canvas/background options if included in MVP

### Story 5.4 — Implement “View Original Page”
**Status:** resolved
**Acceptance criteria**
- Reader exposes explicit action to return to original page
- Return path is stable and tested

### Story 5.5 — Implement previous/next chapter shell
**Status:** resolved
**Acceptance criteria**
- Reader can navigate using chapter links when available
- Unavailable links degrade gracefully

### Story 5.6 — Persist reader progress
**Status:** resolved
**Acceptance criteria**
- Progress saves during/after reading
- Reader restores prior position when reopened

---

## Epic 6 — Series Detail Experience

### Goal
Build a utility-first title detail screen that supports chapter selection and progress-aware continuation.

### Story 6.1 — Implement series detail header
**Acceptance criteria**
- Screen shows title, status, synopsis/summary, and primary CTA
- Primary CTA is progress-aware, e.g. “Continue Chapter 142”

### Story 6.2 — Implement chapter list
**Acceptance criteria**
- Chapter list renders in correct sort order
- Chapter rows are tappable
- Basic loading/empty/error states exist

### Story 6.3 — Implement chapter row state system
**Status:** resolved
**Acceptance criteria**
- Rows can visually represent New, Unread, In Progress, Read, Downloaded
- State styling does not rely on opacity alone
- State system matches UX requirements doc

### Story 6.4 — Implement chapter utilities
**Acceptance criteria**
- Sort control exists
- Download indicator/action shell exists
- Series follow/save state is represented

---

## Epic 7 — Library and Collection Management

### Goal
Turn Library into a first-class collection-management system rather than a passive saved-items list.

### Story 7.1 — Implement library data model changes
**Acceptance criteria**
- Series model supports collection metadata:
  - progressPercent
  - chaptersRead
  - totalKnownChapters
  - lastReadAt
  - libraryState
  - hasUnreadUpdates
  - isCompleted
- Data model changes are reflected in repository interfaces

### Story 7.2 — Implement Library screen shell
**Acceptance criteria**
- Library screen has top bar, segmented control, stats/filter banner, and grid
- Screen matches updated Library mock direction

### Story 7.3 — Implement segmented Library states
**Acceptance criteria**
- Library supports Recent, Reading, Planned segments
- Segment switching updates content correctly
- Segment selection state persists during the session

### Story 7.4 — Implement series card component
**Acceptance criteria**
- Card supports cover, title, last-read metadata, progress bar, and badges
- Card can represent progress and update status consistently
- Card is reusable across Library and Home surfaces where appropriate

### Story 7.5 — Implement card badge and state system
**Acceptance criteria**
- Card supports chapter count badge
- Card supports NEW badge
- Card supports completion state
- Card supports missing-cover fallback

### Story 7.6 — Implement Library filtering and sorting shell
**Acceptance criteria**
- Filter affordance exists
- Basic sort/filter state model exists
- Can be expanded later without redesign

### Story 7.7 — Implement library navigation behaviors
**Acceptance criteria**
- Tapping a series card opens Series Detail
- Library segment changes do not break navigation state
- Active Library tab is visually distinct

---

## Epic 8 — Persistence, Follow State, and Reading Lifecycle

### Goal
Persist reading state and create a usable local library lifecycle.

### Story 8.1 — Implement persistence models and repositories
**Status:** resolved
**Acceptance criteria**
- Series, Chapter, Progress, SearchHistory models are stored locally
- Repositories abstract persistence cleanly

### Story 8.2 — Implement add-to-library flow
**Status:** resolved
**Acceptance criteria**
- User can add a series from reading/browser/series-detail context
- Required metadata is stored
- Default library state is assigned correctly

### Story 8.3 — Implement library state transitions
**Status:** resolved
**Acceptance criteria**
- Series can move between Planned, Reading, Completed
- State transitions are reflected in Library segment views
- Completion state is supported

### Story 8.4 — Implement continue-reading restoration
**Status:** resolved
**Acceptance criteria**
- Last opened chapter and reading position are saved
- Home and Library can resume correctly

### Story 8.5 — Implement recent activity metadata
**Status:** resolved
**Acceptance criteria**
- `lastReadAt` and similar activity fields are updated correctly
- Recent segment can be powered by stored reading metadata

---

## Epic 9 — Updates and Cache

### Goal
Support chapter update awareness and local content reuse.

### Story 9.1 — Implement recent chapter cache
**Acceptance criteria**
- Recently read chapters can be reopened faster
- Cache metadata is persisted

### Story 9.2 — Implement manual chapter download
**Acceptance criteria**
- User can mark chapter for offline retention
- Downloads screen reflects downloaded state

### Story 9.3 — Implement update check service
**Acceptance criteria**
- Service can check latest chapter for saved series
- Update available flag is set correctly

### Story 9.4 — Surface recently updated content on Home and Library
**Acceptance criteria**
- Updated series appear in Recently Updated on Home
- Library cards can show unread update badges

### Story 9.5 — Implement storage management basics
**Acceptance criteria**
- Downloads screen shows cache/download items
- User can remove cached/downloaded content

### Story 9.6 — Implement lightweight latest-chapter fetcher
**Status:** resolved
**Acceptance criteria**
- Fetcher can load a saved series source URL or chapter-list URL
- Fetcher extracts only latest chapter label, latest chapter URL, and checked timestamp
- Parsing is conservative and failures degrade to no update result
- Fetcher does not promote, recommend, or catalog sources

### Story 9.7 — Add manual update check action
**Status:** resolved
**Acceptance criteria**
- User can manually refresh update state from Home or Library
- Saved series update state is persisted after refresh
- Refresh UI supports loading, success, and non-blocking failure states
- Checks remain foreground-safe and lightweight for MVP

### Story 9.8 — Add cache retain/remove feedback
**Status:** resolved
**Acceptance criteria**
- Retain and remove actions show visible success or failure feedback
- Downloads can remove retained and recent cache metadata entries
- Series Detail and Reader reflect retained state after action
- Failure states do not block reading or browsing

### Story 9.9 — Add file-backed cache storage shell
**Status:** resolved
**Acceptance criteria**
- Cache service can map metadata entries to intended local storage locations
- File-backed cache can no-op safely when files are unavailable
- Metadata and file state do not drift silently
- No aggressive prefetching is introduced

### Story 9.10 — Add measured storage accounting
**Status:** resolved
**Acceptance criteria**
- Downloads shows measured local bytes when cached files exist
- Downloads falls back to estimated metadata when files are not present
- Cache removal updates measured storage summary
- Storage accounting remains off the main reader path

---

## Epic 10 — Hardening and QA

### Goal
Tune reliability and prepare MVP for broader testing.

### Story 10.1 — Add logging and debug diagnostics
**Acceptance criteria**
- Key browser/detection/reader/library transitions are logged
- Failures are diagnosable

### Story 10.2 — Add automated test coverage for core flows
**Acceptance criteria**
- Search classification tests
- Detection tests
- Progress persistence tests
- Update badge tests
- Library segmentation tests

### Story 10.3 — Tune detection thresholds
**Acceptance criteria**
- High-confidence false positives are reduced
- Medium-confidence behavior remains useful

### Story 10.4 — Performance pass for reader, browser, and library grid
**Acceptance criteria**
- Reader remains smooth on large chapters
- Browser-to-reader transition is responsive
- Library grid remains performant with larger collections

### Story 10.5 — Update/cache diagnostics pass
**Status:** resolved
**Acceptance criteria**
- Update checks log checked series count, success/failure count, and parser path
- Cache actions log retain, remove, write, and measurement failures
- Logs avoid exposing full sensitive source URLs
- Diagnostics are testable where practical

### Story 10.6 — Update/cache failure-state QA
**Status:** resolved
**Acceptance criteria**
- Tests cover failed latest-chapter fetch
- Tests cover missing or invalid latest labels
- Tests cover cache metadata present but backing file missing
- Tests cover remove failure and retryable UI state

### Story 10.7 — Storage and reader performance pass
**Status:** resolved
**Acceptance criteria**
- Large chapter cache metadata does not block reader scrolling
- Cache summary loads quickly with many entries
- Reader progress/cache recording avoids repeated excessive writes
- Performance checks include realistic large-chapter fixtures

---

## Epic 11 — Product Hardening

### Goal
Close MVP readiness gaps found after Epic 9/10 without expanding ToonEdge into sync, push, recommendations, catalogs, source marketplace, social features, browser tabs, or multi-page chapter stitching.

### Story 11.1 — Simulator QA and release-readiness checklist
**Acceptance criteria**
- Manual QA guide exists for update/cache flows
- QA pass covers Home refresh, Library refresh, Reader retain, Series Detail retain, Downloads remove, storage summary, original-page return, and network failure behavior
- Failures are captured with expected result, actual result, simulator/device, and reproduction steps
- QA pass does not require promoted catalogs or hardcoded piracy-oriented source lists

### Story 11.2 — Seeded local QA fixtures
**Acceptance criteria**
- App can be tested with a deterministic local library state
- Seed data includes in-progress, retained, recently read, and unread-update examples
- Fixtures avoid source promotion and do not appear as recommendations or catalog entries
- Fixtures can be reset between QA passes

### Story 11.3 — Persistent-store migration readiness
**Acceptance criteria**
- SwiftData model/versioning approach is documented before shipping
- Existing local stores can be opened or migrated safely after model changes
- Migration failures degrade with a recoverable path rather than silent data loss
- Tests or manual QA steps cover opening an older local store where practical

### Story 11.4 — Update refresh production safeguards
**Acceptance criteria**
- Manual refresh has clear limits for foreground-safe work
- Network errors, non-HTML responses, parser misses, and invalid labels preserve existing update state
- Refresh feedback distinguishes success, partial failure, and no-update states
- Diagnostics avoid full sensitive source URLs

### Story 11.5 — Cache file lifecycle hardening
**Acceptance criteria**
- Metadata and file state reconciliation is explicit
- Missing backing files are surfaced without treating content as available offline
- Remove failures are retryable and diagnosable
- Cache cleanup does not remove unrelated app files

### Story 11.6 — Storage measurement performance budget
**Acceptance criteria**
- Storage summary remains responsive with large cache metadata sets
- File measurement avoids the reader scroll path
- Downloads can show stale or estimated storage while measurement completes if needed
- Performance threshold is documented and tested with realistic large fixtures

### Story 11.7 — Reader-safe persistence budget
**Acceptance criteria**
- Reader progress remains reliable without excessive cache metadata writes
- Cache write throttling is covered by tests
- Retain/download actions do not interrupt reader scrolling
- Failures in cache persistence do not block reading or “View Original Page”

### Story 11.8 — Manual update/cache diagnostics review
**Status:** resolved
**Acceptance criteria**
- Diagnostics capture enough information to debug update and cache failures
- Logs avoid full source URLs and user-sensitive browsing data
- Diagnostic events are documented for QA and development use
- No diagnostic path promotes approved non-promoted sources

### Story 11.9 — Seamless reader page flow
**Status:** resolved
**Acceptance criteria**
- Reader default vertical image strip has no visual gap between consecutive chapter images
- Full-width chapter images align edge-to-edge so artwork spanning image boundaries reads continuously
- Any optional page spacing remains an explicit reader setting and defaults off for clean/manhwa reading
- Loading and failure placeholders preserve stable layout without adding decorative margins between successfully loaded pages
- QA includes a chapter where the scene spans multiple image assets
- This does not implement multi-page chapter stitching, next-page fetching, or source-page concatenation

### Story 11.10 — Site rendering research catalog
**Status:** resolved
**Acceptance criteria**
- Internal research catalog tracks candidate manga/manhwa sites without exposing them as in-app recommendations, onboarding examples, or catalog entries
- Each profiled site is evaluated from at least one real series page and one real chapter page containing manga/manhwa images
- Each site record captures current domain, example pages, layout type, extraction strategy, image delivery pattern, ordering source, load-state risks, support-tier recommendation, and fixture needs
- Rebranded, blocked, challenge-gated, or unavailable sites are recorded explicitly instead of silently skipped
- Findings identify where generic heuristics are sufficient versus where selector hints, challenge-page suppression, referer-aware loading, or browser-only treatment are needed
- Research output feeds future site-profile stories without expanding MVP into a promoted source marketplace or piracy-oriented catalog

### Story 11.11 — Site profile compatibility classes
**Status:** resolved
**Acceptance criteria**
- Detection profiles classify researched sources into explicit compatibility classes: embedded HTML, hydrated DOM, browser-session extraction, and browser-only
- The first implementation batch registers only the representative profiles needed to validate those classes: `asurascans.com`, `mangakatana.com`, `mangafire.to`, and `manhwatop.com`
- Embedded and hydrated profiles can still route through existing reader detection, while browser-session and browser-only profiles avoid unsafe generic auto-conversion
- Detection diagnostics report the selected compatibility class in addition to parser path, support tier, and profile domain
- Fixture-backed tests cover one representative site per compatibility class and protect challenge-gated pages from Reader conversion
- Approved non-promoted profiles remain excluded from promoted search suggestions
- This story does not add a public catalog, recommendations, sync, notifications, or multi-page stitching

### Story 11.12 — Browser-session retry lifecycle
**Status:** resolved
**Acceptance criteria**
- Browser-session profiles do not auto-convert from the first low-confidence analysis pass
- Browser schedules one bounded follow-up analysis for retry-eligible browser-session pages after initial load
- Retry diagnostics distinguish the first pending pass from the follow-up pass
- If the follow-up pass yields stable ordered candidates, normal high/medium confidence reader behavior can proceed
- If the follow-up pass still lacks viable candidates, the page remains in Browser without repeated retry loops or misleading Reader prompts
- Challenge-gated pages continue to fail closed
- This story does not implement a separate browser, network extractor, site catalog, recommendations, notifications, sync, or multi-page stitching

### Story 11.13 — Fixture-backed profile templates
**Status:** resolved
**Acceptance criteria**
- Site handling is organized around reusable profile templates for shared compatibility behavior instead of duplicating all behavior per domain
- Thin site registrations continue to declare domain, support tier, and local selector hints
- Representative fixture files cover embedded HTML, hydrated DOM, browser-session, and browser-only behavior buckets
- Multiple sites can reuse the same shared template without losing domain-specific diagnostics
- Fixture-backed tests verify both template reuse and the expected detection outcome for each bucket
- The model leaves room for future truly custom parsers without requiring one profile implementation per site by default
- This story does not add a public catalog, recommendations, sync, notifications, or multi-page stitching

### Story 11.14 — Second-batch template classification
**Status:** resolved
**Acceptance criteria**
- A second researched batch is classified against existing templates before introducing any new one
- `mangapill.com` is evaluated from a live chapter page and registered only if it fits an existing compatibility bucket
- Challenge-gated or inaccessible candidates such as `toonily.com` and `kaiscans.org` remain conservative instead of being promoted prematurely
- The research catalog records the second-batch outcome and explains why no new runtime template was added
- Fixture-backed tests cover at least one additional hydrated-DOM site plus one negative/challenge case
- This story does not add a promoted source catalog, recommendations, sync, notifications, or multi-page stitching

### Story 11.15 — Third-batch template validation
**Status:** resolved
**Acceptance criteria**
- A third research batch intentionally probes for a new compatibility bucket rather than assuming one exists
- `mangadex.org`, `comick.io`, and `mangareader.to` candidates are evaluated conservatively from current live behavior
- New runtime templates are added only when evidence proves the current buckets are insufficient
- Challenge-gated and timed-out candidates are recorded explicitly instead of being inferred from search results
- Research output documents whether the existing template model held or changed
- This story does not add a promoted source catalog, recommendations, sync, notifications, or multi-page stitching

### Story 11.16 — Fourth-batch paginated-reader validation
**Status:** resolved
**Acceptance criteria**
- A fourth research batch tests whether current buckets miss paginated single-image reader pages
- `mangahere.cc`, `mangasee123.com`, `mangapark`, and `reaper scans` candidates are evaluated from current live behavior where possible
- Paginated single-image readers are documented as browser-only for MVP rather than forced into clean mode
- The research catalog records inaccessible, failed, or stale-domain candidates explicitly
- Findings identify future work that belongs to post-MVP stitching rather than current Reader conversion
- This story does not implement multi-page stitching, promoted catalogs, recommendations, sync, or notifications

### Story 11.17 — Unsupported paginated-reader diagnostics
**Status:** resolved
**Acceptance criteria**
- Paginated single-image readers have an explicit compatibility class distinct from generic browser-only pages
- MVP keeps paginated single-image readers in Browser and does not attempt clean-mode conversion
- Detection diagnostics identify unsupported paginated readers distinctly from generic low-confidence and challenge-gated pages
- `mangahere.cc` is represented as a browser-only paginated-reader example
- Fixture-backed tests cover the paginated negative-control path
- This story does not implement multi-page chapter stitching, promoted catalogs, recommendations, sync, or notifications

### Story 11.18 — Visible Reader takeover and stable long-page scrolling
**Status:** in progress
**Acceptance criteria**
- High-confidence browser detection exposes diagnostics that confirm whether Reader presentation progresses from detection to browser-owned presentation state
- Browser-detected Reader sessions can be verified independently from app-shell Reader presentation
- Detected Reader sessions preserve per-page image dimensions when extraction provides them
- Reader placeholders reserve height from known page aspect ratios instead of using a single fixed fallback size
- Long vertical chapters avoid large layout jumps when pages above the viewport finish loading
- QA includes a Vortex-style long chapter with upward scrolling after progressive image loads
- This story does not add source promotion, sync, notifications, recommendations, or multi-page chapter stitching

### Story 11.19 — Reader-first routing, library relaunch, and search reuse hardening
**Status:** implemented
**Acceptance criteria**
- Reader content taps toggle chrome both on and off without leaving scrolling trapped behind the overlay
- Reader `x` returns to the canonical source series/index URL, while `View Original Page` returns to the exact chapter URL
- Reader exposes `Add to Library` and `Open in Library`; opening in Library saves first when needed and routes to native Series Detail
- Reader sessions carry canonical series URL and library metadata required for save/open actions without re-deriving those values from the chapter URL in the Reader UI
- Library launches use stored reader payloads immediately when ordered image URLs exist, and fall back to Browser/detection when they do not
- Query searches route through Google, and persisted local search history is reused in visible suggestions
- Extraction excludes obvious ad/banner/sidebar imagery while preserving valid ordered chapter pages

### Story 11.20 — Back button updates
**Status:** implemented
**Acceptance criteria**
- Reader replaces the generic `x` exit control with a labeled back button
- Reader back behavior is origin-aware:
  - Library-launched Reader sessions return to native Series Detail
  - Browser-auto-opened Reader sessions return to the canonical source series/index page
- `View Original Page` remains the explicit route to the exact source chapter URL
- The Reader `Library` action always routes to the Library root, regardless of how the Reader session was entered
- Reader/session routing carries enough origin context to determine the correct back destination without guessing from the current URL
- Regression coverage distinguishes library-origin back behavior, browser-origin back behavior, exact chapter return behavior, and Library-root routing

### Story 11.21 — Reader next and previous chapter navigation
**Status:** implemented
**Acceptance criteria**
- Reader `Next` and `Previous` controls navigate to adjacent chapters without leaving Reader Mode when adjacent chapter URLs can be resolved safely
- Reader sessions carry or can obtain adjacent chapter references needed for chapter-to-chapter transitions
- Tapping `Next` loads the next chapter into Reader and updates chapter title, source URL, progress context, and available adjacent controls
- Tapping `Previous` loads the previous chapter into Reader and updates chapter title, source URL, progress context, and available adjacent controls
- Chapter transitions preserve the Reader flow rather than routing the user back through Browser first
- Unavailable adjacent chapters disable or hide the corresponding control
- If an adjacent chapter cannot be extracted into a viable Reader session, ToonEdge falls back safely instead of presenting a blank or incomplete chapter
- Regression coverage includes working next/previous transitions, first/last chapter control states, and failed-adjacent extraction fallback behavior

### Story 11.22 — Reader back returns to launch context
**Status:** implemented
**Acceptance criteria**
- Reader Back returns to the native in-app screen that launched the Reader whenever one exists
- Web/browser-origin Reader sessions still return to the canonical source series/index page
- Home `Continue Reading` launches return to Home when Back is tapped
- Library Series Detail launches return to that Series Detail page when Back is tapped
- Reader/session routing carries explicit launch-context information rather than inferring destination from chapter URL alone
- `View Original Page` remains the exact chapter-page escape hatch
- Reader `Library` action still opens the Library root
- Regression coverage distinguishes browser-origin, Home-origin, and Library-detail-origin Back behavior

### Story 11.23 — Seamless adjacent chapter loading from app-originated Reader sessions
**Status:** implemented
**Acceptance criteria**
- App-originated Reader sessions, including Home Continue Reading and Library Series Detail launches, can load `Next` and `Previous` chapters without visibly routing the user through Browser
- Reader first uses any stored adjacent chapter payload when available for an immediate transition
- When the adjacent chapter is not stored, ToonEdge performs a background/hidden adjacent-chapter load through the existing browser/detection pipeline and promotes only high-confidence viable Reader sessions
- During adjacent loading, Reader stays on the current chapter and shows a lightweight loading state on the tapped control or reader chrome
- If the adjacent chapter is viable, Reader swaps to the new chapter, resets scroll/progress context appropriately, and updates adjacent controls
- If the adjacent chapter is unavailable, blocked, or unsafe to extract, Reader remains on the current chapter and shows a non-destructive failure message with `View Original Page` still available
- Back behavior preserves the original app launch context after adjacent transitions, so Home-origin sessions return Home and Library-origin sessions return to Series Detail
- The hidden loading path reuses existing extraction, ad filtering, challenge suppression, and confidence thresholds rather than introducing URL guessing or aggressive conversion
- Regression coverage includes stored-payload fast path, unstored hidden-load success, hidden-load failure, preserved Back destination, disabled first/last chapter controls, and no blank Reader session on unsafe pages

### Story 11.24 — Reader overlay current chapter display
**Status:** implemented
**Selected design:** Option A — center the current chapter label between `Previous` and `Next` in the Reader bottom overlay.

**User story**

As a reader, I want to see the current chapter near the chapter navigation controls so I always know which chapter I am reading and can confidently move to the previous or next chapter.

**Acceptance criteria**
- Reader chrome displays the current chapter identifier in the bottom overlay between `Previous` and `Next`
- The preferred layout is conceptually `Previous  ·  Chapter N  ·  Next`
- The display uses the best available chapter label/title from the Reader session, such as `Chapter 169`, without duplicating noisy series text unnecessarily
- If the Reader session only has a longer chapter title, ToonEdge derives a concise display label when possible and otherwise truncates the title gracefully
- The chapter display updates after `Next` or `Previous` navigation
- The centered label remains stable while unavailable chapter-navigation controls are disabled or hidden
- The display remains readable over dark/light reader canvas states and does not block content taps or scrolling
- Long chapter titles truncate gracefully on iPhone-sized screens
- Accessibility labels expose both the series title and current chapter when available
- Regression coverage verifies that the overlay renders the current chapter label and updates it after session replacement

### Story 11.25 — Reader Library icon opens Library root
**Status:** implemented

**User story**

As a reader, I want the Library icon in Reader chrome to take me to my Library so I can leave the current chapter and manage or resume saved/recent titles.

**Intent**

The Reader Library icon is a navigation action, not a save action. Saving remains owned by the separate `Add to Library` / `Saved` control.

**Acceptance criteria**
- Tapping the Reader Library icon opens the native Library root
- The action works from Browser-origin, Home-origin, Library-origin, and direct Reader sessions
- The action dismisses the active Reader presentation before routing to Library
- If Reader is presented above Browser, the Browser presentation is also dismissed or backgrounded so Library becomes the visible active destination
- The selected app tab becomes Library
- The Library icon does not save the current series or mutate saved state
- The Library icon has an accessibility label such as `Open Library`
- Existing `Add to Library` / `Saved` behavior remains unchanged
- Regression coverage verifies Library-root routing from app-shell Reader and browser-owned Reader

### Story 11.26 — Home Continue Reading shows multiple recent titles with View All
**Status:** implemented

**User story**

As a reader, I want Home Continue Reading to show several recently read series so I can quickly resume one of my recent manhwas without opening Library first.

**Target behavior**

- Home `Continue Reading` shows the most recently read distinct series, not just a single item
- The section displays up to 3–4 recent series depending on available screen space
- Each item shows:
  - series title
  - current / continue chapter label
  - progress indicator
  - cover image when available, otherwise the existing placeholder
  - a clear resume affordance
- Tapping an item resumes the appropriate chapter in Reader using stored payloads when available, with the existing safe fallback path when payloads are incomplete
- The bottom of the section includes a `View All` link
- Tapping `View All` routes to Library with the `Recent` segment selected

**Acceptance criteria**

- Continue Reading orders entries by most recently read timestamp
- Multiple chapters from the same series collapse into one distinct series item using the latest reading progress
- The section shows no more than 4 entries on iPhone
- `View All` appears when there is at least one recent-reading entry
- `View All` selects the Library tab and opens the Recent segment
- Empty state remains clean when there are no recent-reading entries
- Regression coverage verifies recent ordering, distinct-series collapse, 3–4 item limit, and `View All` Library routing

### Story 11.27 — Reader loads unseen adjacent chapters through hidden extraction
**Status:** implemented

**User story**

As a reader, I want `Next` and `Previous` in Reader to load adjacent chapters from the source site even if I have never opened, saved, downloaded, or cached those chapters before, so I can keep reading continuously without preparing every chapter ahead of time.

**Acceptance criteria**
- Reader uses stored adjacent payloads first when available.
- If no stored payload exists, Reader loads the adjacent chapter URL through a hidden/non-presented browser extraction flow.
- Hidden loading reuses existing rendered DOM extraction, site profiles, ad/popup suppression, challenge suppression, and high-confidence thresholds.
- Reader remains visible on the current chapter while loading.
- High-confidence viable extraction swaps Reader to the adjacent chapter and resets progress.
- Failure leaves the current chapter intact and shows a non-destructive message.
- Blank, unsafe, low-confidence, medium-confidence, challenged, or mock/sample sessions are never promoted.
- Back preserves the original launch context after adjacent transitions.
- `View Original Page` points to the current Reader chapter’s exact source URL.

### Story 11.28 — Reader chrome action layout refresh
**Status:** implemented

**User story**

As a reader, I want Reader controls to stay available without crowding the title or bottom chapter navigation, so I can focus on the chapter while still quickly saving, downloading, changing settings, going Home, or viewing the original page.

**Intent**

The Reader top bar should prioritize Back and readable series/chapter title text. Secondary actions should move into a compact floating action stack on the lower-right side of the screen. `View Original Page` remains required, but changes from bottom-bar text to a floating icon action.

**Acceptance criteria**
- Remove the Reader Library button from the top chrome.
- Add a Reader Home button in the top chrome where the Library button currently appears.
- Tapping the Home button dismisses Reader as needed and selects the native Home tab.
- Preserve origin-aware Back behavior separately from the Home action.
- Move Save/Saved, Download, Settings, and View Original Page into a floating lower-right action stack.
- `View Original Page` is represented by a single icon with an accessibility label such as `View Original Page`.
- Remove the text `View Original Page` action from the bottom chapter-navigation bar.
- Keep `Previous`, current chapter label, `Next`, and progress display in the bottom bar.
- Use the top-bar space gained from moving secondary actions to show more of the series/chapter title before truncation.
- Long titles still truncate gracefully on iPhone-sized screens without overlapping controls.
- Floating actions remain reachable and readable over dark Reader canvas states.
- Floating actions do not block chapter images, vertical scrolling, or content-tap chrome toggling more than necessary.
- Regression coverage verifies Home routing, original-page routing, title truncation, and the absence of the old bottom-bar text action.

### Story 11.29 — Library cards use equal grid dimensions
**Status:** implemented

**User story**

As a reader, I want Library cards to align cleanly with consistent dimensions, so the collection grid feels stable and polished even when titles, metadata, or chapter labels have different lengths.

**Intent**

Library grid cards should reserve consistent internal regions for cover art, text, progress, and badges. Content should truncate or fall back inside those reserved regions rather than making individual cards taller or shorter than neighboring cards.

**Acceptance criteria**
- Library grid cards in the same row render at equal height.
- Card dimensions stay stable across Recent, Reading, and Planned segments.
- Longer titles and subtitles truncate within reserved text areas instead of increasing card height.
- Cover artwork keeps a consistent aspect ratio and size across cards.
- Badges, progress bars, and chapter labels align consistently at the bottom of each card.
- Empty or missing metadata does not collapse reserved card areas.
- The layout remains readable on iPhone-sized screens without overlapping text or controls.
- Regression coverage verifies card layout metrics for short titles, long titles, missing subtitles, and mixed update/chapter badges.

### Story 11.30 — Simplify Library header and toolbar refresh
**Status:** implemented

**User story**

As a reader, I want the Library screen header to be clean and focused, so I do not see duplicate page titles before my saved and recent series.

**Intent**

Library should use the system navigation title as the single primary page heading. The in-content `Collection` header and subtitle should be removed, and update refresh should move into the trailing navigation toolbar to reduce visual clutter while preserving manual refresh access.

**Acceptance criteria**
- Library no longer renders the in-content `Collection` heading.
- Library no longer renders the subtitle `Reading progress and saved titles`.
- The primary visible page title remains `Library`.
- Refresh moves to a trailing navigation toolbar icon button.
- The toolbar refresh button uses `arrow.clockwise` when idle and `hourglass` while refreshing.
- The toolbar refresh button keeps the accessibility label `Check for new chapters`.
- The toolbar refresh button is hidden when update refresh is unavailable.
- Pull-to-refresh remains available.
- The segmented control moves up after the duplicate header is removed.
- Regression coverage verifies the Library header model excludes `Collection` and exposes refresh as a toolbar action only when refresh is available.

### Story 11.31 — Series Detail chapter progress and list refresh
**Status:** implemented

**User story**

As a reader, I want Series Detail to show my actual latest chapter progress and a useful chapter list, so returning from Reader reflects where I really left off and lets me jump to recent or earlier chapters without stale metadata.

**Intent**

Series Detail should focus on actionable reading state. The primary action should always display a clean numeric chapter label, the reader-origin subtitle should be removed, and the chapter list should update after Reader navigation advances to newer chapters. The page should offer a compact `Recent` list for recently read chapters and an `All` list for the available chapter range without downloading or caching every chapter.

**Acceptance criteria**
- Remove the descriptive subtitle text such as `Saved from Reader Mode.` from the Series Detail header.
- The primary action title always uses `Continue Chapter <chapter number>` or `Start Chapter <chapter number>` when a chapter number can be derived.
- Source/domain words such as `Scans`, `Read Online`, or site names are not used as the primary action chapter label.
- When the user advances from chapter 102 to 103 or 104 in Reader and returns to Series Detail, Series Detail reflects the latest read chapter at the top of recent progress.
- Series Detail refreshes its snapshot when returning from Reader or when the view becomes active again, instead of showing stale chapter 102 state.
- Replace the current newest/oldest-only chapter section with a `Recent` / `All` chapter list mode.
- `Recent` shows up to the 4 most recently read chapters for that series, ordered newest reading activity first.
- `All` shows the available numeric chapter range from the earliest known chapter through the latest known chapter.
- If the source exposes chapter 0, `All` includes chapter 0; otherwise the generated visual range starts at chapter 1.
- Generated visual chapter rows do not require cached page images or stored reader payloads for every prior chapter.
- Selecting a generated chapter row uses the existing safe fallback: open stored Reader payload when available, otherwise route through Browser/detection for that chapter URL when a source URL is known.
- If a generated chapter lacks a resolvable source URL, it is shown disabled or omitted rather than opening a broken Reader.
- Regression coverage verifies clean primary action labels, removal of the reader-origin subtitle, recent ordering after adjacent Reader progress, and generated all-chapter range behavior.

### Story 11.32 — Library refresh pill and centered empty state
**Status:** implemented

**User story**

As a reader, I want Library refresh and empty states to feel integrated and lightweight, so the screen stays focused on saved titles without extra toolbar clutter or verbose empty-copy blocks.

**Intent**

Library should move manual update refresh out of the navigation toolbar and into the summary pill that says `Reading Library` / `<n> saved titles`. After a refresh completes, the `Update refresh` feedback pill should be dismissible and should automatically disappear after 5 seconds. Empty Library sections should use a quiet centered visual state with the existing `sleepy transparent.png` mascot asset and the message `Nothing saved`.

**Acceptance criteria**
- Remove the Library refresh icon from the navigation toolbar.
- Add the refresh action inside the Library summary pill that contains the section label and saved-title count, such as `Reading Library` and `<n> saved titles`.
- The summary-pill refresh action uses `arrow.clockwise` when idle and `hourglass` while refreshing.
- The summary-pill refresh action keeps the accessibility label `Check for new chapters`.
- The summary-pill refresh action is hidden or disabled when update refresh is unavailable.
- Pull-to-refresh remains available.
- When the `Update refresh` feedback pill appears after a refresh, it includes an `x` dismiss button at the top of the box.
- Tapping the `x` immediately dismisses the `Update refresh` feedback pill.
- The `Update refresh` feedback pill automatically disappears after 5 seconds.
- If the current Library section has 0 saved titles, replace the current banner-style empty state with a centered empty state.
- The empty state uses the mascot image asset `sleepy transparent.png`.
- The empty state message is exactly `Nothing saved`.
- The empty state should be vertically centered in the available Library content area on iPhone-sized screens.
- Regression coverage verifies refresh placement, dismissible/auto-expiring refresh feedback, and the centered empty-state model.

### Story 11.33 — Floating Library refresh feedback banner
**Status:** planned

**User story**

As a reader, I want Library update-refresh feedback to appear without moving the page layout, so refresh results feel lightweight and do not disrupt the Library screen while I am browsing saved titles.

**Intent**

The `Update refresh` feedback should no longer render as an in-flow pill or banner that pushes the segmented control, summary pill, grid, or empty state downward. Instead, refresh feedback should appear as a floating overlay banner above the Library content, fade away automatically after a few seconds, and remain manually dismissible with an `x` button.

**Acceptance criteria**
- Replace the current in-flow `Update refresh` feedback view with a floating banner overlay.
- The floating banner does not alter the vertical position of the segmented control, summary pill, grid cards, or empty state when it appears or disappears.
- The banner appears after a manual refresh or pull-to-refresh completes.
- The banner includes the title `Update refresh` and the existing refresh result message.
- The banner includes an `x` dismiss button with accessibility label `Dismiss update refresh`.
- Tapping the `x` dismisses the banner immediately.
- The banner automatically fades out after a few seconds.
- If a newer refresh result appears before the previous banner expires, the newer message replaces the old one and owns the auto-dismiss timer.
- The banner is positioned safely below the navigation bar and does not cover the segmented control in a way that blocks interaction.
- Regression coverage verifies the feedback is modeled as an overlay, does not affect content layout state, supports manual dismissal, and auto-dismisses stale messages safely.

### Story 11.34 — Show only current chapter in Library card continue metadata
**Status:** resolved

**User story**

As a reader, I want each Library card to show only the chapter I am currently on next to `Continue`, so I can choose the right title without scanning extra progress text.

**Intent**

Library cards should make the resume target clear in the metadata line without appending total chapter progress. The current chapter label is already available on `LibrarySeriesSummary`, so this story only changes presentation and keeps persistence, reader progress tracking, and card navigation behavior unchanged.

**Acceptance criteria**
- In-progress Library cards with a current chapter label show metadata in the form `Continue Ch. <label>`.
- Completed series do not show `Continue Ch. <label>` in card metadata.
- Series without a current chapter label fall back to the existing chapter summary text.
- The existing bottom chapter badge remains unchanged.
- Regression coverage verifies chapter-only in-progress metadata plus completed and missing-current-chapter fallback formatting.

### Story 11.35 — Scalable Library views and collection grouping
**Status:** resolved

**User story**

As a reader with dozens of saved manhwas, I want to switch between comfortable cards, compact cards, and a dense list view, and I want to organize saved titles by reading state, so my Library remains fast to scan as it grows.

**Intent**

Library should scale beyond a small visual gallery. The current card grid is useful for a small collection, but larger libraries need denser views and clearer organization. This story adds user-controlled Library density, expands collection groupings, and lets the user choose the saved state when adding a title to Library. The design should move away from overly soft, generic card styling by using tighter radii, less decorative chrome, stronger content hierarchy, and more native list/collection patterns.

**Recommended UX direction**
- Add a Library view-mode control with three modes: `Comfortable`, `Compact`, and `List`.
- Keep `Recent` as activity-based, not a saved collection state.
- Treat saved collection states as `Reading`, `Planned`, `Dropped`, and `Completed`.
- Show collection states as a horizontally scrollable chip/filter row or a compact filter menu rather than forcing five equal-width segmented tabs on iPhone.
- Default `Add to Library` from Reader to `Reading`.
- Default `Add to Library` from Browser or Series Detail to `Planned`.
- Let the user override the default state in a save confirmation sheet before saving.

**Visual direction**
- Reduce card corner radius and avoid soft floating-card treatment on every item.
- Use cover artwork as the primary visual anchor; keep surrounding chrome minimal.
- Use subtle separators, thin dividers, or tonal background shifts instead of heavy borders around every saved title.
- Keep purple as an accent for actions and active states, not the dominant styling of every Library surface.
- Make `List` mode feel dense and native: small cover thumbnail, title, source/domain, `Continue Ch. <label>` when available, update badge, and a compact progress indicator.
- Make `Compact` mode use smaller covers and tighter metadata while preserving enough artwork to recognize titles.
- Keep `Comfortable` mode visually close to the current card grid but with tighter radii, less padding, and more intentional hierarchy.

**Acceptance criteria**
- Library exposes a view-mode control with `Comfortable`, `Compact`, and `List` modes.
- The selected view mode persists locally and is restored when the Library screen opens again.
- `Comfortable` mode keeps a visual card grid suitable for smaller collections.
- `Compact` mode shows more saved titles per viewport than `Comfortable` mode while preserving cover recognition.
- `List` mode shows the highest-density Library layout for large collections.
- Library supports collection filters for `Reading`, `Planned`, `Dropped`, and `Completed`.
- `Recent` remains available as an activity-based view driven by last-read/update activity rather than a stored collection state.
- Filter counts or summary copy reflect the active group and visible title count.
- Existing saved title navigation remains unchanged: selecting a title opens native Series Detail.
- Existing progress, update, completion, and current-chapter metadata remain visible in each mode where space allows.
- Card/list styling uses tighter corner radii and less decorative container chrome than the current large rounded card treatment.
- `Add to Library` presents a save confirmation flow that lets the user pick the collection state before saving.
- Reader-origin saves default to `Reading`.
- Browser-origin and Series Detail saves default to `Planned`.
- Changing the selected save state before confirming persists that chosen state.
- Existing saved-state mutation from Series Detail continues to work for already saved titles.
- Regression coverage verifies view-mode persistence, state filtering, `Dropped` support, default save states by origin, explicit save-state override, and unchanged navigation to Series Detail.

**MVP boundaries**
- Do not add cloud sync, tags, custom shelves, recommendations, public catalogs, or social features.
- Do not add bulk edit, drag-and-drop reordering, or custom user-defined groups in this story.
- Do not change Reader detection, chapter parsing, or update-check behavior except where save-state defaults are passed through existing Library interfaces.

---

## Post-MVP Epic — Multi-Page Chapter Stitching

### Goal
Support chapters split across multiple source pages.

### Story candidates
- detect paginated chapters
- sequential next-page fetch
- append pages progressively
- fallback if stitching fails
- loop/duplicate safeguards

Do not implement in MVP unless explicitly requested.

---

## Recommended implementation order

1. Epic 1 — Foundation and App Shell  
2. Epic 2 — Home and Search Entry  
3. Epic 3 — Browser Experience  
4. Epic 5 — Reader Experience (mock-backed first)  
5. Epic 4 — Detection Engine  
6. Epic 6 — Series Detail Experience  
7. Epic 7 — Library and Collection Management  
8. Epic 8 — Persistence, Follow State, and Reading Lifecycle  
9. Epic 9 — Updates and Cache  
10. Epic 10 — Hardening and QA

### Epic 1 story order

1. Story 1.1 — Set up project structure
2. Story 1.3 — Implement design tokens and shared UI primitives
3. Story 1.2 — Implement app shell and navigation
4. Story 1.4 — Create root routing and modal presentation framework

Rationale: define module boundaries and dependency injection first, establish shared visual primitives second, then build tab navigation and full-screen presentation on top of those foundations.

---

## Notes for Codex
- Do not implement multi-page chapter stitching in MVP
- Do not add browser tabs in MVP
- Keep Library as a first-class surface with segmented collection behavior
- Prefer mock-backed end-to-end flows before real parser integration where needed
- Preserve clean separation between UI, repositories, browser services, and detection logic
