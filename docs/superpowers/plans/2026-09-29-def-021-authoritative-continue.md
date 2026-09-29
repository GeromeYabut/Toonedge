# DEF-021 Authoritative Continue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for production changes, superpowers:systematic-debugging for unexpected failures, and superpowers:verification-before-completion before committing. Execute this plan after DEF-020 is integrated.

**Goal:** Prove that Series Detail immediately and durably continues the most recently active in-progress chapter, including chapters first discovered through Reader adjacency.

**Architecture:** Keep `SeriesPrimaryChapterSelector` and `SwiftDataLibraryRepository.continueReadingTarget(for:)` authoritative. The deterministic UI fixture is a stateful test double used only to drive the existing Series Detail refresh seam; repository reconstruction remains proven by the package regression. Do not create another chapter-label parser or couple primary-action selection to Recent display ordering.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, SwiftData, XCUITest.

## Acceptance criteria

- Chapter 1 exists, but newer in-progress Chapter 3 is the Series Detail CTA and opens Chapter 3.
- Dismissing Reader refreshes Series Detail immediately.
- Repository reconstruction retains Chapter 3 as the target.
- A chapter discovered through adjacent Reader navigation becomes a persisted target.
- Planned/unread series behavior is unchanged.

---

### Task 1: Re-run and strengthen the repository contract first

**Files:**
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Conditional modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift`

- [ ] **Step 1: Run the existing authoritative-target regression**

```bash
swift test --package-path app --jobs 1 \
  --filter seriesDetailContinueUsesDiscoveredChapterThreeImmediatelyAndAfterRepositoryReconstruction
```

Expected: pass. Record it as the package-level proof for chapter 1 versus newer Chapter 3 and repository reconstruction.

- [ ] **Step 2: Add the smallest missing adjacent-discovery assertion**

Extend the nearest existing discovery regression, or add one focused test, so it records a newly discovered Chapter 3 through the same recent/progress write path Reader uses and asserts:

```swift
#expect(detail.primaryActionTitle == "Continue Chapter 3")
#expect(detail.primaryChapter?.id == chapter3ID)
#expect(target.chapterID == chapter3ID)
```

Also reconstruct `SwiftDataLibraryRepository` from the same `ModelContainer` and repeat the assertions.

- [ ] **Step 3: Run the new test and record RED if it exposes a gap**

```bash
swift test --package-path app --jobs 1 \
  --filter adjacentDiscoveredChapterBecomesAuthoritativeContinueTargetImmediatelyAndAfterReconstruction
```

Expected: either the new regression passes against the completed DEF-021 domain work, or fails specifically because the adjacent discovery is not selected/persisted. A passing evidence-only regression does not justify a production change.

- [ ] **Step 4: If RED, fix only the repository selector path**

Use the existing `ChapterNumericLabelExtractor`, normalization, `SeriesPrimaryChapterSelector`, recent-reading reconciliation, and `recordReadingProgress`. Do not add a view-owned selector or chapter parser. Preserve first-readable behavior when there is no progress.

- [ ] **Step 5: Run focused package tests**

```bash
swift test --package-path app --jobs 1 \
  --filter seriesDetailContinueUsesDiscoveredChapterThreeImmediatelyAndAfterRepositoryReconstruction
swift test --package-path app --jobs 1 \
  --filter adjacentDiscoveredChapterBecomesAuthoritativeContinueTargetImmediatelyAndAfterReconstruction
```

Expected: both pass.

### Task 2: Add a deterministic Continue journey fixture

**Files:**
- Modify: `app/ToonEdge/ToonEdgeAppEntry.swift`
- Modify: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`

**Interfaces:**
- Extends: `ReaderHardeningFixtureScenario`
- Exercises: `SeriesDetailView.onChange(of: router.presentedReader)` and `reloadDetail()`
- Does not replace: SwiftData reconstruction coverage from Task 1

- [ ] **Step 1: Extend the typed fixture enum**

Add:

```swift
case continueAdjacentDiscovery = "continue-adjacent-discovery"
```

Keep `continue-target` for the chapter 1/newer Chapter 3 journey.

- [ ] **Step 2: Add a fixture-only stateful library service**

Implement one actor conforming to the existing library lifecycle/progress protocols. It must:

- expose a single sanitized series containing stored Chapter 1;
- expose newer Chapter 3 as the authoritative in-progress target;
- return `Continue Chapter 3` from its detail snapshot and Chapter 3 from `continueReadingTarget`;
- return Reader sessions by chapter ID/source URL;
- update its target only when `recordReadingProgress` or the existing recent-reading path records a genuinely newer active chapter;
- use a namespaced `UserDefaults` key only for deterministic UI-fixture relaunch state;
- clear that key when `-resetTestData` is supplied.

Name the type clearly as a UI-test fixture. Do not present its `UserDefaults` persistence as production repository evidence.

- [ ] **Step 3: Wire dependencies through existing seams**

For `.continueTarget` and `.continueAdjacentDiscovery`, assign the same fixture actor to the compatible `AppDependencies` library, lifecycle, recent-reading, and progress properties. For adjacent discovery, also provide a loader returning sanitized Chapter 3 from Chapter 2.

Route `.continueTarget` to the normal Library tab. Route `.continueAdjacentDiscovery` to a Reader session for Chapter 2 whose Next target is Chapter 3 and whose launch origin returns to the fixture series.

- [ ] **Step 4: Parse the app source**

```bash
xcrun swiftc -parse app/ToonEdge/ToonEdgeAppEntry.swift
```

Expected: exit 0.

### Task 3: Prove immediate return, relaunch, and adjacent discovery in UI

**Files:**
- Modify: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`

- [ ] **Step 1: Add a Series Detail helper**

Launch with:

```swift
["-uiTesting", "-resetTestData", "-readerHardeningFixture", "continue-target"]
```

Open the fixture series from Library using accessibility identifiers or visible fixture labels; do not use coordinate taps except to reveal Reader chrome.

- [ ] **Step 2: Add the immediate-return regression**

Assert the CTA label is `Continue Chapter 3`, tap it, assert `reader.chapter.label` contains `Chapter 3`, dismiss Reader with Back, and assert the refreshed CTA still reads `Continue Chapter 3` with the current progress presentation.

- [ ] **Step 3: Add the relaunch regression**

Terminate without resetting, relaunch with:

```swift
["-uiTesting", "-readerHardeningFixture", "continue-target"]
```

Return to Series Detail and assert the same Chapter 3 CTA opens Chapter 3. Document that SwiftData reconstruction is established by Task 1 and that this UI relaunch uses fixture persistence only.

- [ ] **Step 4: Add the adjacent-discovery regression**

Launch `.continueAdjacentDiscovery`, navigate from Chapter 2 to Chapter 3, wait for Reader progress recording, return to Series Detail, and assert the CTA is `Continue Chapter 3`. Relaunch once without reset and repeat the CTA assertion.

- [ ] **Step 5: Run focused UI tests on iPhone 16 Pro Max**

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-def021-derived \
  test -only-testing:ToonEdgeUITests/ToonEdgeAuthoritativeContinueUITests \
  -resultBundlePath /private/tmp/toonedge-def021.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Expected: immediate return, relaunch, and adjacent discovery all pass.

### Task 4: Verify, document, and commit

**Files:**
- Modify only after acceptance passes: `docs/defects.md`
- Create: `docs/qa_evidence/2026-09-29-def-021-authoritative-continue.md`

- [ ] Run:

```bash
swift test --package-path app --jobs 1
git diff --check
```

- [ ] Record exact commands, package/UI counts, `/private/tmp/toonedge-def021.xcresult`, the distinction between SwiftData and UI-fixture persistence, screenshots containing only sanitized fixture content, and limitations.
- [ ] Mark DEF-021 verified only when every acceptance criterion above passes.
- [ ] Stage exact owned files and commit:

```bash
git add \
  app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift \
  app/ToonEdge/ToonEdgeAppEntry.swift \
  app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift \
  docs/defects.md \
  docs/qa_evidence/2026-09-29-def-021-authoritative-continue.md
git commit -m "test: verify authoritative continue journey"
```

If production code changed, add its exact path and use `fix: preserve authoritative continue target` instead. Confirm the three protected screenshots remain untracked and byte-identical.
