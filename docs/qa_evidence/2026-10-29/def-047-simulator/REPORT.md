# DEF-047 owned simulator flow — 2026-10-29

**Verdict:** PASS. Home → Continue Reading rebuilds a Reader with both chapter controls enabled, and Next and Previous each complete a real adjacent transition, for both affected storage states. The same flow fails on the pre-fix repository code.

## Identity

- Branch `chore/def-047-simulator-flow`, base `origin/main` `6941766` (PR #22 merge, fix `1cd9939`).
- Simulator: iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`, iOS 18.6 (22G86). The shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` was not used.
- Xcode 27.0 (27A266a), macOS 27.0.1.
- Output: `/private/tmp/toonedge-chore-def-047-sim-20261029-01`. The external drive `7C6E7CE1-D8D5-3041-AA58-DC000A724A29` was mounted, but directory creation returned "Operation not permitted", so the documented fallback was used.

## Fixture

`-resumeAdjacencyFixture <recent-only|saved-empty-images>` in `ToonEdgeAppEntry.swift` (UI-test launch path only):

- Uses `AppDependencies.persistent(modelStoreURL:)`, so `SwiftDataLibraryRepository` is the production repository on a file store in the app's caches.
- A `-resetTestData` launch only seeds the store:
  - authored chapter 199 at `owned.toonedge.test/comics/resume-adjacency/chapter/199`;
  - `recent-only` records a recent reading without saving the chapter;
  - `saved-empty-images` additionally saves the chapter, with chapter 198/200 links and an empty image list.
- The test then relaunches without reset, and Home resumes from the persisted store.
- Images are a generated 1×1 PNG in the asset cache. There is no network and no page artwork.
- The chapter-index refresh, series metadata and update services are disabled because the reserved hosts never resolve.
- The adjacent loader is the existing `UITestAdjacentSuccessLoader`. It returns "Chapter N" for the URL it is asked to load, so the displayed chapter confirms the requested target.

## Tests

`ToonEdgeResumeAdjacencyUITests` in `ToonEdgeOfflineUITests.swift`. Each test:

1. seeds and relaunches;
2. waits for Continue Reading and taps the fixture card;
3. asserts the Reader shows "Resume Adjacency Fixture, Chapter 199" with `reader.previousChapter` and `reader.nextChapter` enabled;
4. taps one control and asserts chapter 200 (Next) or 198 (Previous);
5. taps Back and asserts the Reader closes onto Home's Continue Reading.

The four cases are recent-only × Next/Previous and saved-empty-images × Next/Previous.

## Runs

| Run | Repository source | Result | Bundle | Bundle content hash (sha256, 16) | Log sha256 (16) |
|---|---|---|---|---|---|
| Red | `SwiftDataLibraryRepository.swift` from `2651a61`, worktree only, never committed | 4 of 4 failed at "Resumed Reader must offer Previous" (line 554); seed, relaunch, Home card and chapter 199 Reader all succeeded first | `red-01.xcresult` (74 MB) | `2a02da7677480b5e` | `ae56052d93965c86` |
| Green | `HEAD` (`6941766`) | 4 of 4 passed in 81.6 s | `green-01.xcresult` (524 KB) | `0881d5166a6702d8` | `8ae410bf243b3084` |

There were no reruns. The red bundle's size comes from XCTest's automatic failure captures of the synthetic fixture screens. Bundles stay in the fallback output directory and are not retained in the repository.

## Gates

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' -derivedDataPath <out>/dd-<red|green> build-for-testing
xcodebuild test-without-building -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' -derivedDataPath <out>/dd-<red|green> -only-testing:ToonEdgeUITests/ToonEdgeResumeAdjacencyUITests -resultBundlePath <out>/<red|green>-01.xcresult
swift test --package-path app --scratch-path <out>/spm --jobs 1
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath <out>/dd-generic build CODE_SIGNING_ALLOWED=NO
git diff --check
```

- Both test builds succeeded.
- Package suite: 810 tests in 25 suites passed.
- Generic simulator build succeeded.
- `git diff --check` is clean.

## Not covered

- Physical iPhone.
- Adjacent chapters loaded from real sites; the loader is a stand-in.
- Stores written by earlier app versions.
- The rest of the UI test suite was not rerun.
