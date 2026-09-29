# DEF-036 Vortex Live Route Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove that Vortex in-site and direct navigation produce one equivalent viable Reader session, or capture an honest live limitation and keep DEF-036 open.

**Architecture:** Existing WebKit URL KVO, navigation callbacks, `BrowserDetectionNavigationPolicy`, and `BrowserDetectionRetryPolicy` remain the sole scheduling path. Before live capture, detection logging is reduced to a sanitized host/path shape. Production route behavior changes only after a live divergence is reproduced by a failing callback/content-sequence regression.

**Tech Stack:** WebKit, Swift Testing, OSLog, XCUITest/manual simulator exercise, iOS 18.6 iPhone 16e.

## Global Constraints

- Use iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` exclusively for the live run.
- Never target shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- Do not bypass challenges, authentication, rate limits, paywalls, or protected viewers.
- Do not retain third-party page artwork.
- Raw logs remain under `/private/tmp` and are reduced to sanitized facts before documentation.
- A nonviable or unavailable live site keeps DEF-036 open.
- Do not add a view timer, second route observer, or broad Vortex parser.

---

### Task 1: Sanitize detection URL logging

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Services/DetectionDiagnosticsLogger.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

**Interfaces:**
- Produces: `DetectionLogURLShape.init(url:)`, `host`, and `pathShape`.
- Consumes: `OSLogDetectionDiagnosticsLogger.log(_:pageURL:)`.

- [ ] **Step 1: Write the failing sanitizer regression**

Add to `DetectionEngineTests.swift`:

```swift
@Test func detectionLogURLShapeDropsQueryCredentialsAndSpecificRouteValues() throws {
    let url = try #require(URL(string:
        "https://user:secret@vortexscans.org/series/past-life-returner/chapter-169?token=private"
    ))

    let shape = DetectionLogURLShape(url: url)

    #expect(shape.host == "vortexscans.org")
    #expect(shape.pathShape == "/series/:segment/chapter-:number")
    #expect(!shape.description.contains("past-life-returner"))
    #expect(!shape.description.contains("token"))
    #expect(!shape.description.contains("secret"))
}
```

- [ ] **Step 2: Run it and record RED**

```bash
swift test --package-path app --jobs 1 \
  --filter detectionLogURLShapeDropsQueryCredentialsAndSpecificRouteValues
```

Expected: compile failure because `DetectionLogURLShape` does not exist.

- [ ] **Step 3: Add the minimal pure sanitizer**

Add beside the logger:

```swift
struct DetectionLogURLShape: Equatable, Sendable, CustomStringConvertible {
    let host: String
    let pathShape: String

    init(url: URL) {
        host = url.host()?.lowercased() ?? "unknown"
        let structural = Set(["series", "manga", "comics", "read", "chapter", "viewer"])
        let components = url.pathComponents
            .filter { $0 != "/" }
            .map { component -> String in
                let lowercased = component.lowercased()
                if structural.contains(lowercased) {
                    return lowercased
                }
                if component.range(of: #"[0-9]+"#, options: .regularExpression) != nil {
                    return component.replacingOccurrences(
                        of: #"[0-9]+"#,
                        with: ":number",
                        options: .regularExpression
                    )
                }
                return ":segment"
            }
        pathShape = "/" + components.joined(separator: "/")
    }

    var description: String { "host=\(host) path=\(pathShape)" }
}
```

Change the logger to construct the shape and remove `pageURL.absoluteString`:

```swift
let urlShape = DetectionLogURLShape(url: pageURL)
logger.info(
    "Detection result host=\(urlShape.host, privacy: .public) path=\(urlShape.pathShape, privacy: .public) confidence=\(diagnostics.confidence.rawValue, privacy: .public) parserPath=\(diagnostics.parserPath.rawValue, privacy: .public) profile=\(diagnostics.profileDomain ?? "none", privacy: .public) tier=\(diagnostics.supportTier?.rawValue ?? "none", privacy: .public) compatibility=\(diagnostics.compatibilityClass?.rawValue ?? "none", privacy: .public) retry=\(diagnostics.retryRecommendation.rawValue, privacy: .public) score=\(diagnostics.score, privacy: .public) candidates=\(diagnostics.candidateCount, privacy: .public)"
)
```

- [ ] **Step 4: Run GREEN and focused route tests**

```bash
swift test --package-path app --jobs 1 \
  --filter 'detectionLogURLShapeDropsQueryCredentialsAndSpecificRouteValues|routeObservationSchedulesSettledURLOnce|browserDetectionRetryPolicyAllowsOnlyOneFollowUpPerURL|browserSessionFollowUpWaitsForDelayedSPAContentToSettle|vortexLowConfidenceRouteGetsOneBoundedFollowUpWithoutAProfileRetry|vortexRouteFixtureProducesOrderedReaderSession|browserReaderPresentationLogsPendingAndVisibleTransitions'
```

Expected: all selected tests pass.

- [ ] **Step 5: Commit logging safety independently**

```bash
git add \
  app/Sources/ToonEdgeAppCore/Features/Detection/Services/DetectionDiagnosticsLogger.swift \
  app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift
git commit -m "fix: sanitize detection route diagnostics"
```

### Task 2: Revalidate the deterministic Vortex route

**Files:**
- Read: `app/Tests/ToonEdgeAppCoreTests/Fixtures/vortex_spa_chapter_169.json`
- Test: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

**Interfaces:**
- Consumes: `BrowserDetectionNavigationPolicy`, `BrowserDetectionRetryPolicy`, `ProfileAwareChapterDetector`.
- Produces no code unless a regression fails.

- [ ] **Step 1: Confirm fixture sanitization without opening artwork**

```bash
rg -n 'https?://' app/Tests/ToonEdgeAppCoreTests/Fixtures/vortex_spa_chapter_169.json
```

Expected: the page URL uses `vortexscans.org`; all image URLs use the sanitized fixture image host and contain no captured binary content.

- [ ] **Step 2: Run the deterministic control**

```bash
swift test --package-path app --jobs 1 \
  --filter 'routeObservationSchedulesSettledURLOnce|browserDetectionRetryPolicyAllowsOnlyOneFollowUpPerURL|browserSessionFollowUpWaitsForDelayedSPAContentToSettle|vortexLowConfidenceRouteGetsOneBoundedFollowUpWithoutAProfileRetry|vortexRouteFixtureProducesOrderedReaderSession|remediationSiteFixturesRemainSanitizedOrderedAndPolicyAccurate'
```

Expected: one settled URL schedule, one bounded follow-up, ordered viable fixture session, 0 failures.

### Task 3: Run independent live in-site and direct controls

**Files:**
- Create: `docs/qa_evidence/2026-09-29-def-036-vortex-parity.md`
- Modify conditionally: `docs/defects.md`

**Interfaces:**
- Consumes: app launch argument `-uiTesting -openURL <url>`.
- Consumes logs: OSLog categories `Detection` and `BrowserReaderPresentation`.

- [ ] **Step 1: Build and install only on the dedicated iPhone 16e**

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-def036-derived \
  build CODE_SIGNING_ALLOWED=NO

xcrun simctl install \
  4582CDE9-27DB-4669-86AC-0631C1D7F2ED \
  /private/tmp/toonedge-def036-derived/Build/Products/Debug-iphonesimulator/ToonEdge.app
```

Expected: build succeeds and installation targets only the leased simulator.

- [ ] **Step 2: Start sanitized log capture**

```bash
xcrun simctl spawn 4582CDE9-27DB-4669-86AC-0631C1D7F2ED \
  log stream --style compact \
  --predicate 'subsystem == "com.toonedge.app" AND (category == "Detection" OR category == "BrowserReaderPresentation")'
```

Save raw output only to `/private/tmp/toonedge-def036-logs/`. Do not paste full live URLs into committed evidence.

- [ ] **Step 3: Exercise the in-site route**

Launch:

```bash
xcrun simctl launch --terminate-running-process \
  4582CDE9-27DB-4669-86AC-0631C1D7F2ED \
  com.toonedge.app \
  -uiTesting -openURL https://vortexscans.org/series/past-life-returner
```

In the simulator, tap one currently available chapter and wait through the 12-second settled-content window. Record only:

```text
flow=in-site
host=vortexscans.org
path-shape=/series/:segment/chapter-:number
initial-detection-count=<observed integer>
follow-up-count=<observed integer, maximum 1>
confidence=<observed value>
score=<observed integer>
candidates=<observed integer>
parser-path=<observed value>
pending-presentations=<observed integer>
visible-presentations=<observed integer>
```

- [ ] **Step 4: Exercise the exact direct control**

Terminate the app, then launch the exact final chapter URL reached in Step 3 using the same `simctl launch` form. Wait through its settle window and record the same sanitized fields with `flow=direct`.

- [ ] **Step 5: Choose the evidence branch**

Use exactly one outcome:

- **Parity:** both flows reach the same viable chapter, have at most one follow-up, and produce one pending plus one visible Reader presentation. Update DEF-036 to Implemented.
- **Live limitation:** site unavailable/challenged/changed or both controls nonviable. Keep DEF-036 Open and document the limitation separately from fixture PASS.
- **App divergence:** flows reach the same viable document but detection or presentation differs. Continue to Task 4 before editing production code.

### Task 4: Conditional TDD remediation for a live divergence

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Modify only as proven: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- Modify only as proven: `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`

**Interfaces:**
- Consumes the exact observed callback/content sequence.
- Must preserve `BrowserDetectionNavigationPolicy` and `BrowserDetectionRetryPolicy` as the single decision path.

- [ ] **Step 1: Encode the observed sequence as RED**

For a callback-order divergence, add a table-driven policy test shaped like:

```swift
@Test func observedVortexCallbackSequenceSchedulesOneSettledChapterDetection() throws {
    let series = try #require(URL(string: "https://vortexscans.org/series/sample"))
    let chapter = try #require(URL(string: "https://vortexscans.org/series/sample/chapter-168"))
    var policy = BrowserDetectionNavigationPolicy()

    let scheduled = [
        policy.shouldSchedule(url: series, isLoading: false),
        policy.shouldSchedule(url: chapter, isLoading: true),
        policy.shouldSchedule(url: chapter, isLoading: false),
        policy.shouldSchedule(url: chapter, isLoading: false)
    ]

    #expect(scheduled == [true, false, true, false])
}
```

Change the sequence to match the sanitized live callbacks exactly. For hydration or stale-delivery divergence, write the equivalent focused test around retry/result identity rather than forcing it into this policy.

- [ ] **Step 2: Run RED**

```bash
swift test --package-path app --jobs 1 --filter observedVortexCallbackSequence
```

Expected: assertion failure reproducing the observed divergence.

- [ ] **Step 3: Make the smallest owning-layer fix**

Modify only the policy/coordinator branch demonstrated by RED. Do not add a second observer, automatic reload, repeated follow-up, or lower confidence threshold.

- [ ] **Step 4: Run focused, full, and live GREEN**

```bash
swift test --package-path app --jobs 1 --filter 'observedVortexCallbackSequence|vortex|Vortex|routeObservation'
swift test --package-path app --jobs 1
```

Repeat Task 3. DEF-036 closes only when live parity is viable and proven.

### Task 5: Record and commit the slice

**Files:**
- Modify: `docs/defects.md` only for a proven closure or new root-cause note.
- Create: `docs/qa_evidence/2026-09-29-def-036-vortex-parity.md`.

- [ ] **Step 1: Record commands and outcome**

Include fixture results, live result, sanitized diagnostic counts, result/log paths, limitations, and whether production code changed. Explicitly state when DEF-036 remains open.

- [ ] **Step 2: Delete temporary artwork captures**

Delete only captures created by this task that contain third-party pages. Do not touch the three protected screenshots.

- [ ] **Step 3: Commit exact files**

Evidence-only outcome:

```bash
git add docs/qa_evidence/2026-09-29-def-036-vortex-parity.md docs/defects.md
git commit -m "test: revalidate Vortex route parity"
```

Code-fix outcome: stage the exact regression, owning source file, and evidence files, then commit:

```bash
git commit -m "fix: preserve Vortex route parity"
```
