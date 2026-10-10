# Xcode 27 cache sendability compatibility

## Scope

This change replaces the cache's `FileManager & Sendable` dependency with an internal `CacheFileOperating` protocol and an owned, lock-serialized `CacheFileOperations` wrapper. The cache's public interfaces, synchronous behavior, atomic writes, deterministic paths, error propagation, and shared lifecycle lock remain unchanged. The wrapper lock serializes each owned `FileManager` call; it does not add coordination between independently initialized cache instances.

This is a toolchain compatibility prerequisite for the separate persistence investigation. It is not evidence that a persistence writer is safe, and makes no claim about SwiftData persistence safety.

## Source identity and environment

Controller-verified green source hashes:

- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift`: `607a4c81a70dab69720d76892894e85c089dad13`
- `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`: `b2c8ef6b4cfeb7289d13785ee8be1dbbe6141db0`

These hashes were unchanged across the focused, full-package, and Simulator build gates. Environment: Xcode 27.0 (27A266a), Swift 6.4. The external build volume was mounted and writable: UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29`, with 1.4 TiB available (1,521,067,520,000 bytes free). Direct directory-creation probe succeeded at `/Volumes/Seagate 2TB/ToonEdgeBuilds/cache-xcode27-execution-probe.De3poN`. No fallback was used. No protected screenshots or shared simulator were touched.

## TDD and verification evidence

The test-only RED patch added four real-filesystem tests for nested directory creation, file removal, and error propagation with lock release. Its first apply attempt exited 1 because the generated patch omitted the final `*** End Patch` terminator; no tests ran and no worktree files changed. The corrected test patch applied, `git diff --check` passed, and the focused RED command then exited 1 during compilation before any test case executed:

```sh
set -o pipefail
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-xcode27-cache-sendability' --jobs 1 --filter cacheFileOperations 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/wrapper-red.log' | rg 'recorded an issue|Test run with|warning:|error:|Build complete|fatalError'
```

The complete raw output is retained at `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/wrapper-red.log`. Diagnostics matched the compatibility blocker: unavailable `FileManager` Sendable conformance at cache source line 12:66 and an unavailable conformance warning for the old `CacheFileManager` subclass at line 91:63, followed by build failure. This was a compile-time RED gate, not failing runtime assertions.

The first GREEN patch attempt exited 1 before test invocation because its test-double hunk omitted the complete old multiline `createDirectory` signature. The production wrapper had applied first; the test file remained RED-only plus the four new tests. A test-only correction then applied successfully, and production was not replayed.

Focused GREEN command:

```sh
set -o pipefail
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-xcode27-cache-sendability' --jobs 1 --filter 'cacheFileOperations|chapterRemovalWaitsForInFlightStoreAcrossCacheCopies|cachedAssetLookupWaitsForInFlightStoreAcrossCacheCopies' 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/wrapper-green.log' | rg 'recorded an issue|Test run with|warning:|error:|Build complete|fatalError'
```

Result: exit 0; six tests passed in 0.259 seconds after a 76.53 second build. The filtered console contained no warnings, errors, or recorded issues. `tee` retained the complete raw output at `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/wrapper-green.log`.

Full package command:

```sh
set -o pipefail
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-xcode27-cache-sendability' --jobs 1 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/package-green.log' | rg 'recorded an issue|Test run with|warning:|error:|Build complete|fatalError'
```

Result: exit 0; 728 tests across 15 suites passed in 4.345 seconds after a 1.22 second build. The filtered package console contained no warnings, errors, or recorded issues. Complete output is retained at `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/package-green.log`.

Generic iOS Simulator build command:

```sh
set -o pipefail
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/fix-xcode27-cache-sendability' build CODE_SIGNING_ALLOWED=NO 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/simulator-build.log' | rg 'warning:|error:|BUILD SUCCEEDED|BUILD FAILED|SwiftCompile'
```

Result: exit 0; `BUILD SUCCEEDED`, with arm64 and x86_64 compiled. The sole warning was `appintentsmetadataprocessor: Metadata extraction skipped, no AppIntents.framework dependency found`; there were no compiler errors or unavailable Sendable diagnostics. `git diff --check`, run separately after the build, was clean. This was a compile gate only; simulator UI tests were not run. Complete output is retained at `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/simulator-build.log`.

## Limits

No runtime persistence validation was run. No remote writes, push, pull request, or merge were performed. Simulator UI tests were not run.

## Review outcome

The initial task review found a missing fresh-run dependency condition in this QA record. Documentation-only commit `d8ed5c44be139b1040dec9608f588dcf53e8a133` added that condition. Task re-review approved spec compliance and code quality; a separate whole-branch final review approved technical readiness at that commit with no Critical or Important findings. The sole remaining Minor finding is the recorded App Intents extraction warning; targeted inspection found no implemented App Intents feature or dependency affected by it.

Both reviews covered the unchanged production and test hashes listed above. This final handoff updates documentation only and does not repeat the test suite or authorize remote delivery. Retained review reports are `/private/tmp/toonedge-cache27-task1-rereview.md` and `/private/tmp/toonedge-cache27-final-review.md`.

## Fresh persistence validation dependency

Only after the compatibility gates and independent task and broad final reviews pass may a separate, fresh bounded persistence validation be prepared. That run must retain the approved diagnostic predicates, seven-row seed controls, privacy checks, runtime budget, and stop conditions. Keep the stopped persistence worktrees and their evidence unchanged; do not resume or modify a stopped investigation in place.

The fresh investigation must record the exact compatibility commit it consumes (the implementation commit at this record is `423e86d3054a6150b656fbb5b61c9bb31c608b3e`). If that commit has not been integrated into `main`, resolve the dependency against the requirement for a current-main worktree before execution. Do not silently use an unapproved stacked branch. The compatibility gates do not establish SwiftData identity-comparison safety or authorize production adoption.
