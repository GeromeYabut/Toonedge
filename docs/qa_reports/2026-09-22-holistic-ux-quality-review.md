# ToonEdge Hands-on UX and Quality Review

**Review date:** 2026-09-22  
**Repository revision:** `8c538947d8a9191744e988e51529352e7e93a9c6`  
**Build:** Debug, `xcodebuild` succeeded with Xcode 16.4 (16F6)  
**Primary simulator:** iPhone 16 Pro, iOS 18.6, `04F65B71-EEB9-4085-BFBD-8B7406E480A2`  
**Dedicated small-device simulator:** iPhone 16e, iOS 18.6, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`  
**Automated baseline:** `swift test --package-path app --jobs 1` passed, 308 tests, 0 failures  
**Code changes:** None. This report and its evidence images are the only files added by this review.

## Method and scope

I read `AGENTS.md`, the architecture document, PRD, UX requirements, UX brief, `docs/defects.md`, and `docs/site_rendering_research_catalog.md` before testing. Conflicts were resolved using the documented order: architecture, PRD, UX requirements, then visual guidance and delivery planning.

I built and installed the current working tree, then exercised ToonEdge through the simulator UI. The initial iPhone 16 Pro contained pre-existing history, library, and cache data from another workstream. I preserved it and used it for live-site, resume, and populated-state checks. A separate iPhone 16e had a clean ToonEdge state and was used for the empty Home state and large-text checks. Existing uncommitted repository work was not edited.

Live-site results are a point-in-time compatibility sample. Exact URLs and access outcomes are recorded below. A page count found in a live web response is used only as a comparison point; it is not presented as proof that every image rendered in ToonEdge.

### Setup limitations

- The shared iPhone 16 Pro could not be reset because another workstream was using it. Persistence was tested against its existing state, then empty-state and text-size checks were moved to the dedicated iPhone 16e.
- VoiceOver traversal itself was not completed. The simulator accessibility tree was inspected for labels and ordering, but spoken focus behavior remains unverified.
- A large Pro Max device was not exercised. The iPhone 16e covered the small-device case and the iPhone 16 Pro covered the regular Pro layout.
- Network-offline mode was not toggled, and a retained chapter was not opened with networking disabled. Failed-load and retry behavior was observed, but full offline reading remains untested.
- Cache deletion was not performed because the populated simulator belonged to another workstream. Reachability of the controls was assessed without mutating that state.
- Full visual image order and completeness could not be confirmed for long chapters. The matrix distinguishes the first visible page, source page count, and full-chapter verification.

## Executive summary

The current build demonstrates the intended browser-to-reader concept on Asura Scans, Vortex Scans when opened by direct URL, and ManhuaTop. Reader controls, adjacent navigation, View Original Page, save-to-library, cold relaunch, and Library-origin back navigation all worked in at least one live journey.

The most serious risks are trust and reliability at the browser/reader boundary:

1. **A protected WEBTOON episode receives “Read in Clean Mode.”** The PRD classifies WEBTOON as browser-only, yet the app offers extraction on the negative control. Code inspection after the live observation found WEBTOON and GlobalComix registered as `enabledPublic`, conflicting with the PRD.
2. **The same Vortex chapter behaves differently depending on navigation path.** Tapping chapter 169 from the series page left it in Browser; pasting the exact chapter URL auto-opened Reader. Client-side route changes are not producing a reliable detection run.
3. **Reader can open before proving its images are usable.** A MangaBuddy URL redirected to Comizy, auto-opened Reader, then page 1 failed and Retry did not recover.
4. **Large text breaks primary navigation on Settings.** On an iPhone 16e at the largest tested simulator text size, Library and Downloads disappeared from the tab bar on Settings.
5. **A populated Downloads screen is not usable as a list.** Cached chapter cards overflow the non-scrolling screen, leaving later entries and delete actions unreachable.

The unit and service test baseline is strong and fast, but it does not protect these failures because there is no UI test target, current-site fixtures are sparse, and browser navigation tests do not exercise real WebKit route changes, dynamic type, or end-to-end image loading.

## Journey coverage

| Journey | Steps exercised | Expected | Observed | Result |
|---|---|---|---|---|
| Home search: web query | Home → search → enter `toonedge reader test` → choose search action | Immediate suggestions, web results in Browser, visible loading/error states | Local suggestions appeared; Google results loaded in Browser with loading feedback | Pass |
| Home search: pasted URL | Home → search → paste exact series/chapter URLs | URL classified without user choosing a mode; requested page loads | Exact live URLs opened. Redirects were reflected for Comizy and mobile WEBTOON | Pass |
| Home search: empty/invalid | Submit whitespace; then submit `https://` | Empty input should stay put; malformed URL should be rejected or show a recoverable error | Whitespace did nothing. `https://` opened a blank Browser indefinitely with no error or retry | Fail |
| Low confidence / ordinary page | Open series pages on each reachable target | Ordinary pages remain in Browser | All tested series pages remained in Browser | Pass |
| Medium confidence | Open a likely but not high-confidence chapter | Show “Read in Clean Mode” only on eligible pages | CTA appeared on protected WEBTOON, where extraction should be disabled | Fail |
| High confidence | Open viable chapter pages | Auto-open Reader only when a usable session is available | Asura, direct Vortex, and ManhuaTop auto-opened successfully. Comizy auto-opened to a failed image. Vortex series-link navigation did not auto-open | Fail |
| Reader controls | Open ManhuaTop chapter 1 → show chrome → change fit/canvas/spacing/brightness | Controls update the reading presentation without leaving Reader | Settings sheet opened; Fit Screen and Paper selections were reflected; spacing and brightness controls were available | Pass |
| Adjacent chapter | ManhuaTop chapter 1 → Next | Chapter 2 replaces the session and label; current chapter remains intact on failure | Reader changed to Chapter 2 and displayed a first page | Pass, limited to one site |
| View Original Page | Direct Vortex and ManhuaTop Reader → View Original Page | Return to the exact current chapter in Browser; preserve reasonable context | Exact chapter page returned. Vortex returned near the top; ManhuaTop returned to its live page state | Pass |
| Reader back routing | Library Detail → Continue fallback → Reader → Back; Home Continue fallback → Reader → Back | Library origin returns to Series Detail; Home origin returns to Home | Library returned to Series Detail. Home returned to the series webpage in Browser | Partial fail |
| Save and persist | ManhuaTop chapter → Add to Library → Reading → relaunch | Saved state and progress survive relaunch | Saved item persisted; Home and Library showed Continue Chapter 1 after cold relaunch | Pass |
| Series Detail consistency | Open saved ManhuaTop series | Chapter labels and progress agree across Home, Library, and detail | Primary action said Chapter 1, but the active row subtitle said `Chapter Top`; another Home card showed `Continue Chapter Chapter` | Fail |
| Downloads | Open populated Downloads | Summary and all cache entries are reachable; controls have clear labels | Cards overflowed below the screen and could not be reached as a scrolling list | Fail |
| Offline / failed network | Exercise malformed URL, Comizy image Retry, MangaKatana/MangaPill non-hydration | Clear failure state and retry; cached chapters remain readable offline | Malformed URL had no failure UI; Comizy Retry failed; MangaKatana/MangaPill stayed unresolved. True offline reading was not tested | Partial / untested offline |
| Update checks | Inspect available update UI | Manual check and per-series status are understandable | Refresh controls were visible, but a live update-check run was not completed | Untested |
| Empty states | Clean iPhone 16e launch | Clear, actionable empty Home/Library/Downloads | Home empty state was clear and actionable. Empty Library and Downloads were not opened | Partial |
| Settings | Open Settings | Reader preferences, storage, update checks, About | Only a scaffold banner and two static reader values were present | Fail / incomplete slice |
| Small device and large text | iPhone 16e → increase preferred text size five steps → Home and Settings | Content and tab navigation remain available without clipping | Home remained usable but placeholder truncated; Settings showed only Home and Settings tabs | Fail |
| VoiceOver labels/focus | Inspect simulator accessibility tree on Home and Settings | Descriptive labels and logical focus order | Main Home and Settings controls had useful labels. Tab items were exposed only as a `Tab Bar` container to the inspection tool. Spoken traversal was not run | Partial / needs dedicated audit |

### Cross-device usability notes

- **Normal text and contrast:** The dark theme, white primary text, and purple actions were visually legible on both devices. Secondary gray metadata was noticeably quieter and should receive an automated contrast check, especially on Library cards and search history.
- **Tap targets:** Search, primary CTAs, tab items, and Reader's main controls were visually generous. The Downloads trash action is 40×40 points by code inspection, below the commonly expected 44×44-point target, and its label does not identify the chapter.
- **Loading feedback:** Browser navigation usually showed progress. Library briefly looked empty before local data arrived. MangaKatana and MangaPill remained in unresolved loading/placeholder states without a decisive failure explanation.
- **Perceived responsiveness:** Local tabs, search suggestions, Reader chrome, and settings changes responded promptly. Live web transitions varied by site; the clearest app-owned latency issue was the false Library empty state rather than a loading presentation.
- **Accessibility semantics:** Home exposed descriptive labels for Search, Settings, Check for new chapters, and the empty-state CTA. Settings exposed its diagonal-arrow symbol as `Enter Full Screen`, which is misleading in the Reader Fit row. The inspection tree exposed the app tabs only as a `Tab Bar` container; an actual VoiceOver traversal is required before concluding the tabs are inaccessible.

## Site compatibility matrix

All access dates are **2026-09-22**. “Loaded” means visible in ToonEdge Browser. “Reader page verified” describes what was directly observed, not the source's advertised page count.

| Site / current domain | Exact series URL | Exact chapter URL | Page load and detection | Reader result / order and completeness | View Original Page | Classification |
|---|---|---|---|---|---|---|
| Asura Scans — `asurascans.com` | `https://asurascans.com/comics/childhood-friend-of-the-zenith-05c7df14` | `https://asurascans.com/comics/childhood-friend-of-the-zenith-05c7df14/chapter/106` | Series loaded and stayed in Browser. Opening chapter 106 from the series list auto-opened Reader | First page rendered cleanly. Full chapter order/completeness was not traversed | Not tested on this site | Compatible in sampled path |
| ManhwaTop — `manhwatop.com` | `https://manhwatop.com/manga/please-show-up-series/` | `https://manhwatop.com/manga/please-show-up/chapter-1/` | Series loaded. Attempted chapter URL redirected to the series page | No chapter session could be evaluated | Not applicable | Site URL/structure change; not an app defect by itself |
| ManhuaTop — `manhuatop.org` | `https://manhuatop.org/manhua/i-became-the-youngest-disciple-of-the-mount-hua-sect/` | `https://manhuatop.org/manhua/i-became-the-youngest-disciple-of-the-mount-hua-sect/chapter-1/` | Series loaded in Browser; chapter auto-opened Reader | First page rendered. Source exposed 19 numbered images; full 19-image visual traversal was not completed. Next opened Chapter 2 | Returned to the exact chapter page | Compatible, with metadata-label regression |
| ManhwaClan — `manhwaclan.com` | Not exercised | Not exercised | Direct domain access was unavailable during review, so no current public series/chapter pair could be verified | Not tested | Not tested | Site outage/unavailability. Substituted MangaPill, a documented catalog target |
| MangaBuddy → Comizy — `comizy.io` | Requested `https://mangabuddy.com/kono-manga-no-heroine-wa-morisaki-amane-desu`; redirected to `https://comizy.io/kono-manga-no-heroine-wa-morisaki-amane-desu` | Requested `https://mangabuddy.com/kono-manga-no-heroine-wa-morisaki-amane-desu/chapter-1`; redirected to `https://comizy.io/kono-manga-no-heroine-wa-morisaki-amane-desu/chapter-1` | Series loaded after redirect. Chapter auto-opened Reader | Page 1 failed; Retry did not recover. A source response exposed 10 images, but none were proven complete in Reader | Returned to the exact Comizy page, which remained visually unsettled/blurred | Incompatible in sampled Reader path; domain migration is a site change, failed Reader is an app compatibility issue |
| Vortex Scans — `vortexscans.org` | `https://vortexscans.org/series/past-life-returner` | `https://vortexscans.org/series/past-life-returner/chapter-169` | Series loaded. Tapping chapter 169 kept it in Browser without Reader. Pasting the identical URL auto-opened Reader | First page rendered. Source exposed 40 pages; full traversal was not completed | Returned to the exact chapter URL near the top | Direct URL compatible; in-site navigation detection unreliable |
| MangaFire — `mangafire.to` | `https://mangafire.to/title/kx1p6-chainsaw-man` | Tried `https://mangafire.to/read/chainsaw-man.kx1p6/en/chapter-1` and `https://mangafire.to/read/chainsaw-mann.0w5k/en/chapter-225` | Series loaded. Both chapter-shaped URLs redirected to a title page in the live session | No Reader session available to evaluate | Not applicable | Current routing/content change; no app conclusion on chapter extraction |
| MangaKatana — `mangakatana.com` | `https://mangakatana.com/manga/katana.3140` | `https://mangakatana.com/manga/katana.3140/c1` | Series loaded. Chapter shell showed `Pending Load` and `1/46`; it stayed in Browser | Images did not hydrate during the observation window; order/completeness not verified | Not tested | Inconclusive live compatibility; likely hydration/session timing issue |
| MangaPill — `mangapill.com` (ManhwaClan substitute) | `https://mangapill.com/manga/6965/qp` | `https://mangapill.com/chapters/6965-10001000/qp-chapter-1` | Series loaded. Chapter showed sequential page rows but broken/spinning images and remained in Browser | Source exposed 43 pages; images were not usable in ToonEdge | Not tested | Inconclusive boundary between current source delivery and app hydration; needs captured fixture |
| WEBTOON negative control — `webtoons.com` / `m.webtoons.com` | `https://www.webtoons.com/en/fantasy/tower-of-god/list?title_no=95` | `https://www.webtoons.com/en/fantasy/tower-of-god/season-1-ep-0/viewer?episode_no=1&title_no=95` | Series and episode loaded; mobile redirect occurred. Episode displayed `Read in Clean Mode` | CTA was not invoked because this is a documented protected/browser-only control | Remained in Browser | **Fail:** protected reader incorrectly receives extraction CTA |

## Prioritized bugs and UX issues

### QA-01 — Protected WEBTOON reader is offered Clean Mode

- **Severity:** High
- **Steps:** Open the Tower of God series URL above, open Season 1 Ep. 0, wait for page analysis.
- **Expected:** WEBTOON remains browser-only with no Clean Mode prompt, per PRD Tier 3.
- **Actual:** A prominent `Read in Clean Mode` CTA appeared over the episode.
- **Evidence:** [WEBTOON protected-reader CTA](../qa_evidence/2026-09-22/webtoon-protected-reader-cta.png)
- **Affected sites:** WEBTOON; GlobalComix is at risk because the current registry assigns the same enabled-public tier, but it was not live-tested.
- **Existing tracking:** DEF-035.
- **Likely owner:** Detection / SiteProfileRegistry / launch-site policy.
- **Inference from code:** `webtoons.com` and `globalcomix.com` are currently registered as `enabledPublic`, which conflicts with the PRD's browser-only policy.

### QA-02 — Vortex detection depends on whether the chapter was pasted or opened in-site

- **Severity:** High
- **Steps:** Open the Past Life Returner series URL; tap chapter 169. Repeat by pasting the exact chapter URL directly.
- **Expected:** Both paths trigger the same post-load detection and auto-open the viable high-confidence Reader session.
- **Actual:** Series-link navigation stayed in Browser; direct URL auto-opened Reader.
- **Evidence:** Firsthand observation in the same simulator session; direct Reader and View Original were exercised. No standalone screenshot was captured for the route comparison.
- **Affected sites:** Vortex; likely any client-side navigation that changes route/content without the load callback ToonEdge currently watches.
- **Existing tracking:** DEF-036; related to DEF-003 browser-to-reader handoff.
- **Likely owner:** Browser navigation observation / detection scheduling.

### QA-03 — MangaBuddy/Comizy auto-opens Reader with an unusable image

- **Severity:** High
- **Steps:** Open the MangaBuddy chapter URL above; allow redirect to Comizy and auto-open Reader; tap Retry on page 1.
- **Expected:** Reader opens only after a viable image session is proven, or the page remains in Browser with a clear fallback.
- **Actual:** Reader opened, page 1 failed, and Retry did not recover.
- **Evidence:** Firsthand visual observation. View Original returned to the same Comizy chapter, confirming URL ownership.
- **Affected sites:** MangaBuddy's current Comizy destination; other CDNs requiring session cookies, referrer, or WebView-delivered headers may be affected.
- **Existing tracking:** DEF-037; related to DEF-001 incomplete-image handling.
- **Likely owner:** Reader image loader / detection viability / site profiles.

### QA-04 — Largest text size removes Library and Downloads from Settings tab bar

- **Severity:** High (accessibility/navigation)
- **Steps:** On iPhone 16e, open Settings; increase preferred text size five steps using Simulator Features.
- **Expected:** All four primary tabs remain visible and operable.
- **Actual:** Only Home and Settings remained visible in the Settings tab bar. Home still showed all four tabs at the same text size, indicating a screen/layout interaction rather than an OS-wide intentional collapse.
- **Evidence:** [Settings at large text](../qa_evidence/2026-09-22/iphone-16e-settings-large-text.png) and [Home at the same large text](../qa_evidence/2026-09-22/iphone-16e-home-large-text.png)
- **Affected sites:** App-wide navigation, reproducible on Settings on a small iPhone.
- **Existing tracking:** DEF-038.
- **Likely owner:** AppShell / Settings / Shared UI / accessibility.

### QA-05 — Populated Downloads content overflows without scrolling

- **Severity:** High
- **Steps:** Open Downloads on a simulator with many cached chapters.
- **Expected:** Summary and every cached chapter row can be reached; each delete action is available.
- **Actual:** The chapter stack extended beyond the viewport and behind the tab bar; later rows were unreachable.
- **Evidence:** Firsthand observation on the populated iPhone 16 Pro. Code inspection after observation confirms the entries are inside a `VStack`, not a `ScrollView`.
- **Affected sites:** Any source once enough chapters are cached.
- **Existing tracking:** DEF-039.
- **Likely owner:** Downloads UI.

### QA-06 — Bare `https://` opens an indefinite blank Browser

- **Severity:** Medium
- **Steps:** Home → search → enter `https://` → submit.
- **Expected:** Inline validation, search fallback, or a recoverable Browser error.
- **Actual:** Blank white Browser with the malformed string in the command bar; no message or retry surfaced.
- **Evidence:** [Malformed URL blank Browser](../qa_evidence/2026-09-22/malformed-url-blank-browser.png)
- **Affected sites:** Site-independent.
- **Existing tracking:** DEF-040.
- **Likely owner:** Search input classification / Browser error state.
- **Inference from code:** Any `http://` or `https://` prefix earns enough classifier score to be treated as a URL without validating the host.

### QA-07 — Chapter labels can degrade to `Top` or `Chapter`

- **Severity:** Medium
- **Steps:** Read and save ManhuaTop chapter 1; open Series Detail. Separately inspect Home cards restored from existing history.
- **Expected:** The same numeric chapter label appears in Reader, Home, Library, and Series Detail.
- **Actual:** Series Detail primary action said `Continue Chapter 1`, while the active row subtitle said `Chapter Top`. A Home card displayed `Continue Chapter Chapter`.
- **Evidence:** [ManhuaTop label mismatch](../qa_evidence/2026-09-22/manhuatop-chapter-label-top.png)
- **Affected sites:** ManhuaTop and any title where the page title ends in source-brand words.
- **Existing tracking:** DEF-041; related to DEF-033 resume-target semantics.
- **Likely owner:** Detection metadata normalization / persistence / Library presentation.

### QA-08 — Home Continue fallback loses Home back context

- **Severity:** Medium
- **Steps:** Cold relaunch; tap the Home Continue action for the saved ManhuaTop item whose stored Reader payload is absent; allow Browser detection to open Reader; tap Reader Back.
- **Expected:** Return to Home, matching the documented origin-aware back behavior and the existing router unit expectation.
- **Actual:** Returned to the series page in Browser.
- **Evidence:** Firsthand route observation. The original page itself is shown in [ManhuaTop original page](../qa_evidence/2026-09-22/manhuatop-original-page.png).
- **Affected sites:** Any Home resume target that must fall back through Browser detection.
- **Existing tracking:** DEF-042. DEF-034 covers the analogous Library fallback and passed during this review.
- **Likely owner:** AppRouter / Home resume / Browser reader-origin override.

### QA-09 — Settings is still a non-functional scaffold

- **Severity:** Medium (MVP completeness)
- **Steps:** Open Settings.
- **Expected:** Reader preferences, storage management, update checks, and About/support controls described by the UX requirements.
- **Actual:** A scaffold banner plus static Reader Canvas and Reader Fit values; no editable controls or storage/update/about destinations.
- **Evidence:** [Settings at large text](../qa_evidence/2026-09-22/iphone-16e-settings-large-text.png) also shows the limited content.
- **Affected sites:** Site-independent.
- **Existing tracking:** DEF-043.
- **Likely owner:** Settings.

### QA-10 — Search meaning is lost at very large text

- **Severity:** Low
- **Steps:** On iPhone 16e, increase preferred text size five steps and return to Home.
- **Expected:** The primary search action retains an understandable label or reflows.
- **Actual:** The dominant field reads `Search th…`; the adjacent icons enlarge but the field does not provide enough text context visually.
- **Evidence:** [Home at large text](../qa_evidence/2026-09-22/iphone-16e-home-large-text.png)
- **Affected sites:** Site-independent, small iPhones at accessibility text sizes.
- **Existing tracking:** DEF-044. DEF-009 concerned first-open overlay clipping and did not reproduce at normal size.
- **Likely owner:** Home / Shared UI / accessibility.

### QA-11 — Library initially flashes a false empty state while data loads

- **Severity:** Low
- **Steps:** Open Library on the populated simulator immediately after launch.
- **Expected:** Loading/skeleton feedback until the local snapshot is available.
- **Actual:** `0 titles`/empty presentation appeared before the seven stored titles populated.
- **Evidence:** Firsthand observation; no screenshot captured during the brief transition.
- **Affected sites:** Site-independent, more visible with a larger local library.
- **Existing tracking:** DEF-045.
- **Likely owner:** Library view model / loading states.

### QA-12 — Settings exposes a misleading accessibility label

- **Severity:** Low
- **Steps:** Open Settings and inspect the accessibility elements in visual order.
- **Expected:** Decorative icons are hidden from accessibility, or the Reader Fit row is exposed as one meaningful element.
- **Actual:** The diagonal-arrow image is separately described as `Enter Full Screen`, even though the surrounding value is `Reader Fit — Fit Width` and the row is not a full-screen action.
- **Evidence:** Simulator accessibility-tree inspection on the dedicated iPhone 16e.
- **Affected sites:** Site-independent.
- **Existing tracking:** DEF-046.
- **Likely owner:** Settings / Shared UI accessibility semantics.

## Known-defect regression notes

| Existing defect | Hands-on result |
|---|---|
| DEF-001 / DEF-003 browser-to-reader presentation | Direct Vortex and ManhuaTop high-confidence handoff was visibly successful. Vortex in-site navigation still failed to trigger the same handoff (QA-02). Full long-chapter scroll stability was not re-verified. |
| DEF-007 ManhwaTop blank Reader | Not reproducible because the tested public chapter URL redirected to the series page. This remains unverified, not passed. |
| DEF-009 first-open search clipping | Normal-size search opened with the field visible and usable. Passed in this build. |
| DEF-010 Library adjacent navigation | ManhuaTop Next worked from Reader, but the exact Library-origin adjacent scenario was not repeated. Partial coverage only. |
| DEF-022 transient rate-limit/challenge handling | No controlled rate-limit response was produced. Untested. |
| DEF-024 Vortex adjacent Reader navigation | Direct Vortex chapter opened, but Next to chapter 170 was not exercised. Untested. |
| DEF-033 resume label versus latest label | Primary action selected Chapter 1 correctly, but a different normalization failure produced `Chapter Top` (QA-07). |
| DEF-034 Library fallback back context | Library Detail → Browser fallback → Reader → Back returned to native Series Detail. Passed. Home fallback showed the analogous issue in QA-08. |

## Test-suite gap analysis

The current `app/Tests/ToonEdgeAppCoreTests/` suite has broad unit coverage for classifiers, scoring, routing, persistence, cache metadata, update comparison, and reader state. It passed all 308 tests. There is no XCUITest target or `XCUIApplication` coverage, and current fixtures cover only Asura, MangaFire, MangaHere, MangaKatana, MangaPill, and ManhwaTop.

| Priority | Type / target file | Scenario to add | Required assertion |
|---|---|---|---|
| P0 | Unit — `DetectionEngineTests.swift` | PRD browser-only registry policy for WEBTOON and protected GlobalComix | `supportTier == .browserOnly`; protected-reader analyses remain low and never produce a CTA or Reader presentation |
| P0 | Integration — `BrowserExperienceTests.swift` plus a WebKit harness | Load Vortex series, perform a client-side route transition to chapter 169, then publish hydrated content | Every committed main-frame URL/content transition schedules detection exactly once and produces the same high-confidence result as direct load |
| P0 | Unit — `SearchEntryModelTests.swift` | Inputs `https://`, `http://`, scheme plus whitespace, and missing host | Classifier rejects malformed URL or returns an explicit invalid state; Browser is not presented with a hostless request |
| P0 | Integration — `ReaderExperienceTests.swift` | Comizy-shaped redirect and CDN image request requiring WebView session context | Reader is not presented until at least one viable image is loadable; required cookies/referrer propagate; Retry can recover or View Original is offered |
| P0 | Fixture — new `comizy_redirected_chapter.json` | Current MangaBuddy→Comizy URL, canonical metadata, ten ordered images, redirect destination | Canonical domain and series URL are preserved; image URLs remain ordered and pass viability checks |
| P0 | UI — new ToonEdge UI test target | iPhone SE/16e size at accessibility text sizes on every tab | All four tab buttons remain hittable and visible; screenshots and accessibility audit have no clipped primary navigation |
| P1 | UI — new UI target | Downloads with 20 cache entries | Scroll to the last row; last delete button is hittable; summary remains reachable; no content is behind the tab bar |
| P1 | Unit/UI — `CacheMetadataTests.swift` and UI target | Accessible delete labels for multiple entries | Each label includes series/chapter identity, not repeated `Remove cached chapter`; hit frame is at least 44×44 points |
| P1 | Unit — `PersistenceLifecycleTests.swift`, `LibraryExperienceTests.swift` | Persist title `… Chapter 1 - Manhwa Manhua Top` and restore across Home/Library/Detail | All surfaces display numeric `Chapter 1`; never `Chapter Top` or `Chapter Chapter` |
| P1 | Integration/UI — `AppRouterTests.swift` plus UI target | Home Continue without stored payload → Browser detection → Reader → Back | Home origin survives fallback and adjacent replacement; Back returns Home. Mirror the existing DEF-034 Library test end to end |
| P1 | Fixtures — current Vortex, ManhuaTop, MangaKatana, MangaPill | Capture current HTML/DOM before and after hydration | Exact ordered page count, canonical chapter/series links, challenge/placeholder rejection, and adjacent links are stable |
| P1 | Integration — `ReaderExperienceTests.swift` | Sample chapter with 40 images, delayed dimensions, one transient failure | Final loaded set is complete and in DOM order; placeholders do not advance progress; scroll anchor is stable after late image sizing |
| P1 | UI — new UI target | Cold relaunch with saved series and progress | Home Continue, Library card, Series Detail, and Reader display the same chapter and progress; save state persists |
| P1 | Integration/UI — cache and networking | Retain a chapter, terminate, disable network, relaunch and open | All retained images open offline in order; uncached content shows a clear offline state and View Original remains available when meaningful |
| P1 | UI — Settings/update flow | Manual update check with success, no update, and fetch failure fixtures | Progress/loading is visible, results are understandable, prior update state is not erased on failure |
| P2 | UI/accessibility | VoiceOver traversal on Home, Browser CTA, Reader chrome, Library Detail, Downloads | Focus order follows visual/task order; every icon-only control has a unique label and hint; modal focus is trapped and restored correctly |
| P2 | UI/visual | Light/dark mode, increased contrast, 16e and Pro Max | Text remains readable, cards do not clip, controls meet contrast and minimum target sizes |
| P2 | Integration — Library | Delayed local snapshot with seven titles | Loading indicator/skeleton appears; zero-title empty state is never shown before the load completes |

## 2026-09-26 release-hardening addendum

- DEF-020 numeric adjacency, DEF-021 authoritative Continue targeting, and DEF-022 typed adjacent-load failures are implemented and verified. DEF-036 remains open because the live Vortex page did not provide a viable final direct-load control.
- Final package gate: 345 tests passed. Final complete UI gates: 9/9 on iPhone 16e and 9/9 on iPhone 16 Pro Max. The exact required iPhone 16e build succeeded.
- Settings update success/no-update/failure now has deterministic simulator coverage. Protected-site policy, offline retention, deep Downloads reachability, adjacent Retry/Open Original, and accessibility text-size navigation remain green.
- Remaining manual release items are a literal spoken VoiceOver/focus-restoration pass and a single 40-panel end-to-end transient-failure traversal. ToonEdge also continues to force its documented dark appearance under system Light mode.
- Full command, result-bundle, live-site, safety, and limitation details are recorded in [the 2026-09-26 evidence ledger](../qa_evidence/2026-09-26-reader-release-hardening.md).

## Recommended next slices

1. **Restore launch-site policy and add policy tests.** Mark WEBTOON and protected GlobalComix browser-only, suppress CTA/auto-open, and lock the PRD mapping into `DetectionEngineTests`.
2. **Make detection navigation-complete.** Re-run detection for committed same-frame URL/content transitions and add a Vortex SPA integration fixture/test.
3. **Gate Reader on image viability.** Add the Comizy redirect/session fixture, propagate required request context, and keep failed sessions in Browser with a clear explanation.
4. **Fix accessibility and scrolling blockers.** Preserve all four tabs at accessibility sizes, make Downloads scrollable, use 44-point controls, and give delete actions item-specific labels. Add an XCUITest target with 16e large-text coverage.
5. **Normalize chapter identity once.** Store a canonical numeric/display label and reuse it across Reader, Home, Library, Series Detail, updates, and resume. Add persistence and cold-relaunch regressions for `Top`/`Chapter` token failures.
6. **Complete failure and settings surfaces.** Validate malformed URLs before Browser presentation, add explicit browser/network errors, implement the documented Settings groups, and add offline/update-check end-to-end tests.

## Evidence index

- [Protected WEBTOON Clean Mode CTA](../qa_evidence/2026-09-22/webtoon-protected-reader-cta.png)
- [Malformed URL blank Browser](../qa_evidence/2026-09-22/malformed-url-blank-browser.png)
- [ManhuaTop `Chapter Top` mismatch](../qa_evidence/2026-09-22/manhuatop-chapter-label-top.png)
- [ManhuaTop original-page return](../qa_evidence/2026-09-22/manhuatop-original-page.png)
- [Clean iPhone 16e Home](../qa_evidence/2026-09-22/iphone-16e-current.png)
- [iPhone 16e Home at large text](../qa_evidence/2026-09-22/iphone-16e-home-large-text.png)
- [iPhone 16e Settings at large text](../qa_evidence/2026-09-22/iphone-16e-settings-large-text.png)

## Verification boundary

**Verified firsthand:** build/install/launch; search query, URL, and malformed input; live series/chapter loading outcomes listed in the matrix; direct and in-site Vortex behavior; Asura, Vortex, ManhuaTop, and Comizy Reader outcomes; one adjacent-chapter transition; Reader settings; View Original; save/relaunch/resume; Library Detail; populated Downloads; clean Home; large-text Home and Settings.

**Inferred after observation from code/documents:** the WEBTOON/GlobalComix tier mismatch, hostless URL classifier behavior, Downloads' missing scroll container, 40-point cache delete frame, and the exact owning modules.

**Not verified:** complete long-chapter image traversal, Vortex Next to chapter 170, ManhwaTop Reader due redirect, ManhwaClan due unavailability, true offline retained reading, destructive cache deletion, a live update-check result, Pro Max layout, and full VoiceOver spoken focus traversal.

## 2026-09-25 remediation verification addendum

The remediation plan was implemented with regression coverage for DEF-035 through DEF-046. Package tests pass (333/333), the exact iPhone 16e build gate succeeds, and the XCUITest target passes on both iPhone 16e and iPhone 16 Pro Max. Dedicated UI coverage now includes accessibility-size primary navigation, the adaptive Home search label, a 20-entry Downloads list, delayed populated Library loading, persistent Settings, and retained offline reading across termination/relaunch.

Protected WEBTOON and GlobalComix profiles are browser-only. Live WEBTOON remained in Browser without a Clean Mode CTA; direct Vortex and redirected Comizy checks produced viable Reader behavior without bypassing authentication, challenges, paywalls, or protected viewers. The live Vortex series-page-to-chapter route could not be independently repeated during the final pass, so DEF-036 remains Open even though its sanitized fixture and navigation/debounce regressions pass. DEF-035 and DEF-037 through DEF-046 are Implemented.

Commands, result bundles, fixture boundaries, compatibility notes, simulator preservation, and the per-defect evidence table are recorded in [the remediation verification ledger](../qa_evidence/2026-09-25-remediation-verification.md).
