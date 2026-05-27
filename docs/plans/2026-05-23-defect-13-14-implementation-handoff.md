# DEF-013 and DEF-014 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix unreadable large navigation/header titles in dark mode and resolve AsuraScans series cover artwork for Recent/Library cards.

**Architecture:** DEF-013 belongs in shared UI/navigation styling, preferably the design-system modifier applied by screens. DEF-014 belongs in the metadata and persistence flow: derive canonical series URLs from chapter URLs, improve generic cover extraction for AsuraScans-style series pages, and let refreshed cover metadata replace placeholders in recent/library rows.

**Tech Stack:** SwiftUI, Swift Testing, SwiftData repository layer, existing `HTMLSeriesMetadataFetcher` / `HTMLSeriesMetadataParser`, existing `ReaderViewModel` recent-reading metadata refresh.

---

## Context

Open defects:

- `docs/defects.md` — `DEF-013`: large navigation/header titles such as `Library` render black on the dark background.
- `docs/defects.md` — `DEF-014`: AsuraScans Recent/Library card shows a generic placeholder instead of cover artwork for `https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/97`.

Relevant source observations:

- `LibraryView` uses `.navigationTitle("Library")` inside a `NavigationStack`, then `.toonEdgeScreen()`.
- `ToonEdgeScreenBackground` currently sets `.toolbarColorScheme(.dark, for: .navigationBar)` on iOS, but the large title still renders near-black in simulator screenshots.
- `HTMLSeriesMetadataParser` currently prefers JSON-LD portrait `ImageObject`, then `og:image`, then `twitter:image`.
- `ReaderViewModel.updateProgress` calls `enrichSessionMetadataIfNeeded()` before recording recent reading, so cover refresh is already designed to flow into Recent when metadata returns a cover.
- `SwiftDataLibraryRepository.recordRecentReading` currently overwrites existing `coverImageURLString` with `input.coverImageURL?.absoluteString`; preserve/replace behavior needs care so `nil` does not erase a known cover.
- Live AsuraScans chapter page links to the series page; the series page exposes multiple cover-like images around the title area. Use generic extraction/hints where possible, not a hardcoded catalog.

---

## Task 1: Fix large navigation title foreground color globally

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/SharedUI/DesignSystem/ToonEdgeDesignSystem.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/DesignSystemTests.swift` or existing appropriate test file
- Possibly inspect: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`, `SettingsView.swift`, `DownloadsView.swift`

**Step 1: Write the failing test**

Create a lightweight testable style contract instead of trying to snapshot SwiftUI navigation bars in package tests.

Add a public model in the design-system area, then test it first:

```swift
@Test func toonEdgeNavigationChromeUsesReadableDarkModeTitleColors() {
    let chrome = ToonEdgeNavigationChrome.dark

    #expect(chrome.colorScheme == .dark)
    #expect(chrome.prefersVisibleLargeTitles)
}
```

If color values are not directly equatable, test semantic values/flags rather than concrete `Color` internals.

**Step 2: Run the focused test to verify it fails**

Run:

```bash
swift test --package-path app --filter toonEdgeNavigationChromeUsesReadableDarkModeTitleColors
```

Expected: FAIL because `ToonEdgeNavigationChrome` does not exist yet.

**Step 3: Implement the minimal shared styling fix**

In `ToonEdgeDesignSystem.swift`:

1. Add a small testable navigation chrome contract if useful:

```swift
public struct ToonEdgeNavigationChrome: Equatable, Sendable {
    public enum Scheme: Equatable, Sendable { case dark }
    public var colorScheme: Scheme
    public var prefersVisibleLargeTitles: Bool

    public static let dark = ToonEdgeNavigationChrome(
        colorScheme: .dark,
        prefersVisibleLargeTitles: true
    )
}
```

2. Strengthen `ToonEdgeScreenBackground.body` for iOS. Options to try in order:

```swift
#if os(iOS)
content
    .background(ToonEdgeColor.background.ignoresSafeArea())
    .foregroundStyle(ToonEdgeColor.textPrimary)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbarBackground(ToonEdgeColor.background, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
#else
...
#endif
```

3. If SwiftUI modifiers still do not affect large titles in the running app, add an iOS-only `UIViewControllerRepresentable` or app-level appearance configurator that sets:

```swift
let appearance = UINavigationBarAppearance()
appearance.configureWithOpaqueBackground()
appearance.backgroundColor = UIColor(...ToonEdge background...)
appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
UINavigationBar.appearance().standardAppearance = appearance
UINavigationBar.appearance().scrollEdgeAppearance = appearance
UINavigationBar.appearance().compactAppearance = appearance
```

Prefer containing this in a clearly named design-system helper, e.g. `ToonEdgeNavigationAppearance.configure()` called from the app entry, rather than scattering overrides in feature views.

**Step 4: Run the focused test**

```bash
swift test --package-path app --filter toonEdgeNavigationChromeUsesReadableDarkModeTitleColors
```

Expected: PASS.

**Step 5: Manual QA**

Build/run in simulator and verify:

- Library large title is white/readable.
- Settings and Downloads titles are readable.
- Series Detail still does not show a duplicate title.

---

## Task 2: Add AsuraScans-style cover metadata parser coverage

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/HTMLSeriesMetadataFetcher.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/UpdateCheckTests.swift`

**Step 1: Write the failing parser test**

Add a fixture-like inline HTML test for a series page where the real cover is a visible image near the series title but not JSON-LD `ImageObject`.

Example test shape:

```swift
@Test func htmlSeriesMetadataParserExtractsAsuraStyleSeriesCoverImage() throws {
    let baseURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5"))
    let html = """
    <html>
      <head>
        <meta property="og:title" content="The Extra’s Academy Survival Guide | Asura Scans" />
      </head>
      <body>
        <img alt="The Extra’s Academy Survival Guide" src="/cdn-cgi/image/width=400/uploads/cover.webp" width="400" height="600" />
        <h1>The Extra’s Academy Survival Guide</h1>
      </body>
    </html>
    """

    let metadata = try #require(HTMLSeriesMetadataParser.parse(html: html, baseURL: baseURL))

    #expect(metadata.title?.contains("The Extra’s Academy Survival Guide") == true)
    #expect(metadata.coverImageURL?.absoluteString == "https://asurascans.com/cdn-cgi/image/width=400/uploads/cover.webp")
}
```

**Step 2: Run focused test to verify it fails**

```bash
swift test --package-path app --filter htmlSeriesMetadataParserExtractsAsuraStyleSeriesCoverImage
```

Expected: FAIL because parser does not inspect visible image candidates.

**Step 3: Implement generic visible cover extraction**

Extend `HTMLSeriesMetadataParser.parse` image priority to:

1. structured portrait cover
2. visible series-cover-like image candidate
3. `og:image`
4. `twitter:image`

Add a helper such as:

```swift
private static func visibleSeriesCoverImage(in html: String, title: String?) -> String?
```

Candidate rules:

- Parse `<img ...>` tags with regex; extract `src`, `data-src`, `data-lazy-src`, maybe `srcset` first URL.
- Score candidates generically:
  - positive: `alt` contains normalized title words
  - positive: `src` contains `cover`, `poster`, `thumbnail`, `series`, `comic`, `upload`
  - positive: portrait dimensions if `width`/`height` attributes exist
  - negative: `logo`, `avatar`, `banner`, `ad`, `ads`, `icon`, `comment`, `reaction`
- Prefer portrait/high-score candidates.
- Do not hardcode `asurascans.com` as the only supported domain unless generic extraction is insufficient.

Keep this parser conservative. It is better to keep a placeholder than to save an ad/banner as cover.

**Step 4: Run focused parser tests**

```bash
swift test --package-path app --filter htmlSeriesMetadataParser
```

Expected: existing OpenGraph and JSON-LD tests still pass, new Asura-style test passes.

---

## Task 3: Ensure chapter-origin sessions request the canonical Asura series URL

**Files:**
- Inspect/modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Scoring/GenericChapterDetector.swift`
- Inspect/modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift` or `ReaderExperienceTests.swift`

**Step 1: Write a failing canonical URL test**

The Asura chapter URL is:

```text
https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/97
```

Expected series URL:

```text
https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5
```

Add a test against whichever function creates `MockReaderSession.seriesURL`. If no public helper exists, create/test a small helper such as `CanonicalSeriesURLResolver`.

```swift
@Test func canonicalSeriesURLResolverHandlesAsuraComicChapterURLs() throws {
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5/chapter/97"))

    let seriesURL = CanonicalSeriesURLResolver.seriesURL(for: chapterURL)

    #expect(seriesURL.absoluteString == "https://asurascans.com/comics/the-extras-academy-survival-guide-9a7a1ac5")
}
```

**Step 2: Run focused test to verify it fails**

```bash
swift test --package-path app --filter canonicalSeriesURLResolverHandlesAsuraComicChapterURLs
```

Expected: FAIL if no resolver or incorrect URL.

**Step 3: Implement canonical series URL resolution**

Implement a small generic resolver. Rules:

- For `/comics/<slug>/chapter/<number>` return `/comics/<slug>`.
- For existing `/series/<slug>/chapter-*` style paths, preserve current behavior.
- Fallback to current `deletingLastPathComponent()` if no known pattern matches.

Use the resolver where `MockReaderSession(seriesURL:)` is created from detection so metadata fetch uses the series/index URL, not the chapter URL.

**Step 4: Run detection/reader metadata tests**

```bash
swift test --package-path app --filter canonicalSeriesURLResolverHandlesAsuraComicChapterURLs
swift test --package-path app --filter htmlSeriesMetadataFetcherRequestsCanonicalSeriesURL
```

Expected: PASS.

---

## Task 4: Preserve existing covers when recent-reading input has no cover

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`

**Step 1: Write the failing test**

Add a test ensuring a later progress write without a cover does not erase an existing cover.

```swift
@Test func recentReadingDoesNotEraseExistingCoverWhenInputCoverIsNil() async throws {
    let repository = try makeInMemoryLibraryRepository()
    let seriesURL = try #require(URL(string: "https://asurascans.com/comics/sample"))
    let chapterURL = try #require(URL(string: "https://asurascans.com/comics/sample/chapter/97"))
    let coverURL = try #require(URL(string: "https://asurascans.com/uploads/sample-cover.webp"))

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: UUID(),
            chapterID: UUID(),
            seriesTitle: "Sample",
            seriesURL: seriesURL,
            sourceDomain: "asurascans.com",
            coverImageURL: coverURL,
            chapterTitle: "Chapter 97",
            chapterLabel: "97",
            sourceURL: chapterURL,
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
        )
    )

    try await repository.recordRecentReading(
        RecentReadingInput(
            seriesID: UUID(),
            chapterID: UUID(),
            seriesTitle: "Sample",
            seriesURL: seriesURL,
            sourceDomain: "asurascans.com",
            coverImageURL: nil,
            chapterTitle: "Chapter 98",
            chapterLabel: "98",
            sourceURL: chapterURL,
            imageURLs: [],
            progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1)
        )
    )

    let snapshot = await repository.snapshot()
    #expect(snapshot.recentReadSeries.first?.coverImageURL == coverURL)
}
```

Adapt helper names to existing test helpers in `PersistenceLifecycleTests.swift`.

**Step 2: Run focused test to verify it fails**

```bash
swift test --package-path app --filter recentReadingDoesNotEraseExistingCoverWhenInputCoverIsNil
```

Expected: FAIL if current code overwrites with nil.

**Step 3: Implement preservation**

In `recordRecentReading`, change existing-entry update from unconditional overwrite:

```swift
existing.coverImageURLString = input.coverImageURL?.absoluteString
```

to conditional replacement:

```swift
if let coverImageURL = input.coverImageURL {
    existing.coverImageURLString = coverImageURL.absoluteString
}
```

Make equivalent careful updates for saved library series if any path can erase covers with nil input.

**Step 4: Run focused persistence test**

```bash
swift test --package-path app --filter recentReadingDoesNotEraseExistingCoverWhenInputCoverIsNil
```

Expected: PASS.

---

## Task 5: Update defect statuses and run full verification

**Files:**
- Modify: `docs/defects.md`

**Step 1: Update docs after code is verified**

Only after tests/build pass, update:

- DEF-013 status to `Implemented`.
- DEF-014 status to `Implemented` if Asura fixture/canonical URL/persistence all pass.
- Add brief implemented-solution notes under each defect.

**Step 2: Run full tests**

```bash
swift test --package-path app
```

Expected: all tests pass.

**Step 3: Run iOS build**

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -sdk iphonesimulator -configuration Debug build
```

Expected: `BUILD SUCCEEDED`.

**Step 4: Manual QA checklist**

- Library screen: large `Library` title is readable white/light.
- Settings/Downloads screen headers are readable.
- Series Detail still avoids duplicate title.
- Open/read AsuraScans chapter, let progress write, then check Recent/Library card eventually shows series cover.
- Re-reading the same series without a cover payload does not regress the cover back to placeholder.

---

## Risks / notes

- Do not fix DEF-014 by hardcoding one cover URL or a piracy catalog list.
- Keep cover extraction conservative. A placeholder is better than an ad/banner/social image if confidence is low.
- If Asura blocks direct HTTP metadata fetches, use existing browser/detection metadata when available rather than lowering parser quality.
- If SwiftUI navigation-bar modifiers still fail for large titles, use a single iOS appearance configurator in the design system.
