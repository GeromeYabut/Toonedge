# ToonEdge hands-on UX and quality review — second run

Date: 2026-09-22. Review only; no product code or tests changed.

## Executive summary

**The current working-tree build launches and its 308 existing tests pass, but this is a partial hands-on review, not release sign-off.** Simulator accessibility control repeatedly became stuck on stale Window-menu elements and later switched device focus during interaction. Several requested journeys remain untested for that reason. Earlier review findings are not presented as firsthand results from this run.

The most serious firsthand issue is loss of Library and Downloads navigation on Settings at accessibility-large text size. Search also accepts a hostless URL and leaves the user on a blank page. The app shows a fabricated clipboard suggestion and static Settings rather than working preferences. Basic query routing, browser history, all three visible detection branches, image rendering, and a return to the original source page worked in the tested cases.

There are additional high-priority **code-supported risks**: browser-only source policy conflicts with the registry and even with a passing test; detection does not implement the documented hard gates; and “Retain Chapter Offline” appears to record metadata without retaining image bytes. These need targeted hands-on confirmation, not assumptions based on passing unit tests.

## Scope, provenance, and environment

Source-of-truth order used: `AGENTS.md`, canonical architecture, PRD, UX requirements, UX brief, then epic/story sequencing. The short architecture/PRD/UX filenames in `docs/` point to the canonical `toonedge_*` documents. `docs/defects.md` was reviewed, including existing DEF-035–046. The earlier report, evidence, remediation plan, and defect statuses were preserved.

| Item | Recorded value |
|---|---|
| Source revision | `8c538947d8a9191744e988e51529352e7e93a9c6` plus existing uncommitted changes |
| Working tree | 18 tracked modified files at baseline, plus existing untracked material; this review applies to that working tree, not pristine HEAD |
| Build | Debug, scheme ToonEdge, generic iOS Simulator, `CODE_SIGNING_ALLOWED=NO`; **BUILD SUCCEEDED** |
| Toolchain | Xcode 16.4 / build 16F6; iPhone Simulator SDK 18.5 |
| Installed binary SHA-256 | `36b2c737ed1ad3ee338fcd594010c948edb7a6b8c87f6b06e5d911daa3f6ea1a` |
| Bundle | `com.toonedge.app`, version 1.0 (1) |
| Main device | iPhone 16e, iOS 18.6, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`; 390×844 points |
| Large device | iPhone 16 Pro Max, iOS 18.6, `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`; 440×956 points; launch/Home visual check only |
| Text settings | 16e initially `accessibility-large`, subsequently `large`; Pro Max `large` |
| Tests actually run | `swift test --package-path app --scratch-path /private/tmp/toonedge-review-1138/tests --jobs 2`; **308 passed** |
| Data | Existing app containers were not erased. Main device began with empty reading Home. Review query/history and fixture reading activity were added through the app. |

The initial sandboxed build failed because SwiftData macros and simulator services were blocked. Expanded-access build approval was accidentally rejected, then explicitly authorized by the user and retried successfully. This was a setup limitation, not an app build defect. Simulator UI was restarted to recover control; that temporarily shut down booted devices. Subsequent focus interference was not attributed to ToonEdge. No app data was intentionally removed.

Desktop paste timed out and inserted the simulator's previous clipboard content. It was cleared **without submitting it**. Therefore a successful fresh URL paste is not claimed; URL entry was exercised by typing. Two drag/scroll attempts did not move the original page, so nonzero browser scroll restoration and smooth scrolling are unverified. VoiceOver speech and swipe focus traversal were not available; accessibility-tree observations are explicitly narrower evidence.

### Evidence

All new evidence is in [the second-run evidence directory](../qa_evidence/2026-09-22-review-2/):

- [01 — small Home, accessibility-large](../qa_evidence/2026-09-22-review-2/01-small-large-text-home.png)
- [02 — invalid URL blank Browser](../qa_evidence/2026-09-22-review-2/02-invalid-url.png)
- [03 — Settings missing two tabs](../qa_evidence/2026-09-22-review-2/03-small-settings-missing-tabs.png)
- [04 — Reader Settings successfully opened](../qa_evidence/2026-09-22-review-2/04-reader-settings-open.png)
- [05 — large iPhone Home](../qa_evidence/2026-09-22-review-2/05-large-home.png)
- [Build log](../qa_evidence/2026-09-22-review-2/build.log), [test log](../qa_evidence/2026-09-22-review-2/tests.log), [test inventory](../qa_evidence/2026-09-22-review-2/test-inventory.txt), [fixture requests](../qa_evidence/2026-09-22-review-2/fixture-server.log), [UI observation notes](../qa_evidence/2026-09-22-review-2/observations.md).

Synthetic pages use locally generated numbered PNG panels, not third-party chapter artwork. [Fixture generator](../qa_evidence/2026-09-22-review-2/make_fixtures.py) writes to `/private/tmp/toonedge-review-1138/fixtures`; serve that directory with `python3 -m http.server 8765 --bind 127.0.0.1 --directory /private/tmp/toonedge-review-1138/fixtures`. Generator requires Pillow and the macOS Helvetica font. Browser entry point: `http://127.0.0.1:8765/`.

## Journey coverage

“Pass” below applies only to the stated subcase. “Untested” is not a pass or an app failure.

| Journey / steps actually performed | Expected | Observed | Result |
|---|---|---|---|
| Home → search → type `garden comic` → submit | Immediate local suggestion; query opens Google inside app | Search action updated while typing; Google results rendered; loading status visible | Pass |
| Tap Garden Comics result → Browser Back → Forward | Destination loads; history follows prior/next pages | URL/title changed; Back restored Google and Forward restored destination; destination body appeared blank | History pass; live-page rendering inconclusive |
| Close Browser → reopen search | Actual query appears in local recent history | `garden comic` appeared; canned history and fake copied link also remained | Partial / suggestion defect |
| Home → type `https://` → submit; inspect again after screenshot capture | Inline validation or recoverable error | White Browser, no error/repair message; malformed input added to recent links | Fail, DEF-040 |
| Fresh URL paste | Paste intended URL and open it | Desktop paste bridge timed out; prior clipboard text inserted and cleared without submission | Untested successfully; tool limitation |
| Home → type local fixture index URL | Ordinary text page loads; no conversion | Text and links rendered, remained Browser | Pass for low/no-conversion branch |
| Index → `/medium/` (three full-size panels) | Prompt rather than automatic Reader for medium-classified result | “Read in Clean Mode” appeared; action opened native panels | Presentation pass; documented minimum-content gate concern below |
| Medium Reader → tap content → View Original Page | Chrome accessible; exact source restored | Chrome appeared; original “Three panels” page returned at top without immediate re-entry | Pass for URL/top context; nonzero scroll untested |
| Index → `/series/chapter-1/` (eight panels) | Conservative high-confidence chapter visibly opens Reader | Reader opened automatically above Browser; ordered numbered panels rendered | Pass for this positive fixture |
| Reader → reveal chrome → Reader Settings | Settings sheet opens | Fit Width/Fit Screen, spacing, brightness and canvas controls visible | Open-sheet pass; changing controls untested |
| Reader Next/Previous, origin-aware Back, chrome hide/show repeat | Adjacent chapter; correct origin; reversible chrome | Next/Previous and Back observed, but not exercised before control loss | Untested |
| Save → Home resume → Library → Series Detail → relaunch | One series; consistent chapter and exact position | Save/resume/detail journey not reached | Untested: unstable simulator control |
| Cache/retain → Downloads → stop server → reopen → remove | Honest offline availability, usable list and removal | Retain affordance observed; action and Downloads not exercised | Untested: unstable simulator control |
| Update refresh/no-change/new/failure; failed-network and failed-image retry | Clear nonblocking feedback, retained prior data | Fixture endpoints prepared; scenarios not visited | Untested: unstable simulator control |
| Empty Home on both phone sizes | Useful starting action and reachable tabs | Empty explanation, start-reading action and all tabs visible | Pass for Home only |
| Small Home/Settings at accessibility-large; then standard text | Meaningful search label and four usable tabs | Home `Search th…`; Settings only Home/Settings visible | Fail, DEF-038/044 |
| Settings content and accessibility semantics | Editable MVP groups and correct labels | Scaffold, two display-only values; Reader Fit symbol announced as `Enter Full Screen` in tree | Fail, DEF-043/046; spoken VoiceOver untested |
| Large-device full journeys; smallest supported iPhone; contrast/hit-target audit | Consistent usable layout and accessibility | Only Pro Max empty Home visually inspected; no instrumented measurements | Untested beyond recorded screenshot |

No low/medium/high numerical score was recovered from runtime logs. Classification names above describe the observed app branch, supported by fixture shape and detector inspection; they are not measured diagnostic scores.

The Garden Comics page is an unresolved live-site observation. Network, source scripts, sanitization and rendering were not isolated; it is not filed as either a confirmed app defect or a confirmed source outage. Blocked/protected live sites and DEF-035/036/037 were not revisited in this run.

## Prioritized findings

Severity: High blocks a core action or breaks the product trust contract; Medium breaks a supported flow with a workaround; Low causes clarity or accessibility friction. `R2-*` are report identifiers, not new entries in `docs/defects.md`.

### Firsthand confirmed

| ID / severity / owner | Reproduction | Expected vs actual | Evidence / tracking |
|---|---|---|---|
| R2-01 **High** — AppShell/Settings | 16e, content size accessibility-large → Home gear → Settings | All four tabs remain reachable; Library and Downloads disappear, while Home at same size has four | Screenshot 03 versus 01; **DEF-038 open**, reconfirmed |
| R2-02 **Medium** — Search/Browser | Home search → `https://` → submit | Reject missing host with guidance; blank white Browser with no error, and invalid recent-link entry | Screenshot 02 and observation notes; **DEF-040 open**, reconfirmed |
| R2-03 **Medium** — Search/DI | Empty reading install → open search; compare copied-link suggestion with real pasted clipboard | Clipboard row represents actual relevant clipboard; always suggests `https://example.com/series/chapter-12`, alongside sample links/queries | AX notes; `AppDependencies.persistent` injects `MockSearchSuggestionProvider`, whose default clipboard is that URL. **Not explicitly tracked** in defects reviewed; related to resolved DEF-006 but a different behavior |
| R2-04 **Medium** — Settings | Open Settings | Reader preferences, storage, update and About affordances; shows “Settings scaffold” and static Canvas/Fit values | Screenshot 03, AX tree and SettingsView; **DEF-043 open**, reconfirmed |
| R2-05 **Medium** — Browser/detection accessibility | Index → medium page → inspect CTA action; enter Reader and inspect tree | Clean Mode action has correct label; underlying Browser excluded from modal Reader focus | CTA icon action was labeled `Bookmark`; Reader tree retained Browser Close/Refresh/Back alongside Reader controls. Visual action worked, **spoken focus impact remains untested**. **Not explicitly tracked** |
| R2-06 **Low** — Home | 16e accessibility-large → Home | Search retains dual-purpose meaning; visually reduced to `Search th…` | Screenshot 01; **DEF-044 open**, reconfirmed. Full accessible button label remained descriptive |
| R2-07 **Low** — Settings/shared UI | Settings → inspect AX elements in row order | Fit row correctly combined/labeled; decorative icon exposed as `Enter Full Screen` | Screenshot 03 + AX notes; **DEF-046 open**, reconfirmed at tree level only |
| R2-08 **Low** — Browser chrome | Enter plain `http://127.0.0.1:8765/` | Plain HTTP does not imply secure transport; padlock shown and exposed as `Lock` | AX notes; BrowserView `initialRequestIconName` returns lock for every `.url`. **Not explicitly tracked**; also visible for malformed `https://` in screenshot 02 |

### Code-supported concerns requiring separate validation

These are not new firsthand end-to-end failures.

| Priority / owner | Reproduction to add | Expected vs inspected behavior | Tracking / confidence |
|---|---|---|---|
| **High** — Cache/Reader | Read fixture → Retain Offline → terminate → stop server → cold reopen → inspect all panels | Success only when all retained assets exist and reopen offline. `retainCurrentChapter()` writes metadata with zero bytes; Reader image loader uses HTTP; asset-cache type exposes paths/lookups, no download operation in that flow | No explicit equivalent found; related to cache scaffolding. Strong implementation evidence; **offline failure not exercised** |
| **High** — Site policy/detection | Open permitted negative-control WEBTOON fixture; assert no extraction/CTA | PRD Tier 3 browser-only. Registry marks `webtoons.com` and `globalcomix.com` enabled-public; a passing suggestion test explicitly expects WEBTOON support | **DEF-035 open**; code reconfirmed, live behavior not reverified |
| **High** — Generic detection | Execute prepared `/article/`, `/challenge/`, `/broken/chapter-1/` plus search/catalog/paywall negatives | Documented exclusions and readable-session gates. Detector defaults are high 85/≥5 candidates and medium 45/≥2; architecture requires high 78 with stronger gates, medium 55 with minimum count/height, and negative content signals. Page analysis lacks several required page-type/viewport-height inputs | No explicit generic hard-gate defect found; related DEF-002/035/037. Medium fixture confirms CTA on three panels, but does not independently prove every proposed negative failure |
| **Medium** — Reader preferences/progress | Change fit/canvas; read halfway through a tall image; dismiss/relaunch/reopen | Settings and exact place restored. Mutations update session fields; default settings service is a mock. Reader restore scrolls to image top; no intra-image offset measured in view | Not explicitly tracked as these exact failures; **relaunch behavior untested** |
| **High** — Downloads layout | Populate 20 cached chapters at standard and accessibility text; reach/remove final row | Scrollable usable list; source uses non-scrolling VStack, 40×40 trash frame and identical remove labels | **DEF-039 open**; source corroboration only in this run |

Architecture thresholds are a documented implementation discrepancy, not automatically evidence that every different threshold is harmful. Validate against a negative corpus before tuning. The PRD permits a metadata-first download slice; that does **not** justify promising offline availability before bytes exist. Likewise manual background scheduling is deferred: its absence is not a defect. No recommendations here add tabs, cloud sync or chapter stitching.

Other known issues—DEF-020/021/022 and DEF-036/037/041/042/045—remain unverified in this run. Implemented statuses, including DEF-001/003/034, are not blanket re-certified by the limited successful fixture transitions.

## Test-suite gap analysis

The passing suite is predominantly Swift Testing of domain models, view models and repositories. The Xcode project has one app target and no XCUITest target. `PersistenceLifecycleTests.makeRepository()` uses an in-memory configuration. Router state assertions do not execute WKWebView, rendering, browser history or scroll restoration. JavaScript substring assertions prove script content exists, not that it extracts correctly in WebKit. These are useful tests, but they leave the main observed failures exposed.

| Priority / level / proposed test | Current relevant coverage | Scenario and required assertion |
|---|---|---|
| P0 UI: navigation under Dynamic Type | DesignSystemTests checks title colors; no rendered layout gate | 16e/Pro Max, standard through largest accessibility size, every primary tab: all four tab actions hittable, no displacement; especially Settings (R2-01) |
| P0 unit + UI: invalid URL recovery | SearchEntryModelTests covers valid URLs, trimming, localhost, IPv4, unsupported schemes | `https://`, `http://`, whitespace variants and missing hosts: no blank Browser, visible correction; empty input inert; valid cases unchanged (R2-02) |
| P0 integration + UI: honest offline retention | CacheMetadataTests counts metadata; CacheStorageTests validates path/measurement/missing files | Retain eight panels, verify bytes and completeness, restart with server stopped, render all eight; partial download never counted “retained offline”; remove deletes bytes and metadata |
| P0 unit + WebKit integration: source policy | DetectionEngineTests covers tiers/profile fixtures; SearchEntryModelTests currently expects WEBTOON enabled-public | Domain/subdomain policy matrix: browser-only never creates session, CTA or auto-open; fix contradictory test expectation first; protected GlobalComix independently blocked |
| P0 WebKit integration: detection negatives | Thumbnail/challenge fixtures, high/medium/low view-model tests, script text checks | Load article/catalog/search/login/paywall/error pages with large images; assert no auto-open, forbidden pages no CTA; test 3/4/5/6 candidates and exact count/height/score boundaries |
| P0 UI: real Browser/Reader ownership | browserOwnsDetectedReaderPresentation…, viewOriginalPageKeepsExistingBrowserState… | Local page → visible Reader → Original: same URL and nonzero scroll restored; no presentation behind Browser; after adjacent navigation use current chapter URL |
| P1 unit + UI: genuine clipboard/history | searchSuggestionsFollowUXPriorityOrder; historyBackedSuggestions… | Inject valid/invalid/empty clipboard and fresh history; only genuine links shown; no demo entries in production; simulator paste opens intended URL (R2-03) |
| P1 accessibility UI: correct modal/action semantics | No semantic/focus checks found | Clean Mode action named correctly; hidden Browser inaccessible while Reader active; focused escape path; decorative Settings icon hidden/combined; brightness slider labeled (R2-05/07) |
| P1 unit + UI: transport indicator | No equivalent found | HTTP, HTTPS, malformed URL, redirect: indicator follows actual current transport, not initial input kind (R2-08) |
| P1 UI: Settings functional contract | Reader settings mutation test only | Edit preferences; cold relaunch preserves choice; storage/update/About destinations operate; shorter search copy retains meaning at accessibility sizes (R2-04/06) |
| P1 disk integration + UI: save/resume consistency | PersistenceLifecycleTests in-memory save/dedup/payload/progress; LibraryExperienceTests resume projections | Save chapter 1, advance to 2, stop mid-panel, terminate, reconstruct disk container; Home/Library/Detail/Reader agree on chapter and position, no duplicates |
| P1 integration + UI: origin-aware fallback | AppRouterTests Home origin; BrowserExperienceTests Library override; LibraryExperienceTests fallback | Missing payload → Home/Library Browser fallback → detection → Reader Back: original Home/Detail restored; Original still exact chapter; unrelated navigation clears override (DEF-042) |
| P1 WebKit integration: adjacent chapter and SPA transitions | AdjacentReaderSessionLoaderTests viability/static fallbacks; ReaderExperienceTests preserves origin/failure | Chapter 1 → 2 (including client-side navigation): identical detection to direct load; numeric adjacent, no sparse recent jump; timeout/challenge retains current chapter with retry |
| P1 unit + UI: labels and updates | Noisy numeric primary-action tests; UpdateCheckTests compare/fetch/index | Noisy titles ending in site branding normalize once; labels identical on all screens and after relaunch; new chapter distinct from resume label; update failure preserves unread flags |
| P1 UI: Downloads reachability | downloadsViewModelRemoveActionRefreshesSummaryAfterSuccess; failure feedback and large summary tests | 20 rows → scroll last → named ≥44-point delete action → successful count/bytes update; failure recoverable; empty state useful (DEF-039) |
| P1 integration + UI: update feedback | UpdateCheckTests all-saved refresh and failure preservation | Mutable local series index: no-change → new chapter → 503/offline; assert visible loading/success/partial-failure, cross-screen badges and no data loss |
| P2 UI/performance: local-first readiness | LibraryExperienceTests startup policies and source/layout model checks | Delay initial snapshot on populated disk: never flash genuine empty before loaded; measure tap-to-actionable detail with large library; do not rely on named layout constants |

## Ordered next slices

1. Establish an isolated, controllable simulator and an XCUITest target using these synthetic pages. Finish the untested save/resume, adjacent, offline/update and VoiceOver journeys before release sign-off.
2. Fix the confirmed navigation and input failures: Dynamic Type tab reachability, host validation, real clipboard/history, correct action semantics. Add their rendered UI regressions.
3. Enforce source policy and documented detection hard gates; use a negative DOM corpus and actual WebKit transitions before tuning confidence. Keep live-site outages distinct.
4. Make offline status truthful: either complete file-backed retention/reopen/removal or label metadata as metadata. Gate offline success on a server-off cold-relaunch test.
5. Complete Settings persistence and disk-backed reading continuity, then verify labels and launch origins across every entry/exit path. Follow with Downloads layout and update-state coverage.

The review added only its report/evidence artifacts. Existing tracked modifications were byte-for-byte unchanged against the initial `git diff --binary` snapshot when checked. No defect status was edited, and no product code or tests were changed.
