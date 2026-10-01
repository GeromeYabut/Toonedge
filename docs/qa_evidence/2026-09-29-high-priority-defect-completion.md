# High-Priority Defect Completion Evidence Ledger

## Status and scope

Initial baseline recorded **2026-09-30 08:03:29 PDT**, followed by the Task 2 long-chapter, Task 3 retained-cache, Task 4 Settings update-check, Task 5 accessibility/appearance, Task 6 routing, and Task 7 final automated-gate results below. The filename retains the approved 2026-09-29 plan date. This ledger records automated gate completion but does not by itself close a defect or replace the remaining live/manual limitations.

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

Final Task 8 recheck from the primary checkout on its own HEAD `560d74d3ed656647ea1078530eb4e2ccbd52276a` again reported all three exact paths as `??` and reproduced the hashes above byte-for-byte. The release audit worktree was separately on HEAD `21c36b213a4207e9c2fd3628480d4603775a1f4a`. The files were not opened, modified, relocated, staged, or committed.

## Package gate

**Final gate passed** on HEAD `35b9a0a41c4c8335797cff861e5d0a2534a143aa`.

```sh
swift test --package-path app --jobs 1
```

Result: exit 0, **433/433 passed**, 0 failures, no skips reported, in **4.457 seconds**. The command output was observed directly; no separate package text log was created.

## Focused UI and journey gates

**Automated journeys verified with the manual/live limitations recorded below.** Task 2 long-chapter traversal and explicit image recovery passed on both dedicated devices; Task 3 retained-cache deletion, measured recalculation, and relaunch passed on the dedicated 16e; Task 4 Settings update outcomes passed on the dedicated 16e; Task 6 adjacent routing and the separate WEBTOON/GlobalComix browser-only profiles passed on the dedicated 16e. The complete Task 7 UI gates below reran all 48 UI tests on both dedicated device sizes.

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

The recorded Task 2 runs targeted only the dedicated 16e and Pro Max; the shared iPhone 16 Pro was not targeted and protected screenshots were not modified. That ledger-only update ran no simulator commands or tests and did not re-hash protected files; Task 8 completed the final integrity recheck above.

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

Classification: **deterministic fixture UI plus package/filesystem evidence**, not live transport or offline Reader decoding evidence. The synthetic byte payload is not chapter artwork and is not intended as a decodable PNG despite the fixture asset URL's suffix. No network response is required, and no safe screenshot was captured. Task 3 targeted only the dedicated 16e; the shared iPhone 16 Pro and protected screenshots were untouched. The later ledger-only update ran no tests or simulator commands; Task 8 completed the final protected-file hash audit above.

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

Classification: **deterministic fixture UI plus package concurrency evidence**. It does not contact live series sites, validate network timing, or prove how a specific site failure will be classified. The fixture returns aggregate refresh results through the production Settings view model and feedback mapping. No screenshot was necessary or captured. The run targeted only the dedicated 16e; the shared iPhone 16 Pro and protected screenshots were not touched. Swift parse and `git diff --check` passed before GREEN; Task 7 subsequently passed both complete UI suites and the exact build.

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

**Passed** on HEAD `35b9a0a41c4c8335797cff861e5d0a2534a143aa` using the dedicated iPhone 16e, iOS 18.6.

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

Result: exit 0, **48/48 passed**, 0 failures, 0 unexpected failures, and no skips reported. Test execution was **822.838 seconds**; Xcode's test-operation observer reported **824.961 seconds**. Suite completed 2026-09-30 22:41:43 PDT. Result bundle: `/private/tmp/toonedge-final-16e.xcresult`. Xcode warned that the arm64 and x86_64 representations matched the named simulator and selected the first; the executed destination ID was the required dedicated 16e. No separate text log was captured.

## Complete UI suite — iPhone 16 Pro Max

**Passed** on the same HEAD using the dedicated iPhone 16 Pro Max, iOS 18.6, after the 16e gate completed.

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

Result: exit 0, **48/48 passed**, 0 failures, 0 unexpected failures, and no skips reported. Test execution was **829.470 seconds**; Xcode's test-operation observer reported **837.226 seconds**. Suite completed 2026-09-30 22:56:03 PDT. Result bundle: `/private/tmp/toonedge-final-16promax.xcresult`. The same harmless dual-architecture destination warning appeared, and Xcode selected the required Pro Max device ID. No separate text log was captured.

## Exact required build

**Passed** on the same HEAD. The exact unwrapped command below exited 0 and emitted `** BUILD SUCCEEDED **`.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-next-hardening-derived \
  build CODE_SIGNING_ALLOWED=NO
```

The successful build used the required dedicated iPhone 16e destination and `/private/tmp/toonedge-next-hardening-derived`. Warnings were limited to Xcode choosing the first of the arm64/x86_64 representations of the same simulator, App Intents metadata extraction being skipped because the target has no AppIntents dependency, and `--strip-bitcode` being ignored because signing was disabled. No compiler error occurred. Successful output was observed directly and has no separate text-log artifact.

One earlier wrapped attempt (`xcodebuild ... 2>&1 | tee /private/tmp/toonedge-next-hardening-build.log`) exited 70 before compilation when CoreSimulatorService became unavailable inside the wrapped invocation. It reported no matching destination and produced `/var/folders/l6/flfsspp57yn86vr7xy6gyz6m0000gn/T/ResultBundle_2026-30-09_22-57-0022.xcresult`. The log and error bundle were preserved. This is classified as an invocation/environment failure, not a product build failure; the exact unwrapped command immediately resolved the destination and succeeded without code or simulator changes.

## Live versus fixture results

DEF-020, DEF-021, and DEF-022 are supported by package/repository tests plus sanitized deterministic UI fixtures. Their UI journeys use reserved fixture domains and generated imagery; they are not live-site claims. The naturally occurring challenge/rate-limit path for DEF-022 was not deliberately triggered live. The named WEBTOON and GlobalComix release checks are also deterministic profile-policy fixtures, not live protected-page access.

DEF-036 is the only live-site parity audit in this completion set. Both Vortex flows reached the same visible chapter and Reader, with one initial detection, no follow-up, one pending presentation, and one visible presentation. The in-site result scored 114 with 40 candidates; direct scored 168 with 39 candidates. The evidence does not prove equivalent final Reader page lists or stable payload identity, so DEF-036 remains **Open**. No live page art, HTML, cookies, credentials, or complete sensitive URLs were committed.

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

Final audit performed from documentation HEAD `21c36b213a4207e9c2fd3628480d4603775a1f4a`. The final automated gates were executed against app HEAD `35b9a0a41c4c8335797cff861e5d0a2534a143aa`; the intervening commit records those results and changes no app code.

### Defect disposition and root causes

| Defect | Final status | Root cause | Implementation and verification commits |
|---|---|---|---|
| DEF-020 | **Resolved** | Sparse Reader adjacency could accept stale explicit chapter 1/169 links before enforcing numeric `current ± 1`. | Domain: `cd4ddd5`, `c62981b`. Fixture/UI: `3383d6a`, `6df4832`, `63e2e24`. Final full-gate record: `21c36b2`. |
| DEF-021 | **Resolved** | Older unfinished stored state could remain primary unless progress recency and newly discovered adjacent chapters were reconciled into the authoritative saved-series target. | Production selector/reconciliation integrated in checkpoint `4a021184`; repository evidence `9271a6c`; fixtures `26a6f15`, `e19f7ea`; UI `feab4da`. |
| DEF-022 | **Resolved** | Hidden adjacent-load outcomes were collapsed into one generic error, discarding safe target and diagnostics and leaving no controlled recovery. | Typed production flow `d32df30`, visible-failure hardening `8b4380e`, editorial recovery UI `8e0c159`; explicit-retry regression `b2b67f8`; fixtures/fixes `168e65e`, `eb56752`, `dba917f`; UI/evidence `f93f023`, `b6cec01`. |
| DEF-036 | **Open** | Same-WebView SPA route/content settlement originally did not reliably schedule a bounded post-route detection. The bounded follow-up fixed the deterministic scheduling gap, but live payload equivalence remains unproven. | Route fix `90159fa`; focused live ledger [DEF-036 Vortex parity](2026-09-29-def-036-vortex-parity.md); Task 6 fixture/policy records `71b98b1`, `35b9a0a`. |

`docs/defects.md` already states these three resolved statuses and the honest DEF-036 live limitation; Task 8 therefore makes no defect-registry change.

### Acceptance-criterion mapping

#### DEF-020 — numeric Reader adjacency

| Acceptance criterion | Result and evidence |
|---|---|
| Chapter 155 Next attempts 156, never 169. | **Pass.** Exact-label Pro Max UI journey opens Chapter 156. |
| Chapter 155 Previous attempts 154 when resolvable. | **Pass.** Exact-label Pro Max UI journey opens Chapter 154, never chapter 1. |
| Recent activity order does not define adjacency. | **Pass.** Sparse repository regressions use stored chapters 1, 155, and 169 and still resolve only 154/156. |
| Generated All rows and Reader controls share conservative numeric inference. | **Pass.** `ChapterNumericLabelExtractor` and `ChapterURLInference` are canonical; stored payload is preferred, explicit links must identify the requested neighbor, and unsafe patterns expose no target. |
| Sparse recent chapters cannot become adjacent Reader targets. | **Pass.** Nine focused package regressions and 3/3 `ToonEdgeNumericAdjacencyUITests` passed; the final 433-test package and both 48-test UI suites retained coverage. |

Evidence: [DEF-020 numeric adjacency](2026-09-29-def-020-numeric-adjacency.md), `/private/tmp/toonedge-def020-numeric-adjacency.xcresult`, and the two final UI bundles.

#### DEF-021 — authoritative Continue target

| Acceptance criterion | Result and evidence |
|---|---|
| Returning from chapter 3 immediately shows `Continue Chapter 3`. | **Pass.** Focused UI verifies Reader Back refreshes the Series Detail CTA and progress. |
| Continue opens chapter 3, not chapter 1. | **Pass.** The exact CTA destination is asserted in the focused UI journey. |
| Inferred/hidden adjacent chapter discovery becomes a persisted reading target. | **Pass.** Repository reconstruction with a fresh `ModelContext` preserves chapter 3 payload/progress; deterministic UI relaunch preserves the visible journey. |
| Older unfinished chapters cannot override the newest active chapter. | **Pass.** Package regressions retain unfinished chapter 1 while selecting newer chapter 3. Planned/unread first-readable behavior also remains covered. |

Evidence: [DEF-021 authoritative Continue](2026-09-29-def-021-authoritative-continue.md), `/private/tmp/toonedge-def021.xcresult`, and [sanitized Continue Chapter 3 screenshot](2026-09-29/def-021-authoritative-continue-chapter-3.png).

#### DEF-022 — typed adjacent outcomes

| Acceptance criterion | Result and evidence |
|---|---|
| Challenge/rate-limit/timeout failures show specific actionable feedback. | **Pass.** The matrix also covers unavailable, low-confidence, and non-viable-image outcomes with distinct copy. |
| Known target offers Retry and Open Original. | **Pass.** Every failure row retains Chapter 1 and enabled actions; every Open Original route reaches the safe Chapter 2 fixture. Challenge Retry alone succeeds after the explicit 1.5-second delay. |
| Normal adjacent navigation still opens Reader. | **Pass.** Success replaces Chapter 1 with Chapter 2, with Back and View Original free of stale feedback. |
| Challenge/rate-limit and timeout regressions exist. | **Pass.** Loader, feedback, explicit-retry, and parameterized five-reason package tests pass. |
| No aggressive repeated hidden loads. | **Pass.** Each failure remains at one loader call until explicit user Retry; cancellation invalidates late completion and there is no automatic loop. |

Sanitized diagnostics are limited to direction, elapsed milliseconds, reason, target host, confidence, parser path, and challenge signals; full URLs, queries, cookies, headers, credentials, and sessions are absent. Evidence: [DEF-022 typed adjacent outcomes](2026-09-29-def-022-adjacent-outcomes.md), `/private/tmp/toonedge-def022.xcresult`, and [sanitized Reader screenshot](2026-09-29/def-022-adjacent-outcome-chapter-1.png).

#### DEF-036 — Vortex route parity

| Acceptance criterion | Result and evidence |
|---|---|
| WebKit integration covers a client-side/same-WebView series-to-chapter transition. | **Pass, deterministic.** Sanitized Vortex SPA and route-policy regressions exercise the transition and bounded settled-content follow-up. |
| New chapter content runs once and produces the same viable Reader session as direct load. | **Unresolved live criterion.** Both live routes visibly opened Reader with one initial detection, but differing score/candidate counts and absent final page-list/payload comparison prevent an equivalence claim. |
| Repeated callbacks do not duplicate detection or presentation. | **Pass.** Fixture deduplication regressions pass; both live chapter flows recorded one initial detection, zero follow-ups, one pending presentation, and one visible presentation. |

DEF-036 stays **Open**. Fixture success cannot close the missing live Reader-payload parity proof.

### Files and interfaces in the completed slices

- DEF-020: `Core/Domain/AppModels.swift` (`ChapterNumericLabelExtractor`, `ChapterURLInference`) and `Core/Persistence/Repositories/SwiftDataLibraryRepository.swift` numeric adjacency; `PersistenceLifecycleTests.swift`, `ToonEdgeAppEntry.swift`, and `ToonEdgeOfflineUITests.swift` supply repository and UI coverage.
- DEF-021: `AppModels.swift` (`SeriesPrimaryChapterSelector`), `SwiftDataLibraryRepository.continueReadingTarget(for:)` and recent-reading reconciliation, plus `SeriesDetailView.swift` return refresh; persistence tests, namespaced AppEntry fixtures, and `ToonEdgeAuthoritativeContinueUITests` verify the contracts.
- DEF-022: `AdjacentReaderSessionLoader.swift` (`AdjacentReaderSessionLoadError`, diagnostics and logger), `ReaderViewModel.navigateAdjacentChapter`, `ReaderView` recovery controls, Browser-owned replacement routing, `PageAnalysisScript` challenge signals, and the related loader/Reader/Browser tests and AppEntry/UI fixtures.
- DEF-036: `BrowserWebView.swift` settled-route observation/follow-up and `BrowserExperienceTests.swift` route scheduling/deduplication fixtures. Task 6 additionally routes named protected-profile fixtures through the existing `ProfileAwareChapterDetector`; it does not add a parallel policy.

### Verification summary

- Final package gate: **433/433 passed**, 0 failures, no skips reported, 4.457 seconds.
- Focused UI: DEF-020 **3/3** on dedicated Pro Max; DEF-021 **3/3** on dedicated Pro Max; DEF-022 **4/4** on dedicated 16e; named WEBTOON/GlobalComix profiles **2/2** and adjacent routing **4/4** on dedicated 16e.
- Final UI: **48/48** on dedicated iPhone 16e and **48/48** on dedicated iPhone 16 Pro Max, zero failures and no skips reported. Bundles: `/private/tmp/toonedge-final-16e.xcresult` and `/private/tmp/toonedge-final-16promax.xcresult`.
- Exact required Debug simulator build: `** BUILD SUCCEEDED **` with signing disabled. The preceding wrapped invocation-only CoreSimulator failure is separately preserved and is not a product failure.
- Simulator safety: all recorded commands name only dedicated 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` or Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`. No recorded command targets shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.

### Migration, compatibility, and remaining risk

- No persistence schema or migration was introduced by DEF-020, DEF-021, or DEF-022. Existing stored data remains compatible.
- DEF-020 deliberately rejects ambiguous numeric explicit URLs; sites whose URLs do not expose canonical chapter identity may show disabled adjacency unless a stored payload or safe inference exists. This is the conservative failure mode.
- DEF-021 production reconstruction is verified against the same in-memory SwiftData container with a fresh context. The UI process-relaunch proof uses namespaced fixture `UserDefaults`; neither is a disk-schema migration test or live-site Continue journey.
- DEF-022 classification/recovery is deterministic fixture evidence. A naturally occurring live rate limit/challenge and live Vortex Next/Previous were not forced, consistent with the no-bypass/no-aggressive-load guardrails.
- DEF-036 live final payload parity remains the high-priority open risk. External site changes can also alter current confidence/candidate behavior.
- Spoken VoiceOver/focus/rotor/announcement review, subjective Increased Contrast review, and Series Detail appearance signoff remain limitations. Downloads at accessibility XXXL still has the recorded `19.5 KBestimated` readability risk.
- The successful `.xcresult` bundles remain under `/private/tmp` and are not durable. CI should upload them, safe screenshots, sanitized logs, and this ledger keyed by commit SHA/run ID with at least 30-day retention.

## Artifact locations and durable retention

The completed local result paths are `/private/tmp/toonedge-final-16e.xcresult` and `/private/tmp/toonedge-final-16promax.xcresult`; the successful exact build uses `/private/tmp/toonedge-next-hardening-derived`. The initial build invocation failure log is `/private/tmp/toonedge-next-hardening-build.log`. These are local working artifacts, **not durable CI artifacts**.

Recommend a CI artifact set keyed by tested commit SHA and run ID containing both `.xcresult` bundles, sanitized screenshots, package/UI/build text logs, and a copy of this ledger, with **at least 30-day retention**. Record durable artifact URLs here after upload. Review exported attachments/logs for protected art, cookies, credentials, and sensitive full URLs before upload. Preserve prior failed results when rerunning; do not overwrite or delete evidence silently. Record each attempt and its actual path.

## Limitations and outstanding work

- Task 1 provides baseline and integrity observations; Tasks 2–6 add the focused release journeys; Task 7 passes the fresh 433-test package gate, both complete 48-test UI gates, and the exact required build; Task 8 completes the defect and protected-file audit. Spoken VoiceOver/focus/rotor/announcement review, subjective Increased Contrast appearance review, Series Detail appearance, and live Vortex payload parity remain outstanding limitations.
- Local runtime/device inventory is a point-in-time observation, not proof of app behavior or simulator mutation history outside Task 1.
- No live content or protected screenshot contents were viewed or captured in this task.
- The fresh automated gates occurred on HEAD `35b9a0a41c4c8335797cff861e5d0a2534a143aa`. Durable artifact publication has not occurred, so local `/private/tmp` evidence still requires CI upload/retention before cleanup.

## Ledger validation

Task 8 ran `git diff --check` successfully. Final release-worktree `git status --short --untracked-files=all` contains only this modified ledger; the primary checkout separately contains only the three protected screenshots as untracked files. Proposed commit scope is this ledger alone with message `test: complete high-priority defect verification`; `docs/defects.md` is unchanged because its statuses are already accurate.
