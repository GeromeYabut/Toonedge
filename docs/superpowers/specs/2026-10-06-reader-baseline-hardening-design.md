# Reader baseline hardening design

Harden the package test baseline before resuming Story 13.4. The repair removes unnecessary in-memory cache lookup work and makes Reader test prerequisites fail safely under executor contention. Zoom implementation remains paused.

## Scope and evidence

Unchanged Reader tests passed in isolation and the full suite passed when serialized, while default parallel runs intermittently failed at two-second fixture deadlines with no requests yet observed. Main-actor scheduling contention is the leading explanation; the cache fixture is a plausible contributor, not a proven sole cause.

The 1,000-entry cache fixture uses the repository's in-memory mode. Each single-entry lookup currently sorts all cache entries before searching them. This is unnecessary work on the main actor, not evidence of slow disk persistence.

A separate unmerged branch, `fix/reader-pipeline-test-baseline`, already contains a reviewed test-only waiter correction at commit `6bce6aa87789b8d63ff91661e373e2fef83dd06f`. Its plan and QA receipt remain in that worktree, not this branch. That correction passed its older baseline; those results do not certify current main.

## Chosen approach

Use the existing dictionary for individual in-memory cache lookups, and adapt the previously reviewed test waiter to current main. Address its documented suspended-fixture cleanup follow-up as part of the same harness repair.

Global serialization would reduce contention but change how the entire suite runs. A production Reader scheduling redesign would be substantially broader without evidence of a production defect. Neither is part of this repair.

## Cache repository boundary

In `SwiftDataLibraryRepository.fetchCacheEntry`, preserve the SwiftData predicate and fetch limit for real persistence. For in-memory mode, return `cacheEntryStore[sourceURLString]` directly. Preserve sorted collection retrieval for list consumers and summaries.

Keep public repository protocols, cache retention semantics, URL identity, and schemas unchanged. Cover insertion, repeated updates of the same URL, distinct URLs, missing entries, removal, and summary correctness. The existing 1,000-entry aggregation test remains intact. Confirm constant-time lookup structurally; do not introduce a flaky elapsed-time assertion or production telemetry solely to measure the test fixture.

## Reader fixture synchronization

Replace the six fixture polling loops with the existing test-only condition waiter, preserving caller actor isolation. Keep ten-millisecond polling and a ten-second cooperative safety watchdog. This is not a product latency requirement. Preserve every original concurrency, retry, cancellation, readiness, decoding, and progress assertion.

A satisfied condition returns immediately. An unsatisfied condition at the watchdog throws a contextual error, stopping dependent fixture actions. Cancellation propagates. The watchdog cannot preempt a blocked executor or a condition that never returns; it is not a hard wall-clock guarantee.

Add failure-path teardown to tests that own suspended loaders or retry gates. On success, timeout, cancellation, or unexpected error, cancel the pipeline or owned task and release pending fixture continuations exactly once. Wait for owned work to drain with a bounded test-only wait where needed; never resume an already-resumed continuation. Preserve the special tests that intentionally hold cancelled fetches until explicitly released.

Do not change production `ReaderPagePipeline`, disable tests, serialize suites, or relax behavioral expectations. The sole timing adjustment is the test safety watchdog already reviewed on the earlier branch.

## Delivery and verification

Work on `fix/reader-baseline-hardening` in the isolated managed worktree based on freshly fetched `origin/main` at `1eaebe7acba7f984a493488cf799ec40526f85cb`. Preserve both earlier baseline and zoom worktrees.

After written design approval:

1. Record a fresh unchanged baseline on this branch. Prior diagnostic failures authorize investigating this baseline, not ignoring new failure patterns.
2. Add and observe failing harness regressions before implementation: scheduled readiness beyond the old deadline, timeout stopping dependent actions, cancellation propagation, and failure-path continuation cleanup. Verify repository lookup semantics before and after its structural optimization.
3. Implement and verify the cache optimization independently of the waiter change so their effects remain distinguishable. Keep the changes independently reviewable.
4. Run focused Reader and cache tests, then three predeclared consecutive default-parallel full package runs with `--jobs 1`. Do not retry until green or omit the large-cache or DOM tests. Any failure returns the work to diagnosis.
5. Run a generic iOS Simulator compilation gate, `git diff --check`, and independent task and whole-branch review. This does not claim device UI validation; assess additional gates if the implementation expands beyond this scope.

Use branch-isolated build outputs on the verified external volume or a unique temporary fallback. Keep synthetic fixtures and sanitized logs only. Do not access the protected screenshots or shared simulator.

## Completion criteria and remaining risk

Completion requires preserved assertions, bounded failure handling with fixture cleanup, correct cache behavior, all declared verification gates passing, and no unresolved blocking review findings. Three successful full runs support baseline stability but cannot prove the absence of every scheduling-related failure.

No push, PR, merge, remote branch deletion, or renewed native zoom experiment is authorized by this design. Once this repair is verified, resuming the approved sticky-baseline zoom policy is a separate next step.
