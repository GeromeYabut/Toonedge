# DEF-021 Authoritative Continue Evidence — 2026-09-29

## Scope and status

DEF-021 is resolved. Series Detail now has regression coverage proving that the most recently active in-progress chapter is authoritative even when chapter 1 remains unfinished, and that a chapter first discovered through adjacent Reader navigation becomes a valid Continue target. This verification slice did not change production code or persistence schemas.

## Root cause and implementation boundary

- The original failure allowed older stored chapter state to remain the Series Detail primary action after a later chapter became active. The existing production resolution separates primary-action selection from Recent display ordering, selects by authoritative progress recency, and reconciles newly discovered Reader chapters into saved series state.
- `SeriesPrimaryChapterSelector` and `SwiftDataLibraryRepository.continueReadingTarget(for:)` remain authoritative. Chapter identity continues to use `ChapterNumericLabelExtractor`; no view-owned selector or parallel chapter-label parser was introduced.
- Task 1 commit `9271a6c` added the adjacent-discovery repository regression. Task 2 commits `26a6f15` and `e19f7ea` added and corrected the deterministic Continue fixtures. Task 3 commit `feab4da` added the three UI journeys.
- No migration was added. Compatibility risk is limited to the existing progress-recency and recent-reading reconciliation rules already exercised by the full package suite.

## Repository evidence

The package regressions cover two complementary cases:

- A saved series contains unfinished chapter 1 and a newer chapter 3 recent/progress record. Series Detail displays `Continue Chapter 3`, and the Continue target opens chapter 3 immediately and after repository reconstruction.
- A saved series contains chapters 1 and 2, then Reader's normal recent/progress write path records newly discovered chapter 3. Chapter 3 becomes the primary target with its Reader payload and progress immediately and after reconstruction through a new `SwiftDataLibraryRepository` and fresh `ModelContext` against the same `ModelContainer`.

The full package suite also retains the existing `seriesDetailPrimaryActionStartsFirstUnreadWhenNoProgressExists` regression, preserving planned/unread first-readable behavior.

Focused commands recorded by Task 1:

```sh
swift test --package-path app --jobs 1 --filter seriesDetailContinueUsesDiscoveredChapterThreeImmediatelyAndAfterRepositoryReconstruction
swift test --package-path app --jobs 1 --filter adjacentDiscoveredChapterBecomesAuthoritativeContinueTargetImmediatelyAndAfterReconstruction
```

Both focused tests passed. The adjacent-discovery evidence test was already green against the production repository, so it justified no production change.

## UI journey evidence

The focused UI suite ran with deterministic content on the dedicated iPhone 16 Pro Max (`29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`, iOS 18.6):

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-def021-derived \
  test -only-testing:ToonEdgeUITests/ToonEdgeAuthoritativeContinueUITests \
  -resultBundlePath /private/tmp/toonedge-def021.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Result: 3 passed, 0 failed, 0 skipped:

- Reader Back immediately refreshed Series Detail with the current chapter 3 progress, and the exact `Continue Chapter 3` CTA reopened chapter 3.
- Relaunch retained the exact chapter 3 CTA and destination.
- Navigating Reader from chapter 2 to the adjacent-discovered chapter 3 refreshed the CTA and retained chapter 3 across a same-scenario relaunch.

Result bundle: `/private/tmp/toonedge-def021.xcresult`.

The UI fixtures use only `fixture.example`, `images.example.test`, generated labels, and bundled fixture artwork. No live third-party page was loaded. The result bundle contains no screenshot attachments, and no standalone screenshot was created for this slice; this is recorded as an evidence limitation rather than presenting an absent screenshot as proof.

## Persistence boundary

The two persistence claims are intentionally separate:

- Production evidence: package tests reconstruct `SwiftDataLibraryRepository` with a fresh `ModelContext` using the same in-memory `ModelContainer`, and verify chapter 3 remains authoritative. This proves repository reconstruction and persisted model reconciliation, but it is not a disk-backed process-relaunch or migration test.
- UI evidence: XCUITest relaunch state is stored under a scenario-specific `UserDefaults` namespace by `UITestContinueJourneyLibraryService`. It proves the visible return/relaunch journey through existing app interfaces, but it is test transport and is not evidence of production SwiftData disk persistence.

## Final verification

Fresh Task 4 commands:

```sh
swift test --package-path app --jobs 1
git diff --check
```

Result: 426 Swift Testing tests passed, 0 failures; `git diff --check` exited 0. The runner also emitted the expected separate XCTest summary of 0 tests before the Swift Testing run.

Read-only result inspection:

```sh
xcrun xcresulttool get test-results summary --path /private/tmp/toonedge-def021.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/toonedge-def021.xcresult
xcrun xcresulttool export attachments --path /private/tmp/toonedge-def021.xcresult --output-path <temporary-audit-directory>
```

The summary reported 3 passed and 0 failed on the dedicated Pro Max. Attachment export produced an empty manifest.

## Protected artifacts and limitations

From the primary checkout, the protected QA screenshots remained untracked and byte-identical:

```text
7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8  manhuatop-chapter-label-top.png
56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a  manhuatop-original-page.png
49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5  webtoon-protected-reader-cta.png
```

The shared iPhone 16 Pro (`04F65B71-EEB9-4085-BFBD-8B7406E480A2`) was not targeted by the recorded UI run and was not touched during this documentation task. No simulator commands were run during Task 4.

Remaining limitations:

- The result bundle and the failed helper-only bundle from test development are under `/private/tmp`; CI should upload successful `.xcresult` bundles and sanitized test logs as durable artifacts.
- This slice does not claim a production disk-backed app relaunch, schema migration, live-site Continue journey, or screenshot artifact. Those are distinct from the verified repository and deterministic UI contracts.
