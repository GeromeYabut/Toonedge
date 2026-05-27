# Reader Unseen Adjacent Chapter Loading Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Reader `Next` / `Previous` load unseen adjacent chapters from the source site without requiring those chapters to already be saved, downloaded, or cached.

**Architecture:** Add a real `AdjacentReaderSessionLoading` service owned outside SwiftUI. `ReaderViewModel` keeps the current chapter visible, checks stored payloads first, then asks the adjacent loader to perform a hidden browser/detection load that reuses the existing WebKit extraction, site profiles, sanitizer, challenge suppression, and high-confidence gates. Mock/sample reader sessions must never be promoted for real adjacent navigation.

**Tech Stack:** Swift 6, SwiftUI, WebKit/WKWebView, Swift Testing, existing ToonEdge Browser/Detection/Reader/Persistence modules.

---

## Story 11.27 Summary

- Reader adjacent navigation must work for unseen chapters.
- Stored adjacent payload remains the fast path.
- Unstored adjacent chapters load through a hidden/non-presented browser extraction path.
- Reader stays on the current chapter during loading.
- Only high-confidence viable sessions replace the current Reader session.
- Unsafe, challenged, low/medium-confidence, blank, or mock sessions fail safely.
- Back and `View Original Page` semantics remain unchanged.

## Affected Files

- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Create: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift` if WebKit extraction helpers need to be shared.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/JavaScript/PageAnalysisScript.swift` only if hidden extraction cannot currently reuse the page-analysis script.
- Test: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
- Test: add `app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift` if the service can be tested independently without UI.
- Modify docs: `docs/toonedge_epics_and_stories.md`

## Assumptions

- Hidden adjacent loading is allowed to use a non-presented `WKWebView`.
- The hidden loader may run only on the main actor because `WKWebView` is UI-bound.
- The MVP still rejects multi-page chapter stitching.
- Low/medium-confidence adjacent pages should not replace Reader content.
- Browser-origin Reader sessions can keep their existing visible browser navigation behavior unless this service can be shared safely.

---

### Task 1: Add Story 11.27 To Story Docs

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`

**Step 1: Write the failing check**

Run:

```bash
rg -n "Story 11.27" docs/toonedge_epics_and_stories.md
```

Expected: no match.

**Step 2: Add the story**

Append after Story 11.26:

```markdown
### Story 11.27 — Reader loads unseen adjacent chapters through hidden extraction
**Status:** planned

**User story**

As a reader, I want `Next` and `Previous` in Reader to load adjacent chapters from the source site even if I have never opened, saved, downloaded, or cached those chapters before, so I can keep reading continuously without preparing every chapter ahead of time.

**Acceptance criteria**
- Reader uses stored adjacent payloads first when available.
- If no stored payload exists, Reader loads the adjacent chapter URL through a hidden/non-presented browser extraction flow.
- Hidden loading reuses existing rendered DOM extraction, site profiles, ad/popup suppression, challenge suppression, and high-confidence thresholds.
- Reader remains visible on the current chapter while loading.
- High-confidence viable extraction swaps Reader to the adjacent chapter and resets progress.
- Failure leaves the current chapter intact and shows a non-destructive message.
- Blank, unsafe, low-confidence, medium-confidence, challenged, or mock/sample sessions are never promoted.
- Back preserves the original launch context after adjacent transitions.
- `View Original Page` points to the current Reader chapter’s exact source URL.
```

**Step 3: Verify**

Run:

```bash
rg -n "Story 11.27" docs/toonedge_epics_and_stories.md
```

Expected: one match.

---

### Task 2: Define Adjacent Loader Protocol

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`

**Step 1: Write the failing test**

Add to `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`:

```swift
@MainActor
@Test func readerViewModelUsesAdjacentLoaderForUnstoredAppOriginNextChapter() async throws {
    let next = MockChapter(title: "Chapter 2", sourceURL: URL(string: "https://example.com/series/chapter-2")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .homeContinueReading
    current.nextChapter = next
    var loaded = MockReaderSession.sample
    loaded.chapterTitle = "Chapter 2"
    loaded.sourceURL = next.sourceURL
    loaded.imageURLs = [URL(string: "https://cdn.example.com/chapter-2/page-1.webp")!]

    let loader = RecordingAdjacentReaderSessionLoader(result: .success(loaded))
    let viewModel = ReaderViewModel(session: current)

    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: loader
    )

    #expect(viewModel.session.sourceURL == next.sourceURL)
    #expect(viewModel.session.launchOrigin == .homeContinueReading)
    #expect(await loader.requestedURLs == [next.sourceURL])
}
```

Add this test helper:

```swift
private actor RecordingAdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let result: Result<MockReaderSession, Error>
    private(set) var requestedURLs: [URL] = []

    init(result: Result<MockReaderSession, Error>) {
        self.result = result
    }

    func loadAdjacentReaderSession(from url: URL, context: AdjacentReaderSessionLoadContext) async throws -> MockReaderSession {
        requestedURLs.append(url)
        return try result.get()
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path app --filter readerViewModelUsesAdjacentLoaderForUnstoredAppOriginNextChapter
```

Expected: compile failure because `AdjacentReaderSessionLoading`, `AdjacentReaderSessionLoadContext`, and the new view model API do not exist.

**Step 3: Add minimal protocol and context**

Add to `AppServiceProtocols.swift`:

```swift
public struct AdjacentReaderSessionLoadContext: Equatable, Sendable {
    public var currentSession: MockReaderSession
    public var direction: ReaderChapterDirection

    public init(currentSession: MockReaderSession, direction: ReaderChapterDirection) {
        self.currentSession = currentSession
        self.direction = direction
    }
}

public protocol AdjacentReaderSessionLoading: Sendable {
    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession
}
```

**Step 4: Add a temporary adapter in tests only**

Do not wire production yet. The test should still fail until `ReaderViewModel` accepts the loader.

**Step 5: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift
git commit -m "test: specify unseen adjacent reader loading contract"
```

---

### Task 3: Refactor ReaderViewModel To Use Adjacent Loader

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`

**Step 1: Update failing test call site**

Change `ReaderViewModel.navigateAdjacentChapter` to accept:

```swift
public func navigateAdjacentChapter(
    _ direction: ReaderChapterDirection,
    libraryLifecycleService: (any LibraryLifecycleManaging)?,
    adjacentLoader: (any AdjacentReaderSessionLoading)?
) async
```

**Step 2: Implement minimal flow**

In `ReaderViewModel.navigateAdjacentChapter`:

```swift
if var storedSession = await libraryLifecycleService?.readerSession(forSourceURL: chapter.sourceURL),
   !storedSession.imageURLs.isEmpty {
    storedSession = preparedAdjacentSession(storedSession, preserving: originalSession)
    await replaceSession(storedSession)
    adjacentLoadState = .idle
    return
}

guard let adjacentLoader else {
    session = originalSession
    adjacentLoadState = .failed(direction, message: direction.failureMessage)
    isChromeVisible = true
    return
}

do {
    var loadedSession = try await adjacentLoader.loadAdjacentReaderSession(
        from: chapter.sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: originalSession, direction: direction)
    )
    guard !loadedSession.imageURLs.isEmpty else {
        throw URLError(.cannotDecodeContentData)
    }
    loadedSession = preparedAdjacentSession(loadedSession, preserving: originalSession)
    await replaceSession(loadedSession)
    adjacentLoadState = .idle
} catch {
    session = originalSession
    adjacentLoadState = .failed(direction, message: direction.failureMessage)
    isChromeVisible = true
}
```

**Step 3: Update ReaderView dependency**

Replace the `readerService` fallback parameter for adjacent loading with:

```swift
private let adjacentLoader: (any AdjacentReaderSessionLoading)?
```

Pass it into `viewModel.navigateAdjacentChapter`.

**Step 4: Update AppDependencies**

Add:

```swift
public var adjacentReaderSessionLoader: (any AdjacentReaderSessionLoading)?
```

Wire it through `AppShellView` and `BrowserView` when constructing `ReaderView`.

**Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter ReaderExperienceTests
```

Expected: new loader test passes; existing stored fast path and failure tests still pass.

**Step 6: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift
git commit -m "feat: route reader adjacent loading through dedicated loader"
```

---

### Task 4: Build Hidden WebKit Loader Skeleton

**Files:**
- Create: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift`

**Step 1: Write failing test for viability gating**

Create `AdjacentReaderSessionLoaderTests.swift`:

```swift
import Foundation
import Testing
@testable import ToonEdgeAppCore

@MainActor
@Test func adjacentLoaderRejectsLowConfidenceDetectionResult() async throws {
    let detector = StubChapterDetector(
        result: DetectionResult(
            pageURL: URL(string: "https://example.com/chapter-2")!,
            confidence: .low,
            score: 0,
            candidates: [],
            readerSession: nil,
            diagnostics: DetectionDiagnostics(confidence: .low, score: 0, parserPath: .generic)
        )
    )
    let loader = AdjacentReaderSessionLoader(detector: detector, pageLoader: StubAdjacentPageLoader.analysis(.mockLowConfidencePage))

    await #expect(throws: AdjacentReaderSessionLoadError.unavailable) {
        _ = try await loader.loadAdjacentReaderSession(
            from: URL(string: "https://example.com/chapter-2")!,
            context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
        )
    }
}
```

Use stubs in the test file:

```swift
private struct StubChapterDetector: ChapterPageDetecting {
    let result: DetectionResult
    func detect(page: DetectionPageAnalysis) -> DetectionResult { result }
}

private enum StubAdjacentPageLoader: AdjacentChapterPageLoading {
    case analysis(DetectionPageAnalysis)

    func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis {
        switch self {
        case .analysis(let analysis): analysis
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path app --filter adjacentLoaderRejectsLowConfidenceDetectionResult
```

Expected: compile failure because loader and page-loading protocol do not exist.

**Step 3: Implement skeleton**

In `AdjacentReaderSessionLoader.swift`:

```swift
import Foundation

public enum AdjacentReaderSessionLoadError: Error, Equatable, Sendable {
    case unavailable
}

public protocol AdjacentChapterPageLoading: Sendable {
    func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis
}

@MainActor
public final class AdjacentReaderSessionLoader: AdjacentReaderSessionLoading {
    private let detector: any ChapterPageDetecting
    private let pageLoader: any AdjacentChapterPageLoading

    public init(detector: any ChapterPageDetecting, pageLoader: any AdjacentChapterPageLoading) {
        self.detector = detector
        self.pageLoader = pageLoader
    }

    public func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        let analysis = try await pageLoader.loadPageAnalysis(from: url)
        let result = detector.detect(page: analysis)
        guard result.confidence == .high,
              var session = result.readerSession,
              !session.imageURLs.isEmpty else {
            throw AdjacentReaderSessionLoadError.unavailable
        }
        session.launchOrigin = context.currentSession.launchOrigin
        return session
    }
}
```

**Step 4: Run focused test**

Run:

```bash
swift test --package-path app --filter AdjacentReaderSessionLoaderTests
```

Expected: low-confidence test passes.

**Step 5: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift
git commit -m "feat: add adjacent reader session loader gating"
```

---

### Task 5: Add High-Confidence Success And Unsafe Page Tests

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift`

**Step 1: Write high-confidence success test**

Add:

```swift
@MainActor
@Test func adjacentLoaderPromotesOnlyHighConfidenceViableSession() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    var session = MockReaderSession.sample
    session.sourceURL = sourceURL
    session.imageURLs = [URL(string: "https://cdn.example.com/chapter-2/page-1.webp")!]
    let result = DetectionResult(
        pageURL: sourceURL,
        confidence: .high,
        score: 100,
        candidates: [],
        readerSession: session,
        diagnostics: DetectionDiagnostics(confidence: .high, score: 100, parserPath: .generic)
    )
    var current = MockReaderSession.sample
    current.launchOrigin = .library(seriesID: current.seriesID)
    let loader = AdjacentReaderSessionLoader(
        detector: StubChapterDetector(result: result),
        pageLoader: StubAdjacentPageLoader.analysis(.mockHighConfidencePage(url: sourceURL))
    )

    let loaded = try await loader.loadAdjacentReaderSession(
        from: sourceURL,
        context: AdjacentReaderSessionLoadContext(currentSession: current, direction: .next)
    )

    #expect(loaded.sourceURL == sourceURL)
    #expect(loaded.launchOrigin == current.launchOrigin)
    #expect(loaded.imageURLs.isEmpty == false)
}
```

**Step 2: Write blank session rejection test**

Add:

```swift
@MainActor
@Test func adjacentLoaderRejectsHighConfidenceBlankSession() async throws {
    let sourceURL = URL(string: "https://example.com/chapter-2")!
    var session = MockReaderSession.sample
    session.sourceURL = sourceURL
    session.imageURLs = []
    let result = DetectionResult(
        pageURL: sourceURL,
        confidence: .high,
        score: 100,
        candidates: [],
        readerSession: session,
        diagnostics: DetectionDiagnostics(confidence: .high, score: 100, parserPath: .generic)
    )
    let loader = AdjacentReaderSessionLoader(
        detector: StubChapterDetector(result: result),
        pageLoader: StubAdjacentPageLoader.analysis(.mockHighConfidencePage(url: sourceURL))
    )

    await #expect(throws: AdjacentReaderSessionLoadError.unavailable) {
        _ = try await loader.loadAdjacentReaderSession(
            from: sourceURL,
            context: AdjacentReaderSessionLoadContext(currentSession: .sample, direction: .next)
        )
    }
}
```

**Step 3: Run focused tests**

Run:

```bash
swift test --package-path app --filter AdjacentReaderSessionLoaderTests
```

Expected: all adjacent loader tests pass.

**Step 4: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift
git commit -m "test: cover adjacent loader viability gates"
```

---

### Task 6: Implement Hidden WKWebView Page Loader

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift`
- Potentially modify: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift`

**Step 1: Extract shared page-analysis script execution if needed**

Look at `BrowserWebView` and reuse the same JavaScript:

```swift
PageAnalysisScript.javaScript
```

Do not duplicate detection or parser logic.

**Step 2: Implement hidden page loader**

Add:

```swift
import WebKit

@MainActor
public final class HiddenWebViewAdjacentChapterPageLoader: NSObject, AdjacentChapterPageLoading {
    private let timeoutNanoseconds: UInt64

    public init(timeoutNanoseconds: UInt64 = 15_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    public func loadPageAnalysis(from url: URL) async throws -> DetectionPageAnalysis {
        let webView = WKWebView(frame: .zero)
        let coordinator = HiddenWebViewLoadCoordinator(webView: webView, url: url)
        return try await coordinator.loadAndAnalyze(timeoutNanoseconds: timeoutNanoseconds)
    }
}
```

Implement `HiddenWebViewLoadCoordinator` as a small `WKNavigationDelegate` helper that:

- loads `URLRequest(url: url)`
- waits for `webView(_:didFinish:)`
- evaluates `PageAnalysisScript.javaScript`
- decodes JSON into `DetectionPageAnalysis`
- returns analysis
- throws on timeout or navigation failure

Keep this class private to the loader file.

**Step 3: Add timeout/error behavior test**

If direct `WKWebView` unit testing is brittle, test the coordinator through stubs only and rely on Xcode build for compile coverage. Do not add flaky network tests.

**Step 4: Run build**

Run:

```bash
swift test --package-path app --filter AdjacentReaderSessionLoaderTests
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -configuration Debug build
```

Expected: tests pass and iOS build compiles.

**Step 5: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift
git commit -m "feat: load unseen adjacent chapters in hidden web view"
```

---

### Task 7: Wire Production Dependencies

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`

**Step 1: Write dependency test**

Add to `app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift`:

```swift
@MainActor
@Test func persistentDependenciesExposeAdjacentReaderSessionLoader() throws {
    let dependencies = try AppDependencies.persistent(inMemory: true, usesModelContextIO: false)

    #expect(dependencies.adjacentReaderSessionLoader != nil)
}
```

**Step 2: Run to verify failure**

Run:

```bash
swift test --package-path app --filter persistentDependenciesExposeAdjacentReaderSessionLoader
```

Expected: compile failure or failed expectation.

**Step 3: Wire dependency**

In `AppDependencies.persistent`, set:

```swift
adjacentReaderSessionLoader: AdjacentReaderSessionLoader(
    detector: ProfileAwareChapterDetector(),
    pageLoader: HiddenWebViewAdjacentChapterPageLoader()
)
```

In `.mock()`, leave `adjacentReaderSessionLoader` nil or provide a fixture-only loader that does not use stock images. Prefer nil to avoid hiding missing real extraction.

Pass `dependencies.adjacentReaderSessionLoader` into `ReaderView`.

**Step 4: Run dependency test**

Run:

```bash
swift test --package-path app --filter AppDependenciesTests
```

Expected: passes.

**Step 5: Commit**

```bash
git add app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift app/Tests/ToonEdgeAppCoreTests/AppDependenciesTests.swift
git commit -m "feat: wire adjacent reader loader"
```

---

### Task 8: Preserve Reader Semantics Across Unseen Transitions

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`

**Step 1: Add regression for Back context**

```swift
@MainActor
@Test func unseenAdjacentNavigationPreservesHomeBackContext() async throws {
    let next = MockChapter(title: "Chapter 2", sourceURL: URL(string: "https://example.com/chapter-2")!)
    var current = MockReaderSession.sample
    current.launchOrigin = .homeContinueReading
    current.nextChapter = next
    var loaded = MockReaderSession.sample
    loaded.sourceURL = next.sourceURL
    loaded.chapterTitle = "Chapter 2"
    loaded.imageURLs = [URL(string: "https://cdn.example.com/page.webp")!]

    let viewModel = ReaderViewModel(session: current)
    await viewModel.navigateAdjacentChapter(
        .next,
        libraryLifecycleService: nil,
        adjacentLoader: RecordingAdjacentReaderSessionLoader(result: .success(loaded))
    )

    #expect(viewModel.session.launchOrigin == .homeContinueReading)
}
```

**Step 2: Add regression for `View Original Page` URL**

```swift
@Test func viewOriginalPageAfterAdjacentReplacementUsesCurrentChapterURL() {
    var router = AppRouter()
    var loaded = MockReaderSession.sample
    loaded.sourceURL = URL(string: "https://example.com/chapter-2")!

    router.presentReader(loaded)
    router.viewOriginalPage()

    #expect(router.presentedBrowser == .url("https://example.com/chapter-2"))
}
```

**Step 3: Run focused tests**

Run:

```bash
swift test --package-path app --filter ReaderExperienceTests
swift test --package-path app --filter AppRouterTests
```

Expected: passes.

**Step 4: Commit**

```bash
git add app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift app/Tests/ToonEdgeAppCoreTests/AppRouterTests.swift
git commit -m "test: preserve reader semantics after unseen adjacent navigation"
```

---

### Task 9: Manual QA Checklist

**Files:**
- Modify: `docs/qa_guide_epic9_10_updates_cache_hardening.md` or create a new short QA note if preferred.

**Step 1: Add checklist**

Add:

```markdown
## Story 11.27 QA — Unseen adjacent chapter loading

1. Open a saved/recent Reader chapter with a valid `Next` link.
2. Confirm `Next` is enabled even if the next chapter has not been opened before.
3. Tap `Next`.
4. Confirm Reader stays visible and shows a lightweight loading state.
5. Confirm the next source chapter appears in Reader, not stock/sample images.
6. Confirm chapter label and progress reset.
7. Tap `Previous` and confirm the previous chapter can load similarly.
8. Try an unsafe/challenge page and confirm Reader remains on the current chapter with a failure message.
9. Tap Back and confirm it returns to the original native launch context.
10. Tap `View Original Page` and confirm it opens the exact currently displayed chapter URL.
```

**Step 2: Commit**

```bash
git add docs/qa_guide_epic9_10_updates_cache_hardening.md
git commit -m "docs: add unseen adjacent chapter QA"
```

---

### Task 10: Full Verification

**Files:**
- All touched files.

**Step 1: Run full package tests**

Run:

```bash
swift test --package-path app
```

Expected: all tests pass.

**Step 2: Run simulator build**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`.

**Step 3: Manual QA**

Use the QA checklist from Task 9 on at least:

- one stored chapter with a saved adjacent chapter
- one stored chapter with an unseen adjacent chapter
- one unsupported/challenge/unsafe adjacent URL

**Step 4: Update story status**

If verification and manual QA pass, update `docs/toonedge_epics_and_stories.md`:

```markdown
**Status:** implemented
```

**Step 5: Final commit**

```bash
git add docs/toonedge_epics_and_stories.md
git commit -m "docs: mark unseen adjacent chapter loading implemented"
```

---

## Risks

- Hidden `WKWebView` loading may behave differently from visible browser loading on sites with aggressive bot/challenge behavior.
- WebKit lifecycle and timeout handling must be conservative to avoid hanging Reader controls.
- Some sites may not expose reliable adjacent links; in that case this story can only load if the current session has a valid adjacent URL.
- Medium-confidence pages should remain failures for adjacent navigation unless product explicitly approves a user-confirmed prompt.

## Definition Of Done

- Stored adjacent chapters still load immediately.
- Unseen adjacent chapters load from the source site through hidden extraction.
- Mock/sample/stock sessions are never promoted.
- Unsafe adjacent pages fail without replacing the current Reader session.
- Reader Back and `View Original Page` remain correct after adjacent transitions.
- `swift test --package-path app` passes.
- `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -configuration Debug build` succeeds.
