# Site Profile Compatibility Classes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add explicit site-profile compatibility classes and wire the first four representative site profiles into detection with fixture-backed regression coverage.

**Architecture:** Extend the existing Detection site-profile model rather than adding a second registry. Unknown domains keep using generic heuristics; known domains use compatibility classes to decide whether current extraction is safe, hydration-aware, browser-session deferred, or browser-only suppressed.

**Tech Stack:** Swift, Swift Testing, existing ToonEdge detection modules

---

### Task 1: Add compatibility-class tests

**Files:**
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

**Steps:**
1. Add failing tests for the new compatibility enum and registry defaults.
2. Add failing tests for embedded, hydrated, browser-session, and browser-only detector behavior.
3. Run the targeted detection test suite and confirm failures are due to missing compatibility behavior.

### Task 2: Extend the profile model

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Models/DetectionModels.swift`

**Steps:**
1. Add the compatibility enum and store it on `SiteProfile`.
2. Extend diagnostics with the compatibility class.
3. Register the four representative domains with their correct class.
4. Re-run the targeted tests.

### Task 3: Enforce class-aware detection behavior

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Services/ProfileAwareChapterDetector.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Scoring/GenericChapterDetector.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Services/DetectionDiagnosticsLogger.swift`

**Steps:**
1. Keep embedded and hydrated profiles on the current profile-aware extraction path.
2. Return explicit low-confidence diagnostics for browser-session profiles.
3. Preserve browser-only suppression.
4. Include compatibility in diagnostics output.
5. Run targeted tests until green.

### Task 4: Verify and document

**Files:**
- Verify: `docs/toonedge_epics_and_stories.md`
- Verify: `docs/site_rendering_research_catalog.md`
- Verify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

**Steps:**
1. Run the full test suite.
2. Confirm docs and code describe the same four classes.
3. Record what remains for browser-session extraction and future site expansion.
