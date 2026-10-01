# High-Priority Defect Completion Evidence Ledger

## Status and scope

Initial baseline recorded **2026-09-30 08:03:29 PDT**, followed by the Task 2 long-chapter, Task 3 retained-cache, Task 4 Settings update-check, and Task 5 accessibility/appearance results below. The filename retains the approved 2026-09-29 plan date. Final release verification is **pending**; this ledger does not close any defect or claim that the final gates have passed.

Sources: [release-verification plan](../superpowers/plans/2026-09-29-high-priority-release-verification.md) and [master execution plan](../superpowers/plans/2026-09-29-high-priority-defect-execution.md). Task 1 performed read-only environment and repository checks and created this ledger. It did not run tests, build the app, launch or change a simulator, inspect screenshot contents, or modify app code, tests, defect statuses, or protected screenshots.

## Repository baseline

| Field | Recorded value |
|---|---|
| Worktree | `/Users/geromeyabut/Developer/Toonedge/.worktrees/high-priority-release-verification` |
| Branch | `high-priority-release-verification` |
| HEAD before ledger creation | `560d74d3ed656647ea1078530eb4e2ccbd52276a` |
| HEAD subject | `docs: correct DEF-022 simulator evidence` |
| `git status --short --untracked-files=all` | Empty output; clean before ledger creation |

Read-only commands, run from this worktree:

```sh
git branch --show-current
git rev-parse HEAD
git log -1 --oneline
git status --short --untracked-files=all
xcodebuild -version
xcrun simctl list runtimes
xcrun simctl list devices available
```

All completed with exit code 0. Later gate entries must record the tested HEAD and any working-tree changes; this initial baseline does not describe future revisions.

## Toolchain and simulator inventory

- Xcode: **16.4**, build **16F6**.
- Available runtime: **iOS 18.6**, build **22G86**, identifier `com.apple.CoreSimulator.SimRuntime.iOS-18-6`. No other runtime appeared in the inventory.
- Simulator state below was observed through listing only; Task 1 did not change it.

| Device | Identifier | Observed state | Permission |
|---|---|---|---|
| iPhone 16e | `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` | Booted | Dedicated verification device |
| iPhone 16 Pro Max | `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` | Booted | Dedicated verification device |
| iPhone 16 Pro | `04F65B71-EEB9-4085-BFBD-8B7406E480A2` | Shutdown | Shared; never target |

The same runtime also listed SIm1, iPhone 16, iPhone 16 Plus, iPad Pro 11-inch (M4), iPad Pro 13-inch (M4), iPad mini (A17 Pro), iPad (A16), iPad Air 13-inch (M3), and iPad Air 11-inch (M3), all shutdown. They are outside the permitted device set. Run the two approved device gates sequentially, preserve unrelated data, and never erase a simulator.

## Protected screenshot integrity

The three protected files are untracked in the primary checkout, so they are absent from this isolated worktree. They were checked by path and hash only, without opening, copying, staging, or modifying their content.

Read-only commands:

```sh
git -C /Users/geromeyabut/Developer/Toonedge status --short --untracked-files=all -- \
  docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
shasum -a 256 \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
```

Both commands exited 0. Git reported `??` for each exact path. All hashes match the master plan:

| File | Observed and expected SHA-256 | Comparison |
|---|---|---|
| `manhuatop-chapter-label-top.png` | `7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8` | Match |
| `manhuatop-original-page.png` | `56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a` | Match |
| `webtoon-protected-reader-cta.png` | `49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5` | Match |

Repeat this comparison during the final audit. Do not stage these files.

## Package gate

**Final gate pending.** Task 3 development package runs passed 431/431 after the initial deletion fix and 433/433 after the concurrency follow-up, as detailed below. These do not replace a fresh final gate after all implementation/review changes. Task 1 did not execute this gate. Record final tested HEAD, exit code, Swift Testing count, failures/skips, and sanitized log location.

```sh
swift test --package-path app --jobs 1
```

## Focused UI and journey gates

**Partially verified.** Task 2 long-chapter traversal and explicit image recovery passed on both dedicated devices; Task 3 retained-cache deletion, measured recalculation, and relaunch passed on the dedicated 16e; Task 4 Settings update outcomes passed on the dedicated 16e. Adjacent routing and protected-site browser-only final gates remain pending. Run new focused regressions before complete UI gates. Record VoiceOver and appearance findings separately below.

### Task 2 — long-chapter traversal and explicit recovery

Implementation commit: `6c932967f594357da609ce250fc4a5c640d444cd` (`test: verify long chapter traversal recovery`). It changes only fixture plumbing in `app/ToonEdge/ToonEdgeAppEntry.swift` and the focused journey in `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`. No production Reader implementation, schema, or production interface changed.

The focused test is `ToonEdgeUITests/ToonEdgeLongChapterUITests/testLongChapterTraversesFortyPanelsAndRecoversTransientImageFailure`, launched with `-uiTesting -resetTestData -readerHardeningFixture long-chapter`.

| Attempt | Device | Result | Elapsed test time | Result bundle |
|---|---|---|---|---|
| Initial RED | Dedicated iPhone 16e | Failed; development baseline | Not recorded here | `/private/tmp/toonedge-long-16e-red.xcresult` |
| Attempts 2–5 | Dedicated iPhone 16e | 0 passed, 1 failed each; panel 1 was not observed | Not retained | `/private/tmp/toonedge-long-16e-attempt2.xcresult` through `/private/tmp/toonedge-long-16e-attempt5.xcresult` |
| Attempts 6–10 | Dedicated iPhone 16e | 0 passed, 1 failed each; stationary panel-1 expectation failed | Not retained | `/private/tmp/toonedge-long-16e-attempt6.xcresult` through `/private/tmp/toonedge-long-16e-attempt10.xcresult` |
| Attempt 11 | Dedicated iPhone 16e | 0 passed, 1 failed; stationary panel-1 expectation exposed stale restored position and wrong scroll query | Not retained | `/private/tmp/toonedge-long-16e-attempt11.xcresult` |
| Final attempt 12 | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` | 1/1 passed, 0 failures | 165.134 seconds | `/private/tmp/toonedge-long-16e-attempt12.xcresult` |
| Final Pro Max | Dedicated iPhone 16 Pro Max, `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` | 1/1 passed, 0 failures | 176.122 seconds | `/private/tmp/toonedge-long-promax.xcresult` |

Read-only `xcresulttool` inspection confirmed that attempts 2–11 each contain one failed focused test. Attempts 2–5 span the discarded URL-protocol, localhost-listener, and initial cache-transport experiments; the exact experiment-to-bundle mapping was not retained, so this ledger does not invent one. Attempts 6–10 used the stationary page-1 assertion while the fixture bytes, decoding guard, and accessibility query were corrected. Attempt 11's safe hierarchy showed loaded/labeled images 27–33 with positive frames, proving that stale restored progress had opened near panel 30 and that `.scrollViews.firstMatch` selected Home behind Reader. The final fixture validates its replacement PNG with `UIImage`, supplies a fresh mock progress repository, and the test uses `reader.root` after asserting that it is the Reader scroll view. Page 1 is checked while stationary before traversal. These were fixture/test corrections, not evidence of a production Reader defect.

Fixture semantics and observed coverage:

- Forty ordered panel URLs use decodable, sanitized 1×1 PNG content from an injected fixture cache. Metadata is empty, and each cache lookup has an 80 ms synchronous delay, exercising fallback layout before the decoded image becomes available.
- Panel 20's first cache lookup deliberately misses. Its loopback URL (`127.0.0.1:1`) cannot supply the image, so the normal transport attempts produce one visible first-load failure. The test taps the visible **Retry** action; that explicit reload obtains the cached PNG and clears the failure. This is not a single failed HTTP request followed by automatic success.
- The test traverses all forty panels through the lazy Reader surface, checks loaded images and nonzero frames for panels 2–40, confirms the panel 20 failure clears, and finishes with displayed progress of **100%**. It does not instrument lazy-load allocation counts or measure performance/layout-shift bounds.

Classification: **deterministic fixture UI evidence only**. This does not validate live image transport, real delayed image metadata, remote-server recovery, or the memory/performance behavior of full-resolution chapter artwork. The loopback failure is intentional fixture transport; no live content is needed. No safe screenshot was captured for Task 2, so there is no standalone screenshot artifact to claim.

The recorded Task 2 runs targeted only the dedicated 16e and Pro Max; the shared iPhone 16 Pro was not targeted and protected screenshots were not modified. This ledger-only update runs no simulator commands or tests and does not re-hash protected files; their final integrity recheck remains required by the final audit.

### Task 3 — retained-cache deletion, measured recalculation, and relaunch

Production root cause: Downloads called `CacheMetadataManaging.removeCacheMetadata`, but persistent composition supplied the SwiftData repository directly. Removing the entry deleted metadata without deleting chapter files. Because measurement aggregates tracked entries, the UI could show no tracked storage while the chapter directory remained orphaned.

Separate production fixes:

- `c94f3d1d0c97626949eb9a85db0fad5d938cbbb5` (`fix: delete retained chapter files with metadata`) adds `CacheLifecycleService` and the narrow synchronous `ChapterAssetRemoving` interface, implements chapter-directory removal in `FileBackedChapterAssetCache`, and wires the wrapper through persistent/mock composition. DownloadsViewModel retains its existing abstraction; SwiftUI and the SwiftData repository do not own filesystem deletion. No schema migration is required.
- `5858d20c1ece9cdaa575bfb872d3a92e4091b60d` (`fix: serialize chapter cache file lifecycle`) adds a reference lock shared across copies of the same file cache. Lookup, directory creation plus atomic store, and removal are serialized. Deterministic tests pause real directory creation, overlap a copied cache's removal/lookup, and verify that the active store cannot recreate an orphan after removal completes; neighboring chapter bytes remain intact.

Deletion errors remain retryable: file deletion happens before metadata deletion, so a filesystem failure preserves the visible entry. If metadata deletion fails after files are removed, a retry tolerates the missing directory and can finish metadata removal. Coordination does **not** cancel downloads that have not called `store`; later stores remain allowed. The lock is shared by copies of an instance, not a cross-process or global per-path transaction, and a returned cache URL is not a lifetime read lease.

Package TDD evidence (commands run from the recorded worktree):

| Stage | Command | Observed result |
|---|---|---|
| Existing baseline | `swift test --package-path app --jobs 1 --filter CacheStorageTests` | 12/12 passed |
| Deletion RED | `swift test --package-path app --jobs 1 --filter persistentDownloadsRemovalDeletesChapterFilesAndRecalculatesStorage` | 0/1 passed; chapter directory survived removal although metadata/zero-summary assertions passed |
| Initial fix focused GREEN | `swift test --package-path app --jobs 1 --filter 'CacheStorageTests\|AppDependenciesTests'` | 27/27 passed |
| Initial fix full package | `swift test --package-path app --jobs 1` | 431/431 passed, 4.384 seconds |
| Concurrency RED | `swift test --package-path app --jobs 1 --filter 'chapterRemovalWaitsForInFlightStoreAcrossCacheCopies\|cachedAssetLookupWaitsForInFlightStoreAcrossCacheCopies'` | 0/2 passed; premature removal, recreated directory, and partial-store lookup observed |
| Concurrency focused GREEN | `swift test --package-path app --jobs 1 --filter 'CacheStorageTests\|AppDependenciesTests'` | 29/29 passed |
| Concurrency full package | `swift test --package-path app --jobs 1` | 433/433 passed, 4.140 seconds |

Fixture/UI commit: `75c48cb9dd4625a15c733bb63e594fbc286f8262` (`test: verify retained cache deletion lifecycle`). The focused test is `ToonEdgeUITests/ToonEdgeRetainedCacheLifecycleUITests/testMeasuredRetainedChapterRemovalPersistsAcrossRelaunch`. It launches `-uiTesting -resetTestData -cacheLifecycleFixture <UUID>`, then relaunches with the same UUID and without reset.

| Attempt | Device | Result | Elapsed test time | Result bundle |
|---|---|---|---|---|
| True UI RED | Dedicated iPhone 16e | 0/1 passed; expected retained row absent before fixture implementation | Not recorded here | `/private/tmp/toonedge-cache-lifecycle-red.xcresult` |
| UI GREEN | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` | 1/1 passed, 0 failures | Approximately 15.091 seconds | `/private/tmp/toonedge-cache-lifecycle-green.xcresult` |

An earlier disk-space failure occurred before a valid test run and produced invalid/incomplete evidence; it is not counted as RED or a product failure. Recovery cleaned only disposable DerivedData. It did not erase a simulator or delete protected screenshots or retained result evidence.

The fixture uses UUID-isolated persistent SwiftData metadata and a real `FileBackedChapterAssetCache`, composed through the production lifecycle wrapper and `CacheStorageMeasurementService`. It writes **2,048 sanitized synthetic bytes** through `ChapterAssetCaching` and records one retained chapter with an intentionally different 99,999-byte estimate. Downloads displays **1 chapter · 2 KB measured** and **1 retained references · 0 recent references**, demonstrating real measured storage rather than an estimated-only mock.

The test taps the visible **Remove Retained Cache Fixture, Retained Cache Chapter 7 from cache** action and requires the row to disappear, success feedback, the empty state, **0 chapters · No local storage tracked**, and zero retained/recent references. A fixture service delegates the actual removal to production code and then checks the real chapter directory with `FileManager`; if it still exists, the service throws instead of permitting UI success. This is an in-app filesystem assertion, not direct filesystem access from the UI runner. Relaunch reopens the same isolated store without reseeding and verifies that the row remains absent and the zero summary persists.

Classification: **deterministic fixture UI plus package/filesystem evidence**, not live transport or offline Reader decoding evidence. The synthetic byte payload is not chapter artwork and is not intended as a decodable PNG despite the fixture asset URL's suffix. No network response is required, and no safe screenshot was captured. Task 3 targeted only the dedicated 16e; the shared iPhone 16 Pro and protected screenshots were untouched. This ledger-only update runs no tests or simulator commands; the final protected-file hash audit remains pending.

### Task 4 — Settings update-check outcomes

The pre-existing Settings UI journey asserted the final success-with-update, no-update, and partial-failure messages, but its immediate mocks completed before UI automation could observe the loading state. It also had no fixture for a true total refresh failure: `-seedUpdateFailure` is intentionally partial (`checkedCount: 3`, `failedCount: 2`). No production Settings defect was observed. Package coverage already verifies that `SettingsViewModel` suppresses concurrent duplicate refresh calls while one request is suspended.

Fixture/test commit: `8161767` (`test: verify Settings update outcomes`). `app/ToonEdge/ToonEdgeAppEntry.swift` gives all four update fixtures a deterministic three-second service delay and adds `-seedUpdateTotalFailure` with `checkedCount: 3`, `updatedCount: 0`, and `failedCount: 3`. `app/ToonEdgeUITests/ToonEdgeSettingsUITests.swift` verifies the disabled **Checking…** state, distinct final copy, re-enabled update action, and continued tab navigation. No production Settings implementation changed.

Focused command, run from the recorded worktree with the same scoped DerivedData path for RED and GREEN:

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-release-settings-derived \
  test \
  -only-testing:ToonEdgeUITests/ToonEdgeSettingsUITests/testUpdateCheckDisablesDuplicateSubmissionAndShowsDistinctUsableResults \
  -resultBundlePath RESULT_PATH \
  CODE_SIGNING_ALLOWED=NO
```

| Stage | Device and timestamp | Result | Elapsed test time | Result bundle |
|---|---|---|---|---|
| UI RED | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`, iOS 18.6; suite completed 2026-09-30 19:36:15 PDT | 0/1 passed; 5 expected assertion failures. Immediate fixtures did not expose the disabled loading state, and the absent total-failure fixture fell back to `No saved series to check.` | 36.070 seconds | `/private/tmp/toonedge-settings-updates-red.xcresult` |
| UI GREEN | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`, iOS 18.6; suite completed 2026-09-30 19:38:05 PDT | 1/1 passed, 0 failures | 34.942 seconds | `/private/tmp/toonedge-settings-updates-green.xcresult` |

Observed deterministic outcomes:

- Success with update: **Found updates for 1 series.**
- Successful no-update: **No new chapters found.**
- Partial refresh failure: **No updates found; 2 series could not be refreshed.**
- Total refresh failure: **Could not refresh 3 series.**

For every fixture, the identified update button changed to disabled **Checking…**, preventing a second UI submission; after completion it returned to enabled **Check for New Chapters**, making retry available. The Home tab remained hittable, demonstrating that Settings navigation stayed usable after each result. The focused package regression `settingsUpdateCheckSuppressesDuplicateRequests` remains the direct service-call-count proof that a concurrent second invocation is ignored.

Classification: **deterministic fixture UI plus package concurrency evidence**. It does not contact live series sites, validate network timing, or prove how a specific site failure will be classified. The fixture returns aggregate refresh results through the production Settings view model and feedback mapping. No screenshot was necessary or captured. The run targeted only the dedicated 16e; the shared iPhone 16 Pro and protected screenshots were not touched. Swift parse and `git diff --check` passed before GREEN; complete UI and final build gates remain pending.

Prior slice ledgers are context, not substitutes for these final gates:

- [DEF-020 numeric adjacency](2026-09-29-def-020-numeric-adjacency.md)
- [DEF-021 authoritative Continue](2026-09-29-def-021-authoritative-continue.md)
- [DEF-022 typed adjacent outcomes](2026-09-29-def-022-adjacent-outcomes.md)
- [DEF-036 Vortex parity](2026-09-29-def-036-vortex-parity.md)

### Task 6 — adjacent routing and protected browser-only profiles

Existing adjacent-routing UI coverage was rerun rather than rewritten. The four-test `ToonEdgeAdjacentFailureUITests` suite verifies both successful Chapter 2 exits and every deterministic typed failure row. Success retains an explicit **View Original Page** route to the safe Chapter 2 fixture URL and a working Reader **Back** route to Home. Timeout, challenge/rate-limit, unavailable, low-confidence, and non-viable-image outcomes each keep Chapter 1 visible, retain **Back**, expose enabled **Retry** and **Open Original**, and open the known safe Chapter 2 URL only after the user chooses **Open Original**. The challenge fixture additionally verifies explicit user retry recovery to Chapter 2 without automatic looping.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-release-task6-derived \
  test \
  -only-testing:ToonEdgeUITests/ToonEdgeAdjacentFailureUITests \
  -resultBundlePath /private/tmp/toonedge-task6-adjacent-routing.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Result: **4/4 passed**, 0 failures, in **175.769 seconds**; suite completed 2026-09-30 22:24:09 PDT. Result bundle: `/private/tmp/toonedge-task6-adjacent-routing.xcresult`.

The prior generic `protected` fixture supplied a hand-authored low-confidence result and did not independently demonstrate the WEBTOON and GlobalComix registry profiles. Two RED-first UI regressions now launch separate sanitized, profile-realistic URLs and require the corresponding address to remain in Browser while both **Read in Clean Mode** and Reader remain absent across a settle interval. Minimal fixture plumbing feeds sanitized page analysis through the existing `ProfileAwareChapterDetector`; it does not copy or reimplement protected-site policy. Candidate bytes are never fetched, and the only candidate host is `images.example.test`.

| Stage | Device | Result | Test time | Result bundle |
|---|---|---|---|---|
| Protected-profile RED | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`, iOS 18.6 | 0/2 passed; both exact profile URL assertions failed because the named fixtures were not mapped. Clean Mode and Reader were absent. | 21.230 seconds | `/private/tmp/toonedge-task6-protected-red.xcresult` |
| Protected-profile GREEN | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`, iOS 18.6 | 2/2 passed, 0 failures; WEBTOON and GlobalComix remained independently browser-only | 12.484 seconds | `/private/tmp/toonedge-task6-protected-green.xcresult` |

The RED and GREEN command selected `testWebtoonBrowserOnlyProfileNeverExposesCleanModeOrReader` and `testGlobalComixBrowserOnlyProfileNeverExposesCleanModeOrReader`, used the same scoped DerivedData path above, and differed only in result-bundle path. The canonical policy regressions were also rerun:

```sh
swift test --package-path app --jobs 1 \
  --filter 'defaultSiteProfileRegistryIncludesInitialSupportTiers|protectedReaderImagesCannotProduceReaderPresentation'
```

Result: **2/2 passed**, 0 failures, in **0.003 seconds**. This confirms the registry still identifies both domains as browser-only and cannot produce a Reader presentation. No production policy, authentication, challenge handling, cookies, or protected content changed. These are deterministic fixture/package results, not live protected-site checks.

DEF-036 remains **Open**. The prior sanitized live Vortex observations showed the same chapter identity, one initial detection, no follow-up, and one Reader presentation for both in-site and direct flows. They did not establish equivalent final page lists or stable Reader payload identity; the score and candidate counts also differed. Task 6 did not repeat live Vortex access, so fixture evidence does not close that live parity criterion.

Safety: Task 6 targeted only the dedicated iPhone 16e. It did not target the shared iPhone 16 Pro, use live protected pages, capture protected artwork, or access the three protected local screenshots. The local `.xcresult` bundles should be retained as CI artifacts keyed by commit SHA/run ID for at least 30 days alongside sanitized logs and this ledger.

## Complete UI suite — iPhone 16e

**Pending — planned command, not executed by Task 1.** Record tested HEAD, count, failures/skips, elapsed time, and log path.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-final-16e-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-final-16e.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Complete UI suite — iPhone 16 Pro Max

**Pending — planned command, not executed by Task 1.** Run after the 16e gate. Record tested HEAD, count, failures/skips, elapsed time, and log path.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-final-16promax-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-final-16promax.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Exact required build

**Pending — planned command, not executed by Task 1.** Record tested HEAD, exit code, build summary, warnings, and sanitized log path. Expected success marker is `** BUILD SUCCEEDED **`.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-next-hardening-derived \
  build CODE_SIGNING_ALLOWED=NO
```

## Live versus fixture results

**Pending final audit.** Task 2 is deterministic fixture evidence only, with the transport and image-size limitations recorded above. Task 3 combines deterministic fixture UI with real local cache/persistence and package/filesystem evidence; it does not exercise live transport. Task 4 combines deterministic Settings UI fixtures with package concurrency evidence; it does not contact live series sites. Label every other result as live, deterministic fixture, package/repository, or manual inspection. Fixture evidence cannot close a live-only criterion. Reconcile DEF-036 with its focused ledger and keep it open if live in-site parity remains unavailable or nonviable. WEBTOON and protected GlobalComix must remain browser-only; do not authenticate, bypass protection, record protected content, or capture live protected screenshots.

## Accessibility and appearance review

**Partially verified with explicit limitations.** The complete focused `ToonEdgeAccessibilityUITests` class ran on both dedicated device sizes from HEAD `4461cd7bbf1dc156d224a3a2a5920ce54980db3e`. No source or test change was made for Task 5.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=DEVICE_ID' \
  -derivedDataPath /private/tmp/toonedge-release-settings-derived \
  test -only-testing:ToonEdgeUITests/ToonEdgeAccessibilityUITests \
  -resultBundlePath RESULT_PATH \
  CODE_SIGNING_ALLOWED=NO
```

| Device | Result | Test time | Suite completion | Result bundle |
|---|---|---|---|---|
| Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`, iOS 18.6 | 10/10 passed, 0 failures | 73.992 seconds | 2026-09-30 19:59:20 PDT | `/private/tmp/toonedge-task5-accessibility-16e.xcresult` |
| Dedicated iPhone 16 Pro Max, `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`, iOS 18.6 | 10/10 passed, 0 failures | 71.953 seconds | 2026-09-30 20:00:47 PDT | `/private/tmp/toonedge-task5-accessibility-promax.xcresult` |

An initial 16e invocation exited 64 before build or test execution because `/private/tmp/toonedge-accessibility-16e.xcresult` already existed. The existing bundle was preserved, and the run was repeated at the unique Task 5 path above. This was an invocation/setup error, not an app or test failure.

The dedicated 16e initially reported Increased Contrast as `disabled`. It was enabled for one bounded sanitized smoke, then restored and queried again as `disabled`:

```sh
xcrun simctl ui 4582CDE9-27DB-4669-86AC-0631C1D7F2ED increase_contrast
xcrun simctl ui 4582CDE9-27DB-4669-86AC-0631C1D7F2ED increase_contrast enabled
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-release-settings-derived \
  test \
  -only-testing:ToonEdgeUITests/ToonEdgeAccessibilityUITests/testHomeEditorialSearchEntryRemainsReachableAtAccessibilityTextSize \
  -only-testing:ToonEdgeUITests/ToonEdgeAccessibilityUITests/testPrimaryTabsRemainHittableInLightAppearance \
  -only-testing:ToonEdgeUITests/ToonEdgeAccessibilityUITests/testReaderOnlyExposesContextuallyValidControlsAction \
  -resultBundlePath /private/tmp/toonedge-task5-increased-contrast-16e.xcresult \
  CODE_SIGNING_ALLOWED=NO
xcrun simctl ui 4582CDE9-27DB-4669-86AC-0631C1D7F2ED increase_contrast disabled
xcrun simctl ui 4582CDE9-27DB-4669-86AC-0631C1D7F2ED increase_contrast
```

The Increased Contrast smoke passed **3/3**, 0 failures, in **21.080 seconds**; the suite completed 2026-09-30 20:15:28 PDT. It verified accessibility-size Home search, light-appearance primary tabs, the sanitized Browser Clean Mode CTA, and Reader chrome semantics. The result bundle is `/private/tmp/toonedge-task5-increased-contrast-16e.xcresult`.

Automated **Pass** observations:

- **Home:** the editorial search entry exists, remains hittable at accessibility XXXL, and exposes the expected descriptive label.
- **Browser Clean Mode CTA:** the sanitized medium-confidence fixture exposes a reachable CTA that transitions to Reader.
- **Reader chrome:** the sanitized fixture exposes the Reader surface and changes its accessibility value from **Show Reader Controls** to **Hide Reader Controls** after revealing chrome.
- **Downloads:** loading transitions correctly to empty/content; the twentieth sanitized row and its labeled removal action remain reachable; the storage header and actions remain reachable at accessibility XXXL.
- **Settings and tab shell:** Home, Library, Downloads, and Settings tabs remain reachable and selectable in light and dark launch appearances and at accessibility XXXL. Settings opened at accessibility XXXL, and its visible content rendered while the tab bar remained reachable.
- Source inspection found explicit 44-point minimums for Browser, Reader, and Downloads actions plus identified Reader adjacent **Retry** and **Open Original** controls. This is structural evidence, not a runtime measurement or spoken review.

The existing UI tests launched both **Light** and **Dark** appearances on the 16e and Pro Max. They assert reachability and selection, but this automated coverage is **not** a complete subjective appearance signoff for color, contrast, visual hierarchy, truncation, safe areas, or readable widths.

Four sanitized attachments were exported read-only under `/private/tmp/toonedge-task5-attachments.nEEp02` and visually inspected; they were not copied into the repository. On both device sizes, Settings opened at accessibility XXXL, its visible content rendered, and the tab bar remained reachable; the Downloads rows/actions also remained reachable. The Downloads summary visually rendered as **`19.5 KBestimated`** at accessibility XXXL on both sizes. This is a readability issue and remaining release risk, although the focused functional assertions passed and no Task 5 product fix was made.

**Limitations — not performed and not claimed:**

- Spoken VoiceOver audio/order, labels as actually spoken, values/hints, heading navigation, and rotor usefulness were not exercised.
- Focus restoration after sheets or Reader dismissal, focus behavior when Reader chrome is hidden, and focus movement after adjacent-load feedback were not exercised.
- The once-only spoken Reader failure announcement was not verified. Retry/Open Original identifiers exist, but their spoken reachability was not manually reviewed here.
- Increased Contrast received the automated 16e reachability smoke above, but no subjective visual contrast review, spoken review, dark-appearance contrast review, or Pro Max contrast review was performed.
- Series Detail was not included in the focused class or the four exported screenshots, so its appearance and spoken behavior remain unverified in Task 5.
- The four screenshots cover Settings and Downloads, not all six requested surfaces. Browser, Reader, Home, and Series Detail received automated reachability/semantic coverage only where listed above.

Safety: all fixtures were sanitized and deterministic; no live or protected page content was used or captured. Only the dedicated 16e and Pro Max were targeted. The shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` was never targeted, and the three protected local screenshots were not accessed, modified, staged, or committed.

## Final defect audit and compatibility

**Pending.** Map every DEF-020, DEF-021, DEF-022, and DEF-036 acceptance criterion to evidence; list completed and still-open defects, root causes, commits, files/interfaces, test results, and remaining release risks. No schema or production interface changed in Task 1. Audit migration/compatibility risk against later implementation changes before release claims. Recheck protected hashes and confirm the shared 16 Pro was never targeted.

## Artifact locations and durable retention

The prescribed local result paths are `/private/tmp/toonedge-final-16e.xcresult` and `/private/tmp/toonedge-final-16promax.xcresult`; the exact build uses `/private/tmp/toonedge-next-hardening-derived`. These are planned local working paths, **not durable CI artifacts**, and Task 1 does not assert that these future outputs exist.

Recommend a CI artifact set keyed by tested commit SHA and run ID containing both `.xcresult` bundles, sanitized screenshots, package/UI/build text logs, and a copy of this ledger, with **at least 30-day retention**. Record durable artifact URLs here after upload. Review exported attachments/logs for protected art, cookies, credentials, and sensitive full URLs before upload. Preserve prior failed results when rerunning; do not overwrite or delete evidence silently. Record each attempt and its actual path.

## Limitations and outstanding work

- Task 1 provides baseline and integrity observations; Task 2 adds the focused long-chapter journey on both dedicated devices; Task 3 adds package regressions and the retained-cache journey on the dedicated 16e; Task 4 adds focused Settings update-check outcomes on the dedicated 16e; Task 5 adds two-device automated accessibility reachability, a dedicated-16e Increased Contrast smoke, and limited safe screenshot inspection. Spoken VoiceOver/focus/rotor/announcement review, subjective Increased Contrast appearance review, Series Detail appearance, fresh final package, remaining focused UI, complete UI, exact build, live-site, and final defect gates remain pending.
- Local runtime/device inventory is a point-in-time observation, not proof of app behavior or simulator mutation history outside Task 1.
- No live content or protected screenshot contents were viewed or captured in this task.
- The final release claim requires fresh gates after review fixes and durable artifact publication; neither occurred in Task 1.

## Ledger validation

Run `git diff --check` after creating/updating this ledger and record its outcome with the task handoff. Stage only this ledger for the Task 1 commit; the baseline HEAD above intentionally identifies the revision before that documentation commit.
