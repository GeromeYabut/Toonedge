# Reader baseline hardening implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Remove unnecessary in-memory cache lookup sorting and make Reader test prerequisites and teardown reliable without changing Reader behavior.

**Architecture:** Preserve production Reader scheduling and real SwiftData persistence. Use keyed lookup in the existing in-memory repository. Add a shared test-only waiter and cleanup boundaries around owned suspended work.

**Tech Stack:** Swift 6, Swift Testing, SwiftData, ContinuousClock, SwiftPM and Xcode.

## Global Constraints

- Preserve every original concurrency, retry, cancellation, readiness, decoding, and progress assertion.
- Do not change production `ReaderPagePipeline`, disable tests, serialize suites, or relax behavioral expectations.
- Keep ten-millisecond polling and a ten-second cooperative safety watchdog. This is not a product latency requirement.
- Keep public repository protocols, cache retention semantics, URL identity, and schemas unchanged.
- Preserve sorted collection retrieval for list consumers and summaries. The existing 1,000-entry aggregation test remains intact.
- Work only in `/Users/geromeyabut/.codex/worktrees/reader-baseline-hardening/Toonedge`, branch `fix/reader-baseline-hardening`, base `1eaebe7acba7f984a493488cf799ec40526f85cb`.
- Root applies repository patches, runs verification, and makes local commits. Implementers prepare separate immutable RED and GREEN patches in `/private/tmp` and report receipts after root runs them. No concurrent implementers.
- No push, PR, merge, remote deletion, or native zoom experiment. Preserve earlier worktrees, protected screenshots, and shared simulator.

## Commands and handoffs

Run package commands from the worktree using:

```sh
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-reader-baseline-hardening' --jobs 1
```

Root verifies the required external volume UUID, free space and direct directory creation before writing. If unavailable, root substitutes one unique temporary scratch/results directory and reports the change. Logs use `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-06/fix-reader-baseline-hardening`; `pipefail` preserves test status.

Tasks produce separate local commits and independent spec/quality reviews. Root records the commit before each task, generates a review package over its exact range, and updates the durable ledger after a clean review.

### Task 1: Keyed cache lookup

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift` (only the in-memory return in `fetchCacheEntry`).
- Modify: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift` (lookup behavior regression).

**Interfaces:** Existing `recordCacheMetadata`, `removeCacheMetadata`, `cacheMetadataEntries` and `downloadSummary`; no new production API.

- [x] Add this characterization test before the optimization:

```swift
@MainActor
@Test func keyedCacheLookupPreservesUpdatesDistinctURLsAndRemoval() async throws {
    let repository = try makeRepository()
    let first = try #require(URL(string: "https://example.com/keyed/chapter-a"))
    let second = try #require(URL(string: "https://example.com/keyed/chapter-b"))
    let missing = try #require(URL(string: "https://example.com/keyed/missing"))
    #expect(try await repository.removeCacheMetadata(for: missing) == .notFound)
    #expect(try await repository.recordCacheMetadata(.fixture(sourceURL: first, estimatedStorageBytes: 100, retentionState: .recent)) == .recent)
    #expect(try await repository.recordCacheMetadata(.fixture(sourceURL: second, estimatedStorageBytes: 200, retentionState: .retained)) == .retained)
    #expect(try await repository.recordCacheMetadata(.fixture(sourceURL: first, estimatedStorageBytes: 300, retentionState: .retained)) == .retained)
    #expect(try await repository.recordCacheMetadata(.fixture(sourceURL: first, estimatedStorageBytes: 300, retentionState: .retained)) == .unchanged)
    let entries = await repository.cacheMetadataEntries()
    #expect(entries.count == 2)
    #expect(entries.first { $0.sourceURL == first }?.estimatedStorageBytes == 300)
    #expect(entries.first { $0.sourceURL == second }?.estimatedStorageBytes == 200)
    let summary = await repository.downloadSummary()
    #expect(summary.cachedItemCount == 2)
    #expect(summary.retainedItemCount == 2)
    #expect(summary.totalEstimatedBytes == 500)
    #expect(try await repository.removeCacheMetadata(for: first) == .removed)
    #expect(try await repository.removeCacheMetadata(for: first) == .notFound)
    #expect(await repository.cacheMetadataEntries().map(\.sourceURL) == [second])
}
```

- [x] Run `--filter 'keyedCacheLookup|largeCacheSummary'` before the optimization. These characterize unchanged semantics, so a pass is expected; do not claim a behavioral RED. Run this structural complexity guard, expected exit 1 before the fix:

```sh
ruby -e 's=File.read(ARGV[0]); m=s.split("private func fetchCacheEntry(sourceURLString:",2).last.split("private func cacheRetentionState",2).first; abort "single cache lookup still scans sorted entries" unless m.include?("return cacheEntryStore[sourceURLString]") && !m.include?("fetchCacheEntries()"); puts "keyed cache lookup guard passed"' app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift
```

- [x] Change only the in-memory return:

```swift
return cacheEntryStore[sourceURLString]
```

- [x] Re-run the structural guard, expected exit 0, and `--filter 'CacheMetadataTests|keyedCacheLookup'`, expected all pass. Record the existing 1,000-entry test duration as diagnostic context, not a latency assertion. Root commits the two files with `fix: use keyed in-memory cache lookups`, then obtains task review.

### Task 2: Bounded prerequisites and owned fixture cleanup

**Files:**
- Create: `app/Tests/ToonEdgeAppCoreTests/ReaderTestConditionWait.swift`.
- Create: `app/Tests/ToonEdgeAppCoreTests/ReaderTestConditionWaitTests.swift`.
- Modify: `app/Tests/ToonEdgeAppCoreTests/ReaderPagePipelineTests.swift` (six waits, cleanup helpers, owned-task boundaries and regressions).

**Interfaces:** `waitForReaderTestCondition(_:timeout:isolation:condition:) async throws`; test-only `ReaderTestWaitError.timedOut(String)`. Private test fixtures gain terminal teardown that rejects late work. No production hooks.

- [x] Add the scheduled readiness regression to the existing test file only:

```swift
@Test @MainActor func pipelineStateWaitAllowsScheduledWorkBeyondOldFixtureDeadline() async throws {
    var ready = false
    let release = Task { @MainActor in
        try await Task.sleep(for: .milliseconds(2_200))
        ready = true
    }
    do { try await waitForPipelineState { ready } }
    catch {
        release.cancel()
        _ = await release.result
        throw error
    }
    #expect(ready)
    try await release.value
}
```

- [x] Run `--filter pipelineStateWaitAllowsScheduledWorkBeyondOldFixtureDeadline`; expected exit 1 with the original state/ready assertions failing before the scheduled release. Keep this evidence distinct from missing-symbol compilation errors.

- [x] Add waiter tests before the helper: immediate success at zero timeout, timeout with contextual error and dependent action not executed, cancellation throwing `CancellationError`. For example:

```swift
@Test func readerTestWaitTimeoutStopsDependentActions() async throws {
    var dependentActionRan = false
    do {
        try await waitForReaderTestCondition("fixture request", timeout: .milliseconds(30)) { false }
        dependentActionRan = true
        Issue.record("Expected timeout")
    } catch let error as ReaderTestWaitError {
        #expect(error == .timedOut("fixture request"))
    }
    #expect(!dependentActionRan)
}
```

- [x] Implement the helper after RED, preserving caller isolation:

```swift
import Foundation
enum ReaderTestWaitError: Error, Equatable, Sendable { case timedOut(String) }
func waitForReaderTestCondition(
    _ description: String,
    timeout: Duration = .seconds(10),
    isolation: isolated (any Actor)? = #isolation,
    condition: () async -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while true {
        try Task.checkCancellation()
        if await condition() { return }
        guard ContinuousClock.now < deadline else { throw ReaderTestWaitError.timedOut(description) }
        try await Task.sleep(for: .milliseconds(10))
    }
}
```

Replace each existing loop with `try await waitForReaderTestCondition(description) { predicate }`, retaining its final original `#expect`. The six predicates are `requests.count >= count`, `requestedURLs.count >= count`, `requestCount >= count`, `cancellationCount >= count`, `concurrentRequests == 0`, and the main-actor `condition()` respectively. Use descriptions identifying HTTP requests, retry requests, asset requests, asset cancellations, active requests and pipeline state.

- [x] Before implementing cleanup, add a real-pipeline regression that injects `ReaderTestWaitError.timedOut` after a suspended request begins. The test must verify the same error reaches the caller and all owned work drains. Also exercise terminal cleanup before a queued load starts, repeated cleanup, and cleanup while the retry HTTP continuation is suspended. Observe RED before adding terminal fixture behavior. Missing-helper compilation is API RED; the behavioral RED must use an executable regression with pending work still active or late work incorrectly admitted.

- [x] Add a private cleanup boundary to the pipeline test file:

The failure-path regression must preserve this contract:

```swift
@Test @MainActor func readerPipelineCleanupPreservesFailureAndDrainsPendingWork() async throws {
    let loader = SuspendedReaderAssetLoader()
    let pipeline = ReaderPagePipeline(session: .pipelineFixture(pageCount: 1), assetLoader: loader)
    let injected = ReaderTestWaitError.timedOut("injected prerequisite")
    do {
        try await withReaderPipelineCleanup(pipeline: pipeline, cleanup: { await loader.finish() }) {
            pipeline.updateVisibleIndex(0)
            try await loader.waitForRequestCount(1)
            throw injected
        }
        Issue.record("Expected the prerequisite failure")
    } catch let error as ReaderTestWaitError {
        #expect(error == injected)
    }
    #expect(await pipeline.waitForWorkToDrain())
    await loader.finish()
    try await loader.waitForNoActiveRequests()
}
```

For executable cleanup RED, temporarily use the old failure behavior in the test boundary: `try await body()` without teardown. After the drain expectation fails, manually cancel and release pending work in the RED test so the run exits without leaking continuations. In GREEN remove this emergency-only RED teardown once the boundary owns cleanup. Keep the error and drain assertions identical. This is test scaffolding, not production implementation or a replacement for behavioral RED.

```swift
@MainActor private func withReaderPipelineCleanup(
    pipeline: ReaderPagePipeline,
    cleanup: () async -> Void,
    body: () async throws -> Void
) async throws {
    let result: Result<Void, Error>
    do { try await body(); result = .success(()) }
    catch { result = .failure(error) }
    pipeline.cancel()
    await cleanup()
    #expect(await pipeline.waitForWorkToDrain())
    try result.get()
}
```

Wrap the work after construction in each suspended-loader pipeline test and the retry-gate pipeline test using this boundary. Keep original body actions/assertions in order, including explicit release of intentionally cancelled fetches. For suspended loaders the cleanup closure is `await loader.finish()`. For retry gates it is `await http.finish()`. Ensure cleanup waits remain bounded under task cancellation; if cancellation would cause immediate busy polling in the existing production drain helper, run the test-only cleanup in a fresh owned task and await it.

- [x] Add terminal fixture state. In `SuspendedReaderAssetLoader`, `finish()` sets `isFinished = true`, removes all pending continuations, and resumes them throwing `CancellationError`. `load` rejects `isFinished` before incrementing counters or suspending. Removing continuations before resuming makes repeated cleanup safe. In `RetryGateReaderHTTPClient`, `finish()` sets its terminal state and releases the pending second attempt; future requests reject terminal state, and resumed work checks cancellation/terminal state before returning. Keep ordinary `complete`, `completeAll`, `fail`, and `releaseSecondAttempt` semantics unchanged for the existing test bodies.

- [x] Apply the same ownership discipline to the two tests owning standalone load/decode tasks. On failure, cancel and await the owned task; release a decoder return gate before awaiting a task that may be suspended there. A decoder gate release must be sticky if cleanup occurs before its wait is registered, preventing late suspension. Use a shared test-only cleanup boundary rather than duplicate error-handling blocks. Add a regression that forces the early-release path. Await the scheduled readiness release task on both paths.

- [x] Run `--filter 'ReaderPagePipelineTests|ReaderTestConditionWaitTests'`, expected all pass. Inspect original assertions and production Reader source diff for preservation. Root commits test-only changes with `fix: bound reader test prerequisites and clean up owned work`, then obtains task review.

## Whole branch gates

- [x] Run three predeclared consecutive default-parallel full package runs using the common command. Any failing run stops acceptance and returns to diagnosis. Do not skip DOM/cache tests or keep retrying for a green run.
- [x] Run the generic simulator build:

```sh
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/fix-reader-baseline-hardening' build CODE_SIGNING_ALLOWED=NO
git diff --check
```

Expected: exit 0 and `BUILD SUCCEEDED`; report warnings exactly. Compilation does not certify simulator UI behavior. If scope changes, reassess device/UI gates before claiming completion.

- [x] Root saves sanitized receipts to `docs/qa_evidence/2026-10-06-reader-baseline-hardening.md`, records no schema/API/UI changes, and checks logs for credentials or sensitive URLs before retention.
- [x] Dispatch an independent whole-branch reviewer over the original base to final HEAD, with this plan, approved spec, task receipts and minor findings. Resolve all blocking findings, re-run covering tests after fixes and the full declared gates if verification no longer covers final source. Keep the branch local pending explicit delivery authority.
