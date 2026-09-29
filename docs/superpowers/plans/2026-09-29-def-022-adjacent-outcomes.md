# DEF-022 Typed Adjacent Outcomes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for production changes, superpowers:systematic-debugging for unexpected failures, and superpowers:verification-before-completion before committing. Execute this plan after DEF-021 is integrated.

**Goal:** Exercise every typed adjacent-load failure and normal success through Reader UI, proving actionable recovery, known-target preservation, and conservative retry behavior.

**Architecture:** Preserve `AdjacentReaderSessionLoadError`, `AdjacentReaderSessionLoader`, `ReaderViewModel.adjacentLoadState`, and `ReaderAdjacentFeedbackPresentation` as the single typed path. A deterministic loader varies only its fixture outcome; Reader remains responsible for state and explicit Retry/Open Original actions.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, XCUITest, OSLog.

## Acceptance matrix

| Fixture | Expected copy | Actions |
|---|---|---|
| timeout | Chapter timed out. | Retry, Open Original |
| challenge/rate limit | Reader access is temporarily limited. | Retry, Open Original |
| unavailable | Chapter unavailable in Reader. | Retry, Open Original |
| low confidence | Chapter could not be verified. | Retry, Open Original |
| non-viable images | No usable chapter images found. | Retry, Open Original |
| success | Chapter 2 installed | normal Reader controls |

All failures retain Chapter 1, do not retry automatically, and preserve the sanitized Chapter 2 URL.

---

### Task 1: Lock the typed domain behavior with focused tests

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Conditional modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift`
- Conditional modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`

- [ ] **Step 1: Run the existing loader and presentation suites**

```bash
swift test --package-path app --jobs 1 --filter AdjacentReaderSessionLoaderTests
swift test --package-path app --jobs 1 --filter adjacentFeedback
```

Expected: typed timeout, challenge/rate-limit, unavailable, low-confidence, non-viable-image, diagnostic, and copy regressions pass.

- [ ] **Step 2: Add a request-count regression for no automatic retry**

Use a recording loader that always throws a typed failure with a known target. Call `navigateAdjacentChapter` once, allow the async task to settle, and assert exactly one load occurred. Then call `retryAdjacentChapter`, advance through the configured delay, and assert the second load occurs only because of that explicit call.

- [ ] **Step 3: Run the test and record RED**

```bash
swift test --package-path app --jobs 1 --filter adjacentFailureWaitsForExplicitRetry
```

Expected before any required fix: one request before Retry. If it fails, capture the observed count and state transition.

- [ ] **Step 4: If RED, make the smallest Reader-state fix**

Do not add polling or hidden retry loops. Preserve the known adjacent URL and the existing retry backoff. Do not weaken cancellation/race guards.

- [ ] **Step 5: Re-run the focused tests**

Expected: all typed cases, single-request behavior, explicit retry, and normal adjacent success pass.

### Task 2: Expand the namespaced UI fixture matrix

**Files:**
- Modify: `app/ToonEdge/ToonEdgeAppEntry.swift`

**Interfaces:**
- Extends: `ReaderHardeningFixtureScenario`
- Supplies: `AdjacentReaderSessionLoading`
- Uses only: `fixture.example` and `images.example.test`

- [ ] **Step 1: Replace the challenge-only loader with one scenario loader**

Create an actor whose first call produces the enum-selected result:

```swift
private actor UITestAdjacentOutcomeLoader: AdjacentReaderSessionLoading {
    let scenario: ReaderHardeningFixtureScenario
    private var attempts = 0

    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        attempts += 1
        // Return Chapter 2 for adjacent-success.
        // Throw the exact typed error for every failure scenario.
    }
}
```

For challenge, include sanitized confidence/parser/challenge diagnostics. Every thrown error must include the safe Chapter 2 target. A Retry may succeed on a second attempt only in the challenge recovery test; all other cases stay deterministic.

- [ ] **Step 2: Route every adjacent scenario to the same Chapter 1 fixture**

Use the foundation enum cases `adjacent-timeout`, `adjacent-challenge`, `adjacent-unavailable`, `adjacent-low-confidence`, `adjacent-nonviable`, and `adjacent-success`. Set launch origin to `.homeContinueReading` so Back can be asserted, and keep Next pointed to `https://fixture.example/series/chapter-2`.

- [ ] **Step 3: Preserve the legacy flag only as a temporary alias**

Existing `-seedAdjacentFailureReader` continues to map to `.adjacentChallenge`; all new tests use `-readerHardeningFixture`.

- [ ] **Step 4: Parse the source**

```bash
xcrun swiftc -parse app/ToonEdge/ToonEdgeAppEntry.swift
```

Expected: exit 0.

### Task 3: Add the UI outcome matrix and origin-routing tests

**Files:**
- Modify: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`

- [ ] **Step 1: Convert the current challenge tests to the typed launcher**

Keep the existing explicit Retry recovery and Open Original assertions, but launch `adjacent-challenge` through the namespaced fixture.

- [ ] **Step 2: Add one shared failure assertion helper**

For each fixture in the acceptance matrix:

1. reveal Reader chrome;
2. tap Next once;
3. assert the exact message;
4. assert Chapter 1 remains visible;
5. assert Retry and Open Original exist;
6. wait at least two seconds without action and assert the same failure remains;
7. assert no chapter transition occurred.

The wait is UI evidence of no automatic loop; the package request-count regression is authoritative.

- [ ] **Step 3: Prove known-target Open Original for every typed family**

At minimum, table-drive timeout, challenge, unavailable, low-confidence, and non-viable scenarios. Tap `reader.adjacent.openOriginal` and assert `browser.root` appears. Never inspect or expose a full live URL.

- [ ] **Step 4: Prove normal success and post-navigation routing**

Launch `adjacent-success`, navigate to Chapter 2, and assert:

- Reader label is Chapter 2;
- View Original opens Browser for the current chapter;
- in a separate fresh launch, Back returns to Home according to `.homeContinueReading` origin;
- no stale failure feedback remains.

- [ ] **Step 5: Run the focused suite on iPhone 16e**

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-def022-derived \
  test -only-testing:ToonEdgeUITests/ToonEdgeAdjacentFailureUITests \
  -resultBundlePath /private/tmp/toonedge-def022.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all typed failure rows, explicit recovery, success, Back, and View Original pass.

### Task 4: Verify sanitized diagnostics and commit

**Files:**
- Modify only after acceptance passes: `docs/defects.md`
- Create: `docs/qa_evidence/2026-09-29-def-022-adjacent-outcomes.md`

- [ ] Run package diagnostics regressions and confirm logged fields are direction, elapsed milliseconds, reason, target host, confidence, parser path, and challenge signals—never full sensitive URLs, cookies, or session data.
- [ ] Run:

```bash
swift test --package-path app --jobs 1
git diff --check
```

- [ ] Record exact commands, counts, `/private/tmp/toonedge-def022.xcresult`, fixture-only status, safe screenshots, retry delay, and limitations.
- [ ] Update DEF-022 only when all acceptance rows pass.
- [ ] Stage exact owned files and commit:

```bash
git add \
  app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift \
  app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift \
  app/ToonEdge/ToonEdgeAppEntry.swift \
  app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift \
  docs/defects.md \
  docs/qa_evidence/2026-09-29-def-022-adjacent-outcomes.md
git commit -m "test: verify typed adjacent outcomes"
```

If a production fix was required, add its exact path and use `fix: preserve typed adjacent failures`. Confirm the protected screenshots remain untracked and byte-identical.
