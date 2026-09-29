# DEF-020 Numeric Reader Adjacency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure numeric Reader adjacency rejects stale non-adjacent explicit links and prove the visible chapter-155 controls target 154 and 156 rather than sparse chapters 1 and 169.

**Architecture:** `SwiftDataLibraryRepository` remains the resolver owner. Exact stored `current ± 1` payloads win, explicit links are accepted only when their URL contains the expected numeric identity, and `ChapterURLInference` is the final safe fallback. UI fixtures provide deterministic sessions but contain no selection algorithm.

**Tech Stack:** SwiftData, Swift Testing, SwiftUI app fixture injection, XCUITest.

## Global Constraints

- Start from the reviewed fixture-foundation revision.
- Never use Recent/activity ordering for adjacency.
- Reuse `ChapterNumericLabelExtractor` and `ChapterURLInference`; do not add another label parser.
- Preserve nonnumeric stored-order behavior.
- Unsafe numeric adjacency resolves nil and fails gracefully.
- Use iPhone 16 Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` for this slice.
- Preserve the protected screenshots untracked and unchanged.

---

### Task 1: Reject stale explicit numeric links

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Interfaces:**
- Produces: `ChapterURLInference.containsChapterNumber(_:in:) -> Bool`.
- Updates: repository numeric adjacent resolution.
- Preserves: `readerSession(forChapterID:) -> MockReaderSession?`.

- [ ] **Step 1: Write the stale-link regression**

Add to `PersistenceLifecycleTests.swift`:

```swift
@MainActor
@Test func swiftDataRepositoryRejectsNonAdjacentExplicitLinkForNumericChapter() async throws {
    let repository = try makeRepository()
    let chapter169URL = URL(string: "https://example.com/series/chapter-169")!
    var chapter155 = LibraryChapterInput.mock(
        title: "Chapter 155",
        chapterLabel: "155",
        sourceURL: URL(string: "https://example.com/series/chapter-155")!,
        imageURLs: [URL(string: "https://images.example.test/155.png")!]
    )
    chapter155.previousChapterURL = URL(string: "https://example.com/series/chapter-1")!
    chapter155.nextChapterURL = chapter169URL
    let input = LibrarySeriesInput.mock(
        chapters: [
            .mock(chapterLabel: "1", sourceURL: URL(string: "https://example.com/series/chapter-1")!),
            chapter155,
            .mock(chapterLabel: "169", sourceURL: chapter169URL)
        ]
    )

    try await repository.addToLibrary(input, context: .reader)
    let session = try #require(await repository.readerSession(forChapterID: chapter155.id))

    #expect(session.previousChapter?.sourceURL == URL(string: "https://example.com/series/chapter-154"))
    #expect(session.nextChapter?.sourceURL == URL(string: "https://example.com/series/chapter-156"))
    #expect(session.previousChapter?.sourceURL != input.chapters[0].sourceURL)
    #expect(session.nextChapter?.sourceURL != chapter169URL)
}
```

If `LibraryChapterInput` uses different adjacent-link property labels at the current revision, use its existing initializer labels rather than adding test-only setters. Keep the asserted values unchanged.

- [ ] **Step 2: Run RED**

```bash
swift test --package-path app --jobs 1 \
  --filter swiftDataRepositoryRejectsNonAdjacentExplicitLinkForNumericChapter
```

Expected: current session resolves explicit chapter 1/169 instead of 154/156.

- [ ] **Step 3: Add one canonical URL-number validator**

In `ChapterURLInference`, expose the existing private component rule without adding a new parser:

```swift
static func containsChapterNumber(_ number: Int, in sourceURL: URL) -> Bool {
    let label = "\(number)"
    return sourceURL.pathComponents.contains {
        pathComponentContainsChapterNumber($0, knownLabel: label)
    }
}
```

Add focused model coverage if needed:

```swift
@Test func chapterURLInferenceValidatesOnlyTheRequestedNumericIdentity() throws {
    let url = try #require(URL(string: "https://example.com/series/chapter-156"))
    #expect(ChapterURLInference.containsChapterNumber(156, in: url))
    #expect(!ChapterURLInference.containsChapterNumber(169, in: url))
}
```

- [ ] **Step 4: Move explicit-link validation into repository resolution**

Extend `numericAdjacentChapter`:

```swift
private func numericAdjacentChapter(
    targetNumber: Int,
    explicitURLString: String?,
    currentChapter: StoredChapter,
    chaptersByNumber: [Int: StoredChapter]
) -> MockChapter? {
    guard targetNumber > 0 else { return nil }

    if let storedChapter = chaptersByNumber[targetNumber] {
        return mockChapter(from: storedChapter)
    }

    if let explicitURLString,
       let explicitURL = URL(string: explicitURLString),
       ChapterURLInference.containsChapterNumber(targetNumber, in: explicitURL) {
        return MockChapter(title: "Chapter \(targetNumber)", sourceURL: explicitURL)
    }

    guard let currentNumber = integerChapterNumber(for: currentChapter),
          let currentSourceURL = URL(string: currentChapter.sourceURLString),
          let inferredURL = ChapterURLInference.inferredSourceURL(
              forChapter: targetNumber,
              knownChapters: [.init(number: currentNumber, sourceURL: currentSourceURL)]
          ) else {
        return nil
    }

    return MockChapter(title: "Chapter \(targetNumber)", sourceURL: inferredURL)
}
```

Pass `previousChapterURLString` and `nextChapterURLString` from `adjacentChapters(for:in:)`. For nonnumeric chapters, preserve the existing explicit-link-first behavior plus stored-order fallback. Then make `readerSession(forChapterID:)` consume only the fully resolved tuple instead of applying explicit strings a second time.

- [ ] **Step 5: Run focused GREEN**

```bash
swift test --package-path app --jobs 1 \
  --filter 'swiftDataRepositoryRejectsNonAdjacentExplicitLinkForNumericChapter|swiftDataRepositoryDerivesNumericAdjacentReaderControlsForSparseChapterLists|swiftDataRepositoryPrefersStoredNumericAdjacentChapterWhenPayloadExists|swiftDataRepositoryDoesNotJumpToSparseStoredChapterWhenNumericAdjacentURLIsUnsafe|swiftDataRepositoryDerivesAdjacentReaderControlsFromSavedChapterListWhenLinksAreMissing|chapterURLInferenceValidatesOnlyTheRequestedNumericIdentity'
```

Expected: all selected tests pass.

### Task 2: Add the sanitized numeric Reader fixture

**Files:**
- Modify: `app/ToonEdge/ToonEdgeAppEntry.swift`

**Interfaces:**
- Consumes: `ReaderHardeningFixtureScenario.numericAdjacency` and `.numericAdjacencyUnsafe`.
- Produces: a chapter-155 Reader session and a deterministic adjacent loader.

- [ ] **Step 1: Add fixture sessions without resolver logic**

```swift
private let numericAdjacencyFixtureSession: MockReaderSession = {
    var session = MockReaderSession(
        seriesTitle: "Numeric Adjacency Fixture",
        chapterTitle: "Chapter 155",
        sourceURL: URL(string: "https://fixture.example/series/chapter-155")!,
        imageURLs: [URL(string: "https://images.example.test/numeric/155.png")!]
    )
    session.previousChapter = MockChapter(
        title: "Chapter 154",
        sourceURL: URL(string: "https://fixture.example/series/chapter-154")!
    )
    session.nextChapter = MockChapter(
        title: "Chapter 156",
        sourceURL: URL(string: "https://fixture.example/series/chapter-156")!
    )
    return session
}()

private let numericAdjacencyUnsafeFixtureSession = MockReaderSession(
    seriesTitle: "Numeric Adjacency Fixture",
    chapterTitle: "Chapter 155",
    sourceURL: URL(string: "https://fixture.example/series/latest")!,
    imageURLs: [URL(string: "https://images.example.test/numeric/155.png")!]
)
```

- [ ] **Step 2: Add a deterministic success loader**

```swift
private actor UITestAdjacentSuccessLoader: AdjacentReaderSessionLoading {
    func loadAdjacentReaderSession(
        from url: URL,
        context: AdjacentReaderSessionLoadContext
    ) async throws -> MockReaderSession {
        let label = url.lastPathComponent.replacingOccurrences(of: "chapter-", with: "")
        var session = MockReaderSession(
            seriesID: context.currentSession.seriesID,
            seriesTitle: context.currentSession.seriesTitle,
            seriesURL: context.currentSession.seriesURL,
            chapterTitle: "Chapter \(label)",
            sourceURL: url,
            imageURLs: [URL(string: "https://images.example.test/numeric/\(label).png")!]
        )
        session.launchOrigin = context.currentSession.launchOrigin
        return session
    }
}
```

This loader loads the target it receives; it does not choose the target.

- [ ] **Step 3: Wire dependencies and router state**

For `.numericAdjacency`, set `adjacentReaderSessionLoader` to the success loader and present `numericAdjacencyFixtureSession`. For `.numericAdjacencyUnsafe`, present the unsafe session with no adjacent target.

- [ ] **Step 4: Parse app source**

```bash
xcrun swiftc -parse app/ToonEdge/ToonEdgeAppEntry.swift
```

Expected: exit 0.

### Task 3: Prove visible Previous/Next behavior

**Files:**
- Modify: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`

**Interfaces:**
- Consumes stable IDs: `reader.root`, `reader.chapter.label`, `reader.previousChapter`, `reader.nextChapter`.
- Consumes fixture: `numeric-adjacency` and `numeric-adjacency-unsafe`.

- [ ] **Step 1: Add a focused UI test class**

```swift
@MainActor
final class ToonEdgeNumericAdjacencyUITests: XCTestCase {
    func testSparseChapter155NextOpens156Never169() {
        let app = launchFixture("numeric-adjacency")
        revealChrome(in: app)
        app.buttons["reader.nextChapter"].tap()
        assertChapter("Chapter 156", in: app)
        XCTAssertFalse(app.staticTexts["reader.chapter.label"].label.contains("169"))
    }

    func testSparseChapter155PreviousOpens154Never1() {
        let app = launchFixture("numeric-adjacency")
        revealChrome(in: app)
        app.buttons["reader.previousChapter"].tap()
        assertChapter("Chapter 154", in: app)
        XCTAssertFalse(app.staticTexts["reader.chapter.label"].label.contains("Chapter 1"))
    }

    func testUnsafeNumericPatternDoesNotExposeSparseAdjacentTargets() {
        let app = launchFixture("numeric-adjacency-unsafe")
        revealChrome(in: app)
        XCTAssertFalse(app.buttons["reader.previousChapter"].isEnabled)
        XCTAssertFalse(app.buttons["reader.nextChapter"].isEnabled)
    }
}
```

Implement `launchFixture`, `revealChrome`, and `assertChapter` using the existing helpers in this file: launch with `-uiTesting -readerHardeningFixture <value>`, tap the center of `reader.root`, and wait for `reader.chapter.label`.

- [ ] **Step 2: Run the focused UI suite**

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-def020-derived \
  test -only-testing:ToonEdgeUITests/ToonEdgeNumericAdjacencyUITests \
  -resultBundlePath /private/tmp/toonedge-def020-numeric-adjacency.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Expected: 3 tests pass.

- [ ] **Step 3: Run full package tests**

```bash
swift test --package-path app --jobs 1
git diff --check
```

Expected: all tests pass; no whitespace errors.

### Task 4: Record and commit DEF-020

**Files:**
- Create: `docs/qa_evidence/2026-09-29-def-020-numeric-adjacency.md`
- Modify: `docs/defects.md` only if the new stale-link behavior changes its resolution note.

- [ ] **Step 1: Record RED/GREEN evidence**

Include the stale explicit-link failure, focused package results, visible 154/156 journeys, unsafe graceful state, result-bundle path, and the distinction between repository resolution and UI fixture transport.

- [ ] **Step 2: Commit exact files**

```bash
git add \
  app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift \
  app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift \
  app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift \
  app/ToonEdge/ToonEdgeAppEntry.swift \
  app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift \
  docs/qa_evidence/2026-09-29-def-020-numeric-adjacency.md \
  docs/defects.md
git commit -m "fix: enforce numeric reader adjacency"
```

Omit `docs/defects.md` from staging when its text did not change.
