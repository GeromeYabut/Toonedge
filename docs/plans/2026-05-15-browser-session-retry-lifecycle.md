# Browser-Session Retry Lifecycle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add one bounded retry pass for browser-session profiles so pages can wait for DOM stabilization before Reader eligibility is decided.

**Architecture:** Detection carries retry metadata; `ProfileAwareChapterDetector` decides when a retry is allowed; `BrowserWebView.Coordinator` schedules at most one follow-up analysis for the same URL. Current generic scoring remains the only promotion path.

**Tech Stack:** Swift, SwiftUI/WebKit, Swift Testing

---

### Task 1: Add retry-behavior tests

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`

**Steps:**
1. Add failing tests for retry metadata on browser-session initial results.
2. Add failing tests for retry promotion and retry exhaustion.
3. Add a failing browser retry-policy test for one retry per URL.

### Task 2: Extend detection models and policy

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Models/DetectionModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Services/ProfileAwareChapterDetector.swift`

**Steps:**
1. Add retry metadata to detection results and diagnostics.
2. Let browser-session profiles recommend a retry on the first pass.
3. Add an explicit retry analysis path that can reuse normal scoring on the follow-up pass.

### Task 3: Add bounded browser retry scheduling

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`

**Steps:**
1. Track retry state per URL.
2. Schedule one delayed follow-up analysis when the detector recommends it.
3. Prevent repeated retry loops.

### Task 4: Verify

**Files:**
- Verify: `docs/toonedge_epics_and_stories.md`
- Verify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
- Verify: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`

**Steps:**
1. Run targeted tests.
2. Run the full package test suite.
3. Confirm resolved-story tagging is limited to clearly completed stories.
