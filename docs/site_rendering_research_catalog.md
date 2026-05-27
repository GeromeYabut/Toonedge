# Site Rendering Research Catalog

## Purpose

This document tracks site-level reader research needed to make ToonEdge render user-opened manga/manhwa chapter pages reliably.

This is an internal engineering and QA artifact. It is **not** an in-app catalog, recommendation surface, onboarding list, or promoted source list.

## Research rule

Do not classify a site from its homepage alone. Each site must be evaluated from at least one real series page and one real chapter page containing manga/manhwa images.

For each investigated site, capture:

- current canonical domain
- series-page example
- chapter-page example
- content type: manga, manhwa, manhua, mixed
- reader layout: long-strip, paged, right-to-left, mixed
- extraction method: generic heuristic, selector hints, or browser-only
- image delivery pattern: direct `src`, lazy attributes, `srcset`, canvas, API-backed, blocked
- page ordering source: DOM order, explicit page index, filename order, API order
- load-state risks: lazy loading, huge images, referer requirements, auth/challenge pages, anti-bot interstitials
- recommended ToonEdge support tier
- fixture/test needs

## Initial verified examples

| Site | Current example found | Notes |
| --- | --- | --- |
| Bato.to | Series page example found for `The Reincarnation Magician Of The Inferior Eyes` | Search-indexed series metadata links to a concrete chapter URL; direct lightweight fetch timed out during batch 1. |
| Asura Scans | Current series and chapter examples found on `asurascans.com` | Current pages expose enough HTML to document a concrete profile path. |

## Research queue

Status values:

- `queued`: not yet investigated
- `series-found`: real series page found, chapter page still needed
- `chapter-found`: real chapter page found, pattern extraction pending
- `profiled`: rendering guidance documented
- `blocked`: blocked by auth, challenge page, takedown, or inaccessible site

| Site | Status | Current domain | Series page | Chapter page | Notes |
| --- | --- | --- | --- | --- | --- |
| MangaDex | series-found | mangadex.org | found | app shell only | Lightweight fetch returned a shell without usable reader images; browser-session candidate, not yet registered. |
| Bato.to | blocked | bato.to | found | found via indexed metadata | Direct lightweight fetch timed out during batch 1; keep browser-only until live fetch behavior is rechecked. |
| MangaKakalot | queued |  |  |  |  |
| Manganelo | queued |  |  |  |  |
| Manganato | queued |  |  |  |  |
| MangaPark | blocked | mangapark.io | found via search | failed | Direct fetch failed during TLS negotiation in batch 4. |
| MangaFox | queued |  |  |  |  |
| MangaHere | profiled | mangahere.cc | found | found | Paginated single-image reader; browser-only for MVP because stitching is out of scope. |
| MangaBuddy | series-found | mangabuddy.com | found |  | Search-indexed series pages found; direct chapter behavior still needs a verified live page. |
| MangaReader | blocked | mangareader.to | found via search | timed out | Direct lightweight fetch timed out in batch 3. |
| MangaPill | queued |  |  |  |  |
| MangaSee | blocked | mangasee123.com | found via query | 404 | Direct test URL returned `404` in batch 4. |
| MangaFire | profiled | mangafire.to | found | found | JS-driven reader shell; chapter content is not present in initial HTML. |
| MangaOwl | queued |  |  |  |  |
| MangaKatana | profiled | mangakatana.com | found | found | Long-strip chapter pages expose ordered placeholders and hydrate image URLs in script. |
| ReadM | queued |  |  |  |  |
| TenManga | queued |  |  |  |  |
| KissManga | queued |  |  |  |  |
| 1st Kiss Manga | queued |  |  |  |  |
| Coffee Manga | queued |  |  |  |  |
| Asura Scans | profiled | asurascans.com | found | found | Current reader HTML includes explicit page metadata and rendered image elements. |
| Reaper Scans | blocked | reaperrscans.com | found via search | failed | Candidate domain returned server error; stale/unstable domain state needs re-verification. |
| Flame Scans | queued |  |  |  |  |
| Void Scans | queued |  |  |  |  |
| Luminous Scans | queued |  |  |  |  |
| Zero Scans | queued |  |  |  |  |
| Realm Scans | queued |  |  |  |  |
| Leviatan Scans | queued |  |  |  |  |
| Astra Scans | queued |  |  |  |  |
| Night Scans | queued |  |  |  |  |
| Omega Scans | queued |  |  |  |  |
| MM Scans | queued |  |  |  |  |
| ManhuaPlus | queued |  |  |  |  |
| Aqua Manga | queued |  |  |  |  |
| Drake Scans | queued |  |  |  |  |
| Rizz Fables | queued |  |  |  |  |
| Reset Scans | queued |  |  |  |  |
| Tritinia Scans | queued |  |  |  |  |
| Arven Scans | queued |  |  |  |  |
| Infernal Void Scans | queued |  |  |  |  |
| MangaClash | queued |  |  |  |  |
| MangaRaw | queued |  |  |  |  |
| Rawkuma | queued |  |  |  |  |
| Sen Manga | queued |  |  |  |  |
| MangaFreak | queued |  |  |  |  |
| MangaTX | queued |  |  |  |  |
| Hari Manga | queued |  |  |  |  |
| ManhwaTop | blocked | manhwatop.com | found | blocked | Indexed pages exist, but the live chapter fetch returned a Cloudflare challenge page in batch 1. |
| ManhwaClan | queued |  |  |  |  |
| Manhwa Freak | queued |  |  |  |  |
| ManhwaZ | queued |  |  |  |  |
| Toonily | profiled | toonily.com | found | found | Search-indexed chapter pages expose sequential page images and a load-all option. |
| ToonGod | queued |  |  |  |  |
| ManyToon | queued |  |  |  |  |
| WebComics | queued |  |  |  |  |
| Hiperdex | queued |  |  |  |  |
| Kun Manga | queued |  |  |  |  |
| TopManhua | queued |  |  |  |  |
| Nitro Scans | queued |  |  |  |  |
| Surya Scans | queued |  |  |  |  |
| Immortal Updates | queued |  |  |  |  |
| Temple Scan | queued |  |  |  |  |
| Scylla Scans | queued |  |  |  |  |
| Cosmic Scans | queued |  |  |  |  |
| Animated Glitch Scans | queued |  |  |  |  |
| Shimada Scans | queued |  |  |  |  |
| Kai Scans | profiled | kaiscans.org | found | found | Search-indexed chapter pages expose sequential chapter images in a long strip. |
| Gourmet Scans | queued |  |  |  |  |
| MangaHub | queued |  |  |  |  |
| Comick | blocked | comick.io | found via search | blocked | Direct lightweight fetch returned a Cloudflare challenge page in batch 3. |

## Per-site write-up template

### Site name

- Current domain:
- Support tier recommendation:
- Series page example:
- Chapter page example:
- Content type:
- Reader layout:
- Extraction recommendation:
- Image delivery:
- Page ordering:
- Load-state / anti-bot risks:
- Required fixtures:
- Notes:

## Batch 1 summary

Batch 1 covered eight representative sites: `MangaFire`, `MangaKatana`, `Asura Scans`, `Toonily`, `Kai Scans`, `MangaBuddy`, `Bato.to`, and `ManhwaTop`.

The first pass exposed four distinct compatibility classes:

1. **Embedded page data in HTML**: direct reader candidates when the DOM already carries page URLs and order metadata.
2. **Lazy-source hydration**: feasible with selector hints or script-aware extraction, but risky for first-page completeness if ToonEdge snapshots too early.
3. **JS-driven reader shells**: likely require browser-session extraction rather than relying on the initial response body.
4. **Challenge-gated or unreachable pages**: should remain browser-only until detection can suppress false reader prompts and QA has a reliable live path.

Near-term implementation implication: the next hardening story should focus on `SiteProfile` fixtures that distinguish `embedded`, `hydrated`, `session-extracted`, and `browser-only` handling rather than treating all chapter pages as one generic DOM problem.

## Batch 2 summary

Batch 2 revisited `Toonily` and `Kai Scans`, added `MangaPill`, and reused `ManhwaTop` as the negative/challenge control.

Findings:

1. **MangaPill fits the existing hydrated-DOM bucket**: live chapter HTML exposes ordered `data-src` images with page counters, so no new template is needed yet.
2. **Toonily remains browser-only for now**: indexed chapter content is visible, but the direct lightweight fetch still returned a Cloudflare challenge page in batch 2.
3. **Kai Scans remains unregistered**: indexed chapter content exists, but direct lightweight fetches still reset before usable chapter DOM could be captured.
4. **No new runtime template was justified**: the research widened confidence in the current buckets instead of proving a distinct fifth class.

## Batch 3 summary

Batch 3 intentionally probed for a fifth compatibility bucket using `MangaDex`, `Comick`, `MangaReader`, and `Toonily` as a blocked control.

Findings:

1. **MangaDex still fits an existing browser-session bucket**: the lightweight response returned an app shell without usable chapter image payloads, which is insufficient for first-pass conversion but not a distinct class by itself.
2. **Comick remained challenge-gated**: the live fetch returned a Cloudflare challenge page.
3. **MangaReader remained unclassified**: the direct lightweight fetch timed out before usable chapter HTML was captured.
4. **Toonily again confirmed the blocked-control case**: live direct fetch still returned a Cloudflare challenge page.
5. **No new runtime template was added**: the existing four-bucket model still covered all evidence gathered so far.

## Batch 4 summary

Batch 4 tested whether the current model misses paginated or stale-domain readers using `MangaHere`, `MangaSee`, `MangaPark`, and `Reaper Scans`.

Findings:

1. **MangaHere exposed a distinct paginated-reader pattern**: the live chapter page presents one image at a time, page navigation links, and chapter metadata for the current page only.
2. **That pattern is browser-only for MVP**: supporting it cleanly would require post-MVP multi-page stitching, which remains explicitly out of scope.
3. **MangaSee test URL returned `404`**, so no runtime classification was added.
4. **MangaPark direct fetch failed during TLS negotiation**, so it remains unclassified.
5. **Reaper Scans candidates are unstable/stale**, and the direct page tested returned a server error rather than a usable chapter response.
6. **The current runtime buckets still hold for MVP**: paginated single-image readers are now documented as a known browser-only exclusion rather than a new supported template.

### MangaFire

- Current domain: `mangafire.to`
- Support tier recommendation: `browserOnly` until browser-session extraction is implemented
- Series page example: `https://mangafire.to/manga/chainsaw-man.kx1p6`
- Chapter page example: `https://mangafire.to/read/chainsaw-man.kx1p6/en/chapter-1`
- Content type: mixed
- Reader layout: mixed, with long-strip as one supported display mode
- Extraction recommendation: browser-session extraction after page hydration
- Image delivery: JS/API-backed; initial HTML exposes the reader shell but not page images
- Page ordering: session/API order, not recoverable from the initial HTML alone
- Load-state / anti-bot risks: JS dependency, delayed content population, Cloudflare/Turnstile assets present on the site shell
- Required fixtures: initial chapter HTML, post-hydration DOM snapshot, extraction timing fixture
- Notes: Generic initial-response parsing is insufficient for reliable reader launch.

### MangaKatana

- Current domain: `mangakatana.com`
- Support tier recommendation: `approvedNonPromoted` after adding a site profile
- Series page example: `https://mangakatana.com/manga/katana.3140`
- Chapter page example: `https://mangakatana.com/manga/katana.3140/c1`
- Content type: manga
- Reader layout: long-strip
- Extraction recommendation: selector hints plus hydration wait
- Image delivery: ordered page containers with `data-src` hydrated by inline script
- Page ordering: explicit DOM container order (`page1`, `page2`, ...)
- Load-state / anti-bot risks: first snapshot can see placeholders before real URLs are applied
- Required fixtures: pre-hydration and post-hydration chapter DOM
- Notes: Strong candidate for validating first-page/load-state correctness.

### Asura Scans

- Current domain: `asurascans.com`
- Support tier recommendation: `approvedNonPromoted`
- Series page example: `https://asurascans.com/comics/solo-leveling-b6e039fe`
- Chapter page example: `https://asurascans.com/comics/solo-leveling/chapter/111`
- Content type: manhwa
- Reader layout: long-strip
- Extraction recommendation: generic DOM extraction with optional selector hints
- Image delivery: direct reader images plus embedded page metadata in HTML
- Page ordering: explicit `data-page-index` and embedded page list order
- Load-state / anti-bot risks: image CDN dependency; recheck if chapter IDs or domains drift
- Required fixtures: embedded page-data chapter HTML, image ordering test
- Notes: Good baseline site for deterministic profile tests.

### Toonily

- Current domain: `toonily.com`
- Support tier recommendation: `browserOnly` until a direct live chapter fetch succeeds
- Series page example: `https://toonily.com/serie/mercenary-enrollment/chapter/`
- Chapter page example: `https://toonily.com/serie/solo-leveling-005/chapter-129/`
- Content type: manhwa
- Reader layout: long-strip
- Extraction recommendation: generic DOM extraction with load-all awareness
- Image delivery: sequential chapter images exposed in the indexed chapter page
- Page ordering: DOM order
- Load-state / anti-bot risks: direct lightweight fetch hit a Cloudflare challenge in batch 1 even though indexed chapter content exists
- Required fixtures: successful browser-session DOM, challenge-page fixture
- Notes: Batch 2 confirmed that search-index visibility and lightweight-client behavior remain separate signals.

### Kai Scans

- Current domain: `kaiscans.org`
- Support tier recommendation: `browserOnly` pending a successful direct live chapter fetch
- Series page example: `https://kaiscans.org/manga/asura-manhwa/`
- Chapter page example: `https://kaiscans.org/asura-manhwa-chapter-1/`
- Content type: manhwa
- Reader layout: long-strip
- Extraction recommendation: generic DOM extraction
- Image delivery: sequential chapter images exposed in the indexed chapter page
- Page ordering: DOM order
- Load-state / anti-bot risks: direct lightweight fetch reset during batch 1
- Required fixtures: browser-session DOM and retry/failure fixture
- Notes: Batch 2 still could not capture a successful direct response; keep this as a research item rather than a runtime registration.

### MangaPill

- Current domain: `mangapill.com`
- Support tier recommendation: `approvedNonPromoted`
- Series page example: `https://mangapill.com/manga/1411`
- Chapter page example: `https://mangapill.com/chapters/6965-10001000/qp-chapter-1`
- Content type: manga
- Reader layout: paged chapter HTML rendered as a sequential image list
- Extraction recommendation: hydrated-DOM template with selector hints
- Image delivery: ordered lazy `data-src` images in HTML
- Page ordering: DOM order plus visible page counters
- Load-state / anti-bot risks: lazy image hydration; some pages may be landscape spreads rather than tall manhwa panels
- Required fixtures: hydrated-DOM chapter analysis fixture
- Notes: Existing `hydratedDOM` handling is sufficient for current evidence; no new template added in batch 2.

### MangaDex

- Current domain: `mangadex.org`
- Support tier recommendation: `browserOnly` until a successful chapter payload strategy is proven
- Series page example: current public site
- Chapter page example: direct chapter fetch inspected in batch 3
- Content type: mixed
- Reader layout: app-shell / browser-session candidate
- Extraction recommendation: defer; current lightweight response is insufficient for conversion
- Image delivery: not present in the lightweight HTML response
- Page ordering: unknown from current response
- Load-state / anti-bot risks: app-shell rendering, additional data fetches required
- Required fixtures: browser-session shell fixture, post-load browser DOM fixture
- Notes: Current evidence fits the existing `browserSession` bucket; it does not justify a new runtime template.

### Comick

- Current domain: `comick.io`
- Support tier recommendation: `browserOnly`
- Series page example: search-indexed site found in batch 3
- Chapter page example: challenge-gated direct test URL
- Content type: mixed
- Reader layout: unknown from lightweight fetch
- Extraction recommendation: none until a successful live response is captured
- Image delivery: blocked
- Page ordering: unknown
- Load-state / anti-bot risks: Cloudflare challenge page
- Required fixtures: challenge-page fixture
- Notes: Stay browser-only until direct chapter behavior can be observed.

### MangaReader

- Current domain: `mangareader.to`
- Support tier recommendation: `browserOnly` pending direct inspection
- Series page example: search-indexed site found in batch 3
- Chapter page example: direct test URL timed out in batch 3
- Content type: mixed
- Reader layout: unknown
- Extraction recommendation: defer until a direct chapter response is captured
- Image delivery: unknown
- Page ordering: unknown
- Load-state / anti-bot risks: lightweight fetch timeout
- Required fixtures: timeout/failure fixture, later successful response fixture
- Notes: Search visibility alone is not enough to classify runtime support.

### MangaHere

- Current domain: `mangahere.cc`
- Support tier recommendation: `browserOnly`
- Series page example: `https://www.mangahere.cc/manga/i_reincarnated_as_a_white_pig_noble_s_daughter_from_a_shoujo_manga/`
- Chapter page example: `https://www.mangahere.cc/manga/i_reincarnated_as_a_white_pig_noble_s_daughter_from_a_shoujo_manga/c006/15.html`
- Content type: manga
- Reader layout: paginated single-image reader
- Extraction recommendation: none for MVP
- Image delivery: current page image with page-navigation links and chapter script metadata
- Page ordering: page index metadata, not a complete same-page image list
- Load-state / anti-bot risks: would require multi-page fetch/stitch logic to build a clean reader session
- Required fixtures: paginated single-page fixture for future post-MVP work
- Notes: Important negative case. This is exactly the pattern ToonEdge should leave in Browser until chapter stitching exists.

### MangaSee

- Current domain: `mangasee123.com`
- Support tier recommendation: `browserOnly` pending direct verification
- Series page example: not verified in batch 4
- Chapter page example: attempted direct test URL returned `404`
- Content type: mixed
- Reader layout: unknown
- Extraction recommendation: defer
- Image delivery: unknown
- Page ordering: unknown
- Load-state / anti-bot risks: stale or invalid direct path tested
- Required fixtures: one successful current chapter response
- Notes: Do not infer support from historical naming alone.

### MangaPark

- Current domain: `mangapark.io`
- Support tier recommendation: `browserOnly` pending direct verification
- Series page example: search-indexed brand found
- Chapter page example: direct fetch failed during TLS negotiation in batch 4
- Content type: mixed
- Reader layout: unknown
- Extraction recommendation: defer
- Image delivery: unknown
- Page ordering: unknown
- Load-state / anti-bot risks: transport failure on direct inspection
- Required fixtures: one successful direct response
- Notes: Keep in queue until a current live domain is confirmed.

### Reaper Scans

- Current domain: unstable / needs re-verification
- Support tier recommendation: `browserOnly`
- Series page example: candidate search result found in batch 4
- Chapter page example: not verified
- Content type: manhwa / mixed
- Reader layout: unknown
- Extraction recommendation: defer
- Image delivery: unknown
- Page ordering: unknown
- Load-state / anti-bot risks: candidate page returned server error; domain state appears unstable
- Required fixtures: current canonical domain, successful series page, successful chapter page
- Notes: Do not add runtime support until the current site state is clear.

### MangaBuddy

- Current domain: `mangabuddy.com`
- Support tier recommendation: `browserOnly` until a verified chapter page is captured
- Series page example: `https://mangabuddy.com/read/chainsaw-man/`
- Chapter page example: not yet verified
- Content type: mixed
- Reader layout: unknown
- Extraction recommendation: defer until a chapter page is captured
- Image delivery: unknown
- Page ordering: unknown
- Load-state / anti-bot risks: a direct test URL returned `502 Bad Gateway` during batch 1
- Required fixtures: one live series page, one live chapter page, one failure response
- Notes: Keep in the queue, but do not infer reader behavior from series metadata.

### Bato.to

- Current domain: `bato.to`
- Support tier recommendation: `browserOnly` pending a successful lightweight chapter fetch
- Series page example: `https://bato.to/series/74331`
- Chapter page example: indexed metadata references `https://bato.to/title/74517-the-reincarnation-magician-of-the-inferior-eyes/1327638-ch_1`
- Content type: mixed
- Reader layout: unknown
- Extraction recommendation: defer until a direct chapter response is captured
- Image delivery: unknown
- Page ordering: unknown
- Load-state / anti-bot risks: direct lightweight series and chapter fetches timed out in batch 1
- Required fixtures: successful chapter HTML or browser-session DOM, timeout fixture
- Notes: Public metadata is not enough to justify reader-mode behavior.

### ManhwaTop

- Current domain: `manhwatop.com`
- Support tier recommendation: `browserOnly` pending browser-session QA
- Series page example: indexed series metadata present on `https://manhwatop.com/manga/please-show-up/chapter-1/`
- Chapter page examples:
  - `https://manhwatop.com/manga/please-show-up/chapter-1/`
  - `https://manhwatop.com/manga/my-little-brother-is-the-academys-hotshot/chapter-0/`
- Content type: manhwa
- Reader layout: unknown from lightweight fetch; user reported the live chapter is reachable in a normal browser on 2026-05-15
- Extraction recommendation: re-evaluate as a `browserSession` candidate during simulator QA before changing runtime support
- Image delivery: blocked to lightweight fetches by Cloudflare challenge; browser-session behavior not yet verified in-app
- Page ordering: unknown
- Load-state / anti-bot risks: Cloudflare challenge page still returned to lightweight fetches during 2026-05-15 recheck
- Required fixtures: challenge-page fixture, plus browser-session DOM fixture if simulator QA confirms successful in-app rendering
- Notes: Keep false-positive suppression in place until simulator QA proves the app can reach and extract the settled browser DOM reliably.

## Open questions

- Which sites require explicit approval as `approvedNonPromoted` versus remaining `browserOnly`?
- Which domains have rebranded or moved since the original seed list was compiled?
- Which sites need fixture capture because generic detection produces false positives or incomplete sessions?
- Which sites require referer/header-aware image loading rather than plain native requests?
