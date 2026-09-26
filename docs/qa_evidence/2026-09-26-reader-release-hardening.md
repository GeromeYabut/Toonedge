# ToonEdge Reader Release-Hardening Evidence — 2026-09-26

## Baseline

- Branch: `story-11.27-unseen-adjacent-reader-loading`
- Starting revision: `4a0211841cd4707eebed7bffa3342aa3455f1f7d`
- Initial worktree: only the three protected third-party screenshots were untracked.
- Dedicated simulator used: iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`.
- Shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` was not targeted.

## DEF-036 — Vortex route parity

### Deterministic tests

- RED: the delayed-SPA route test initially failed because generic low-confidence Vortex results did not request a follow-up.
- GREEN: `swift test --package-path app --jobs 1 --filter 'vortex|browserDetectionRetryPolicyAllowsOnlyOneFollowUpPerURL|browserSessionFollowUpWaitsForDelayedSPAContentToSettle'`
- Result: 4 tests passed, 0 failures.
- Coverage proves one bounded host-scoped follow-up, duplicate suppression, a longer Vortex settle interval, and an ordered viable Reader session from the sanitized fixture.

### Live iPhone 16e result

- Initial control run: series-to-chapter navigation settled on chapter 168 at low confidence (`score=33`, `candidates=1`); a direct chapter 168 load reached high confidence (`score=160`, `candidates=41`) and produced one pending and one visible Reader presentation.
- Remediated route runs: the initial chapter result and the single 12-second follow-up both remained low confidence (`score=33`, `candidates=1`). A later direct control produced the same low result, so the site no longer supplied a viable direct baseline during final revalidation.
- No challenge signal, authentication bypass, protected-viewer interaction, or aggressive retry loop was used.
- Result bundles from diagnostic runs are under `/private/tmp/toonedge-live-vortex-derived/Logs/Test/`; these are temporary host artifacts and should be retained by CI when live compatibility checks are run.
- Conclusion: deterministic app behavior is improved, but DEF-036 remains open because live in-site/direct Reader parity could not be verified against a viable final control.

## DEF-020 — Numeric Reader adjacency

- Existing checkpoint implementation was inspected before changing status. Numeric adjacency uses canonical chapter identity plus `ChapterURLInference`, prefers an exact stored adjacent payload, and does not fall through to sparse Recent ordering.
- Focused command: `swift test --package-path app --jobs 1 --filter 'swiftDataRepositoryDerivesNumericAdjacentReaderControlsForSparseChapterLists|swiftDataRepositoryPrefersStoredNumericAdjacentChapterWhenPayloadExists|swiftDataRepositoryDoesNotJumpToSparseStoredChapterWhenNumericAdjacentURLIsUnsafe'`
- Result: 3 tests passed, 0 failures.
- Sparse chapters 1, 155, and 169 resolve chapter 155 to previous 154 and next 156; an unsafe source pattern resolves neither adjacent target instead of jumping to 1 or 169.
- Full gate after revalidation: `swift test --package-path app --jobs 1` — 335 tests passed, 0 failures.
- The exact sparse-chapter journey is repository/integration covered; a dedicated simulator fixture for chapters 1/155/169 does not currently exist. Live Vortex navigation was not used as proof because DEF-036’s final control was non-viable.

## DEF-021 — Authoritative Continue target

- Added an exact chapter 1/chapter 3 persistence regression covering the immediate Series Detail snapshot and a new repository instance over the same SwiftData store.
- The first RED run failed at repository reconstruction because the test harness used the non-persistent fast-store mode. Switching the reconstruction test to actual in-memory SwiftData I/O made the relaunch boundary valid; no production workaround was added.
- Focused command: `swift test --package-path app --jobs 1 --filter 'seriesDetailContinueUsesDiscoveredChapterThreeImmediatelyAndAfterRepositoryReconstruction|swiftDataRepositoryAddsRecentAdjacentChapterToSavedSeriesDetail|swiftDataRepositoryReconcilesRecentReadingWithSavedChapterContinueTarget'`
- Result: 3 tests passed, 0 failures.
- Verified outcomes: `Continue Chapter 3`, chapter 3 URL/ID on immediate return, the same target after repository reconstruction, and persisted Continue targeting for a chapter discovered through adjacent Reader navigation.

## DEF-022 — Typed adjacent-load failures

### TDD and automated coverage

- RED regressions first demonstrated missing typed error metadata, missing actionable retry state, missing explicit adjacent-target routing, and a static fallback that could bypass a detected challenge page.
- Independent review then found that browser-owned Readers still bypassed the typed loader, a dismissed Reader could receive a late retry result, and challenge recognition did not cover dynamic rate-limit copy or challenge bodies returned with HTTP 403/503. The review regressions failed to compile against the missing ownership replacement, cancellation, and HTTP classification interfaces before those behaviors were added.
- Loader coverage now includes deterministic challenge, HTTP-429/rate-limit copy, timeout, unavailable/low-confidence, non-viable-image, static-fallback, no-challenge-bypass, and normal-success paths.
- Browser-owned Reader navigation now uses the same typed loading path as app-owned Reader navigation and publishes only successful viable sessions back to the Browser owner. An operation token plus task cancellation prevents a dismissed Reader from reopening or replacing itself after a delayed result.
- Dynamic analysis recognizes rate-limit copy, main-frame response metadata carries safe 429/`cf-mitigated` signals, and static HTTP classification inspects challenge bodies before mapping 403/503 responses to generic unavailability.
- Focused loader command: `swift test --package-path app --jobs 1 --filter adjacentLoader` — 12 tests passed, 0 failures.
- Focused Reader/routing coverage verifies reason-specific copy, retained target URL, no request before explicit Retry, one request after Retry with injected zero-delay policy, current-session preservation, and adjacent Open Original routing.
- Review-fix focused command: `swift test --package-path app --jobs 1 --filter 'adjacent|Adjacent|pageAnalysisScriptCollectsChallengeSignals|browserOwnedReaderAcceptsOnlyViableAdjacentSessionReplacement|cancellingAdjacentNavigationPreventsLateSessionReplacement'` — 37 tests passed, 0 failures.
- Full gate after review fixes: `swift test --package-path app --jobs 1` — 345 tests passed, 0 failures.

### Dedicated iPhone 16e journey

- Command: `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' -derivedDataPath /private/tmp/toonedge-def022-derived test -only-testing:ToonEdgeUITests/ToonEdgeAdjacentFailureUITests CODE_SIGNING_ALLOWED=NO`
- Result: 2 UI tests passed, 0 failures. The fixture presents challenge/rate-limit feedback, exposes Retry and Open Original, performs no automatic retry, proves the explicit backed-off retry advances the Reader to Chapter 2, and routes Open Original to Browser.
- Latest result bundle path: `/private/tmp/toonedge-def022-derived/Logs/Test/Test-ToonEdge-2026.09.26_09-14-57--0700.xcresult`.
- Xcode reported a post-test result-bundle import/CAS warning even though the selected tests succeeded. CI should publish the `.xcresult` directory immediately and separately retain the raw `xcodebuild` log so successful test evidence survives partial result-bundle import failures.

## Release-hardening verification

### Deterministic journeys

- Focused command covering long vertical detection, reader-tagged images before dimensions are available, one transient image timeout followed by success, retained-cache deletion with measured-summary recalculation, Settings success/no-update/failure feedback, protected-reader suppression, and View Original routing: 9 tests passed, 0 failures.
- The Settings simulator journey was initially RED: the success and failure launches both returned the default `No new chapters found.` result. Test-only launch services were added for success, no-change, and failure; the same UI journey then passed all three visible result messages.
- Cache deletion/recalculation is covered at the file-backed storage layer. The UI suites also traverse a 20-entry Downloads list and verify item-specific removal controls, but the final run did not delete a real retained file through the UI.
- Long-chapter behavior is covered by the delayed-dimension detector, placeholder/progress, ordered retention, and transient image retry regressions. A single 40-panel end-to-end simulator traversal with one injected failure was not completed and remains a release-risk item.

### Simulator and build gates

- Final `swift test --package-path app --jobs 1`: 345 tests passed, 0 failures.
- Complete ToonEdgeUITests, iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`: 9 tests passed, 0 failures. Result bundle: `/private/tmp/toonedge-final-ui-16e/Logs/Test/Test-ToonEdge-2026.09.26_12-10-50--0700.xcresult`.
- Complete ToonEdgeUITests, iPhone 16 Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`: 9 tests passed, 0 failures. Result bundle: `/private/tmp/toonedge-final-ui-pro-max/Logs/Test/Test-ToonEdge-2026.09.26_12-10-50--0700.xcresult`.
- Exact required iPhone 16e Debug build using `/private/tmp/toonedge-next-hardening-derived`: `** BUILD SUCCEEDED **`.
- CI recommendation: retain both final `.xcresult` bundles plus raw `xcodebuild` logs as durable artifacts; do not rely on `/private/tmp` surviving the host job.

### Appearance and accessibility

- Safe Home screenshots were inspected in system Light, system Dark, and Dark with Increase Contrast on iPhone 16e. Text, cards, and controls remained readable and unclipped; the simulator was restored to its original Light/normal-contrast state afterward.
- ToonEdge intentionally applies `.preferredColorScheme(.dark)` and fixed dark design tokens, so system Light mode still renders the dark ToonEdge palette. This is consistent with the existing dark-chrome contract but is not adaptive Light-mode support.
- Both final UI suites exercise Home search, all four tabs at accessibility text size, Downloads depth, Reader chrome/failure actions, and Settings controls on compact and large devices. Source/test review confirms unique labels for the exercised icon-only controls.
- A literal spoken VoiceOver traversal and focus-restoration pass across Home, Browser CTA, Reader, Series Detail, Downloads, and Settings was not completed by the available automation. This remains a manual release checklist item; the automated accessibility/hittability results are supporting evidence, not a substitute.

### Live-site and policy results

- Live Vortex Next/Previous could not be exercised because the final direct and in-site chapter controls both remained low confidence with one viable candidate. DEF-036 therefore remains open; deterministic route and adjacent-loader fixtures pass.
- WEBTOON and protected GlobalComix remain `.browserOnly`; protected-reader fixture analysis remains low confidence and cannot produce a Clean Mode CTA or Reader presentation.
- Adjacent success/failure back routing and explicit Open Original behavior pass unit and UI coverage. The failure UI preserves the safe adjacent target and opens Browser without retry looping.

### Protected evidence and device safety

- The three protected screenshots remain untracked and were never staged. Final SHA-256 values: `7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8`, `56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a`, and `49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5` in the requested file order.
- The shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` was never used as a build, install, launch, boot, shutdown, erase, or UI-test destination.
