# 2026-09-25 Holistic UX Remediation Verification

Baseline revision: `8c538947d8a9191744e988e51529352e7e93a9c6`.

The pre-existing dirty worktree was recorded before editing and was preserved. No reset, clean, stash, broad reformat, or unrelated overwrite was performed. The shared iPhone 16 Pro (`04F65B71-EEB9-4085-BFBD-8B7406E480A2`) was not booted, closed, erased, installed to, or otherwise modified. Simulator work used the dedicated iPhone 16e (`4582CDE9-27DB-4669-86AC-0631C1D7F2ED`) and iPhone 16 Pro Max (`29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`).

## Defect results

| Defect | Result | Regression evidence |
|---|---|---|
| DEF-035 | Implemented | Browser-only registry and presentation tests; live WEBTOON stayed in Browser without a Clean Mode CTA. GlobalComix is fixture/policy verified only. |
| DEF-036 | Open | Route observation/debounce tests and sanitized Vortex route fixture pass; direct live Vortex auto-opened Reader. The live series-page-to-chapter transition was not independently completed, so acceptance remains open. |
| DEF-037 | Implemented | Comizy redirect fixture, request-context propagation, native image preflight, retry/fallback tests; live redirected chapter opened Reader only with viable images. |
| DEF-038 | Implemented | XCUITest confirms all four tabs remain present and hittable at accessibility text size; exercised on iPhone 16e and Pro Max. |
| DEF-039 | Implemented | Twenty-entry Downloads XCUITest reaches the final row/action; unit coverage checks scrolling, 44-point actions, and item-specific labels. |
| DEF-040 | Implemented | Hostless HTTP(S) validation tests plus dedicated-simulator manual check confirm inline guidance without Browser presentation. |
| DEF-041 | Implemented | Numeric identity, rejection, persistence-write, and relaunch projection regressions pass. |
| DEF-042 | Implemented | Router tests cover Home fallback origin, Back to Home, View Original, and clearing on failure/dismissal/unrelated navigation. |
| DEF-043 | Implemented | Settings repository persistence tests and relaunch XCUITest pass; reader, storage, update feedback, and About sections are present. |
| DEF-044 | Implemented | Small-device accessibility-size XCUITest preserves the full accessibility name and captures the adaptive Home/Settings layout. |
| DEF-045 | Implemented | Phase unit test and delayed-populated-library XCUITest prove the empty state is never exposed before load completion. |
| DEF-046 | Implemented | Settings XCUITest confirms `Enter Full Screen` is absent; shared row semantics hide decorative icons and expose meaningful controls. |

## Automated and build gates

- `swift test --package-path app --jobs 1`: PASS, 333 tests, 0 failures.
- Exact remediation-plan iPhone 16e build with `/private/tmp/toonedge-remediation-derived`: `** BUILD SUCCEEDED **`.
- Full ToonEdgeUITests on iPhone 16e: PASS, 6 tests, `/private/tmp/toonedge-final-ui-16e-2.xcresult`.
- Full ToonEdgeUITests on iPhone 16 Pro Max: PASS, 6 tests, `/private/tmp/toonedge-final-ui-promax.xcresult`.
- Explicit final search-label and Settings-semantics checks: PASS on iPhone 16e and Pro Max, `/private/tmp/toonedge-final-accessibility-16e.xcresult` and `/private/tmp/toonedge-final-accessibility-promax-2.xcresult`.
- Accessibility-extra-extra-extra-large iPhone 16e run: PASS, `/private/tmp/toonedge-large-text-16e.xcresult`.
- Retain, terminate, relaunch, forced-network-unavailable offline journey: PASS, `/private/tmp/toonedge-offline-16e-2.xcresult`.
- Final safe screenshot: `docs/qa_evidence/2026-09-25-final-iphone-16e.png`.

## Fixture and live-site boundary

Sanitized fixtures cover Vortex, ManhuaTop, MangaKatana, MangaPill, and Comizy using metadata and `example.test` image URLs only. They contain no copyrighted page images, credentials, cookies, or session secrets. WEBTOON and protected GlobalComix remain browser-only, and no challenge, authentication, paywall, or protected viewer bypass was added.

Live WEBTOON, direct Vortex, and redirected Comizy checks were completed on the dedicated iPhone 16e. Temporary live-site screenshots that contained third-party artwork were deleted and are not evidence artifacts. Vortex's in-site series-to-chapter transition remains the sole live-site limitation and keeps DEF-036 open; its deterministic fixture and navigation regression pass.

## Compatibility notes

No persistent model migration was introduced. Reader settings add namespaced UserDefaults keys with field-by-field defaults, and retained chapter assets reuse the existing file-backed cache namespace. The XCUITest target and launch fixtures are Debug/test-only. Live-site DOM, redirect, CDN-header, and challenge behavior can change independently of the app and remains a compatibility risk mitigated by conservative fallback to Browser.
