# ToonEdge Architecture / Technical Design Doc

**Product:** ToonEdge  
**Document Type:** Technical Design / Architecture  
**Version:** v1.0  
**Audience:** Engineering, Codex agent, technical reviewers

## 1. Overview

ToonEdge is an iPhone-first app that converts cluttered manhwa chapter webpages into a clean native reading experience. It combines a universal web search / URL entry point, in-app browsing, DOM-based chapter detection, a native reader, local library persistence, progress tracking, chapter update checks, and local caching.

This document defines the recommended technical architecture for MVP and immediate post-MVP extension.

## 2. Technical Goals

### Primary goals
- Build a stable iOS app with a clean modular architecture
- Support search-first entry into reading
- Support browser-based detection and Reader Mode conversion
- Preserve local library, reading progress, and update state
- Make it easy to add new site profiles and evolve detection heuristics

### Secondary goals
- Minimize coupling between UI, browser logic, and parser logic
- Keep the app testable and incrementally shippable
- Support future extension for multi-page chapter stitching, sync, and more site adapters

## 3. Platform and Stack

### 3.1 Recommended platform
- iOS only for MVP
- iPhone-first layout
- SwiftUI app shell
- `WKWebView` for browser and rendered DOM access

### 3.2 Recommended core technologies
- SwiftUI for UI
- WebKit / WKWebView for in-app browser and DOM extraction
- SwiftData for MVP local persistence
- URLSession for cache downloads and update checks where needed
- BackgroundTasks for future background refresh
- OSLog / unified logging for diagnostics

### 3.3 Architecture style
Use a modular feature architecture with clear service boundaries.

Recommended shape:
- Presentation layer
- Domain layer
- Service / infrastructure layer
- Persistence layer
- Web parsing / detection layer

Avoid:
- putting parsing logic directly in SwiftUI views
- mixing persistence and UI state
- hardcoding site-specific behavior inside browser screens

## 4. High-Level System Architecture

Home / Search UI  
↓  
Search Input Classifier  
↓  
In-App Browser (WKWebView)  
↓  
Detection Engine  
├─ Site Profile Parser  
└─ Generic Heuristic Parser  
↓  
Detection Result  
↓  
Reader Coordinator  
↓  
Native Reader UI  
↓  
Library / Progress / Cache / Update Services

## 5. Module Breakdown

### 5.1 App Shell Module
Responsibilities:
- app entry
- tab navigation
- deep link handling
- environment / dependency injection
- top-level routing

### 5.2 Search Module
Responsibilities:
- search bar state
- search suggestions
- input classification
- recent searches / recent links
- clipboard suggestion behavior

Key types:
- `SearchInput`
- `SearchInputKind`
- `SearchSuggestion`
- `SearchSession`

### 5.3 Browser Module
Responsibilities:
- host `WKWebView`
- load URL or search result pages
- expose back/forward/refresh
- trigger detection after page load
- preserve current page state
- route into Reader Mode

### 5.4 Detection Module
Responsibilities:
- inject JS into loaded page
- extract candidate content
- run heuristic scoring
- apply site profiles
- classify confidence
- return structured `DetectionResult`

### 5.5 Reader Module
Responsibilities:
- render extracted chapter images
- manage reader controls and settings
- save progress
- allow return to original page
- support chapter navigation
- consume reader sessions that include canonical series URL plus library metadata needed for save/open-library actions

### 5.6 Library Module
Responsibilities:
- save/remove series
- save chapter metadata
- continue reading
- surface recently updated
- expose series detail state
- The library module owns collection organization and consumes reading metadata such as progress percent, last-read timestamp, unread update state, completion state and library segment state

### 5.7 Update Check Module
Responsibilities:
- check tracked series for new chapters
- compare stored latest chapter against source latest chapter
- flag new chapter availability
- update library badges
- provide a lightweight latest-chapter fetcher behind a protocol
- orchestrate manual foreground refresh without adding MVP background scheduling or push notifications

### 5.8 Cache / Download Module
Responsibilities:
- cache recent images
- manage local storage
- support manual chapter download
- track storage usage
- evict low-priority cache
- separate cache metadata, file-backed asset storage, and storage measurement
- provide user-visible retain/remove action results without blocking the reader

### 5.9 Site Profile Module
Responsibilities:
- provide domain-specific selectors/strategies
- version profiles
- fall back gracefully when profiles fail

### 5.10 Shared UI / Design System Module
Responsibilities:
- define colors, typography, spacing, radius, and motion tokens
- provide reusable buttons, chips, cards, banners, segmented controls, list rows, and loading/error states
- keep visual primitives independent from feature-specific business logic
- support the quiet-editorial visual direction defined in `docs/plans/2026-09-27-quiet-editorial-ux-design.md`
- use system-adaptive application chrome outside Reader while keeping explicit Reader canvas choices independent from app appearance
- make borderless editorial grouping the default and reserve elevated surfaces for chrome, sheets, selection, and transient feedback

### 5.11 Persistence / Repository Module
Responsibilities:
- own SwiftData models and persistence setup
- expose repository protocols for library, chapters, progress, search history, cache metadata, and update state
- keep SwiftUI views and feature view models from directly reading or writing persistent storage
- provide mock repositories for tests and early vertical slices
- provide direct stored-reader-session reconstruction for chapters with persisted ordered image payloads

## 5.12 Proposed Xcode Project Structure

```text
ToonEdge/
  ToonEdgeApp.swift
  App/
    AppShell/
    Navigation/
    DependencyInjection/
    Routing/
  Features/
    Home/
      Views/
      ViewModels/
      Components/
    Search/
      Models/
      Services/
      ViewModels/
    Browser/
      Views/
      WebView/
      Coordinators/
      ViewModels/
    Detection/
      Models/
      JavaScript/
      Scoring/
      SiteProfiles/
      Services/
    Reader/
      Views/
      ViewModels/
      Components/
      Settings/
    Library/
      Views/
      ViewModels/
      Components/
      SeriesDetail/
    Downloads/
      Views/
      ViewModels/
    Settings/
      Views/
      ViewModels/
  Core/
    Domain/
      Models/
      ValueTypes/
    Services/
      Protocols/
      Implementations/
    Persistence/
      Models/
      Repositories/
      Migrations/
    Networking/
    Logging/
  SharedUI/
    DesignSystem/
      Colors/
      Typography/
      Spacing/
      Radius/
    Components/
      Buttons/
      Chips/
      Cards/
      Banners/
      Rows/
      SegmentedControls/
    Assets/
  Tests/
    UnitTests/
    IntegrationTests/
    UITests/
```

## 6. Data Model

### 6.1 Series
```swift
struct Series {
    let id: UUID
    var title: String
    var canonicalURL: URL
    var sourceDomain: String
    var coverImageURL: URL?
    var followState: FollowState
    var latestKnownChapterLabel: String?
    var updateAvailable: Bool
    var lastOpenedChapterID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var progressPercent: Double
	var chaptersRead: Int
	var totalKnownChapters: Int?
	var lastReadAt: Date?
	var libraryState: LibraryState
	var hasUnreadUpdates: Bool
	var isCompleted: Bool
}
```

### 6.2 Chapter
```swift
struct Chapter {
    let id: UUID
    let seriesID: UUID
    var title: String
    var chapterLabel: String
    var chapterNumber: Double?
    var chapterURL: URL
    var previousChapterURL: URL?
    var nextChapterURL: URL?
    var imageURLs: [URL]
    var readStatus: ReadStatus
    var lastReadImageIndex: Int?
    var lastReadOffset: Double?
    var cachedAt: Date?
    var updatedAt: Date
}
```

### 6.3 ReaderSession
```swift
struct ReaderSession {
    let chapterID: UUID
    let sourceURL: URL
    var displayMode: ReaderDisplayMode
    var progress: ReaderProgress
    var enteredFrom: ReaderEntrySource
}
```

### 6.4 SearchInput
```swift
struct SearchInput {
    let rawValue: String
    let kind: SearchInputKind
}
```

### 6.5 DetectionResult
```swift
struct DetectionResult {
    let isChapterPage: Bool
    let confidence: DetectionConfidence
    let title: String?
    let chapterTitle: String?
    let imageURLs: [URL]
    let nextChapterURL: URL?
    let previousChapterURL: URL?
    let sourceDomain: String
    let siteProfileID: String?
    let signals: [DetectionSignal]
}
```

### 6.6 SiteProfile
```swift
struct SiteProfile {
    let id: String
    let domainPatterns: [String]
    let parserStrategy: SiteProfileStrategy
    let version: Int
}
```

### 6.7 Library State
enum LibraryState {
	recent
	reading
	planned
	completed
	archived
}

## 7. Search Architecture

### 7.1 Search entry model
The Home screen contains a universal search / URL field.

Behavior:
- classify input
- URLs open directly in browser
- search queries load search results in browser
- detection runs only after destination page load

### 7.2 Search suggestions
Search suggestions should be local-first:
- clipboard link
- recent links
- recent searches
- recent sites

Do not block typing on network calls.

### 7.3 Input classification
Use a scoring-based classifier.

Suggested signals:
- starts with `http`
- contains TLD
- looks like a domain
- no spaces
- contains path-like separators
- presence of spaces may reduce URL score

Return:
- `url`
- `searchQuery`

## 8. Browser Architecture

### 8.1 Browser ownership
The Browser module owns a single `WKWebView` session per visible browser context.

### 8.2 Lifecycle
- receive search input
- load URL or search results
- observe navigation completion
- wait for page stabilization
- run detection
- branch by confidence

### 8.3 Detection branch behavior
- high confidence → auto-open Reader Mode
- medium confidence → show CTA
- low confidence → remain in browser

### 8.4 Escape hatch
The browser state must remain accessible after Reader Mode is entered, so the user can return to the original page.

## 9. Detection Engine Design

### 9.1 Detection philosophy
Use heuristic detection in MVP.

Reason:
- controllable
- explainable
- faster to implement
- better for site-by-site tuning

### 9.2 Parsing order
1. Attempt site profile parser if domain matches
2. If unavailable or failed, run generic heuristic parser

### 9.2.1 Launch site profile tiers
Site profiles must include a support tier:
- `enabledPublic`: clean-reader profile is enabled in public builds
- `approvedNonPromoted`: clean-reader profile is enabled for user-initiated pages, but the source is not advertised, suggested, recommended, or listed as a catalog/source option
- `browserOnly`: no extraction profile; load in browser and preserve normal browsing

Initial profile policy:
- `enabledPublic`: ComicFury public comic pages, The Duck Webcomics public comic pages, generic creator-owned/self-hosted webcomic pages
- `approvedNonPromoted`: Asura Scans (`asurascans.com`, legacy/redirect `asuracomic.net`), ManhwaTop (`manhwatop.com`), ManhuaTop (`manhuatop.org`), ManhwaClan (`manhwaclan.com`), MangaBuddy (`mangabuddy.com`), Vortex Scans, Flame Scans / Flame Comics, RoliaScan
- `browserOnly`: WEBTOON, Tapas, MANGA Plus, GlobalComix paid/login/protected-reader pages, and any source requiring auth, DRM, canvas/blob extraction, anti-bot bypass, or protected media access

Approved non-promoted sources must render correctly in Reader when opened explicitly by the user and detection passes. They must not be promoted as built-in catalog sources, search suggestions, onboarding examples, or recommendations. They must not bypass source restrictions, and offline retention must remain disabled for MVP.

### 9.3 Extraction pipeline
1. page load complete
2. inject JS
3. collect DOM candidates
4. normalize image attributes (`src`, `data-src`, `srcset`, etc.)
5. filter decorative/small images
6. detect dominant content cluster
7. score signals
8. produce `DetectionResult`

### 9.4 Heuristic signals
- count of large images
- vertical stacking continuity
- same-container clustering
- chapter-like URL pattern
- consistent source/CDN pattern
- long page height
- lazy-load attribute presence
- repeated sibling images

### 9.5 Confidence model
- high → auto-open
- medium → CTA
- low → no action

Use conservative thresholds for high confidence. False positives are worse than false negatives.

#### 9.5.1 Detection hard gates
- Run detection only after page load completion and `750 ms` of page stability.
- Require at least `4` candidate images, or `3` candidate images with total rendered height `>= 3.5x` the viewport height.
- Block auto-open on search results, catalog/listing pages, login/paywall/captcha/interstitial pages, product pages, or error pages.
- Block extraction for pages requiring auth bypass, DRM bypass, canvas/blob extraction, anti-bot workarounds, or protected media access.

#### 9.5.2 Candidate image filter
An image is a reader candidate when it passes all applicable filters:
- rendered width `>= 72%` of viewport width or natural width `>= 500 px`
- rendered height `>= 280 px`
- rendered area `>= 90,000 px`
- source is recoverable from `src`, `data-src`, `data-original`, `srcset`, or similar lazy-load attributes
- class, id, alt, or URL does not strongly indicate UI/decorative content such as logo, avatar, icon, ad, banner, sprite, thumb, profile, or comment

#### 9.5.3 Scoring model
Start from `0` and add positive signals:
- Large candidate image count: `4-5 = +8`, `6-9 = +14`, `10+ = +20`
- Vertical continuity: `>= 70%` same x-axis within `32 px` and ordered top-to-bottom `= +15`, `>= 55% = +8`
- Full-width consistency: `>= 75%` candidates at least `78%` viewport width `= +15`, `>= 60% = +8`
- Common container cluster: largest shared container contains `>= 70%` candidates `= +10`, `>= 55% = +5`
- Total candidate height: `>= 8x` viewport `= +12`, `>= 5x = +8`, `>= 3x = +4`
- Chapter-like URL/title: chapter, episode, ep, chap, or read `= +8`; manga, manhwa, webtoon, or comic `= +4`
- Image host/source consistency: `>= 80%` same CDN/host/path pattern `= +8`, `>= 65% = +4`
- Lazy-load signal: `>= 30%` candidates use lazy attributes or srcset `= +6`
- Next/previous chapter link found: both directions `= +6`, one direction `= +3`
- Low decoration ratio: candidate images are `>= 45%` of all page images `= +8`

Apply negative signals:
- Search results page `= -35`
- Series/catalog/listing page `= -25`
- Article/blog/news page with high text density `= -20`
- E-commerce/product page `= -30`
- Gallery of thumbnails/cards `= -25`
- Comment/forum-heavy page `= -15`
- Login/paywall/captcha/interstitial/error page `= hard block`

#### 9.5.4 Confidence thresholds
- `high`: score `>= 78`, no hard block, negative score total better than `-20`, and at least `6` candidates or candidate height `>= 5x` viewport
- `medium`: score `55-77`, no hard block, and at least `4` candidates or candidate height `>= 3.5x` viewport
- `low`: score `< 55`
- Manual clean-mode attempt may be exposed from browser tools at `45-54`, but the primary “Read in Clean Mode” CTA should start at medium confidence

### 9.6 JS injection responsibilities
Injected script should:
- inspect rendered DOM
- gather image candidates
- infer likely chapter container
- read next/previous chapter links if present
- return structured JSON

The Swift side should:
- decode payload
- apply heuristic scoring
- map to `DetectionResult`

## 10. Reader Architecture

### 10.1 Reader input
The Reader should consume a normalized `DetectionResult` or stored `Chapter`.

### 10.2 Rendering model
- vertical long-strip rendering
- lazy image loading
- persistent reader settings
- progress saved per chapter

### 10.3 Reader transitions
High-confidence entry:
- browser triggers auto-open
- reader shows subtle toast/confirmation if needed

Medium-confidence entry:
- user taps “Read in Clean Mode”

### 10.4 Required controls
- dismiss / back
- chapter title
- chapter selector or navigation
- progress
- settings
- view original page

## 11. Persistence Architecture

Series-level reading metadata must be persisted and queryable to support segmented Library views, recent sorting, progress visualization, completion states and update badges

### 11.1 Storage choice
Use local persistence for:
- library
- chapters
- read progress
- recent searches
- recent links
- cache metadata

Use SwiftData for MVP persistence. Keep repositories protocol-backed so Core Data or another store can replace SwiftData later if migration, compatibility, or performance requirements change.

### 11.2 Persistence boundaries
UI code should never directly read/write persistent storage. Use repositories/services.

Suggested repositories:
- `LibraryRepository`
- `ChapterRepository`
- `ProgressRepository`
- `SearchHistoryRepository`
- `CacheRepository`

## 12. Update Checking Architecture

### 12.1 MVP model
Update checking may run:
- on pull to refresh
- on app foreground
- on selected series open

### 12.2 Flow
1. fetch series source page or known chapter list page
2. extract latest chapter label
3. compare with stored latest chapter label
4. mark update available if different/newer

### 12.3 Safety
Keep update checks lightweight and rate-limited.

### 12.4 Service boundaries
Update checking must stay protocol-backed and separate from SwiftUI views.

Recommended protocols:
- `SeriesLatestChapterFetching`: loads a saved source/chapter-list URL and returns latest chapter metadata only
- `SeriesUpdateChecking`: compares fetched latest metadata against stored state
- `LibraryUpdateRefreshing`: orchestrates manual refresh for saved series and persists results

The concrete fetcher may use `URLSession`, site profile selector hints, or generic HTML parsing. It must not hardcode piracy-oriented catalogs, promote approved non-promoted sources, or fetch full chapter image payloads during update checks.

### 12.5 Refresh UX and failure model
Manual update refresh should expose loading, success, partial failure, and no-change states. Failures should be non-blocking and should not clear existing update state unless a newer authoritative result is available.

## 13. Caching Architecture

### 13.1 MVP scope
Support:
- recent chapter cache
- optional manual download
- storage management

### 13.2 Cache policy
- persist recently opened chapters
- use size-based eviction
- preserve manual downloads until user removes them

### 13.3 Cache service boundaries
Cache behavior should be split into focused services:
- `CacheMetadataManaging`: persists metadata, retention state, and summary DTOs
- `ChapterAssetCaching` or `ReaderAssetCaching`: owns file-backed image storage and path mapping
- `CacheStorageMeasuring`: computes measured local bytes from file storage

SwiftData models should not compute filesystem size directly. SwiftUI views should not write files or read SwiftData cache models directly.

### 13.4 File-backed cache shell
The cache layer should map each retained/recent chapter to a deterministic local storage namespace derived from stable IDs or normalized source URLs. File writes must be best-effort and recoverable: metadata can exist without files, but the UI must be able to detect and repair/remove stale entries.

### 13.5 Retain/remove user feedback
Reader, Series Detail, and Downloads should receive typed cache action results so they can show success, no-op, and failure states. Cache errors should not interrupt reading; they should be surfaced as non-blocking feedback.

### 13.6 Storage accounting
Downloads should prefer measured bytes from `CacheStorageMeasuring` when files exist and fall back to metadata estimates when they do not. Storage aggregation must stay off the reader scroll path and should remain fast with many cache entries.

## 14. Error Handling

### 14.1 Failure cases
- page failed to load
- parser failed
- low-confidence page
- image unavailable
- update check failed

### 14.2 UX behavior
- browser remains usable when detection fails
- reader should surface soft failures, not crash
- library data should degrade gracefully if refresh fails

## 15. Analytics / Instrumentation

Track at least:
- search submitted
- URL opened
- search result clicked
- page detected high/medium/low
- reader entered automatically
- reader entered manually
- series added to library
- progress resumed
- update available surfaced

## 16. Testing Strategy

### 16.1 Unit tests
- input classification
- heuristic scoring
- repository behavior
- update check comparison logic

### 16.2 Integration tests
- browser → detection → reader flow
- add to library and resume
- update badge behavior

### 16.3 UI tests
- Home search flow
- medium-confidence CTA flow
- high-confidence auto-open flow
- return to original page

## 17. MVP Boundaries

In scope:
- search bar
- browser
- detection heuristics
- reader
- library
- progress
- update check
- cache basics

Out of scope:
- multi-page chapter stitching
- sync
- ML detection
- advanced recommendations

## 18. Post-MVP Extension Points

- multi-page chapter stitching
- cloud sync
- more site profiles
- smarter ranking
- richer offline management
