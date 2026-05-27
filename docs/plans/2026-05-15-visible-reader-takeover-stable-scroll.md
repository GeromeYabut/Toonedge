# Visible Reader Takeover And Stable Long-Page Scrolling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add browser-owned Reader presentation diagnostics and stabilize long-chapter placeholder sizing from detected image metadata.

**Architecture:** Keep the current Browser-owned Reader flow, but expose a small presentation diagnostic state from `BrowserViewModel` so tests and QA can verify the runtime path. Extend Reader sessions with optional ordered page metadata, populated by detection and consumed by Reader placeholder layout.

**Tech Stack:** Swift, SwiftUI, Swift Testing

---

### Task 1: Document and test Browser-owned Reader presentation diagnostics

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`
- Modify: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/ViewModels/BrowserViewModel.swift`

**Steps:**
1. Write a failing test proving the browser view model reports pending and visible Reader presentation states.
2. Run the focused browser tests and confirm failure.
3. Add the minimal diagnostic state API to `BrowserViewModel`.
4. Re-run the focused browser tests and confirm pass.

### Task 2: Preserve detected page dimensions in Reader sessions

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Scoring/GenericChapterDetector.swift`

**Steps:**
1. Write a failing detection test proving detected Reader sessions retain image width and height metadata.
2. Run the focused detection test and confirm failure.
3. Add `ReaderPageMetadata` and populate it from normalized candidates.
4. Re-run the focused detection test and confirm pass.

### Task 3: Use aspect-ratio-aware placeholder sizing

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`

**Steps:**
1. Write failing tests for metadata-derived placeholder height and fallback height.
2. Run the focused reader tests and confirm failure.
3. Add a small placeholder-height calculator and feed metadata into `ReaderImagePanel`.
4. Re-run the focused reader tests and confirm pass.

### Task 4: Verify the slice

**Files:**
- Review: `docs/defects.md`

**Steps:**
1. Run `swift test --jobs 1`.
2. Review `DEF-003` against the implemented diagnostics and sizing changes.
3. Record remaining runtime QA needed for the actual Vortex browser handoff.
