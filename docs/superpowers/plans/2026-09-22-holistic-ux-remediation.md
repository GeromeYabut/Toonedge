# Holistic UX Defect Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve DEF-035 through DEF-046 from the 2026-09-22 hands-on QA review and add regression coverage for the browser, Reader, persistence, Downloads, Settings, Dynamic Type, and loading flows that failed.

**Architecture:** Keep detection policy in SiteProfileRegistry/ProfileAwareChapterDetector, navigation observation in BrowserWebView, routing intent in AppRouter, chapter identity in one domain normalizer, persistence behind repositories, and UI state inside feature-level view models. Deliver each task as an independently testable vertical slice; do not fold site-specific behavior into generic UI views.

**Tech Stack:** Swift 6, SwiftUI, WebKit, SwiftData, Swift Testing, XCTest/XCUITest, Xcode 16.4, iOS 18.6 simulator.

## Global Constraints

- Read `AGENTS.md`, `docs/toonedge_architecture_doc.md`, `docs/toonedge_prd.md`, and `docs/toonedge_ux_requirements_doc.md` before editing.
- Use the documented source-of-truth order. WEBTOON and protected GlobalComix pages are browser-only.
- Preserve all existing uncommitted work. Inspect `git status --short` before every slice and stage only files touched for that slice.
- Do not reset, clean, stash, or close the shared iPhone 16 Pro. Use a dedicated simulator such as the existing iPhone 16e.
- Do not bypass challenges, authentication, paywalls, or protected viewers.
- Keep multi-page stitching, cloud sync, recommendations, social features, ML detection, and browser tabs out of scope.
- Add a failing regression test before implementation for every defect.
- Run `swift test --package-path app --jobs 1` after every slice and the full simulator build before claiming completion.
- Update each defect status only after its acceptance criteria pass in automated tests and simulator verification.

## Source and test map

| Responsibility | Primary files |
|---|---|
| Site policy and detection | `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`, `ProfileAwareChapterDetector.swift`, `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift` |
| Browser navigation and Reader promotion | `Features/Browser/WebView/BrowserWebView.swift`, `Features/Browser/ViewModels/BrowserViewModel.swift`, `BrowserExperienceTests.swift` |
| Routing context | `App/Routing/AppRouter.swift`, `Features/Home/Views/HomeView.swift`, `AppRouterTests.swift` |
| Search validation | `Core/Domain/AppModels.swift`, `Features/Search/Views/SearchOverlayView.swift`, `SearchEntryModelTests.swift` |
| Reader image requests | `Core/Services/Protocols/AppServiceProtocols.swift`, `Features/Reader/Loading/ReaderPageImageLoader.swift`, `ReaderExperienceTests.swift` |
| Chapter identity | `Core/Domain/AppModels.swift`, `Features/Reader/ViewModels/ReaderViewModel.swift`, persistence repository, Library/Persistence tests |
| Downloads | `Features/Downloads/Views/DownloadsView.swift`, `CacheMetadataTests.swift` |
| App shell and accessibility | `App/AppShell/AppShellView.swift`, Home/Settings/Shared UI, new UI tests |
| Library loading | `Features/Library/Views/LibraryView.swift`, `LibraryExperienceTests.swift` |
| Settings | `Features/Settings/Views/SettingsView.swift`, service protocols/implementations, dependencies, Settings tests |

---

### Task 1: Enforce protected-reader policy (DEF-035)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/SearchEntryModelTests.swift`

**Interfaces:**
- Consumes: `SiteProfileRegistry.default`, `SiteProfileSupportTier.browserOnly`, `ProfileAwareChapterDetector.detect(page:)`.
- Produces: a registry invariant that protected readers cannot produce Reader or CTA candidates.

- [ ] **Step 1: Replace the outdated registry expectation with a failing policy test**

```swift
@Test func defaultRegistryKeepsProtectedReadersBrowserOnly() throws {
    let registry = SiteProfileRegistry.default
    let webtoon = try #require(URL(string: "https://m.webtoons.com/en/fantasy/sample/viewer"))
    let globalComix = try #require(URL(string: "https://globalcomix.com/c/sample/chapters/en/1"))

    #expect(registry.profile(for: webtoon)?.supportTier == .browserOnly)
    #expect(registry.profile(for: globalComix)?.supportTier == .browserOnly)
}
```

- [ ] **Step 2: Add a detector assertion for a protected page with chapter-like images**

Construct `DetectionPageAnalysis` with at least five long vertical candidates and a WEBTOON URL. Assert `.low`, `readerSession == nil`, and `diagnostics.parserPath == .browserOnlyProfile`.

- [ ] **Step 3: Run the focused tests and verify failure**

Run: `swift test --package-path app --filter defaultRegistryKeepsProtectedReadersBrowserOnly`  
Expected: FAIL because WEBTOON and GlobalComix are currently `enabledPublic`.

- [ ] **Step 4: Change both profiles to `.browserOnly` with the browser-only template**

Use `supportTier: .browserOnly` and `template: .browserOnly`. Remove image selector hints that imply extraction support.

- [ ] **Step 5: Verify policy and suggestion behavior**

Run: `swift test --package-path app --filter DetectionEngineTests` and `swift test --package-path app --filter SearchEntryModelTests`  
Expected: PASS; protected domains are absent from promoted suggestions and cannot produce Reader/CTA state.

---

### Task 2: Validate malformed URL input before Browser presentation (DEF-040)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Search/Views/SearchOverlayView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/SearchEntryModelTests.swift`

**Interfaces:**
- Produces: `SearchInputValidation` with `.empty`, `.valid(SearchInput)`, and `.invalidURL` cases; `SearchInputClassifier.validate(_:)`.
- Keeps: `SearchInputClassifier.classify(_:)` for callers that already operate on known non-empty valid values.

- [ ] **Step 1: Add the validation type and failing tests**

```swift
public enum SearchInputValidation: Equatable, Sendable {
    case empty
    case valid(SearchInput)
    case invalidURL
}

@Test func searchValidationRejectsHostlessHTTPURLs() {
    #expect(SearchInputClassifier.validate("https://") == .invalidURL)
    #expect(SearchInputClassifier.validate(" http:// \n") == .invalidURL)
}

@Test func searchValidationKeepsEmptyInputInert() {
    #expect(SearchInputClassifier.validate("  \n") == .empty)
}
```

- [ ] **Step 2: Implement `validate(_:)` using `URLComponents`**

For an explicit HTTP(S) prefix, require a non-empty host. Return `.valid(classify(trimmed))` for valid HTTP(S), likely domains, localhost, IPv4, and ordinary queries.

- [ ] **Step 3: Add `@State private var validationMessage: String?` to SearchOverlayView**

In `openValue`, switch on `validate`. Do nothing for `.empty`; set `validationMessage = "Enter a complete web address or search phrase."` for `.invalidURL`; record history and present Browser only for `.valid`.

- [ ] **Step 4: Render validation next to the field and clear it on query change**

Use accessible error text with `foregroundStyle(ToonEdgeColor.danger)` and `.accessibilityLiveRegion(.assertive)` where supported. Do not use a blocking alert.

- [ ] **Step 5: Run tests**

Run: `swift test --package-path app --filter SearchEntryModelTests`  
Expected: PASS for malformed, whitespace, domain, localhost, IPv4, unsupported-scheme, and ordinary-query cases.

---

### Task 3: Observe in-site route changes and preserve Home launch origin (DEF-036, DEF-042)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/Routing/AppRouter.swift` only if cleanup semantics require it
- Modify: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/AppRouterTests.swift`

**Interfaces:**
- Produces: a route-observation helper that schedules one detection pass per settled URL transition.
- Reuses: `AppRouter.presentBrowser(_:readerLaunchOrigin:)` and `ReaderLaunchOrigin.homeContinueReading`.

- [ ] **Step 1: Add a failing route-observation policy test**

Extract a small pure type such as `BrowserDetectionNavigationPolicy` with `shouldSchedule(previousURL:newURL:isLoading:)`. Assert series→chapter URL schedules detection, duplicate callbacks for the same URL do not, and a loading URL waits until settled.

- [ ] **Step 2: Observe WKWebView URL changes in Coordinator**

Store an `NSKeyValueObservation` created in `attach(_:)` for `webView.url`. On a changed non-nil URL, update navigation state and schedule the existing debounced detection after the document settles. Keep `lastAutoDetectionURL` as the duplicate guard and reset retry state for a new URL.

- [ ] **Step 3: Add a Vortex-shaped integration fixture**

Create `app/Tests/ToonEdgeAppCoreTests/Fixtures/vortex_spa_chapter_169.json` from sanitized current analysis data. Assert the route-triggered analysis and direct-load analysis produce the same confidence and ordered session.

- [ ] **Step 4: Add a failing Home fallback origin test**

Extend the existing Home Continue tests to assert the fallback call is:

```swift
router.presentBrowser(
    startPoint,
    readerLaunchOrigin: .homeContinueReading
)
```

Then promote the detected Reader session and assert `navigateBackFromReader()` selects Home and clears Browser/Reader state.

- [ ] **Step 5: Pass Home origin from the fallback call site**

Change only the Home Continue fallback path; ordinary Home search must retain Browser origin.

- [ ] **Step 6: Verify focused and full tests**

Run: `swift test --package-path app --filter BrowserExperienceTests` and `swift test --package-path app --filter AppRouterTests`  
Expected: PASS with one detection per route and correct Home/Library/Browser back behavior.

---

### Task 4: Gate Reader promotion on usable image requests (DEF-037)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/ReaderPageImageLoader.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Add: `app/Tests/ToonEdgeAppCoreTests/Fixtures/comizy_redirected_chapter.json`
- Modify: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`

**Interfaces:**
- Produces: a sendable image request context containing referrer and cookie headers; a request-based HTTP loader path; a Reader-session viability result.
- Constraint: do not persist raw cookies or log complete image URLs.

- [ ] **Step 1: Add request-based loading without removing the URL convenience API**

Extend `HTTPDataLoading` with `data(for request: URLRequest)` and provide a default `data(from:)` adapter. Update `URLSessionHTTPDataLoader` and test doubles.

- [ ] **Step 2: Add failing header propagation tests**

Create a recording HTTP loader. Build a Reader image request with `Referer`, mobile Safari `User-Agent`, and cookies, then assert the loader receives the exact headers and the page reaches `.loaded`.

- [ ] **Step 3: Capture ephemeral WebKit request context at promotion time**

Read cookies from `webView.configuration.websiteDataStore.httpCookieStore`, serialize only cookies applicable to the image host, and use the chapter page as the referrer. Attach the context to the in-memory Reader session; do not store it in SwiftData.

- [ ] **Step 4: Preflight the first non-placeholder image before high-confidence presentation**

If the preflight returns a successful image response, allow promotion. If it fails after the existing retry policy, keep Browser visible, suppress the CTA/auto-open, and expose a concise non-blocking message with View Original behavior intact.

- [ ] **Step 5: Use the same request context in ReaderPageImageLoader**

Every page request must share the validated headers. Retry must rebuild the same request rather than falling back to a bare URL.

- [ ] **Step 6: Add the sanitized Comizy fixture and viability regressions**

Assert redirect canonicalization, ten ordered image candidates, successful header-aware loading, and refusal to promote when the loader cannot fetch page 1.

- [ ] **Step 7: Run focused tests**

Run: `swift test --package-path app --filter ReaderExperienceTests` and `swift test --package-path app --filter BrowserExperienceTests`  
Expected: PASS; no viable-image failure can become visible Reader.

---

### Task 5: Canonicalize chapter identity across all surfaces (DEF-041)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Interfaces:**
- Produces: one public chapter display helper based on `ChapterNumericLabelExtractor`.
- Removes: last-token parsing and duplicated `conciseChapterLabel` behavior.

- [ ] **Step 1: Add failing normalization tests**

```swift
@Test func chapterIdentityRejectsBrandSuffixTokens() {
    let title = "I Became The Youngest Disciple of the Mount Hua Sect Manhwa - Chapter 1 - Manhwa Manhua Top"
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "Top", title: title) == "1")
}

@Test func chapterIdentityNeverUsesChapterAsItsOwnLabel() {
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "Chapter", title: "Chapter 7") == "7")
}
```

- [ ] **Step 2: Reject non-numeric chapterLabel values before falling back to title**

Keep decimal support. Prefer explicit numeric `chapterNumber`, then numeric content in `chapterLabel`, then the number adjacent to the word `chapter` in title/URL.

- [ ] **Step 3: Replace ReaderViewModel's last-token and first-`chapter` parsing**

Expose a shared display function that returns `Chapter <number>` when numeric identity exists and a conservative original title otherwise.

- [ ] **Step 4: Normalize at repository write boundaries**

Ensure recent reading, saved chapter, and index merge inputs store the canonical label. Do not migrate or rewrite unrelated records; repair affected records when they are next merged/read.

- [ ] **Step 5: Add a cold-relaunch persistence regression**

Persist the noisy ManhuaTop sample, reconstruct the repository, and assert Home, Library summary, Series Detail primary action, and active row all report chapter 1.

- [ ] **Step 6: Run tests**

Run: `swift test --package-path app --filter ReaderExperienceTests`, `--filter LibraryExperienceTests`, and `--filter PersistenceLifecycleTests`  
Expected: PASS with no `Chapter Top` or `Chapter Chapter` output.

---

### Task 6: Make Downloads scrollable and accessible (DEF-039)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Downloads/Views/DownloadsView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/CacheMetadataTests.swift`
- Add or modify: UI test files created in Task 7

**Interfaces:**
- Keeps: `DownloadsViewModel.load()` and `remove(sourceURL:)`.
- Produces: a scrollable content layout and item-specific delete semantics.

- [ ] **Step 1: Add a layout-model test for a populated list**

Add a small `DownloadsContentLayout` value with `entryCount`, `usesScrollableContent`, and `minimumActionSize`. Assert 20 entries require scrolling and action size is at least 44.

- [ ] **Step 2: Wrap the complete Downloads content in `ScrollView`**

Keep banner, summary, feedback, and entries in one `LazyVStack`. Remove the layout-driving `Spacer()` and add bottom padding so the final card clears the tab bar.

- [ ] **Step 3: Fix the destructive action**

Use a minimum 44×44 frame and an accessibility label such as `Remove <chapter title> from cache`, plus a hint that local cached data will be removed.

- [ ] **Step 4: Add a UI test with 20 deterministic entries**

Launch with a UI-test fixture, open Downloads, swipe until the twentieth title exists, assert it is hittable, and verify its delete button label contains that title. Do not tap delete in the shared-data configuration.

- [ ] **Step 5: Run tests**

Run: `swift test --package-path app --filter CacheMetadataTests` and the dedicated Downloads UI test.  
Expected: PASS; last row reachable on iPhone 16e.

---

### Task 7: Add UI coverage and repair Dynamic Type/accessibility layout (DEF-038, DEF-044, DEF-046)

**Files:**
- Modify: `app/ToonEdge.xcodeproj/project.pbxproj`
- Add: `app/ToonEdgeUITests/ToonEdgeAccessibilityUITests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/AppShell/AppShellView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Home/Views/HomeView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Settings/Views/SettingsView.swift`
- Modify: `app/Sources/ToonEdgeAppCore/SharedUI/Components/ToonEdgePrimitives.swift`

**Interfaces:**
- Produces: an XCUITest target, stable accessibility identifiers for tabs and primary actions, and large-text-safe layouts.

- [ ] **Step 1: Create a ToonEdgeUITests target and smoke test**

Add a UI-testing bundle hosted by the ToonEdge app. The smoke test launches with `-uiTesting -resetTestData`, asserts `home.searchEntry` exists, and terminates.

- [ ] **Step 2: Add stable identifiers**

Assign identifiers `tab.home`, `tab.library`, `tab.downloads`, `tab.settings`, `home.searchEntry`, and `settings.readerFit`. Keep visible labels user-facing.

- [ ] **Step 3: Add failing large-text tests**

Launch with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`. On Home and Settings, assert all four tabs exist and are hittable. Capture an attachment for each screen.

- [ ] **Step 4: Make Settings content scroll instead of competing with the tab bar**

Use `ScrollView`/`LazyVStack` for Settings, preserve safe-area/tab-bar space, and avoid fixed-height containers that expand past the available content region.

- [ ] **Step 5: Make Home search label adaptive**

Use `ViewThatFits(in: .horizontal)` with the full copy first and `Search or paste link` second. Preserve `.accessibilityLabel("Search the web or paste a chapter link")`.

- [ ] **Step 6: Combine Settings row semantics**

Mark decorative symbols hidden and combine the row's children, exposing label and value. Assert Reader Fit is not announced as `Enter Full Screen`.

- [ ] **Step 7: Verify two device sizes**

Run the UI tests on iPhone 16e and iPhone 16 Pro Max, iOS 18.6.  
Expected: all tabs and primary controls exist and are hittable at normal and accessibility sizes.

---

### Task 8: Distinguish Library loading from empty state (DEF-045)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Add or modify: `app/ToonEdgeUITests/ToonEdgeLibraryUITests.swift`

**Interfaces:**
- Produces: `LibraryContentPhase` with `.loading`, `.empty`, and `.content` states.

- [ ] **Step 1: Add phase tests**

```swift
@Test func libraryPhaseDoesNotExposeEmptyBeforeInitialLoadCompletes() {
    #expect(LibraryContentPhase(hasLoadedSnapshot: false, visibleCount: 0) == .loading)
    #expect(LibraryContentPhase(hasLoadedSnapshot: true, visibleCount: 0) == .empty)
    #expect(LibraryContentPhase(hasLoadedSnapshot: true, visibleCount: 7) == .content)
}
```

- [ ] **Step 2: Render an explicit local loading state**

Before the first snapshot completes, show a compact progress/skeleton presentation and suppress zero-count/empty copy. Keep filter and navigation structure stable.

- [ ] **Step 3: Add a delayed-library UI fixture**

Launch with seven deterministic titles and a short injected snapshot delay. Assert the loading identifier appears, `Nothing saved yet` never appears, then the first title becomes visible.

- [ ] **Step 4: Run tests**

Run: `swift test --package-path app --filter LibraryExperienceTests` and the Library UI test.  
Expected: PASS with no false empty transition.

---

### Task 9: Complete the MVP Settings slice (DEF-043)

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Protocols/AppServiceProtocols.swift`
- Add: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/UserDefaultsSettingsRepository.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Mocks/MockServices.swift`
- Modify: `app/Sources/ToonEdgeAppCore/App/DependencyInjection/AppDependencies.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Settings/Views/SettingsView.swift`
- Add: `app/Tests/ToonEdgeAppCoreTests/SettingsExperienceTests.swift`
- Add or modify: `app/ToonEdgeUITests/ToonEdgeSettingsUITests.swift`

**Interfaces:**
- Replace read-only usage with `SettingsManaging: SettingsProviding` and `func updateSettings(_ settings: ReaderSettings) async`.
- Reuse `CacheMetadataManaging`, `CacheStorageMeasuring`, and `LibraryUpdateRefreshing` for storage and update actions.

- [ ] **Step 1: Add persistence tests for editable Reader settings**

Write tests that update canvas, display mode, page spacing, and brightness, reconstruct the repository with the same isolated UserDefaults suite, and assert equality.

- [ ] **Step 2: Implement UserDefaultsSettingsRepository**

Persist each enum raw value plus spacing and brightness. Fall back field-by-field to `ReaderSettings.default` when data is absent or invalid.

- [ ] **Step 3: Inject the persistent implementation**

Use the repository in `AppDependencies.persistent`; keep a deterministic mutable mock for previews/tests.

- [ ] **Step 4: Build Settings sections**

Create editable Reader controls, a Storage section showing measured cache summary and navigation to Downloads, an Update section that invokes `refreshUpdates()` with loading/result feedback, and an About section with app name/version and support/legal copy required by the UX document.

- [ ] **Step 5: Share settings with newly opened Reader sessions**

Ensure new Reader sessions receive current persisted settings. Reader changes that are intended to be global must write back through `SettingsManaging`; chapter progress remains separate.

- [ ] **Step 6: Add Settings UI tests**

Change Fit Width to Fit Screen, relaunch, and assert persistence. Run manual update fixtures for success, no update, and failure. Navigate to Downloads from Storage.

- [ ] **Step 7: Run tests**

Run: `swift test --package-path app --filter SettingsExperienceTests` and Settings UI tests.  
Expected: PASS across relaunch and failure states.

---

### Task 10: Final site-fixture, offline, accessibility, and regression verification

**Files:**
- Add sanitized fixtures under `app/Tests/ToonEdgeAppCoreTests/Fixtures/` for current Vortex, ManhuaTop, MangaKatana, MangaPill, and Comizy behavior
- Modify the relevant Detection, Browser, Reader, Cache, and UI test files
- Modify: `docs/defects.md`
- Append verification results to `docs/qa_reports/2026-09-22-holistic-ux-quality-review.md`

- [ ] **Step 1: Add deterministic current-site fixtures**

Fixtures must contain analysis fields needed by ToonEdge, omit copyrighted image data, and preserve ordered URL metadata, placeholder/challenge signals, canonical series/chapter links, and navigation links.

- [ ] **Step 2: Add a retained-offline UI journey**

Using fixture-backed networking: retain a chapter, terminate, relaunch with networking forced unavailable, and assert every retained page opens in order. Assert an uncached chapter shows a clear offline state.

- [ ] **Step 3: Run the complete automated suite**

Run: `swift test --package-path app --jobs 1`  
Expected: all tests pass with no skipped regression for DEF-035 through DEF-046.

- [ ] **Step 4: Build the simulator app**

Run:

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-remediation-derived \
  build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run UI tests on dedicated devices**

Run the ToonEdgeUITests scheme on iPhone 16e and iPhone 16 Pro Max. Do not use or close the shared iPhone 16 Pro.

- [ ] **Step 6: Repeat the critical live checks**

Verify WEBTOON has no CTA, Vortex series→chapter matches direct URL, Comizy stays in Browser unless images are viable, malformed URL is rejected, Home fallback returns Home, Downloads reaches the last row, labels stay numeric after relaunch, and all tabs remain available at large text.

- [ ] **Step 7: Update defect statuses with evidence**

For each DEF-035 through DEF-046, record the implementation summary, tests added, exact verification command/result, and any remaining live-site limitation. Keep a defect Open if its firsthand acceptance check cannot be completed.

## Final completion gate

- Every DEF-035 through DEF-046 has automated regression coverage.
- The app builds successfully for the dedicated iPhone 16e simulator.
- Swift package tests and UI tests pass.
- Protected readers remain browser-only.
- No product code hardcodes a piracy catalog or bypasses a challenge/protected viewer.
- Existing uncommitted work remains intact and the final report lists only files changed for remediation.
