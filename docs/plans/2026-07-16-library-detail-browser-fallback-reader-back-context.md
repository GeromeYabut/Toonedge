# Library Detail Browser Fallback Reader Back Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement DEF-034 so Library Series Detail `Continue` launches that fall back through Browser still return to the originating Series Detail when Reader back is tapped, with no indefinite loading or hidden hang state.

**Architecture:** Preserve the existing direct Reader path and existing Browser fallback. Add a small, scoped Reader launch-origin override to Browser presentation state, apply it only when Browser detection promotes the originally requested chapter into Reader, then consume/clear it. Browser remains visible and dismissible while detection runs; no blocking intermediate screen is introduced.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing `AppRouter`, `BrowserViewModel`, `BrowserView`, `SeriesDetailView`, and `ReaderLaunchOrigin`.

## Global Constraints

- Implement only DEF-034.
- Do not change persistence schema.
- Do not change Reader detection scoring, chapter parsing, update checks, save-to-library grouping, or Library card/layout behavior.
- Do not remove Browser fallback for chapters without a stored native Reader payload.
- Do not block Series Detail or Browser while waiting for detection.
- Do not add an indefinite full-screen loading state.
- Browser fallback must remain visible and dismissible if detection fails or stays low-confidence.
- `View Original Page` must still expose the Browser.
- Normal Browser-origin Reader sessions must keep Browser-origin back behavior.
- Home Continue Reading direct Reader sessions must still return to Home.

---

## File Map

- Modify: `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`
  - Add a scoped optional `presentedBrowserReaderLaunchOrigin`.
  - Add an overload/default parameter to `presentBrowser`.
  - Clear the override on Browser dismissal and root route changes.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
  - Accept an optional launch-origin override.
  - Apply it only to the matching initial fallback URL.
  - Consume it after a viable Reader session is presented.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
  - Pass the override into `BrowserViewModel`.
  - Clear router override after Browser-owned Reader is actually presented.
- Modify: `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
  - Pass the router's pending launch-origin override into `BrowserView`.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Set `.library(seriesID:)` when Series Detail falls back to Browser for `Continue`.
- Modify: `app/Tests/ToonEdgeAppCoreTests/AppRouterTests.swift`
  - Add router-state tests for carrying and clearing fallback launch context.
- Modify: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
  - Add Browser-owned Reader promotion tests for launch-origin override behavior.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Add or adjust a test proving Series Detail fallback opens Browser with Library-origin context.
- Modify: `docs/defects.md`
  - Mark DEF-034 implemented after verification.

---

## Task 1: Add Router State for Browser Reader Launch Origin

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/AppRouterTests.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift`

**Interfaces:**
- Produces: `AppRouter.presentedBrowserReaderLaunchOrigin: ReaderLaunchOrigin?`
- Produces: `AppRouter.presentBrowser(_:readerLaunchOrigin:)`
- Produces: `AppRouter.clearPresentedBrowserReaderLaunchOrigin()`
- Consumed by later tasks: `AppShellView` and `BrowserView`.

- [ ] **Step 1: Write failing router tests**

Add these tests near `presentingBrowserStoresStartPoint()`:

```swift
@Test func presentingBrowserCanCarryReaderLaunchOrigin() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-107")
    let seriesID = UUID()

    router.presentBrowser(startPoint, readerLaunchOrigin: .library(seriesID: seriesID))

    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedBrowserReaderLaunchOrigin == .library(seriesID: seriesID))
    #expect(router.activeSheet == nil)
}

@Test func dismissingBrowserClearsReaderLaunchOriginOverride() {
    var router = AppRouter()
    router.presentBrowser(
        .url("https://example.com/series/chapter-107"),
        readerLaunchOrigin: .library(seriesID: UUID())
    )

    router.dismissBrowser()

    #expect(router.presentedBrowser == nil)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
}

@Test func clearingBrowserReaderLaunchOriginKeepsBrowserVisible() {
    var router = AppRouter()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-107")
    router.presentBrowser(startPoint, readerLaunchOrigin: .library(seriesID: UUID()))

    router.clearPresentedBrowserReaderLaunchOrigin()

    #expect(router.presentedBrowser == startPoint)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --package-path app --filter 'presentingBrowserCanCarryReaderLaunchOrigin|dismissingBrowserClearsReaderLaunchOriginOverride|clearingBrowserReaderLaunchOriginKeepsBrowserVisible'
```

Expected: fail because `presentedBrowserReaderLaunchOrigin`, the new `presentBrowser` parameter, and `clearPresentedBrowserReaderLaunchOrigin()` do not exist.

- [ ] **Step 3: Implement minimal router state**

In `AppRouter`, add the property and initializer parameter:

```swift
public var presentedBrowserReaderLaunchOrigin: ReaderLaunchOrigin?
```

Update the initializer:

```swift
public init(
    selectedTab: AppTab = .home,
    activeSheet: AppSheet? = nil,
    presentedBrowser: BrowserStartPoint? = nil,
    presentedReader: MockReaderSession? = nil,
    pendingLibrarySeriesID: UUID? = nil,
    pendingLibrarySegment: LibrarySegment? = nil,
    presentedBrowserReaderLaunchOrigin: ReaderLaunchOrigin? = nil
) {
    self.selectedTab = selectedTab
    self.activeSheet = activeSheet
    self.presentedBrowser = presentedBrowser
    self.presentedReader = presentedReader
    self.pendingLibrarySeriesID = pendingLibrarySeriesID
    self.pendingLibrarySegment = pendingLibrarySegment
    self.presentedBrowserReaderLaunchOrigin = presentedBrowserReaderLaunchOrigin
}
```

Replace `presentBrowser(_:)` with a defaulted parameter:

```swift
public mutating func presentBrowser(
    _ startPoint: BrowserStartPoint,
    readerLaunchOrigin: ReaderLaunchOrigin? = nil
) {
    activeSheet = nil
    presentedBrowser = startPoint
    presentedBrowserReaderLaunchOrigin = readerLaunchOrigin
}
```

Update `dismissBrowser()`:

```swift
public mutating func dismissBrowser() {
    presentedBrowser = nil
    presentedBrowserReaderLaunchOrigin = nil
}
```

Add:

```swift
public mutating func clearPresentedBrowserReaderLaunchOrigin() {
    presentedBrowserReaderLaunchOrigin = nil
}
```

Update root route methods that clear Browser state (`openLibraryRoot`, `openHomeRoot`, `openLibraryRecent`, `openLibraryDetail`) to also set:

```swift
presentedBrowserReaderLaunchOrigin = nil
```

- [ ] **Step 4: Run router tests**

Run:

```bash
swift test --package-path app --filter AppRouterTests
```

Expected: pass.

---

## Task 2: Apply Browser Reader Launch Origin Override Without Blocking

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`

**Interfaces:**
- Consumes: `ReaderLaunchOrigin`.
- Produces: `BrowserViewModel.init(startPoint:readerPresentationLogger:readerLaunchOriginOverride:)`.
- Produces: Browser-owned Reader sessions that use the override only for the initial fallback URL.

- [ ] **Step 1: Write failing BrowserViewModel tests**

Add these tests near `browserReaderPresentationStateTracksPendingAndVisibleReader()`:

```swift
@MainActor
@Test func browserReaderPresentationAppliesLibraryLaunchOriginOverrideForInitialURL() throws {
    let seriesID = UUID()
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: seriesID)
    )
    let session = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .library(seriesID: seriesID))
    #expect(viewModel.readerPresentationState == .browserOwnedReaderVisible)
}
```

Add a normal Browser-origin guard:

```swift
@MainActor
@Test func browserReaderPresentationKeepsBrowserOriginWithoutOverride() throws {
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-12"))
    let viewModel = BrowserViewModel(startPoint: .url(pageURL.absoluteString))
    let session = MockReaderSession(
        seriesTitle: "Moonlit Edge",
        chapterTitle: "Chapter 12",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .browser)
}
```

Add a stale-navigation/no-hang guard:

```swift
@MainActor
@Test func browserReaderLaunchOriginOverrideDoesNotApplyToDifferentURL() throws {
    let initialURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let navigatedURL = try #require(URL(string: "https://example.com/other/chapter-1"))
    let viewModel = BrowserViewModel(
        startPoint: .url(initialURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: UUID())
    )
    let session = MockReaderSession(
        seriesTitle: "Other Series",
        chapterTitle: "Chapter 1",
        sourceURL: navigatedURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )

    viewModel.updateNavigation(
        url: navigatedURL,
        title: "Other Series Chapter 1",
        canGoBack: true,
        canGoForward: false,
        isLoading: false
    )
    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: navigatedURL,
            confidence: .high,
            score: 100,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .high, score: 100, parserPath: .genericHeuristic)
        )
    )
    viewModel.presentPendingReaderInsideBrowser(session)

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .browser)
    #expect(viewModel.readerPresentationState == .browserOwnedReaderVisible)
}
```

Add a consume-once guard:

```swift
@MainActor
@Test func browserReaderLaunchOriginOverrideIsConsumedAfterVisibleReaderPresentation() throws {
    let seriesID = UUID()
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: seriesID)
    )
    let firstSession = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )
    let secondSession = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/2.jpg"))],
        launchOrigin: .browser
    )

    viewModel.presentPendingReaderInsideBrowser(firstSession)
    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .library(seriesID: seriesID))

    viewModel.dismissBrowserOwnedReader()
    viewModel.presentPendingReaderInsideBrowser(secondSession)

    #expect(viewModel.browserOwnedReaderSession?.launchOrigin == .browser)
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --package-path app --filter 'browserReaderPresentationAppliesLibraryLaunchOriginOverrideForInitialURL|browserReaderPresentationKeepsBrowserOriginWithoutOverride|browserReaderLaunchOriginOverrideDoesNotApplyToDifferentURL|browserReaderLaunchOriginOverrideIsConsumedAfterVisibleReaderPresentation'
```

Expected: fail because `readerLaunchOriginOverride` initializer parameter does not exist and Browser presentation does not override launch origin.

- [ ] **Step 3: Implement BrowserViewModel override**

In `BrowserViewModel`, add private properties:

```swift
private var pendingReaderLaunchOriginOverride: ReaderLaunchOrigin?
private let readerLaunchOriginOverrideSourceURL: URL?
```

Update the initializer signature:

```swift
public init(
    startPoint: BrowserStartPoint,
    readerPresentationLogger: any BrowserReaderPresentationLogging = OSLogBrowserReaderPresentationLogger(),
    readerLaunchOriginOverride: ReaderLaunchOrigin? = nil
) {
```

Inside the initializer, after `self.readerPresentationLogger = readerPresentationLogger`, add:

```swift
self.pendingReaderLaunchOriginOverride = readerLaunchOriginOverride
self.readerLaunchOriginOverrideSourceURL = initialRequest?.url
```

Update `presentPendingReaderInsideBrowser(_:)` to prepare a session before publishing it:

```swift
public func presentPendingReaderInsideBrowser(_ session: MockReaderSession) {
    guard isViableReaderSession(session) else {
        clearPendingReaderSession(session)
        return
    }

    var preparedSession = session
    if let override = pendingReaderLaunchOriginOverride,
       session.sourceURL == readerLaunchOriginOverrideSourceURL {
        preparedSession.launchOrigin = override
        pendingReaderLaunchOriginOverride = nil
    }

    browserOwnedReaderSession = preparedSession
    clearPendingReaderSession(session)
    readerPresentationLogger.log(.browserOwnedReaderVisible)
}
```

This implementation introduces no new loading state. Low-confidence or non-viable detections continue to leave `browserOwnedReaderSession == nil` and Browser remains visible.

- [ ] **Step 4: Run Browser focused tests**

Run:

```bash
swift test --package-path app --filter BrowserExperienceTests
```

Expected: pass.

---

## Task 3: Wire Library Detail Fallback Through the Scoped Browser Context

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/AppRouterTests.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/Features/Browser/Views/BrowserView.swift`
- Implementation: `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`

**Interfaces:**
- Consumes: `AppRouter.presentBrowser(_:readerLaunchOrigin:)`
- Consumes: `BrowserViewModel.init(startPoint:readerPresentationLogger:readerLaunchOriginOverride:)`
- Produces: Library Detail fallback Browser launches that carry `.library(seriesID:)`.

- [ ] **Step 1: Add a route policy model test for Series Detail fallback**

If no small route policy model exists for this path, add one near `SeriesDetailSeedShellLayout` in `LibraryView.swift`:

```swift
struct SeriesDetailChapterOpenRoute: Equatable, Sendable {
    var chapter: ChapterSummary
    var seriesID: UUID

    var browserStartPoint: BrowserStartPoint {
        .url(chapter.sourceURL.absoluteString)
    }

    var browserReaderLaunchOrigin: ReaderLaunchOrigin {
        .library(seriesID: seriesID)
    }
}
```

First write this failing test in `LibraryExperienceTests.swift` near the Series Detail route tests:

```swift
@Test func seriesDetailBrowserFallbackCarriesLibraryReaderLaunchOrigin() throws {
    let seriesID = UUID()
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/extras/chapter/107"))
    let chapter = ChapterSummary.mock(
        chapterLabel: "107",
        sourceURL: chapterURL,
        isOpenable: true
    )

    let route = SeriesDetailChapterOpenRoute(chapter: chapter, seriesID: seriesID)

    #expect(route.browserStartPoint == .url(chapterURL.absoluteString))
    #expect(route.browserReaderLaunchOrigin == .library(seriesID: seriesID))
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --package-path app --filter seriesDetailBrowserFallbackCarriesLibraryReaderLaunchOrigin
```

Expected: fail because `SeriesDetailChapterOpenRoute` does not exist.

- [ ] **Step 3: Add the route policy model**

Add this struct near the existing Series Detail layout helper structs in `LibraryView.swift`:

```swift
struct SeriesDetailChapterOpenRoute: Equatable, Sendable {
    var chapter: ChapterSummary
    var seriesID: UUID

    var browserStartPoint: BrowserStartPoint {
        .url(chapter.sourceURL.absoluteString)
    }

    var browserReaderLaunchOrigin: ReaderLaunchOrigin {
        .library(seriesID: seriesID)
    }
}
```

- [ ] **Step 4: Wire `SeriesDetailView.open(_:)` fallback**

Change the fallback in `SeriesDetailView.open(_:)` from:

```swift
router.presentBrowser(.url(chapter.sourceURL.absoluteString))
```

to:

```swift
let route = SeriesDetailChapterOpenRoute(chapter: chapter, seriesID: seriesID)
router.presentBrowser(
    route.browserStartPoint,
    readerLaunchOrigin: route.browserReaderLaunchOrigin
)
```

Keep the direct stored session path unchanged:

```swift
if let directSession = await dependencies.libraryLifecycleService?.readerSession(forChapterID: chapter.id) {
    var librarySession = directSession
    librarySession.launchOrigin = .library(seriesID: seriesID)
    router.presentReader(librarySession)
    return
}
```

- [ ] **Step 5: Pass the override from AppShell to BrowserView**

Change `BrowserView` initializer signature:

```swift
public init(
    startPoint: BrowserStartPoint,
    readerLaunchOriginOverride: ReaderLaunchOrigin? = nil,
    dependencies: AppDependencies,
    router: Binding<AppRouter>
) {
    self.dependencies = dependencies
    self._router = router
    self._viewModel = StateObject(
        wrappedValue: BrowserViewModel(
            startPoint: startPoint,
            readerLaunchOriginOverride: readerLaunchOriginOverride
        )
    )
}
```

Update `AppShellView` Browser presentation:

```swift
BrowserView(
    startPoint: router.presentedBrowser ?? .searchQuery(""),
    readerLaunchOriginOverride: router.presentedBrowserReaderLaunchOrigin,
    dependencies: dependencies,
    router: $router
)
```

- [ ] **Step 6: Clear router override after Reader is actually presented**

In `BrowserView.onChange(of: viewModel.pendingReaderSession)`, change:

```swift
guard let session else { return }
viewModel.presentPendingReaderInsideBrowser(session)
```

to:

```swift
guard let session else { return }
viewModel.presentPendingReaderInsideBrowser(session)
if viewModel.browserOwnedReaderSession != nil {
    router.clearPresentedBrowserReaderLaunchOrigin()
}
```

This clearing does not dismiss Browser and does not block detection. It only prevents the Library-origin override from leaking into later Browser reads.

- [ ] **Step 7: Add an end-to-end router behavior regression**

Add this test to `AppRouterTests.swift`:

```swift
@Test func readerBackFromLibraryFallbackDetectedReaderReturnsToSeriesDetail() {
    var router = AppRouter(selectedTab: .library)
    let seriesID = UUID()
    let startPoint = BrowserStartPoint.url("https://example.com/series/chapter-107")
    var detectedSession = MockReaderSession.sample
    detectedSession.launchOrigin = .library(seriesID: seriesID)

    router.presentBrowser(startPoint, readerLaunchOrigin: .library(seriesID: seriesID))
    router.presentReader(detectedSession)
    router.clearPresentedBrowserReaderLaunchOrigin()
    router.navigateBackFromReader()

    #expect(router.presentedReader == nil)
    #expect(router.presentedBrowser == nil)
    #expect(router.selectedTab == .library)
    #expect(router.pendingLibrarySeriesID == seriesID)
    #expect(router.presentedBrowserReaderLaunchOrigin == nil)
}
```

- [ ] **Step 8: Run focused routing tests**

Run:

```bash
swift test --package-path app --filter 'AppRouterTests|BrowserExperienceTests|seriesDetailBrowserFallbackCarriesLibraryReaderLaunchOrigin'
```

Expected: pass.

---

## Task 4: No-Hang Regression and Documentation Status

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Documentation: `docs/defects.md`

**Interfaces:**
- Consumes: Browser state behavior from Task 2.
- Produces: explicit coverage that low-confidence fallback leaves Browser usable and no Reader/spinner state is forced.

- [ ] **Step 1: Add low-confidence no-hang test**

Add this test to `BrowserExperienceTests.swift` near the Browser Reader presentation tests:

```swift
@MainActor
@Test func browserLaunchOriginOverrideDoesNotForceReaderWhenDetectionIsLowConfidence() throws {
    let seriesID = UUID()
    let pageURL = try #require(URL(string: "https://example.com/series/chapter-107"))
    let viewModel = BrowserViewModel(
        startPoint: .url(pageURL.absoluteString),
        readerLaunchOriginOverride: .library(seriesID: seriesID)
    )
    let session = MockReaderSession(
        seriesTitle: "The Extra's Academy Survival Guide",
        chapterTitle: "Chapter 107",
        sourceURL: pageURL,
        imageURLs: [try #require(URL(string: "https://img.example.com/1.jpg"))],
        launchOrigin: .browser
    )

    viewModel.handleDetectionResult(
        DetectionResult(
            pageURL: pageURL,
            confidence: .low,
            score: 20,
            candidates: [],
            readerSession: session,
            diagnostics: .init(confidence: .low, score: 20, parserPath: .genericHeuristic)
        )
    )

    #expect(viewModel.pendingReaderSession == nil)
    #expect(viewModel.browserOwnedReaderSession == nil)
    #expect(viewModel.readerPresentationState == .none)
    #expect(!viewModel.showsCleanModeCTA)
}
```

- [ ] **Step 2: Run focused no-hang test**

Run:

```bash
swift test --package-path app --filter browserLaunchOriginOverrideDoesNotForceReaderWhenDetectionIsLowConfidence
```

Expected: pass.

- [ ] **Step 3: Mark DEF-034 implemented after verification**

In `docs/defects.md`, change only DEF-034:

```markdown
**Status:** Implemented
```

- [ ] **Step 4: Run final focused tests**

Run:

```bash
swift test --package-path app --filter AppRouterTests
swift test --package-path app --filter BrowserExperienceTests
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

---

## Final Verification

Run:

```bash
swift test --package-path app --filter AppRouterTests
swift test --package-path app --filter BrowserExperienceTests
swift test --package-path app --filter LibraryExperienceTests
swift test --package-path app
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected:

- All focused tests pass.
- Full package tests pass.
- Xcode build succeeds.

## Manual QA

Use a toon/chapter that does not have a stored native Reader payload yet, such as the reported Extra's Academy chapter flow:

1. Open Library.
2. Open the series detail page.
3. Tap `Continue Chapter 107`.
4. Confirm Browser visibly loads the chapter page and remains dismissible while detection runs.
5. Confirm Reader opens when high-confidence detection completes.
6. Tap Reader back.
7. Confirm the app returns directly to the same Library Series Detail, not first to Browser.
8. Repeat from normal Browser/search entry and confirm Reader back still returns to Browser context.
9. Repeat Home Continue Reading with a stored session and confirm Reader back still returns Home.

## Expected Outcome

- Library Detail fallback through Browser preserves Library-origin Reader back behavior.
- No new blocking loading screen is introduced.
- Failed or low-confidence detection leaves the user in normal Browser controls.
- Browser-origin and Home-origin Reader behavior remain unchanged.
