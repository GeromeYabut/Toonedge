# Reader Hardening Fixture Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish one typed, namespaced launch-fixture contract before DEF-020, DEF-021, and DEF-022 add parallel UI journeys.

**Architecture:** `ToonEdgeAppEntry` parses one `-readerHardeningFixture <scenario>` argument and maps it through existing dependency/router seams. The existing adjacent-challenge fixture migrates first, with its legacy flag retained temporarily as an alias so current UI tests stay green.

**Tech Stack:** SwiftUI app entry, dependency injection, XCUITest.

## Global Constraints

- Start from approved design commit `9db0a2601bc5d8c5934dc51dd7b0cb58d6312c63`.
- Modify only app-entry fixture plumbing and its current adjacent-failure UI launcher.
- Do not add production parsing, persistence, detection, or Reader behavior.
- Fixtures use only `fixture.example` and `images.example.test` URLs.
- Do not target a simulator until focused source compilation passes.
- Preserve the protected screenshots untracked and unchanged.

---

### Task 1: Add the typed launch-scenario parser

**Files:**
- Modify: `app/ToonEdge/ToonEdgeAppEntry.swift`

**Interfaces:**
- Produces: `ReaderHardeningFixtureScenario.from(arguments:) -> ReaderHardeningFixtureScenario?`
- Consumes later: DEF-020, DEF-021, and DEF-022 fixture branches.

- [ ] **Step 1: Add the typed scenario contract near the app entry**

```swift
private enum ReaderHardeningFixtureScenario: String {
    case numericAdjacency = "numeric-adjacency"
    case numericAdjacencyUnsafe = "numeric-adjacency-unsafe"
    case continueTarget = "continue-target"
    case adjacentTimeout = "adjacent-timeout"
    case adjacentChallenge = "adjacent-challenge"
    case adjacentUnavailable = "adjacent-unavailable"
    case adjacentLowConfidence = "adjacent-low-confidence"
    case adjacentNonviable = "adjacent-nonviable"
    case adjacentSuccess = "adjacent-success"

    static func from(arguments: [String]) -> Self? {
        guard let marker = arguments.firstIndex(of: "-readerHardeningFixture"),
              arguments.indices.contains(marker + 1) else {
            return arguments.contains("-seedAdjacentFailureReader") ? .adjacentChallenge : nil
        }
        return Self(rawValue: arguments[marker + 1])
    }
}
```

- [ ] **Step 2: Parse it once in both app-entry seams**

At the top of `launchDependencies()` and `launchRouter()`, add:

```swift
let hardeningFixture = ReaderHardeningFixtureScenario.from(arguments: arguments)
```

Replace the existing adjacent-failure checks with:

```swift
if hardeningFixture == .adjacentChallenge {
    dependencies.adjacentReaderSessionLoader = UITestAdjacentFailureLoader()
}
```

and:

```swift
if arguments.contains("-uiTesting"), hardeningFixture == .adjacentChallenge {
    return AppRouter(presentedReader: adjacentFailureFixtureSession)
}
```

Other enum cases intentionally produce the normal mock launch until their owning defect slice supplies dependencies and a router state. This keeps one parser without inventing incomplete services.

- [ ] **Step 3: Parse the app source**

Run:

```bash
xcrun swiftc -parse app/ToonEdge/ToonEdgeAppEntry.swift
```

Expected: exit 0.

### Task 2: Move the current UI test to the namespaced contract

**Files:**
- Modify: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`

**Interfaces:**
- Consumes: `-readerHardeningFixture adjacent-challenge`.
- Preserves: `ToonEdgeAdjacentFailureUITests` observable behavior.

- [ ] **Step 1: Change only the launch arguments**

```swift
private func launchFixture() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
        "-uiTesting",
        "-readerHardeningFixture",
        "adjacent-challenge"
    ]
    app.launch()
    return app
}
```

- [ ] **Step 2: Run the migrated UI regression on the dedicated iPhone 16e**

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-hardening-foundation-derived \
  test -only-testing:ToonEdgeUITests/ToonEdgeAdjacentFailureUITests \
  -resultBundlePath /private/tmp/toonedge-hardening-foundation.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both existing adjacent-failure UI tests pass.

- [ ] **Step 3: Run package and diff gates**

```bash
swift test --package-path app --jobs 1
git diff --check
```

Expected: all package tests pass; no whitespace errors.

- [ ] **Step 4: Commit exact files**

```bash
git add \
  app/ToonEdge/ToonEdgeAppEntry.swift \
  app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift
git commit -m "test: add reader hardening fixture contract"
```

Expected: one foundation commit with no protected evidence staged.
