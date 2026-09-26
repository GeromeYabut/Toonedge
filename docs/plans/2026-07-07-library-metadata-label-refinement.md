# Library Metadata Label Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Library metadata labels mode-specific: comfortable grid shows the source website, list rows show a useful chapter number, and compact grid keeps the Story 11.36 chapter label behavior.

**Architecture:** Keep this change inside the Library presentation layer. Add testable display-string properties to `LibrarySeriesCardContent` and consume them from the existing `SeriesCard`, `SeriesCompactTile`, and `SeriesListRow` views. Do not change domain models, persistence, parser output, update checks, Reader, Browser, or save-to-library grouping.

**Tech Stack:** Swift, SwiftUI, Swift Testing, existing ToonEdge design tokens and Library feature module.

## Global Constraints

- Work story by story and implement only Story 11.38.
- Preserve clean separation between SwiftUI view code, persistence, parsing, browser coordination, and repository logic.
- Do not change persistence schema, Reader detection, Browser behavior, chapter parsing, update checks, search classification, or save-to-library grouping behavior.
- Do not add new persisted fields or migrations.
- Do not redesign Library layout beyond metadata text shown in existing Library cells.
- Comfortable grid metadata must show the source website/domain.
- List metadata must show a chapter label when a numeric current or latest chapter label is available.
- Compact grid metadata must remain unchanged from Story 11.36.
- Avoid adding new dependencies.

---

## Files

- Modify: `docs/toonedge_epics_and_stories.md`
  - Story 11.38 source of truth.
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
  - Library display metadata derivation and view consumption.
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
  - Layout/display-string tests for comfortable, compact, and list metadata behavior.

## Design Decisions

- Keep `LibrarySeriesCardContent.metadata` for existing resume-style behavior to minimize unrelated churn.
- Add `sourceMetadata` for comfortable grid cards.
- Add `listMetadata` for list rows.
- Keep `compactMetadata` behavior unchanged:
  - `Ch. <latestChapterLabel>` when `latestChapterLabel` exists.
  - `Continue Ch. <currentChapterLabel>` when latest is unavailable and current exists.
  - `series.chapterSummaryText` otherwise.
- For list rows, prefer a numeric current chapter label when available.
- If `currentChapterLabel` is nonnumeric, such as `Scans`, fall back to numeric `latestChapterLabel`.
- If neither current nor latest chapter labels are numeric, fall back to the existing resume-style metadata.
- Display source domains as the stored `series.sourceDomain`, trimmed of whitespace and lowercased. If the stored domain is empty after trimming, fall back to `series.canonicalURL?.host()` and then `series.chapterSummaryText`.

## Task 1: Add Testable Mode-Specific Metadata Contracts

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Produces: `LibrarySeriesCardContent.sourceMetadata`.
- Produces: `LibrarySeriesCardContent.listMetadata`.
- Preserves: `LibrarySeriesCardContent.compactMetadata`.

- [ ] **Step 1: Write failing tests for source metadata and list metadata**

Add these tests near `libraryCompactCardMetadataPrefersShortChapterLabel` in `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`:

```swift
@Test func libraryComfortableCardMetadataShowsSourceWebsite() {
    let asura = LibrarySeriesSummary.mock(
        title: "The Regressed Mercenary",
        canonicalURL: URL(string: "https://asurascans.com/comics/the-regressed-mercenarys-machinations-a80d257e/chapter/16")!,
        currentChapterLabel: "Scans",
        latestChapterLabel: "16",
        sourceDomain: "asurascans.com"
    )

    #expect(LibrarySeriesCardContent(series: asura).sourceMetadata == "asurascans.com")
}

@Test func libraryListMetadataPrefersNumericChapterLabelOverNoisyCurrentLabel() {
    let noisyCurrent = LibrarySeriesSummary.mock(
        currentChapterLabel: "Scans",
        latestChapterLabel: "16",
        sourceDomain: "asurascans.com"
    )
    let numericCurrent = LibrarySeriesSummary.mock(
        currentChapterLabel: "237",
        latestChapterLabel: "300"
    )

    #expect(LibrarySeriesCardContent(series: noisyCurrent).listMetadata == "Ch. 16")
    #expect(LibrarySeriesCardContent(series: numericCurrent).listMetadata == "Ch. 237")
}
```

Update the existing private `LibrarySeriesSummary.mock` helper in the same file to accept `sourceDomain` before `canonicalURL`:

```swift
private extension LibrarySeriesSummary {
    static func mock(
        id: UUID = UUID(),
        title: String = "Moonlit Edge",
        sourceDomain: String = "example.com",
        canonicalURL: URL? = nil,
        libraryState: LibraryCollectionState = .reading,
        progressPercent: Double = 0.5,
        hasUnreadUpdates: Bool = false,
        lastReadAt: Date? = Date(timeIntervalSince1970: 1_700_000_000),
        currentChapterLabel: String? = "42",
        latestChapterLabel: String? = "100"
    ) -> LibrarySeriesSummary {
        LibrarySeriesSummary(
            id: id,
            title: title,
            sourceDomain: sourceDomain,
            canonicalURL: canonicalURL,
            coverImageURL: nil,
            progressPercent: progressPercent,
            chaptersRead: Int(progressPercent * 100),
            totalKnownChapters: 100,
            lastReadAt: lastReadAt,
            libraryState: libraryState,
            hasUnreadUpdates: hasUnreadUpdates,
            isCompleted: progressPercent >= 1,
            latestChapterLabel: latestChapterLabel,
            currentChapterLabel: currentChapterLabel
        )
    }
}
```

- [ ] **Step 2: Write a regression test that compact metadata remains unchanged**

Extend `libraryCompactCardMetadataPrefersShortChapterLabel` with this assertion:

```swift
let noisyCurrentWithLatest = LibrarySeriesSummary.mock(
    currentChapterLabel: "Scans",
    latestChapterLabel: "16",
    sourceDomain: "asurascans.com"
)

#expect(LibrarySeriesCardContent(series: noisyCurrentWithLatest).compactMetadata == "Ch. 16")
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: fails because `sourceMetadata` and `listMetadata` do not exist.

- [ ] **Step 4: Add minimal display-string properties**

In `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`, update `LibrarySeriesCardContent`:

```swift
struct LibrarySeriesCardContent: Equatable, Sendable {
    var metadata: String
    var sourceMetadata: String
    var compactMetadata: String
    var listMetadata: String

    init(series: LibrarySeriesSummary) {
        if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            self.metadata = "Continue Ch. \(currentChapterLabel)"
        } else {
            self.metadata = series.chapterSummaryText
        }

        let trimmedSourceDomain = series.sourceDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSourceDomain.isEmpty {
            self.sourceMetadata = trimmedSourceDomain.lowercased()
        } else if let host = series.canonicalURL?.host(), !host.isEmpty {
            self.sourceMetadata = host.lowercased()
        } else {
            self.sourceMetadata = series.chapterSummaryText
        }

        if let latestChapterLabel = series.latestChapterLabel {
            self.compactMetadata = "Ch. \(latestChapterLabel)"
        } else if let currentChapterLabel = series.currentChapterLabel, !series.isCompleted {
            self.compactMetadata = "Continue Ch. \(currentChapterLabel)"
        } else {
            self.compactMetadata = series.chapterSummaryText
        }

        if let currentChapterLabel = series.currentChapterLabel,
           Self.isChapterNumberLike(currentChapterLabel) {
            self.listMetadata = "Ch. \(currentChapterLabel)"
        } else if let latestChapterLabel = series.latestChapterLabel,
                  Self.isChapterNumberLike(latestChapterLabel) {
            self.listMetadata = "Ch. \(latestChapterLabel)"
        } else {
            self.listMetadata = self.metadata
        }
    }

    private static func isChapterNumberLike(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil
    }
}
```

- [ ] **Step 5: Run focused tests and verify pass**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 2: Use Mode-Specific Metadata in Library Cells

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Library/Views/LibraryView.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`

**Interfaces:**
- Consumes: `LibrarySeriesCardContent.sourceMetadata`.
- Consumes: `LibrarySeriesCardContent.listMetadata`.
- Preserves: `LibrarySeriesCardContent.compactMetadata`.

- [ ] **Step 1: Write a rendering-contract test for mode metadata selection**

Add this test near `libraryGridCardsAvoidOuterGeneratedCardContainer`:

```swift
@Test func libraryModeMetadataContractsUseDistinctDisplayStrings() {
    let series = LibrarySeriesSummary.mock(
        canonicalURL: URL(string: "https://asurascans.com/comics/the-regressed-mercenarys-machinations-a80d257e/chapter/16")!,
        currentChapterLabel: "Scans",
        latestChapterLabel: "16",
        sourceDomain: "asurascans.com"
    )
    let content = LibrarySeriesCardContent(series: series)

    #expect(content.sourceMetadata == "asurascans.com")
    #expect(content.compactMetadata == "Ch. 16")
    #expect(content.listMetadata == "Ch. 16")
}
```

- [ ] **Step 2: Run tests and verify pass before rendering change**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass. This confirms the display strings exist before changing views.

- [ ] **Step 3: Update comfortable grid card to use source metadata**

In `SeriesCard.body`, replace:

```swift
Text(content.metadata)
```

with:

```swift
Text(content.sourceMetadata)
```

- [ ] **Step 4: Update list row to use list metadata**

In `SeriesListRow.body`, replace:

```swift
Text(content.metadata)
```

with:

```swift
Text(content.listMetadata)
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: `LibraryExperienceTests` pass.

## Task 3: Full Verification

**Files:**
- Test-only verification across the package and app target.

- [ ] **Step 1: Run the full Swift package test suite**

Run:

```bash
swift test --package-path app
```

Expected: all tests pass.

- [ ] **Step 2: Build the app target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 3: Manual visual check in Simulator**

Open the Library tab with a saved Asura title and verify:

- Comfortable grid subtitle shows `asurascans.com`.
- List row subtitle shows `Ch. 16`.
- Compact grid still shows `Ch. 16`.
- No Library filters, view modes, or title navigation changed.

## Risks

- Current chapter labels may already contain nonnumeric but valid chapter names, such as side-story labels. This story intentionally prefers numeric labels for list rows to solve the observed `Scans` issue and falls back to the existing resume-style metadata when no numeric label exists.
- Source domain display depends on existing `sourceDomain` quality. This story does not change extraction or persistence.
- Existing tests are grouped in `LibraryExperienceTests.swift`; this plan follows that local organization rather than introducing a new test file.

## Self-Review

- Story coverage: Story 11.38 acceptance criteria map to Tasks 1-3.
- Scope check: no persistence, parser, Reader, Browser, update-check, or save-to-library changes are included.
- Type consistency: `sourceMetadata`, `compactMetadata`, and `listMetadata` are defined on `LibrarySeriesCardContent` and consumed only by Library presentation views.
- Placeholder scan: no implementation step depends on unresolved behavior or unspecified values.
