# Reader baseline hardening verification

The cache optimization and Reader test harness repair passed three consecutive default-parallel full package runs, each with 645 tests, and generic iOS Simulator compilation. Production Reader behavior, schemas and public interfaces are unchanged. Both task reviews approved spec compliance and code quality without findings; whole-branch review is pending.

## Scope and cause

Branch `fix/reader-baseline-hardening` starts from freshly fetched `origin/main` at `1eaebe7acba7f984a493488cf799ec40526f85cb`. It is separate from Story 13.4 zoom implementation and both older research worktrees remain preserved.

The fresh unchanged baseline failed with 8 Reader issues across 634 tests. Some loader request counts were still zero when two-second fixture deadlines expired. Main-actor contention is the leading explanation; the cache fixture is a contributor hypothesis, not a proven sole trigger.

Single-entry cache lookup now uses the existing dictionary in in-memory repository mode instead of sorting and scanning all entries. Real SwiftData predicate lookup and sorted collection retrieval are unchanged. The 1,000-entry cache test took 1.290 seconds before the optimization and 0.042 seconds afterward in focused runs; those observations are diagnostic context, not a timing contract. The cache-only full package diagnostic passed 635 tests before the harness repair.

Reader test prerequisites retain the original expectations and use ten-millisecond polling with a ten-second cooperative watchdog. A timeout throws a contextual error rather than continuing into dependent assertions. Owned pipeline and task cleanup cancels, releases pending continuations and awaits completion on both success and failure. Terminal fixtures reject late work; decoder gate release is sticky. Fresh owned cleanup tasks avoid cancelled drain sleeps becoming immediate polling. No suites were newly serialized and no tests were skipped.

## Commands and receipts

All package commands ran in `/Users/geromeyabut/.codex/worktrees/reader-baseline-hardening/Toonedge` using:

```sh
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-reader-baseline-hardening' --jobs 1
```

Focused commands appended the filters below. `--jobs 1` controls compilation parallelism; the final full runs retained default test scheduling. Shell `pipefail` preserved command status through log capture. The three acceptance runs were declared before execution and stopped on any failure; no retries were needed.

| Gate | Result | Log |
| --- | --- | --- |
| Fresh unchanged full package | Exit 1; 634 tests, 8 issues; 6.871 s | `unchanged-baseline.log` |
| Cache characterization before optimization, `--filter 'keyedCacheLookup\|largeCacheSummary'` | Exit 0; 2 passed; 1.295 s | `cache-characterization-before-v3.log` |
| Cache focused after optimization, `--filter 'CacheMetadataTests\|keyedCacheLookup'` | Exit 0; 15 passed; 0.051 s | `cache-focused-green.log` |
| Cache-only full diagnostic | Exit 0; 635 passed; 4.786 s | `cache-only-full.log` |
| Readiness behavioral RED, `--filter pipelineStateWaitAllowsScheduledWorkBeyondOldFixtureDeadline` | Exit 1; 1 test, 2 original waiter/ready issues; 2.343 s | `readiness-red.log` |
| Waiter API RED, `--filter readerTestWait` | Exit 1; missing helper/error definitions, cascading diagnostics | `waiter-api-red.log` |
| Waiter GREEN, `--filter 'readerTestWait\|pipelineStateWaitAllowsScheduledWorkBeyondOldFixtureDeadline'` | Exit 0; 4 passed; 2.203 s | `waiter-focused-green.log` |
| Cleanup behavioral RED, `--filter readerPipelineCleanupPreservesFailureAndDrainsPendingWork` | Exit 1; 1 test, pending-work drain issue; 2.025 s | `cleanup-red.log` |
| Harness focused GREEN, `--filter 'ReaderPagePipelineTests\|ReaderTestConditionWaitTests'` | Exit 0; 31 passed; 2.221 s | `harness-focused-green-v2.log` |
| Final full run 1 | Exit 0; 645 passed; 4.121 s | `final-full-1.log` |
| Final full run 2 | Exit 0; 645 passed; 3.760 s | `final-full-2.log` |
| Final full run 3 | Exit 0; 645 passed; 3.735 s | `final-full-3.log` |
| Generic iOS Simulator compilation | Exit 0; `BUILD SUCCEEDED` | `simulator-build.log` |
| `git diff --check` | Exit 0 | Direct command receipt |

Cache semantics characterization correctly passed before optimization. A structural complexity guard failed before the lookup change and passed afterward; it was not a behavioral failure:

```sh
ruby -e 's=File.read(ARGV[0]); m=s.split("private func fetchCacheEntry(sourceURLString:",2).last.split("private func cacheRetentionState",2).first; abort "single cache lookup still scans sorted entries" unless m.include?("return cacheEntryStore[sourceURLString]") && !m.include?("fetchCacheEntries()"); puts "keyed cache lookup guard passed"' app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift
```

Two setup corrections occurred: the first cache patch had unsupported diff formatting, then the characterization test was nested accidentally before its placement was corrected. A later harness compile error required `@escaping` on cleanup closures captured by owned tasks. These are patch/compilation corrections, not behavioral RED evidence. The waiter API RED emitted a cascading no-async warning because definitions were missing. Final focused and full package runs had no warnings or errors.

Build command:

```sh
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/fix-reader-baseline-hardening' build CODE_SIGNING_ALLOWED=NO
```

The build ran after the final production-source change, at `dd3b8a0`; subsequent changes were package test harness only. Warning: `Metadata extraction skipped. No AppIntents.framework dependency found.` This is compilation evidence, not simulator UI, VoiceOver or iPad interaction validation. No device was booted or targeted.

## Storage and source preservation

Build storage was verified mounted, writable and UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29`, with 1.4 TiB available and successful direct directory creation. Logs are in `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-06/fix-reader-baseline-hardening`. Scratch and DerivedData directories are branch-isolated. Credential-pattern inspection found no matches in retained logs. Fixtures are synthetic; no page artwork or screenshots were collected.

The production diff is one in-memory lookup return in `SwiftDataLibraryRepository.swift`. The production Reader pipeline diff against the original base is empty. Existing pipeline assertions and explicit cancellation/release sequences were preserved; cleanup wrappers add teardown after those sequences. The three protected local screenshots, shared simulator and unrelated worktrees were untouched.

## Review and delivery

Cache task commit: `dd3b8a0`. Harness task commit: `5d4bcec`. Independent task reviews approved both spec compliance and code quality with no findings. Root directly verified their historical RED and command-status qualifications; whole-branch gates are recorded above. The existing AppIntents build warning is a non-blocking follow-up outside this repair.

The branch remains local. No push, PR, merge, remote branch deletion or renewed native zoom experiment occurred. Three passing full runs support baseline stability but cannot prove absence of every scheduling-related failure. Zoom remains paused pending the separate next step.
