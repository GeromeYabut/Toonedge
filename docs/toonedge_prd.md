# ToonEdge Product Requirements Document (PRD)

**Product:** ToonEdge  
**Platform:** iOS, iPhone-first  
**Document Version:** v1.1
**Status:** Draft for review
**Last Revised:** 2026-09-28

### Revision Summary

Version 1.1 incorporates the approved requirements from the 2026-09-28 MangaPin competitive review. It adds six bounded MVP requirements: Reader continuity and prefetch, guarded manual Clean Mode, saved-library search matches, Reader zoom, operational Library sorting/source filtering, and local search-history controls. It also records the approved post-MVP opportunity backlog without promoting those items into the release commitment.

## 1. Overview

ToonEdge is a mobile application that converts cluttered online manhwa and manga chapter webpages into a clean, native reading experience on iPhone. The product combines a smart browser, a detection engine, a clean reader, a persistent local library, and chapter update tracking.

The core user problem is that many online manhwa websites are difficult to read on mobile. They often include spam-heavy side content, poor image sizing, distracting chrome, and inconsistent chapter presentation. ToonEdge solves this by detecting when a loaded webpage is likely a manhwa chapter page and then rendering the chapter in a reader mode that removes everything except the reading content.

ToonEdge is not intended to host or curate a first-party content catalog. Its primary value is as a personal reading layer over web content, paired with local library management and update awareness.

## 2. Product Vision

ToonEdge should feel like a smart reading browser with a personal library attached.

The product should let users:
- start from search or a link
- open web content inside the app
- have chapter pages detected automatically
- enter a clean reader with little or no friction
- save series and resume progress
- know when new chapters are available

The product should prioritize trust, speed, and ease of reading over complexity.

## 3. Goals

### 3.1 Primary Goals
- Convert cluttered manhwa chapter webpages into a clean reader experience
- Make entry into reading easy through a global search and URL bar
- Automatically detect chapter pages with high reliability
- Persist a local library of ongoing reads
- Track reading progress and restore users to their exact place
- Surface when a saved series has a new chapter available

### 3.2 Secondary Goals
- Support offline-friendly local caching of recent reading content
- Minimize friction between discovery and reading
- Create a strong mobile-native reading experience for iPhone users
- Keep long-strip reading visually stable while images load
- Make saved content discoverable from the universal search entry point
- Give users direct control over locally stored search history

### 3.3 Non-Goals
- Building a first-party hosted content library
- Offering a large curated piracy catalog
- Supporting desktop or Android in v1
- Implementing machine-learning-based detection in MVP
- Supporting multi-page chapter stitching in MVP
- Requiring an account or cloud sync in MVP
- Building external tracker, social, recommendation, or community features
- Adding browser tabs or conventional paginated manga modes in MVP

## 4. Target Users

### 4.1 Primary Users
Mobile manhwa readers who currently use iPhone browsers to read on ad-heavy or cluttered websites and want a better reading experience.

### 4.2 Secondary Users
Heavy readers who follow multiple ongoing series and want progress tracking, quick resume, and update detection.

## 5. Core Product Principles

### 5.1 Reading First
Everything in the product should support fast transition into a better reading experience.

### 5.2 Trust Before Magic
Automatic behavior should only occur when confidence is high. False positives are more damaging than false negatives.

### 5.3 Start Anywhere
Users should be able to begin from a web search, a pasted URL, recent links, or their saved library.

### 5.4 Escape Is Always Available
Users must always be able to return to the original webpage if detection or reader mode is incorrect.

Reader exit semantics:
- Reader uses a back button rather than a generic `x`
- Back returns to the prior product context:
  - if Reader was launched from Library, return to native Series Detail
  - if Reader was auto-opened from Browser, return to the canonical source series/index page when available
- `View Original Page` returns to the exact source chapter page
- Reader `Library` action always opens the Library root

## 6. Product Scope

### 6.1 In Scope for v1
- Home screen with a universal search and URL bar
- In-app browser
- Search query handling through web search
- URL entry handling
- Detection engine for identifying chapter pages
- Automatic entry into reader mode at high confidence
- Reader mode with native iPhone-optimized display
- Bounded ahead-of-scroll Reader prefetch and stable page placeholders
- Pinch and double-tap zoom in the long-strip Reader
- Local library and progress persistence
- Saved-library matches in universal search
- Operational Library sorting and filtering by sources already in the user's collection
- Individual and clear-all local search-history controls
- New chapter availability checks for saved series
- Local caching of reading content
- Site-specific parsing profiles plus fallback generic detection
- Medium-confidence detection prompt via reader CTA banner
- Guarded manual Clean Mode attempt for viable manual-only detections
- Ability to return to original webpage from reader mode
- Reader actions for `Add to Library` and `Open in Library`
- Google as the default web search provider for query submissions

### 6.2 Out of Scope for MVP
- Multi-page chapter stitching
- Cross-device sync
- Social features
- Community source sharing
- Full source marketplace
- Tabs in the browser
- ML-based document or image classification
- Extensive settings complexity beyond core reading preferences
- Source migration, batch download queues, and per-series reader overrides
- Cloud backup, external tracker integration, notes, ratings, custom lists, and reading statistics
- Background chapter notifications or predicted release dates
- Single-page, double-page, left-to-right, or right-to-left reading modes

## 7. User Experience Summary

ToonEdge is centered on a single high-frequency user loop:
1. User opens ToonEdge
2. User either resumes from library or uses the search bar
3. User enters a URL, search query, or saved-series title
4. A saved-series result opens native Series Detail; a URL or web query opens the in-app browser
5. Detection engine analyzes the loaded page
6. If high confidence, app auto-enters Reader Mode
7. If medium confidence, app shows a “Read in Clean Mode” prompt
8. If manual-only eligibility is confirmed, Browser offers a secondary “Try Clean Mode” action
9. User reads in the native reader
10. Progress is saved automatically
11. Series can be added to library and tracked for updates

## 8. Functional Requirements

### 8.1 Home Screen
- The topmost element must be a universal search and URL bar
- The search bar must accept both URLs and general search queries
- The Home screen must also display Continue Reading, Recently Updated, and All Library
- The search bar must not be a library-only search field
- The search experience must include local saved-series matches without turning Home into a catalog
- The Home screen must communicate two primary actions: resume reading from saved library, and start a new reading session from the web

### 8.2 Search Input Classification
- The application must classify search bar input as either a likely URL or a likely search query
- Input classification must use a scoring-based method rather than a simple “contains dot” rule
- If classified as URL, open directly in the in-app browser
- If classified as search query, run the query through a web search experience inside the in-app browser

### 8.3 In-App Browser
- Must support back, forward, refresh
- Must load direct URLs from the search bar
- Must show search results when query input is entered
- Must trigger detection after page load
- Must support browser search result selection followed by detection on the selected page
- Must maintain enough state to support easy return from reader mode

### 8.4 Detection Engine
- Feature extraction from the loaded DOM and rendered page
- Heuristic scoring
- Confidence classification
- UI action based on confidence level

Detection confidence model:
- high confidence: auto-enter Reader Mode
- medium confidence: show reader CTA
- manual-only low confidence: expose a secondary manual attempt only when the detector has a viable session and no hard block
- all other low confidence: do nothing

Reader entry thresholds are:
- high: score `>= 78` plus high-confidence viability constraints
- medium: score `55-77` plus medium-confidence viability constraints
- manual-only: score `45-54`, no hard block, and a viable normalized Reader session
- unavailable: score below `45`, nonviable output, or any hard block

The detector owns entry eligibility. Browser UI must not infer eligibility from score alone or bypass challenge, authentication, paywall, protected-viewer, browser-only, unsupported-paginated, DRM/canvas/blob, error-page, or other hard blocks.

Detection features may include:
- count of large vertically stacked images
- image dimensions
- dominant single-column layout
- chapter-like URL patterns
- grouping of relevant images within the same DOM container
- consistent image source patterns or CDN patterns
- lazy-load image attributes
- long total scroll height
- repeated sibling images in reading order

### 8.5 Reader Mode
- Display chapter images in vertical reading order
- Remove all non-reading page chrome
- Use edge-to-edge or fit-to-width rendering by default
- Preserve image aspect ratio
- Provide smooth scrolling for long chapters
- Prefetch and decode the current page, two pages ahead, and retain one recently visible page behind by default
- Limit concurrent page fetch/decode work to three operations
- Reuse available cached assets before requesting the network
- Preserve the selected Reader canvas and page geometry while images load or fail
- Keep a failed page isolated and retryable without resetting the chapter
- Support pinch zoom from `1x` through `3x`
- Support double tap to toggle between `1x` and `2x`, with a zoomed double tap returning to `1x`
- Allow panning while zoomed and immediately restore normal vertical scrolling at `1x`
- Reset transient zoom when changing chapters or leaving Reader
- Automatically save reading progress
- Restore the user to their last reading position

Reader controls must provide:
- origin-aware back navigation to the prior product context
- chapter title
- chapter selector or chapter navigation access
- next/previous chapter controls when available
- progress indicator
- reader settings entry point
- “View Original Page” action
- Library action that always opens the Library root
- an accessible Reset Zoom action while content is zoomed

Reader prefetch must not imply explicit offline retention. Network-prefetched content may remain memory-scoped; user-requested offline retention continues to use the existing download/cache lifecycle.

### 8.6 Library System

The Library is a first-class organizational surface for managing reading state and collection intent.

Users must be able to:
- add a series to library
- remove a series from library
- view continue reading items
- view recently updated saved series
- see progress per series
- see whether a saved series has a new chapter available

The Library must support:
- segmented reading states
- reading progress visualization
- filtering and sorting
- saved/planned/completed organization
- new chapter indicators
- series lifecycle management
#### Library Collection States

A saved series may exist in one of the following states:

- Reading
  - actively being read
  - appears in Continue Reading and Reading segment

- Planned
  - saved for future reading
  - not yet started

- Completed
  - user finished the available content

- Dropped
  - intentionally stopped and excluded from active reading surfaces

#### Reading Progress Visualization

Series cards should support:
- progress bar overlays
- current chapter indicators
- total progress percentages
- last-read timestamps
- completion states
- new chapter badges

#### Library Filtering

The Library should support:
- segmented filtering (Recent, Reading, Planned, Dropped, Completed)
- sorting by recent activity, title, or unread updates first
- ascending and descending order where meaningful
- multi-select source filtering derived only from domains already present in the user's Library
- reading status filtering
- composition of lifecycle segment, sort, source filter, and view density
- a Reset action that restores Recent, recent activity descending, and all sources
- local persistence of selected segment, sort, source filter, and view density

Sorting and filtering must not mutate saved series metadata. Source filters must not become source recommendations, discovery shortcuts, or a hardcoded source catalog. If active filters produce no results, Library must explain that filters are active and offer Reset.

### 8.7 Add to Library Flow
- After a user begins or completes reading a chapter, the app may prompt them to add the series to their library
- The user must also be able to manually add from the series detail or browser context
- Add to Library should save enough metadata to support chapter update checking later
- Add to Library saves collection metadata only; it does not imply offline download
- Open in Library saves first when needed, then opens native Series Detail for the saved series

### 8.8 New Chapter Availability Checking
For series saved in the library, the app must:
- store a canonical series or chapter source URL sufficient to identify the series later
- periodically check the chapter listing or source page
- compare the latest known chapter against the saved latest known chapter
- flag the series when a newer chapter is detected

### 8.9 Local Caching and Offline Support
- cache recently read chapters
- optionally allow chapter download for offline reading
- support storage usage visibility
- allow cache clearing

### 8.10 Site Profiles
- For known sources, the app may use site-specific selectors or extraction strategies
- For unknown sources, the app must fall back to generic heuristic detection
- The architecture should allow new site profiles to be added without redesigning the reader system

### 8.11 Saved-Library Search

- Universal search must match saved series locally as the user types
- Matching must be case-insensitive and support exact title, title prefix, and token containment
- Results must be deterministic, deduplicated, available offline, and visibly labeled as saved content
- Saved results should show useful local context such as lifecycle state and resume chapter
- Selecting a saved result must open native Series Detail and must not submit a web search
- An exact clipboard-link action remains first; exact and partial saved matches follow; the explicit web-search action remains visible
- Empty-query behavior must remain restrained and must not list the Library as a catalog
- Opening a saved result must not create a web-search-history entry

### 8.12 Local Search-History Controls

- Users must be able to delete an individual recent search or recent link from Search
- Settings must provide `Clear Search History` with confirmation
- Successful deletion must update visible suggestions immediately and persist across relaunch
- Clearing search history must delete only locally stored search/link history
- Clearing search history must not delete Library entries, reading progress, recent reading, downloads, cache metadata, cookies, or website data
- Canceling confirmation must have no effect
- The feature must not introduce an account, analytics upload, or remote history store

## 9. Search UX Details
- Search is not a library-only function; it is a unified entry system
- Search should feel instant and lightweight
- Users should not need to think about whether they are entering a URL or a search query
- The browser should be the output target for URLs and web queries; saved-library results open native Series Detail
- Saved-library matching must remain local and work without a network connection
- Detection should occur after page load, not on the Home screen alone
- The app may suggest opening a copied link from clipboard, but should not auto-open clipboard content without explicit user action
- Browser tabs are explicitly not required in v1

## 10. Detection Heuristics Specification
- The detection engine must use heuristics in v1 rather than machine learning
- Heuristic signals may include image count, image dimensions, vertical clustering, URL patterns, central reading container, image host consistency, chapter metadata, high document height, and low decorative-image proportion
- The extractor must account for lazy-loading where practical
- The engine should guard against blog posts, galleries, comment sections, ad-heavy sidebars, and product pages with repeated thumbnails
- If detection is uncertain or extraction fails: remain in browser and do not auto-enter Reader
- A secondary manual attempt may be exposed only for the `45-54` manual-only band when a viable normalized session exists and no hard block applies
- Manual failure must leave the exact browser page and navigation history intact

## 11. Multi-Page Chapter Stitching
Status: Post-MVP only.

Future requirement:
- detect paginated chapter flows
- identify next-page links or numbered pagination
- load multiple pages belonging to the same chapter
- merge extracted images into one continuous reader experience

Initial technical direction: sequential retrieval, not parallel, for the first implementation.

## 12. UX Requirements by Screen
- Home: universal search and URL bar, Continue Reading, Recently Updated, All Library
- Series Detail: title, cover, follow state, chapter list, read/unread indicators, download/cache action where available
- Browser: address/search bar, back/forward/refresh, page content, medium-confidence “Read in Clean Mode” CTA, and a secondary manual-only “Try Clean Mode” tool action when eligible
- Reader: immersive reading, minimal chrome, stable bounded prefetch, pinch/double-tap zoom, quick return to original page, saved progress, chapter navigation where available
- Library: lifecycle segments, view density, recent/title/unread sorting, source filtering derived from saved domains, filtered empty-state Reset
- Downloads / Cache Management: viewing downloaded or cached reading content, removing downloaded items, monitoring storage usage
- Settings: reader behavior settings, cache management, local search-history clearing, update checking behavior where exposed

## 13. Key User Flows
- Start from Search Query
- Start from URL
- Open a Saved Series from Universal Search
- Resume from Library
- Attempt Manual Clean Mode from Browser
- New Chapter Flow
- Return to Original Page
- Delete One Search-History Item
- Clear Search History from Settings

## 14. Technical Architecture Requirements
High-level components:
- UI shell and navigation
- Home and library management
- search bar and suggestion system
- input classification
- in-app browser
- detection engine
- extraction and parsing engine
- reader rendering engine
- chapter-scoped page loading/prefetch coordination
- local persistence and library storage
- caching / download manager
- update-checking engine
- site profile manager

## 15. Data Requirements
Entities should include:
- Series
- Chapter
- Search History
- Site Profile

## 16. Quality Requirements
- Reader should feel smooth on long image chapters
- Reader page loading must not produce full-canvas flashes or scroll-position jumps
- No more than three Reader page fetch/decode operations may be active concurrently
- Leaving or replacing a chapter must cancel stale nonessential prefetch work
- Search suggestions should appear quickly
- Saved-library search results must be available offline and route to native Series Detail
- Transition from browser to reader at high confidence should feel immediate and deliberate
- Manual Clean Mode must never weaken detection hard blocks
- Caching should improve reopen speed for recent chapters
- Detection must degrade gracefully when uncertain
- Reader progress must persist reliably
- Reader zoom must preserve content bounds, progress, image order, and normal `1x` scrolling
- Library filtering and sorting must be deterministic and nonmutating
- Search-history deletion must not affect any other local data category

## 17. Risks and Constraints
- Detection fragility due to source changes
- False positives harming trust
- Source variability from lazy-loading or obfuscated markup
- Storage growth from cached images
- Memory pressure from decoded long-strip images
- Gesture conflict between Reader zoom, vertical scrolling, and chrome toggling
- Confusion between saved-library results and web-search suggestions
- Detection threshold drift between documented policy and implementation

## 18. Release Phasing
### MVP / v1
- Home with universal search and URL bar
- Search suggestions
- URL/query classification
- In-app browser
- Heuristic detection engine
- Site profiles plus fallback generic extraction
- Auto-enter Reader Mode at high confidence
- Prompt at medium confidence
- Guarded manual Clean Mode at manual-only confidence
- Native reader
- Bounded Reader prefetch and page-local retry
- Pinch and double-tap Reader zoom
- Local library
- Saved-library matches in universal search
- Library sorting and saved-source filtering
- Individual and clear-all local search-history controls
- Progress saving
- New chapter checking
- Local caching basics
- View Original Page escape hatch

### Post-MVP
- Multi-page chapter stitching
- Source migration and source-health tooling with preview, confirmation, duplicate detection, and rollback
- Per-series overrides for a small subset of global Reader preferences
- Batch chapter downloads with a visible bounded queue, retry, and storage estimates
- Portable local backup/export and safe import before any cloud-sync work
- Optional local notes and personal ratings
- Custom lists and tags after collection-scale research demonstrates the need
- Transparent local reading statistics with reset/correction controls
- Opt-in update notifications after confirmed update accuracy and iOS scheduling constraints are addressed
- External tracker import/export with explicit mapping and conflict behavior
- Cloud backup and multi-device sync only after safe local export/import and migration rollback are proven
- Additional single-page, double-page, left-to-right, and right-to-left reading modes as a deliberate product expansion
- Per-site browser-protection controls only when compatibility evidence demonstrates the need
- Restrained Home customization that permanently keeps universal search first
- More site profiles that continue to comply with the launch-site policy
- Configurable high-confidence auto-open preference if user research demonstrates the need

## 19. Explicit Product Decisions Locked In
1. The app name is ToonEdge.
2. The Home screen includes a universal search and URL bar.
3. The search bar supports both direct links and general web search queries.
4. Search input opens into the in-app browser, not directly into Reader Mode.
5. Detection occurs after page load inside the browser.
6. At high confidence, the app auto-enters Reader Mode.
7. At medium confidence, the app shows a reader conversion prompt.
8. At manual-only low confidence, the app may expose a secondary guarded attempt; all other low-confidence and hard-blocked pages remain in Browser.
9. Detection strategy is hybrid and conservative for auto-entry, not aggressive.
10. Multi-page chapter stitching is future, not MVP.
11. Users must always be able to return to the original webpage.
12. The product stores library data locally and checks saved series for new chapters.
13. Saved Library results are included in universal search but open native Series Detail rather than Browser.
14. Reader zoom is transient and bounded to `1x...3x`.
15. Reader prefetch is bounded and does not imply an offline download.
16. Library sort and source filters are presentation preferences and do not mutate collection metadata.
17. Search-history clearing affects only locally stored search/link history.
18. Accounts, cloud sync, browser tabs, external trackers, and social/community features remain outside MVP.

## 20. Open Questions for Next Revision
- whether to expose user-facing toggles for auto-open reader behavior in v1 or later
- fixture validation for the initial enabled-public site profiles and approved popular reader profiles

## 21. MVP Implementation Decisions
- Update checking in MVP runs on foreground, pull-to-refresh, and selected series open. Background refresh remains a future extension point.
- Manual download management is not part of the first implementation slice. MVP should scaffold Downloads and support recent cache visibility/removal first; explicit offline-retain actions can be implemented later in Epic 9.
- SwiftData is the MVP persistence store behind repository protocols.
- Bottom navigation for MVP is Home, Library, Downloads, and Settings. Browser is launched from Home/Search and preserved for return from Reader Mode, not exposed as a required bottom tab.
- Exact initial detection thresholds are defined in the architecture doc and should be tuned during Epic 10 using fixture pages and diagnostics.
- Reader entry presentation is driven by an explicit detector-owned disposition so Browser does not duplicate threshold or hard-block policy.
- Initial launch-site policy is defined as enabled-public, approved non-promoted, and browser-only tiers in this PRD and the architecture doc.

## 21.1 Resolved Conflicts and Clarifications
- Architecture owns technical boundaries, module ownership, and persistence/service architecture.
- PRD owns product scope and MVP boundaries.
- UX requirements own user-facing behavior, interaction states, and screen acceptance criteria unless they conflict with PRD scope.
- Mockups are visual and layout references only; docs govern behavior when they conflict.
- MVP bottom navigation is Home, Library, Downloads, and Settings. Browser is a launched flow, not a required bottom tab.
- SwiftData is the MVP persistence store.
- Manual offline-retain downloads are deferred until later cache/download work; recent cache visibility/removal is the first MVP slice.
- The Architecture document's `>=78` high, `55-77` medium, and `45-54` manual-only entry bands are authoritative. Implementations using different defaults must be aligned before the guarded manual action ships.
- Planned UX work that says all low-confidence pages hide Clean Mode must distinguish ordinary/hard-blocked low confidence from the approved manual-only band.

## 22. Launch Site Research and Policy

Site support is split into three tiers so ToonEdge can validate real reader behavior while avoiding catalog-like promotion of third-party reader sites.

### Tier 1 — MVP clean-reader profiles enabled by default
- ComicFury public webcomic pages
- The Duck Webcomics public comic pages
- Generic creator-owned or self-hosted webcomic pages, including WordPress/Webcomic/ComicPress-style pages when the page passes detection hard gates

These sources are best suited for the first public build because they are public webcomic hosting or creator-owned pages, and they validate the core Browser -> Detection -> Reader loop without centering the product on piracy-oriented catalogs.

### Tier 2 — approved popular manhwa reader targets, non-promoted
- Asura Scans: `asurascans.com`, with `asuracomic.net` treated as a legacy/redirect domain
- ManhwaTop: `manhwatop.com`
- ManhuaTop: `manhuatop.org`
- ManhwaClan: `manhwaclan.com`
- MangaBuddy: `mangabuddy.com`
- Vortex Scans: `vortexscans.org` and current reader domains if verified during implementation
- Flame Scans / Flame Comics: current reader domains to be verified during implementation
- RoliaScan: current reader domains to be verified during implementation

Tier 2 is approved as reader-rendering target support. These sites should render correctly in ToonEdge Reader when the user explicitly opens a page or URL and the page passes detection. Do not promote these sites in search suggestions, do not include them as built-in catalog entries, do not list them in onboarding, and do not surface them as recommended sources.

Tier 2 support must remain user-initiated. Do not bypass anti-bot, login, paywall, delayed-release, subscription, or protected viewer behavior. Do not enable manual download/offline retention for these domains in MVP.

### Tier 3 — browser-only / no extraction by default
- WEBTOON
- Tapas
- MANGA Plus
- GlobalComix paid, login, subscription, or protected-reader pages
- Any source requiring authentication, canvas/blob extraction, DRM bypass, anti-scrape workarounds, or protected media access

### Research notes
- Asura Scans is highly relevant to the target audience. Public traffic estimates show roughly 12M+ monthly visits, and ComicK group popularity data ranks Asura far above other scanlation groups.
- ManhwaTop is also high-volume. Semrush reports roughly 19M monthly visits in March 2026 and lists adjacent reader destinations such as ManhuaTop and ManhwaClan.
- MangaBuddy and Bato-style aggregators demonstrate strong demand, but Bato's 2026 shutdown and piracy reporting reinforce the need for a conservative App Store posture.
- Several reader sites publish terms or DMCA pages that restrict copying, distribution, bulk access, or infringement. Treat popularity as a compatibility signal, not as a reason to promote sources inside the product.

Sources reviewed:
- Apple App Review Guidelines 5.2.2: https://developer.apple.com/app-store/review/guidelines/
- Asura Scans traffic estimate: https://hypestat.com/info/asurascans.com
- Asura Scans current site / terms links: https://asurascans.com/
- ManhwaTop traffic estimate: https://www.semrush.com/website/manhwatop.com/overview/
- ManhwaTop terms: https://manhwatop.com/conditions-and-terms/
- ManhwaTop legal disclaimer: https://manhwatop.com/legal-disclaimer-page/
- ComicK popular groups: https://comick.dev/group/popular
- Bato shutdown reporting: https://www.thepopverse.com/comics-manga-piracy-site-shutdown-bato-50-thousand-dollars-a-month
- Vortex Scans DMCA / terms page: https://vortexscans.org/dmca-policy
- RoliaScan terms: https://goldenhazestudio.com/terms
