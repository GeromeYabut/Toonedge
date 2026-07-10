# Defects

This document tracks confirmed product defects, their evidence, current status, and intended resolution.

## DEF-028 — Series Detail can show all known local chapters read while the next source chapter exists

**Status:** Implemented
**Severity:** Medium
**Reported:** 2026-07-09
**Area:** Series Detail primary action, update refresh, chapter availability indexing

### User-visible problem

After chapter 106 is fully read, Series Detail can show `All Chapters Read` even though chapter 107 is available on the source site. The app may have a latest-known label from update metadata, but no stored chapter URL for chapter 107.

### Expected behavior

- Refresh and Series Detail opening should index available chapter links when possible.
- If chapter 107 is indexed and chapter 106 is read, Series Detail should offer `Start Chapter 107`.
- If every indexed available chapter is read, Series Detail can show `All Chapters Read`.

### Resolution

- Added lightweight available-chapter indexing from source series pages.
- Manual Library refresh and opportunistic Series Detail loading update the local chapter index.
- Series Detail primary action now uses indexed chapter rows as openable reading targets without requiring cached reader image payloads.

## DEF-022 — Reader adjacent navigation masks transient rate-limit/challenge failures

**Status:** Open  
**Severity:** High  
**Reported:** 2026-06-05  
**Area:** Reader adjacent chapter navigation, hidden WebView loading, site challenge/rate-limit handling, failure UX

### User-visible problem

When reading The Extra's Academy Survival Guide chapter 102 and tapping Previous or Next, the Reader can load for an extended period and then fail with a generic message such as "Could not open previous chapter in Reader." or "Could not open next chapter in Reader."

The reporter observed a rate-limited error in another browser around the same time, and retrying a few minutes later worked. This makes the failure intermittent and hard to reproduce consistently.

### Expected behavior

- Adjacent Reader navigation should handle transient site rate limits, challenge pages, and timeouts gracefully.
- If the hidden adjacent loader hits a challenge/rate-limit/timeout path, the Reader should show an actionable message instead of a generic "could not open" failure.
- The user should have a clear retry path or a way to open the original adjacent chapter page.
- The app should avoid rapid repeated hidden loads that could worsen rate limiting.

### Evidence

- Reported on 2026-06-05 with chapter URL:
  - `https://asurascans.com/comics/the-extras-academy-survival-guide-46f09241/chapter/102`
- Screenshot evidence shows chapter 102 loaded in Reader with Previous and Next available, and an inline failure message after attempting adjacent navigation.
- Live investigation on 2026-06-05 found chapters 101, 102, and 103 returning normal HTTP 200 HTML when retried later. The pages included expected previous/next chapter metadata and embedded page image URLs, which suggests the URL pattern and parser path were not permanently broken.
- `AdjacentReaderSessionLoader` currently requires a high-confidence detection result with non-empty, non-mock images. Challenge pages, low-confidence pages, timeouts, or unavailable adjacent payloads collapse into adjacent-load failure.
- `ReaderViewModel.navigateAdjacentChapter(_:)` catches all adjacent-load failures and displays the generic direction failure message, losing the underlying reason.

### Initial root-cause hypothesis

Hidden adjacent chapter loading is likely being intermittently blocked by site-side rate limiting or a Cloudflare-style challenge during repeated next/back navigation. The app already has challenge-page detection signals in the detection pipeline, but adjacent Reader navigation does not preserve or surface those diagnostics to the user.

### Proposed fix

1. Add focused tests for adjacent navigation failures caused by challenge/rate-limit signals and hidden-loader timeouts.
2. Extend `AdjacentReaderSessionLoadError` to carry a reason such as timeout, challenge/rateLimit, unavailable, or lowConfidence.
3. Propagate challenge/rate-limit diagnostics from detection/page analysis into the adjacent-load failure path.
4. Update Reader adjacent failure messaging to be actionable, for example: "This site may be rate limiting Reader Mode. Try again in a moment or open the original chapter."
5. Add a retry/open-original path for adjacent failures where the target adjacent URL is known.
6. Consider a conservative retry/backoff strategy, but do not auto-loop hidden WebView loads.
7. Log lightweight diagnostics for adjacent-load URL, direction, elapsed time, detection confidence, parser path, and challenge signals.

### Acceptance criteria

- Rate-limit/challenge/timeout failures show a specific actionable Reader message.
- The user can retry or open the original adjacent chapter when the target URL is known.
- Normal adjacent chapter navigation still opens Reader Mode as before.
- Regression tests cover challenge/rate-limit and timeout failure paths.
- The app does not issue aggressive repeated hidden loads after a transient failure.

## DEF-021 — Series Detail Continue can reopen chapter 1 after reading later chapters

**Status:** Open  
**Severity:** High  
**Reported:** 2026-06-05  
**Area:** Series Detail continue action, Reader progress persistence, recent chapter selection

### User-visible problem

After reading multiple chapters in a series and returning from Reader to Series Detail using the Reader back button, tapping the large `Continue Chapter` button can reopen chapter 1 instead of the most recently read/in-progress chapter.

### Expected behavior

- Series Detail `Continue Chapter` should open the latest active reading target for that series.
- If the user is currently reading chapter 3, the detail header should continue chapter 3, not chapter 1.
- Recent chapter list ordering should not cause an older chapter with lower progress to become the primary continue target.
- Returning from Reader to Series Detail should preserve the current Reader chapter/progress state for the header CTA.

### Evidence

- Reported on 2026-06-05 with `Past Life Returner`.
- Screenshot evidence shows Series Detail for `Past Life Returner` with chapters 1, 155, and 169 in Recent.
- The header CTA displays `Continue Chapter 1` while Reader screenshot from the same flow shows `Past Life Returner Chapter 3` at 7% progress.
- User reports that after reading a few chapters, tapping Reader back returns to Detail, then tapping Continue opens chapter 1.

### Initial root-cause assessment

- Series Detail primary chapter selection may be derived from the first in-progress chapter in the current chapter list rather than the most recently updated progress record.
- Reader progress for hidden-loaded or inferred adjacent chapters may not be upserting the current chapter into the saved series detail chapter list before returning.
- Existing sparse chapter state may make chapter 1 the only stored direct Reader session target, so the header CTA falls back to it even though recent progress exists for chapter 3.

### Proposed implementation plan

1. Add a regression test with a saved series containing chapter 1 and a later recent/progress record for chapter 3.
2. Verify Series Detail `primaryChapter` and `primaryActionTitle` choose chapter 3 when it is the most recently read/in-progress chapter.
3. Ensure Reader progress save or recent-reading save updates enough series detail state for the current chapter to become the continue target.
4. Keep Recent chapter list display ordering separate from primary continue selection rules.
5. Preserve existing behavior for planned/unread series with no progress, where the primary action can start the earliest or current available chapter according to existing UX.

### Acceptance criteria

- After reading chapter 3 and returning to Series Detail, the header CTA shows `Continue Chapter 3`.
- Tapping the Series Detail continue CTA opens chapter 3, not chapter 1.
- The fix works for adjacent chapters reached through inferred/hidden-loaded Reader navigation, not only chapters already stored before opening Reader.
- Regression coverage proves older in-progress chapters do not override the most recently read chapter.

## DEF-020 — Reader Next can jump to the next recent chapter instead of the next numeric chapter

**Status:** Open  
**Severity:** High  
**Reported:** 2026-05-28  
**Area:** Reader adjacent chapter navigation, Series Detail recent ordering, generated chapter range routing

### User-visible problem

On the test toon `Past Life Returner`, Reader `Next` can jump from chapter 155 to chapter 169 because chapter 169 is the next item in Series Detail `Recent`, rather than navigating to the next numeric chapter.

### Expected behavior

- Reader `Next` should always navigate to the next numeric chapter when the current chapter has a numeric label.
- Reader `Previous` should navigate to the previous numeric chapter.
- `Recent` ordering should not define adjacent Reader navigation order.
- If the next numeric chapter is not stored locally but has a safely inferable source URL, Reader should use the existing adjacent Browser/detection fallback.
- If the next numeric chapter cannot be safely resolved, Reader should fail gracefully instead of jumping to a non-adjacent recent chapter.

### Evidence

- Reported on 2026-05-28 using `https://manhuaus.com/manga/past-life-returner/chapter-155/`.
- Screenshot evidence shows Reader open on chapter 155 with `Next` available.
- After tapping `Next`, Series Detail shows recent progress entries ordered as chapter 155, chapter 169, chapter 1, and the observed navigation lands on chapter 169.
- This indicates adjacent navigation is being derived from recent/activity ordering or a non-numeric chapter sequence rather than numeric chapter adjacency.

### Initial root-cause assessment

- Story 11.31 introduced `Recent` / `All` chapter modes and generated numeric chapter rows.
- Reader adjacent controls may still be receiving adjacent chapter candidates from the currently available chapter list order rather than a numeric chapter adjacency resolver.
- If the repository/session builder uses recent-read ordering, sparse stored chapter payloads, or generated rows without enforcing numeric `current +/- 1`, it can select chapter 169 as the next candidate after 155.

### Proposed implementation plan

1. Add a regression test using known chapters 1, 155, and 169 where Reader is opened at chapter 155.
2. Verify `Next` resolves to chapter 156 when a safe source URL can be inferred, not chapter 169.
3. Verify `Previous` resolves to chapter 154 when a safe source URL can be inferred.
4. Add or update a numeric adjacent chapter resolver that uses the current chapter number and source URL pattern before considering stored list order.
5. Keep `Recent` solely for display ordering and never use it as Reader adjacent navigation order.
6. Preserve stored payload preference: if numeric adjacent chapter payload exists locally, open it directly; otherwise fall back through Browser/detection when the URL is safe.

### Acceptance criteria

- From `Past Life Returner` chapter 155, tapping `Next` attempts chapter 156, not chapter 169.
- From chapter 155, tapping `Previous` attempts chapter 154 when resolvable.
- Recent activity order does not affect Reader adjacent chapter selection.
- Generated `All` rows and Reader adjacent controls share the same safe numeric URL inference rules where practical.
- Regression coverage proves sparse recent chapters do not become adjacent Reader targets.

## DEF-019 — Same source series can appear twice in Library Recent

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-25  
**Area:** Library snapshot identity, recent-reading dedupe, save-to-library flow

### User-visible problem

The Library Recent page can show two cards for the same manhwa/source series. In the reported screenshot, `The Extra’s Academy Survival Guide` appears twice with the same cover artwork while the summary banner reports three saved titles.

### Expected behavior

- Library Recent should show one visible card per actual series.
- A recent-reading record and a saved-series record for the same canonical source series should merge into one card.
- The merged card should preserve the latest recent-reading progress and timestamp while using the best saved-series metadata and cover.
- The fix should be generic for other sites, not AsuraScans-specific.

### Evidence

- Screenshot captured on 2026-05-25 shows two visible `The Extra’s Academy Survival Guide` cards in Recent Library.
- Earlier DEF-015 suppressed domain-only placeholders such as `asurascans.com`, but this screenshot shows a stronger duplicate: both entries now have real series metadata/cover.

### Root-cause assessment

- `LibrarySnapshot.deduplicatedRecentSeries` currently de-duplicates only by `UUID`.
- `SwiftDataLibraryRepository.recentReadingSummary` only maps a recent-reading record to a saved series when the recent title is a domain placeholder.
- If a recent-reading record already has real metadata but was created with a different `seriesID` or a slightly different canonical URL than the saved `StoredSeries`, both records survive into `recentReadSeries + series`.
- This explains why DEF-015 fixed `asurascans.com` placeholder duplicates but not real-title duplicates for the same manhwa.

### Proposed implementation plan

1. Add a regression test where a real-title recent-reading record and a saved-series record refer to the same source series but have different IDs and nearby canonical URLs.
2. Add a stable library identity key that prefers canonical URL when available and falls back to normalized `sourceDomain + title`.
3. Update Recent snapshot assembly so recent-reading summaries merge into matching saved-series summaries, not only domain placeholders.
4. Update `LibrarySnapshot` de-duplication to use the stable identity key rather than UUID alone.
5. Preserve recent-reading state when merging: `lastReadAt`, `progressPercent`, and `currentChapterLabel` should come from the recent record.

### Acceptance criteria

- The same actual series appears once in Library Recent even if recent and saved records have different IDs.
- Saved metadata/cover remain preferred for the visible card.
- Recent progress/timestamp remain preferred for ordering and continue labels.
- Domain placeholder suppression from DEF-015 continues to work.
- Regression coverage proves both domain-placeholder duplicate and real-title duplicate cases.

### Implemented solution — 2026-05-25

- Added a stable Library identity normalizer that compares canonical URLs and normalized `sourceDomain + title` when UUIDs differ.
- Updated Recent snapshot de-duplication to use the stable identity key instead of UUID-only matching.
- Updated recent-reading summary construction so real-title recent records can merge into saved-series summaries, not only domain placeholders.
- Preserves saved-series metadata/cover while applying recent-reading progress, last-read timestamp, and continue chapter label.
- Added regression coverage for a recent-only Asura detail record plus saved Asura library record representing the same source series.

## DEF-018 — Library cover images flash missing when switching back from empty Planned segment

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-24  
**Area:** Library UI, cover image loading, segmented filtering

### User-visible problem

When the user switches from `Reading` to the empty `Planned` Library section, then switches back to `Reading`, cover images briefly disappear and reload. The cards should retain their artwork immediately instead of flashing placeholders.

### Expected behavior

- Recently loaded Library cover images should remain visually available when changing Library segments.
- Switching through an empty segment should not force visible cards to re-fetch or flash missing artwork.
- Placeholder artwork should only appear for genuinely missing covers or first-time loads, not for already-loaded covers.

### Evidence

- User report on 2026-05-24: toggling from empty `Planned` back to `Reading` causes a split-second image reload before covers appear again.

### Initial root-cause assessment

- `SeriesCard` uses `AsyncImage` directly.
- Segment changes remove and recreate the grid/card views, resetting `AsyncImage` phase state.
- Even if the network/cache returns quickly, SwiftUI briefly renders the placeholder phase on recreated cards.

### Initial implementation plan

1. Add a small shared in-memory cover artwork cache for Library/Home card images.
2. Replace direct `AsyncImage` usage on Library cards with a cache-aware image view that synchronously renders already-loaded artwork.
3. Reuse the same cache-aware component for Home cards if applicable.
4. Keep placeholder fallback for genuinely missing or failed cover URLs.
5. Add regression coverage for the cache contract, plus manual QA for segment switching.

### Acceptance criteria

- After a cover has loaded once, switching `Reading → Planned → Reading` renders the existing cover immediately.
- Empty `Planned` state does not clear or invalidate cover artwork for other segments.
- The fix is generic for all source sites and not tied to AsuraScans/Vortex.
- Existing missing-cover fallback behavior remains intact.

### Implemented solution — 2026-05-24

- Added a shared cache-aware cover artwork loader for card images.
- Replaced direct `AsyncImage` usage in Library and Home card/detail artwork with the cache-aware component.
- Existing placeholders remain for missing or first-time-loading covers, but already-loaded covers can render synchronously after segment/view recreation.
- Added regression coverage for the cover cache contract.

## DEF-017 — ManhuaUS chapter page fails to load cleanly and allows ads/popups through

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-24  
**Area:** Browser loading, site profiles, Reader extraction, ad/popup suppression

### User-visible problem

Attempting to access `https://manhuaus.com/manga/the-cold-blooded-warrior/chapter-54/` produced page loading errors. The site should load in the in-app browser when possible and ToonEdge should suppress ads/popups while extracting/displaying the toon content.

### Expected behavior

- ManhuaUS chapter pages should be treated as a supported browser-session style source when loaded by the user.
- Cloudflare/challenge pages must not be converted to Reader.
- Once the real chapter DOM is available, ToonEdge should extract only ordered chapter page images into Reader.
- Browser chrome should suppress common ad/pop-up surfaces and third-party target-window popups where possible without breaking first-party navigation.

### Evidence

- User reported loading errors for the chapter URL on 2026-05-24.
- Independent request inspection shows the site can return a Cloudflare `403` challenge with `cf-mitigated: challenge` and `Just a moment...` HTML to non-browser clients.
- Search/opened page metadata shows the real chapter contains ordered chapter images plus sign-in/sign-up/lost-password modal markup after the toon content.

### Initial root-cause assessment

- ManhuaUS is not currently represented in the default site-profile registry.
- The source may require browser-session hydration/challenge handling rather than direct static fetch behavior.
- Existing extraction already avoids mutating arbitrary source pages, but Browser-level ad/popup suppression is minimal.

### Initial implementation plan

1. Add ManhuaUS as an approved non-promoted browser-session profile with reader/chapter selector hints.
2. Keep Cloudflare/challenge pages low confidence with diagnostics and no Reader conversion.
3. Add Browser-level defensive sanitization for common ad/modal/popup containers.
4. Add a popup policy that blocks third-party target-window popups while allowing same-host user navigation.
5. Add regression tests for ManhuaUS profile classification, challenge suppression, viable chapter promotion after browser-session follow-up, and popup policy.

### Acceptance criteria

- ManhuaUS is recognized by the site-profile registry.
- Initial ManhuaUS browser-session detection does not prematurely convert challenge/partially hydrated pages.
- Follow-up detection can promote a viable ManhuaUS chapter image set to Reader.
- Reader image extraction excludes ad/modal/sidebar/non-reader candidates and preserves ordered toon pages.
- Third-party popups are blocked or ignored by Browser coordination.

### Implemented solution — 2026-05-24

- Added ManhuaUS to the default site-profile registry as an approved non-promoted browser-session profile.
- Added a Browser user-agent and document-end sanitizer script to hide common ad/popup/sidebar/modal surfaces while preserving reader/chapter containers.
- Added target-window popup policy to allow same-host navigation and ignore third-party popup destinations.
- Tightened image exclusion so common `/uploads/` image paths are not falsely blocked by broad `ads` substring matching.
- Added regression coverage for ManhuaUS browser-session promotion, popup policy, sanitizer presence, and cover cache behavior.

## DEF-016 — Home Continue Reading uses compact rows instead of card-style series artwork

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-23  
**Area:** Home, Continue Reading UI, recent-reading presentation

### User-visible problem

On the Home tab, `Continue Reading` shows compact horizontal rows with small placeholder icons instead of richer card-style recent series views with cover artwork.

### Expected behavior

- Home `Continue Reading` should use a card-style presentation for recent series.
- Cards should show cover artwork when available.
- If cover artwork is missing, use the existing placeholder treatment.
- The visual treatment should feel consistent with Library cards while still fitting the Home layout.
- Multiple recent items should remain scannable without overcrowding the screen.

### Evidence

- Screenshot captured on 2026-05-23 shows `Continue Reading` entries for:
  - `The Extra’s Academy Survi...`
  - `asurascans.com`
  - `Past Life Returner`
- Entries render as horizontal rows with small purple placeholders and no cover artwork.

### Initial root-cause assessment

- `LibrarySeriesSummary` carries `coverImageURL`, but `SeriesSummary`, the Home-facing model, does not.
- `homeSummary(_:)` discards cover artwork before Home renders the card.
- `HomeSeriesCard` always renders a small symbolic rectangle instead of a cover-aware card image.

### Acceptance criteria

- Home `Continue Reading` carries and renders available cover images.
- Placeholder-only cards are used only when no cover is available.
- Continue Reading uses a card-style visual treatment rather than plain compact rows.
- Layout remains usable for 3–4 recent entries.
- Regression coverage verifies cover propagation into Home summaries.

### Implemented solution — 2026-05-23

- Extended the Home-facing `SeriesSummary` model to carry `coverImageURL`.
- Preserved cover artwork when converting Library summaries into Home summaries.
- Updated Home cards so featured Continue Reading entries render a larger cover-aware card treatment instead of only a compact symbolic row.
- Added regression coverage for cover propagation into Home Continue Reading summaries.

## DEF-015 — Domain-level AsuraScans placeholder series duplicates the actual series

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-23  
**Area:** Library persistence, recent-reading identity, save-to-library flow, series metadata

### User-visible problem

After saving an AsuraScans series, Library shows duplicate AsuraScans entries:

1. a real series card with the extracted title/cover, such as `The Extra’s Academy Survival Guide`
2. a generic `asurascans.com` placeholder card with no real cover, `0/0` or `0/1` chapters, and generic chapter metadata

The placeholder appears in both Recent and Reading/Saved-style library views, and opening it shows a non-series detail page.

### Expected behavior

- ToonEdge should show one distinct Library/Recent card per actual series.
- The same source series should not appear both as a domain-level placeholder and as a real series.
- Domain-only records such as `asurascans.com` should not be promoted to Library cards when they do not represent an actual series.
- Saving a real series should merge, replace, or suppress any earlier placeholder recent-reading record for the same canonical series/source flow.

### Evidence

- Screenshot captured on 2026-05-23 shows:
  - `The Extra’s Academy Survi...` with AsuraScans cover artwork
  - a separate `asurascans.com` placeholder card beside it
  - additional placeholder `asurascans.com` card lower in the grid
- Detail screenshots show:
  - one placeholder entry with `asurascans.com • 0/0 chapters` and no chapters
  - another recent placeholder with `asurascans.com • 0/1 chapters` and a chapter row for the actual series

### Initial root-cause assessment

- Some Reader/detection sessions can still be created with domain-level metadata before series metadata enrichment completes.
- Recent-reading persistence keys primarily by canonical series URL / series ID. If an early session uses a domain/chapter-derived placeholder identity and a later save uses the resolved series identity, the repository can retain both records.
- Saved-library and recent-reading de-duplication does not fully suppress recent-only placeholder records that point to the same eventual source series or source domain/title pattern.
- Series Detail for recent-only entries can expose placeholder records instead of treating them as transient/incomplete records.

### Initial investigation plan

1. Reproduce with an AsuraScans chapter read followed by save-to-library.
2. Inspect the sequence of `MockReaderSession` values:
   - initial `seriesTitle`
   - `seriesURL`
   - `sourceDomain`
   - `coverImageURL`
   - chapter count/image payload
3. Inspect `SwiftDataLibraryRepository.recordRecentReading`, `addToLibrary`, duplicate normalization, and snapshot assembly.
4. Add regression coverage for:
   - placeholder recent record followed by real saved series
   - same source domain + same canonical series URL collapse
   - domain-only records excluded from visible Library cards when they have no chapter payload
5. Fix at persistence identity/normalization level, not by hiding AsuraScans specifically in the UI.

### Acceptance criteria

- Saving an AsuraScans series after reading it results in a single visible card for the actual series.
- Domain-only placeholder entries such as `asurascans.com` are not visible as standalone Library/Recent cards when a real series record exists.
- Placeholder records with no chapter payload or `0/0` chapters are not promoted into Series Detail as if they were real series.
- Duplicate prevention is generic and applies to other website profiles with delayed metadata enrichment.
- Regression coverage proves placeholder-to-real-series merge/suppression for recent and saved library snapshots.

### Implemented solution — 2026-05-23

- Library snapshots now suppress domain-title placeholder records such as `asurascans.com` from visible series/recent lists.
- When a placeholder recent-reading record exists and a real series from the same source domain exists, the recent entry resolves to the real series summary while preserving recent progress context.
- Series Detail no longer promotes domain-title placeholder records as standalone real series pages.
- Added regression coverage for placeholder suppression after a real AsuraScans series is saved.

## DEF-014 — AsuraScans recent/library card does not resolve series cover artwork

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-22  
**Area:** Series metadata extraction, Library artwork, recent-reading cards

### User-visible problem

An AsuraScans title appears in Recent/Library with the generic placeholder artwork instead of the corresponding series cover image.

Observed source:

- `https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/97`

### Expected behavior

- Recent and Library cards should show the best available series cover when the source site exposes one.
- AsuraScans chapter-origin sessions should be able to resolve or refresh series-level artwork from the canonical series/index page.
- The card should not remain on the generic initials/placeholder artwork when a valid cover can be discovered safely.

### Evidence

- Screenshot captured on 2026-05-22 shows:
  - `asurascans.com` card in Recent Library
  - generic purple placeholder artwork with the letter `A`
  - neighboring Vortex title correctly showing cover artwork

### Initial investigation plan

1. Inspect AsuraScans chapter and series/index metadata for cover candidates:
   - Open Graph / Twitter images
   - JSON-LD `ImageObject`
   - visible series cover image near title/header
   - chapter page links back to canonical comic/series page
2. Verify whether ToonEdge is saving only the chapter URL/domain before series metadata refresh has enough canonical series context.
3. Extend the generic metadata parser or add AsuraScans profile-specific cover hints only if generic metadata is insufficient.
4. Ensure cover refresh can replace an existing placeholder for recent-reading and saved-library entries.

### Acceptance criteria

- The AsuraScans title resolves a real cover image when available from the source site.
- Recent Library and Reading/Saved Library cards use the resolved cover instead of the generic placeholder.
- Existing placeholder artwork can be replaced on later metadata refresh.
- The implementation remains generic where possible and does not hardcode a piracy-oriented catalog list.
- Regression coverage includes an AsuraScans-style metadata fixture where the chapter page links to series cover metadata.

### Implemented solution — 2026-05-23

- Added canonical series URL resolution for AsuraScans-style chapter URLs, mapping `/comics/<slug>/chapter/<number>` to `/comics/<slug>` before metadata refresh.
- Extended generic series metadata parsing to consider conservative visible cover image candidates near series metadata when structured JSON-LD cover data is unavailable.
- Preserved existing Recent/Library cover artwork when later progress writes do not provide a cover URL, avoiding placeholder regressions.
- Added regression coverage for Asura-style visible cover extraction, canonical series URL resolution, and nil-cover preservation.

## DEF-013 — Large navigation/header titles render black on dark backgrounds

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-22  
**Area:** Global navigation/header styling, dark mode readability

### User-visible problem

On dark screens, large top titles such as `Library` render as black or near-black text, making them effectively unreadable.

### Expected behavior

- Large navigation/header titles should render in white or another readable light color.
- This should apply consistently across dark-mode screens, not only Library.
- The fix should not require each individual screen to manually override title color if a shared style can handle it.

### Evidence

- Screenshot captured on 2026-05-22 shows the large `Library` title above `Collection` blending into the dark background.
- This appears related to, but not fully resolved by, DEF-012.

### Acceptance criteria

- `Library` large title is readable in white/light text.
- Other large navigation titles using the same app chrome are also readable.
- Existing body/header text remains unchanged unless needed for consistency.
- Regression/manual QA includes Library, Home, Downloads, and Settings top headers.

### Implemented solution — 2026-05-23

- Strengthened the shared ToonEdge screen chrome so navigation bars use dark color scheme, visible dark background, and the app's dark presentation.
- Added a small testable navigation chrome contract to guard the expected readable dark-mode navigation behavior.
- Manual simulator QA is still recommended for Library, Settings, and Downloads because SwiftUI navigation-title color is ultimately rendered by UIKit.

## DEF-012 — Dark-mode screen headers use unreadable near-black text

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-18  
**Area:** Design system, typography color tokens, dark mode

### User-visible problem

Top-level screen headers can render in near-black text on the dark app background, making them difficult to read. The issue is visible on Library (`Library`) and appears likely to affect other large headers that use the same styling path.

### Expected behavior

- In dark mode, primary page headers should render with a readable light foreground color.
- Shared header/title styling should use the correct semantic text token rather than a hardcoded or inherited black foreground.
- Header contrast should be consistent across top-level and detail screens.

### Evidence

- Screenshot captured on 2026-05-18 shows the `Library` page title barely visible against the dark background.
- A related Series Detail screenshot also showed a nearly black top navigation title, suggesting the problem is not isolated to one view.

### Initial investigation plan

1. Audit top-level and navigation-title text styling for hardcoded black / default foreground usage.
2. Compare affected headers against components already using `ToonEdgeColor.textPrimary`.
3. Move shared title styling onto semantic color tokens where needed.
4. Verify representative screens in dark mode:
   - Library
   - Series Detail
   - Home
   - Settings / Downloads if they use the same header path

### Acceptance criteria

- Primary headers render in a readable light color in dark mode.
- Library title is clearly legible without relying on brightness or screenshot adjustment.
- Shared title styling is consistent across affected screens.
- No screen header regresses to unreadable near-black text on the dark theme.

## DEF-011 — Series Detail shows a redundant duplicate title in the navigation bar

**Status:** Implemented  
**Severity:** Low  
**Reported:** 2026-05-18  
**Area:** Library UI, Series Detail navigation chrome

### User-visible problem

On Series Detail, the series title appears twice:

1. once as the navigation-bar title at the top of the screen
2. again as the actual detail-page heading beside the cover image

In dark mode, the top navigation title can also appear nearly black against the dark background, making it look accidental or broken.

### Expected behavior

- Series Detail should show the title once in the main detail header.
- The navigation bar should keep the back affordance but omit the duplicate series title.
- The screen should feel visually cleaner and avoid redundant title repetition.

### Evidence

- Screenshot captured on 2026-05-18 shows:
  - top navigation title: `Past Life Returner`
  - detail header title: `Past Life Returner`
  - the top title rendering with poor contrast in dark mode

### Acceptance criteria

- Series Detail no longer renders the duplicate top navigation title.
- Back navigation remains available.
- The detail-page header remains the sole visible series-title treatment.

## DEF-010 — Reader next/previous navigation stalls when chapter was opened from Library

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-18  
**Area:** Reader chapter navigation, Library-origin sessions

### User-visible problem

When a chapter is opened from Library and the user taps `Next` or `Previous` in Reader, ToonEdge does not continue to the adjacent chapter.

### Expected behavior

- Reader `Next` and `Previous` should work regardless of whether the current chapter was opened from Browser or Library.
- If an adjacent chapter is not already stored locally, ToonEdge should still load the adjacent chapter through the web/detection path when a valid adjacent chapter URL is known.
- The user should remain in the Reader flow when the adjacent chapter can be safely converted.

### Current behavior

- Browser-origin Reader sessions can use the preserved Browser flow to load adjacent chapter URLs.
- Library-origin Reader sessions currently depend on direct/stored Reader payload availability first; when the adjacent chapter is not already stored, navigation does not provide the same web-backed continuation path.

### Initial root-cause assessment

- The recent Reader navigation implementation split behavior by launch origin:
  - Browser-owned Reader uses the live Browser to load and detect adjacent chapters.
  - App-shell / Library-origin Reader tries stored payload reuse, then falls back to the older direct-reader path rather than a real adjacent web-load/detection flow.
- This leaves Library-origin sessions without equivalent continuation capability when only adjacent URLs are known.

### Proposed direction

1. Introduce a Reader-adjacent-chapter loading path that is available to Library-origin sessions too.
2. Reuse known adjacent URLs and existing detection/viability gates rather than requiring the chapter to be pre-stored.
3. Preserve Reader launch origin so Back still returns to Series Detail after adjacent navigation.
4. Keep the same safe fallback rule: if the adjacent chapter cannot become a viable Reader session, do not present a blank/incomplete Reader.

### Acceptance criteria

- From a Library-launched Reader session, tapping `Next` loads the next adjacent chapter when a valid adjacent URL exists.
- From a Library-launched Reader session, tapping `Previous` loads the previous adjacent chapter when a valid adjacent URL exists.
- Navigation works even when the adjacent chapter was not already stored locally.
- After adjacent navigation from Library, Back still returns to native Series Detail.
- Failed/unsafe adjacent extraction does not open a broken Reader session.

### Follow-up story

- Story 11.23 covers the deeper seamless UX improvement: app-originated Reader sessions should fetch unstored adjacent chapters through a hidden/background loader so the user does not visibly bounce through Browser.

## DEF-009 — Search input is clipped offscreen on first overlay open

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-18  
**Area:** Search overlay layout, first-focus state

### User-visible problem

When opening the search bar / search overlay for the first time, the actual text-entry field is hidden or clipped at the very top of the screen. It becomes visible only after the user starts typing and the layout refreshes.

### Expected behavior

- The search input field is fully visible immediately when the search overlay opens.
- First-open layout should match the typing state layout except for the absence of entered text.
- Users should not need to type blindly to reveal the field they are meant to interact with.

### Evidence

- Screenshot captured on 2026-05-18 shows:
  - visible `Cancel`
  - visible `Suggestions`
  - the search text-entry container clipped against the top edge
  - suggestions list rendering below it
- The issue resolves after text entry begins, which suggests a first-open layout/focus-state discrepancy rather than missing content.

### Initial investigation plan

1. Reproduce from a fresh app launch and compare:
   - first overlay presentation
   - subsequent overlay presentations
   - idle focused state vs typing state
2. Inspect Search overlay layout constraints / safe-area handling / keyboard avoidance around the text field.
3. Check whether focus activation, sheet presentation animation, or conditional content changes alter the top inset only after typing.
4. Add regression coverage for the first-open search overlay state if feasible.

### Acceptance criteria

- Opening Search from a fresh launch shows the full input field without requiring any typing.
- `Cancel`, input field, and `Suggestions` title are all visible in the correct order on first presentation.
- Typing no longer causes a corrective layout jump for the input field.

### Implemented solution — 2026-05-19

- Removed the first-open dependency on a navigation-toolbar `Cancel` item.
- Search input and `Cancel` now live together in the sheet content header, so they share the same safe-area and keyboard-avoidance layout.
- Focus activation is delayed until after the first layout pass to avoid the keyboard/focus update racing the initial sheet layout.
- Suggestions are contained in a scroll view so keyboard compression does not push the input offscreen.

## DEF-008 — Library can store a social-preview banner instead of the series cover

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-18  
**Area:** Series metadata extraction, Library artwork

### User-visible problem

Observed on:

- `https://vortexscans.org/series/past-life-returner`

The saved Library artwork can appear as a wide page-preview/banner crop rather than the portrait series cover.

### Expected behavior

- Library cards and Series Detail should prefer a true series cover when the source page exposes one.
- Generic social-preview images should be used only as a fallback when no stronger cover signal exists.
- Existing preview artwork should be replaceable when a better cover is later discovered.

### Root cause and implemented solution

- The metadata parser previously read only `og:image` / `twitter:image`.
- Vortex exposes a wide social-preview image in Open Graph metadata, but the actual portrait cover in JSON-LD as an `ImageObject`.
- The parser now prefers portrait JSON-LD `ImageObject` candidates before falling back to Open Graph / Twitter images.
- Reader metadata refresh now replaces an already-stored preview image when better cover metadata becomes available.

### Coverage and scope

- This is a general improvement, not a Vortex-only rule.
- It benefits any site that exposes structured portrait `ImageObject` metadata.
- Sites that expose only generic preview artwork still fall back conservatively to the available social image rather than guessing from arbitrary page images.

### Acceptance criteria

- When both a wide social preview and a portrait structured cover exist, ToonEdge stores the portrait cover.
- When only social metadata exists, ToonEdge still stores the available fallback image.
- A previously stored preview image can be replaced by a better structured cover on later metadata refresh.

## DEF-007 — ManhwaTop can open Reader with blank pages

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-15  
**Area:** Site profiles, extraction quality, Reader launch safety

### User-visible problem

Observed on:

- `https://manhwatop.com/manga/past-life-returner/chapter-1/`

Reader opens, but the chapter contains multiple blank pages instead of a viable ordered image set.

### Expected behavior

- ManhwaTop should enter Reader Mode only when ToonEdge has extracted a viable ordered image set.
- Placeholder, blank, ad, or challenge assets must not become Reader pages.
- If extraction is incomplete or unsafe, the page should remain in Browser.

### Root cause and implemented solution

- ManhwaTop had only challenge/browser-only fixture coverage, so the codebase did not contain a viable positive path for the new product intent.
- The profile is now reader-capable (`approvedNonPromoted`, hydrated DOM template) rather than browser-only.
- Added regression coverage for:
  - viable ManhwaTop chapters promoting to Reader
  - blank placeholder images remaining excluded
  - challenge pages still staying out of Reader

### Acceptance criteria

- A viable ManhwaTop chapter extracts ordered visible page images and can auto-open Reader.
- Challenge or incomplete ManhwaTop pages stay in Browser.
- Blank/placeholder assets are excluded from Reader sessions.

## DEF-006 — Save, recent-reading, and typed-search history are unavailable in the running app

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-15  
**Area:** App dependency wiring, Library lifecycle, Search history

### User-visible problem

1. Reader does not show a save-to-library option.
2. Library does not retain recently read manhwas under Recent unless they were explicitly saved.
3. Search does not retain the exact query used to find a manhwa.

### Expected behavior

- Persistent builds expose `Add to Library`.
- Recently read manhwas appear under Recent even when unsaved.
- The exact typed search query is persisted and reused in visible suggestions.

### Root cause and implemented solution

- `ToonEdgeAppEntry` was constructing `ToonEdgeRootView()` with default mock dependencies.
- Shipping launch now builds persistent dependencies by default.
- Added a dedicated recent-reading persistence path separate from saved-library membership.
- Reader progress writes now record recent-reading entries.
- Exact typed search queries continue to be recorded independently from clicked links through the persistent history repository.

### Acceptance criteria

- Persistent app launch exposes `Add to Library`.
- Unsaved recently read titles appear in Recent.
- Submitted queries remain available as recent searches after reopening search.

## DEF-005 — Reader `x` still returns to the chapter browser page

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-15  
**Area:** Browser-owned Reader routing

### User-visible problem

Tapping `x` from Reader returns to the current chapter browser page instead of the source series/index page.

### Expected behavior

- Reader `x` leaves the current chapter and opens the canonical source series/index URL.
- `View Original Page` remains the explicit action for returning to the exact chapter URL.

### Root cause and implemented solution

- The browser-owned Reader path dismissed Reader and mutated router state, but never instructed the already-mounted live `WKWebView` to navigate away from the chapter URL.
- Browser commands now support explicit URL loads.
- Browser-owned Reader `x` dismisses Reader and commands the preserved browser to load the canonical series URL.
- `View Original Page` still only dismisses Reader and preserves the chapter page.

### Acceptance criteria

- `x` from browser-owned Reader loads the source series/index URL in the live browser.
- `View Original Page` still returns to the same chapter page.

## DEF-004 — Visible Reader chrome can block the second content tap

**Status:** Implemented  
**Severity:** Medium  
**Reported:** 2026-05-15  
**Area:** Reader interaction

### Problem

Reader chrome could be revealed with a content tap, but the visible full-screen chrome layer then intercepted the next tap, making it unreliable to hide controls again and creating the impression that scrolling had been taken over.

### Resolution

- The decorative chrome gradient no longer participates in hit testing.
- Tapping visible chrome outside of controls now also toggles chrome back off.
- `x` semantics were clarified at the same time: `x` now returns to the source series/index page, while `View Original Page` remains the exact chapter return path.

### Acceptance criteria

- Tap once reveals chrome.
- Tap again hides chrome.
- Scroll interaction remains available after chrome dismissal.

## DEF-003 — Browser-to-reader handoff still fails in simulator, and upward scrolling jitters after lazy image loads

**Status:** Implemented; manual QA recommended  
**Severity:** High  
**Reported:** 2026-05-15  
**Area:** Browser detection presentation, Reader layout stability

### User-visible problem

Observed on:

- `https://vortexscans.org/series/past-life-returner/chapter-1`

Observed behavior:

1. The chapter remains visible in Browser even after detection should have enough evidence to enter Reader.
2. No automatic Reader takeover is visible, and there is no visible browser/reader swap while staying in the flow.
3. Reader only becomes visible after the Browser is dismissed.
4. In Reader, downward scrolling works, but scrolling back upward causes visible jitter and can prevent steady upward progress.

### Expected behavior

- High-confidence chapter detection visibly presents Reader above Browser without requiring Browser dismissal.
- Returning to the original page is explicit via `View Original Page`; the user should not have to discover Reader by leaving Browser.
- Scrolling upward through a loaded chapter should remain stable and continuous.

### Evidence gathered

- `vortexscans.org` exposes a long ordered chapter for `past-life-returner/chapter-1`; current indexed content shows at least 60 chapter page images.
- The current codebase intends browser-owned Reader presentation:
  - `BrowserView` watches `pendingReaderSession` and calls `presentPendingReaderInsideBrowser(_:)`
  - `BrowserView` owns a local full-screen Reader cover
  - `BrowserExperienceTests.browserOwnsDetectedReaderPresentationWithoutChangingAppShellReader()` verifies view-model state, but not the actual SwiftUI cover stack at runtime
- The reported simulator behavior still matches the older failure mode where Reader exists behind Browser, so the remaining issue is either:
  1. the simulator build under test did not include the newer browser-owned presentation path, or
  2. the current nested presentation path is not actually surfacing Reader at runtime even though the state model is correct.
- The current Reader layout uses a fixed `430pt` placeholder for every unloaded page, then replaces it with the actual image height after load.
- Long vertical manhwa pages can be many thousands of points tall. When an image above the viewport expands from `430pt` to its real height while the user is scrolling upward, the scroll offset shifts substantially, which is consistent with the reported jitter.

### Current root-cause assessment

#### Reader handoff

Root cause is not fully proven yet.

The intended code path is present, but the live simulator behavior conflicts with that implementation. This needs runtime-level verification, not just view-model tests:

- confirm the app binary under test contains the latest handoff code
- log whether detection produces `.high`
- log whether `pendingReaderSession` becomes non-`nil`
- log whether `browserOwnedReaderSession` becomes non-`nil`
- verify whether the nested `fullScreenCover` is presented while Browser itself is already presented

#### Upward-scroll jitter

Most likely root cause:

- Reader placeholders do not reserve the eventual image height.
- As earlier pages finish loading, the LazyVStack grows above the current viewport.
- Upward scrolling fights repeated layout expansion from images above the viewport.

### Proposed fix

#### 1. Prove and fix the Browser-to-Reader presentation path

Recommended next steps:

1. Add temporary diagnostics around detection confidence, `pendingReaderSession`, and `browserOwnedReaderSession`.
2. Add a UI/integration test that verifies a detected high-confidence chapter results in a visible Reader presentation above Browser, not only a view-model state change.
3. If nested `fullScreenCover` proves unreliable, move Browser and Reader into a single explicit in-flow state machine inside the Browser flow:
   - one root presentation from `AppShell`
   - Browser content and Reader content switch/overlay within that flow
   - `View Original Page` returns to the preserved `WKWebView`

Acceptance criteria:

- High-confidence Vortex-style pages visibly enter Reader without dismissing Browser.
- `View Original Page` returns to the same browser instance.
- UI coverage fails if Reader is only created behind Browser.

#### 2. Reserve stable Reader page heights before image decode

Recommended next steps:

1. Carry source dimensions or aspect-ratio metadata from detection into the Reader session where available.
2. Use the expected aspect ratio to reserve the final rendered page height before the image finishes loading.
3. Fall back to a measured ratio only when metadata is unavailable, then avoid changing height again once the page is visible if possible.
4. Add regression coverage for long vertical pages that load out of order while the visible position is below them.

Acceptance criteria:

- Unloaded pages reserve a height close to their final rendered height.
- Loading an image above the viewport does not cause large scroll-offset jumps.
- Upward scrolling through a long chapter remains smooth after images progressively load.

### Suggested implementation order

1. Instrument and reproduce the handoff failure in the current simulator build.
2. Add a failing UI/integration test for visible Reader takeover.
3. Stabilize the presentation architecture if the current nested-cover approach is the problem.
4. Add a failing regression test for layout growth from above-viewport image loads.
5. Add aspect-ratio-based placeholder sizing and verify upward-scroll stability manually on a long Vortex chapter.

### Implementation update — 2026-05-15

Completed:

- Added explicit browser Reader presentation diagnostics with states for:
  - no Reader presentation
  - pending browser-owned Reader
  - visible browser-owned Reader
- Added runtime OSLog events for pending, visible, and dismissed browser-owned Reader states.
- Preserved per-page image dimensions from detection into Reader sessions.
- Replaced the fixed `430pt` placeholder-only path with aspect-ratio-derived placeholder sizing when metadata is available.
- Added regression coverage for:
  - browser presentation-state transitions
  - browser presentation logging
  - detected Reader page-dimension preservation
  - metadata-derived placeholder sizing and fallback behavior

Still required:

- Re-run the Vortex simulator scenario on a fresh build to determine whether the live handoff issue is:
  1. detection never reaching browser-owned presentation, or
  2. nested presentation state advancing without a visible Reader cover
- Manually verify that upward scrolling on a long Vortex chapter is stable after aspect-ratio placeholders are in use.

### Implementation update — 2026-05-19

Completed:

- Replaced the nested Browser-owned Reader `fullScreenCover` with an explicit in-flow Reader overlay inside `BrowserView`.
- Browser remains mounted behind Reader, so `View Original Page` can return to the same live browser instance.
- This removes the remaining nested presentation risk where Reader state could advance without a visibly presented Reader cover.

Still recommended:

- Manual simulator QA on a Vortex-style long chapter to confirm visible takeover and upward scroll stability in the live app.

## DEF-002 — Reader placeholders can advance progress before page images load

**Status:** Implemented  
**Severity:** High  
**Reported:** 2026-05-15  
**Area:** Reader image loading, reader progress, blocked-page detection

### Problem

Some chapters enter Reader with a valid ordered page list, but early pages remain placeholders while later pages render. Because progress is currently updated from row appearance rather than successful image load, placeholders can advance saved progress before the page is actually readable.

Separately, blocked/challenge pages can look like failed extraction even though no chapter DOM is present.

### Evidence

- `vortexscans.org` currently exposes 11 ordered reader-tagged page images for the reported chapter, including valid page 1 and page 2 URLs.
- Those early page assets are large valid WebP files, so the remaining fault is reader-side load state rather than missing source URLs.
- The current reader uses raw `AsyncImage`, which does not provide retry control, per-page diagnostics, or a durable distinction between loading and failure.
- Reader progress is saved from `onAppear`, before the image is known to have loaded.
- `manhuaus.com` currently returns a Cloudflare challenge page instead of chapter content.

### Proposed solution

1. Add explicit challenge-page signals to browser page analysis and force those pages to low-confidence detection.
2. Replace raw `AsyncImage` usage in Reader with a small reader-owned loader that exposes `loading`, `loaded`, and `failed` states and supports retry.
3. Record visible reader progress only after the visible page has loaded successfully.

### Acceptance criteria

- Challenge pages do not present Reader or Clean Mode CTA.
- Reader pages expose retryable failure state instead of indistinguishable placeholders.
- A visible placeholder does not advance saved progress until its image loads.
- A successfully loaded visible page still advances progress and persists cache metadata.
- Existing image ordering behavior remains unchanged.

### Implemented solution

- `PageAnalysisScript` now emits challenge signals for common blocked-page markers.
- `GenericChapterDetector` forces challenge pages to low confidence and logs `challengePage=true`.
- Reader now uses `ReaderPageImageLoader` instead of raw `AsyncImage`.
- The loader exposes `idle`, `loading`, `loaded`, and `failed` states, retries transient failures once by default, and surfaces a retry action after terminal failure.
- `ReaderViewModel` now separates image visibility from image load success; saved progress updates only when the currently visible page has loaded.

### Verification

- Added regression tests for challenge-page suppression, load-aware progress, and transient image retry.

## DEF-001 — Reader Mode is created behind Browser and may open with incomplete images

**Status:** Implemented; manual QA recommended  
**Severity:** High  
**Reported:** 2026-05-14  
**Area:** Browser detection, Reader presentation, image extraction/loading

### User-visible problem

When opening a chapter URL from the in-app browser, ToonEdge may not visibly prompt for Reader Mode or visibly auto-switch into Reader Mode.

Observed examples:

- `https://vortexscans.org/series/the-back-alley-mage's-return/chapter-32`
- `https://manhuaus.com/manga/the-back-alley-mages-return/chapter-1/`

Observed behavior:

- The chapter page remains visible in Browser.
- No “Read in Clean Mode” prompt appears.
- When the Browser is dismissed, Reader is revealed underneath.
- Reader may contain missing placeholder pages near the top of the chapter.
- On some sites, Reader may contain no visible pages.

### Expected behavior

- High-confidence chapter pages should visibly auto-open Reader Mode.
- Medium-confidence chapter pages should show the “Read in Clean Mode” CTA.
- Low-confidence or blocked pages should remain in Browser.
- Reader should not be created behind Browser.
- Reader should not open with an empty or obviously incomplete page list.
- “View Original Page” must remain available.

### Evidence and root cause

There are multiple contributing issues.

1. Browser and Reader are sibling full-screen covers from `AppShellView`.

   `BrowserView` calls `router.presentReader(session)` when detection finds a high-confidence chapter. This sets `router.presentedReader`, but `router.presentedBrowser` remains set. SwiftUI keeps the already-presented Browser cover on top, so the Reader exists behind Browser and only becomes visible after Browser is dismissed.

2. Detection can run before chapter image dimensions are available.

   Some chapter pages expose semantically correct reader images, such as `data-reader-page-image`, before `naturalWidth`, `naturalHeight`, or layout dimensions are ready. The generic detector previously rejected zero-dimension candidates, which could prevent the CTA/auto-open or produce an incomplete reader session.

3. Some sites may be blocked or delayed by anti-bot/challenge pages.

   `manhuaus.com` returned a Cloudflare challenge during investigation. In that state, the DOM being analyzed is not the chapter DOM, so no reader images are available. ToonEdge should keep the page in Browser and avoid creating an empty Reader.

4. Native image loading is separate from the browser-loaded page.

   Even when `WKWebView` displays chapter images, `AsyncImage` loads them again from native SwiftUI. CDN behavior, transient failures, WebP decoding behavior, headers, or timing can cause individual pages to show placeholders.

### First-page/load-state investigation — 2026-05-15

Findings:

- The current `vortexscans.org` chapter HTML contains 11 ordered `data-reader-page-image` entries, starting with `01.webp` and `02.webp`.
- The first three chapter image URLs return `200` responses and valid WebP images. Their pixel sizes are very tall: page 1 is `800x14002`, page 2 is `800x14302`, and page 3 is `800x15000`.
- That means the observed missing top pages on `vortexscans.org` are not currently explained by extraction order or missing image URLs. The more likely remaining fault is reader-side load state: `AsyncImage` exposes no retry policy, no per-page diagnostics, and no distinction between a still-loading page and a terminally failed page.
- Reader progress is advanced from `ReaderImagePanel.onAppear`, so placeholders can move the saved visible index before their underlying image actually loads. This can make a partially loaded chapter reopen at a later placeholder rather than the true first rendered page.
- The current `manhuaus.com` response is a Cloudflare challenge page (`403`, `cf-mitigated: challenge`, title `Just a moment...`), so the analyzed DOM is not chapter content and should stay in Browser.

Investigation conclusion:

- `vortexscans.org`: extraction appears complete; prioritize a dedicated reader image loader plus progress gating on successful render/load state.
- `manhuaus.com`: add challenge-page detection before any Reader conversion attempt.

### Partial fix already applied

The detection model now carries image semantic hints, and page analysis captures reader-specific attributes. Browser-detected Reader Mode is now presented by `BrowserView` instead of app-shell routing, so Reader opens above the existing Browser instance rather than behind it.

Changed files:

- `app/Sources/ToonEdgeAppCore/Features/Detection/Models/DetectionModels.swift`
- `app/Sources/ToonEdgeAppCore/Features/Detection/JavaScript/PageAnalysisScript.swift`
- `app/Sources/ToonEdgeAppCore/Features/Detection/Scoring/GenericChapterDetector.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
- `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
- `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

Implemented behavior:

- `PageAnalysisScript` captures `data-reader-page-image` and related semantic hints.
- `GenericChapterDetector` can accept strongly reader-tagged images before dimensions load.
- Regression test added for reader-tagged chapter images with zero dimensions.
- Browser-detected high-confidence Reader sessions are stored in browser-owned presentation state.
- `BrowserView` presents Reader locally above the live Browser.
- Browser-owned Reader dismiss and “View Original Page” return to the existing Browser instance.
- App-shell Reader presentation remains available for direct Home and Library launches.

Verification after partial fix:

- `swift test --jobs 1` passed with 117 tests.
- `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/ToonEdgeDerivedData build CODE_SIGNING_ALLOWED=NO` passed.

### Remaining recommended solution

#### 1. Fix Browser-to-Reader presentation ownership

Replace sibling full-screen Browser and Reader presentation with a single browser reading flow.

Status: Implemented for browser-detected Reader sessions.

Recommended approach:

- Keep Browser as the active full-screen flow.
- Present Reader from inside `BrowserView` when detection succeeds.
- Preserve the existing `WKWebView` behind Reader so “View Original Page” can dismiss Reader and return to the original loaded page.
- Only use app-shell Reader presentation for Reader sessions launched directly from Home or Library.

Acceptance criteria:

- High-confidence detection visibly opens Reader above Browser.
- Dismissing Browser is not required to reveal Reader.
- “View Original Page” dismisses Reader and returns to the same Browser instance.
- Browser state is preserved.

#### 2. Add a Reader session completeness gate

Before presenting Reader, validate that the detected session has a plausible page count and source URLs.

Recommended behavior:

- If the page has strong reader semantic hints, wait briefly and re-run analysis when only a partial set is detected.
- Do not present Reader with zero images.
- For suspiciously incomplete sessions, show a non-blocking “Still loading page images” or “Try Clean Mode again” state instead of opening Reader.

Acceptance criteria:

- Empty Reader sessions are not presented.
- Partial sessions from still-loading chapter pages are retried once before degrading.
- Browser remains usable if extraction is incomplete.

Implementation update — 2026-05-19:

- Browser presentation now rejects empty Reader sessions before pending or visible Reader state is set.
- Browser-owned Reader presentation now uses an in-flow overlay rather than a sibling or nested full-screen cover.
- This keeps Browser usable behind Reader and avoids presenting an empty Reader when extraction yields no page URLs.

#### 3. Replace `AsyncImage` with a dedicated reader image loader

Reader image loading should use a small app-owned loader instead of raw `AsyncImage`.

Recommended behavior:

- Use `URLSession` with retry and cancellation.
- Preserve page ordering and stable layout placeholders.
- Support optional request headers when needed, such as a source-page referrer.
- Track per-page load failure separately from extraction failure.

Acceptance criteria:

- Individual image failures are retryable.
- Page failures are visible but do not collapse layout.
- Successfully loaded pages remain visible while failed pages retry.

#### 4. Handle challenge and blocked pages explicitly

Do not convert anti-bot or challenge pages into Reader.

Recommended behavior:

- Detect common challenge signals such as Cloudflare challenge title/body/script markers.
- Force confidence to low with diagnostics.
- Keep user in Browser.

Acceptance criteria:

- Challenge pages do not open empty Reader.
- Diagnostics indicate blocked/challenge page.
- User can continue using Browser normally.

### Would building our own browser instead of DuckDuckGo help?

Not materially for this defect.

The current issue is not caused by DuckDuckGo search results. It occurs after a destination chapter page is already loaded in ToonEdge's in-app `WKWebView`.

Building a custom search/browser layer may improve search UX later, but it would not solve:

- Reader being presented behind Browser
- DOM analysis running before reader images are ready
- Native image loading failures
- Cloudflare/challenge pages

The higher-impact fix is to make Browser and Reader one coordinated flow, improve extraction readiness checks, and replace `AsyncImage` with a reader-specific image loader.

### Suggested tests

- Browser high-confidence detection presents Reader visibly above Browser.
- “View Original Page” returns to the same Browser instance.
- Reader-tagged zero-dimension images are accepted after semantic analysis.
- Empty detection result does not present Reader.
- Challenge page detection remains in Browser.
- Reader image loader retries failed page image requests.
