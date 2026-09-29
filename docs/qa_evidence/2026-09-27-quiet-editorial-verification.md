# Quiet Editorial UX Verification Ledger

Plan authored 2026-09-27. Verification below was executed on 2026-09-29 on the Story 12.8 branch beginning at revision `1710b5946406a87bce79700fbb54dac0ecd543a9`.

## Scope and disposition

Epic 12 Stories 12.1–12.7 are implemented. Deterministic unit, integration, fixture, and UI coverage passed for the quiet-editorial foundations, Home/Search, Browser, Reader, Library/Series Detail, Downloads/Settings, and semantic haptics.

Story 12.8 remains in progress. Its automated release gates passed, but full per-surface light/dark review, literal spoken VoiceOver review, and physical-device haptic feel/intensity review were not available in this environment. Increased Contrast and Reduce Motion have logic-level coverage, but still require a hands-on perceptual pass together with spoken VoiceOver. Those limitations are not treated as passed acceptance criteria.

## Implementation slices

| Story | Integration commit | Result |
|---|---|---|
| 12.1 Adaptive editorial foundation | `0689970`, `dd4396d` | Implemented; adaptive palette, typography, borderless primitives, and interaction policy covered by package tests. |
| 12.2 Home and Search | `3a687ea` | Implemented; search-first hierarchy, whole-row suggestions, routing, validation, and large-text entry covered. |
| 12.3 Browser | `2382f9b` | Implemented; borderless chrome, Clean Mode action, and protected/low/nonviable negative controls covered. |
| 12.4 Reader | `92e48aa` | Implemented; chrome gesture isolation, settings reachability, typed adjacent feedback, Back, and View Original covered. |
| 12.5 Library and Series Detail | `e56f1e3` | Implemented; densities, filters, primary action, chapter utilities, and mutation recovery covered. |
| 12.6 Downloads and Settings | `a412015` | Implemented; utility lists, removal recovery, storage routing, and update outcomes covered. |
| 12.7 Semantic haptics | `d585cac` | Implemented; preference persistence and outcome-to-event semantics covered. Physical feel remains a Story 12.8 manual gate. |
| 12.8 Release QA additions | `eaf7712`, `8a1f966`, `1710b59` | Added deterministic Library, Series mutation, accessibility launch, high-confidence auto-open, Back, and View Original journeys. |

## Focused regression evidence

The seven newly added Story 12.8 journeys passed together on the dedicated iPhone 16e:

- Home search remains reachable at Accessibility XXXL.
- A high-confidence Browser fixture auto-opens Reader without exposing the medium-confidence CTA.
- Reader Back returns to its originating Browser.
- View Original returns to its originating Browser.
- Library filter selection narrows the collection.
- Library density persists across relaunch.
- Series Detail mutation failure offers Retry and recovers.

Result bundle: `/private/tmp/toonedge-story-12.8-new-ui-focused.xcresult`.

Earlier Story 12.7 focused Settings haptic-preference coverage also passed on the dedicated iPhone 16e. Result bundle: `/private/tmp/toonedge-story-12.7-haptic-preference-ui-green3.xcresult`.

Independent review found that the original Series Detail retry assertion only proved that its error cleared. A stronger failing regression required the saved-series accessibility value to change from `Reading` to `Planned`. The production menu now exposes its current collection state, and the corrected focused test passed at `/private/tmp/toonedge-story-12.8-retry-recovery-green2.xcresult`.

## Complete automated gates

### Swift package

Command:

```bash
swift test --package-path app --jobs 1
```

Result: PASS — 418 tests, 0 failures.

Coverage includes adaptive contrast calculations, Reduce Motion policy, search routing and validation, conservative detection, protected-site policy fixtures, Reader gesture/chrome behavior, adjacent-load errors and retry suppression, persistence, local-first hydration, Downloads accounting and retry, Settings outcomes, and semantic-feedback event suppression.

### Complete ToonEdgeUITests — iPhone 16e

Device: dedicated iPhone 16e, iOS 18.6, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`.

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-quiet-editorial-ui-16e-final-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-quiet-editorial-ui-16e-final.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST SUCCEEDED **` — 36 tests, 0 failures.

Result bundle: `/private/tmp/toonedge-quiet-editorial-ui-16e-final.xcresult`.

### Complete ToonEdgeUITests — iPhone 16 Pro Max

Device: dedicated iPhone 16 Pro Max, iOS 18.6, `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`.

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-quiet-editorial-ui-promax-final-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-quiet-editorial-ui-promax-final.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST SUCCEEDED **` — 36 tests, 0 failures.

Result bundle: `/private/tmp/toonedge-quiet-editorial-ui-promax-final.xcresult`.

### Exact simulator build

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-quiet-editorial-derived \
  build CODE_SIGNING_ALLOWED=NO
```

Result: `** BUILD SUCCEEDED **`.

## Journey matrix

| Journey | Deterministic evidence | Status / limitation |
|---|---|---|
| Home and Search | Light/dark primary tabs, Accessibility XXXL search entry, keyboard/focus, cancel/reopen, clear/retype, invalid-input recovery, whole-row suggestion | Automated PASS on both device sizes. Literal spoken focus order remains manual. |
| Browser Clean Mode | High auto-open, medium whole-surface CTA, low/nonviable/protected negative controls | Automated PASS on both device sizes using sanitized fixtures. Live protected pages were not loaded. |
| Reader chrome/settings | Reading-surface-only chrome toggle, accessibility-size settings, explicit Done, Back, View Original | Automated PASS on both device sizes. Spoken rotor/action review remains manual. |
| Reader adjacent failure | Typed challenge feedback, explicit Retry, explicit Open Original, no automatic loop | Automated PASS on both device sizes. Adjacent success is covered in package integration tests, not a deterministic live UI fixture in this run. |
| Library / Series Detail | Loading transitions, filters, density persistence, primary action visibility, chapter utility, mutation failure and retry | Automated PASS on both device sizes. Literal spoken focus order remains manual. |
| Downloads | Loading/empty/content, accessibility header/actions, removal failure, preserved row, retry, success, summary refresh | Automated PASS on both device sizes. |
| Settings | Accessibility layout, Reader preference persistence, Storage route, update found/no-update/failure, haptic preference persistence | Automated PASS on both device sizes. Physical haptic output remains manual. |
| Appearance and motion | Light/dark primary-tab smoke journeys, adaptive contrast and Reduce Motion policy tests | Automated PASS for the stated smoke and logic coverage. Full per-surface light/dark plus hands-on Increased Contrast and Reduce Motion perceptual review remains manual. |

## Product guardrails

- Sanitized protected-page fixtures verified that protected content exposes neither Clean Mode nor automatic Reader presentation.
- Low-confidence and nonviable fixtures also remain Browser-only.
- Reader retains explicit View Original Page; both adjacent-failure Open Original and Browser-owned Reader return paths passed UI tests.
- No source marketplace, recommendation surface, protected-viewer bypass, multi-page stitching, or additional catalog was introduced.
- Reader canvas remains a separately persisted preference and is not coupled to system appearance.
- Live WEBTOON, GlobalComix, and Vortex checks were not performed during this Story 12.8 run. Fixture results must not be represented as live-site validation. DEF-036 therefore remains governed by its existing live-site status.

## Haptic verification boundary

Simulator and unit tests verified event selection, single-emission behavior, preference persistence, immediate suppression when disabled, and silence for cancellation, stale completion, no-op, automatic entry, scrolling, progress, image loading/retry, brightness, and chrome visibility.

A supported physical iPhone was not available. Causal feel, restrained intensity, and enabled-versus-disabled physical output remain required manual release checks.

## Protected evidence and simulator safety

The three intentionally untracked protected screenshots in the primary checkout were hashed after all automated gates without opening or copying them:

```text
7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8  manhuatop-chapter-label-top.png
56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a  manhuatop-original-page.png
49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5  webtoon-protected-reader-cta.png
```

They remain the only untracked files in the primary checkout and are unchanged from the recorded baseline. They were not added, modified, moved, staged, or committed.

Only the dedicated iPhone 16e and iPhone 16 Pro Max destinations were used. No command targeted the shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`; it remained untouched.

No new screenshot was committed for this pass because all exercised content was represented by deterministic fixtures and the result bundles provide inspectable local UI evidence. No copyrighted page capture was created.

## Remaining release checks

Before Story 12.8 can be marked complete:

1. Perform full per-surface light/dark visual review across Home, Search, Browser Clean Mode, Reader chrome/settings/failures, Library, Series Detail, Downloads, and Settings on both dedicated device sizes.
2. Perform a literal spoken VoiceOver focus-order and action review across the same surfaces.
3. Perform hands-on Increased Contrast and Reduce Motion review on both dedicated device sizes.
4. Exercise Back and View Original after a successful adjacent chapter transition; package integration coverage does not replace this UI/manual navigation check.
5. Exercise approved haptic events on a supported physical iPhone with Haptic Feedback enabled and disabled, and confirm intended silent paths.
6. Re-run live protected-site and Vortex checks when those sites are available and authorized; retain browser-only policy and do not close live-specific defects from fixture evidence.

## Artifact retention

The `.xcresult` bundles and `/private/tmp` Derived Data are ephemeral. CI should upload both complete UI result bundles and the focused regression bundle on every release candidate, retain successful bundles for at least 30 days, and retain failed bundles for at least 90 days. CI should also archive the package-test log and exact-build log, record the tested simulator runtimes/UDIDs, and avoid uploading any live third-party page imagery or session data.
