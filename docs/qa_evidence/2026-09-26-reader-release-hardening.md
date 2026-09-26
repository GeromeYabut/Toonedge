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
