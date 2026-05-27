# Second-Batch Template Classification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend the bucketed site-profile model with one additional supported hydrated-DOM site while documenting why the rest of the batch remains conservative.

**Architecture:** Reuse existing compatibility templates where evidence supports them. Add only thin registrations and fixtures for sites with verified behavior; leave blocked/inaccessible sites in the research catalog without runtime promotion.

**Tech Stack:** Swift, Swift Testing, Markdown docs, live HTTP inspection

---

### Task 1: Document batch 2 findings

**Files:**
- Modify: `docs/site_rendering_research_catalog.md`
- Modify: `docs/toonedge_epics_and_stories.md`

### Task 2: Add hydrated-DOM coverage for MangaPill

**Files:**
- Create: `app/Tests/ToonEdgeAppCoreTests/Fixtures/mangapill_hydrated_dom.json`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

### Task 3: Verify

**Files:**
- Verify: `docs/site_rendering_research_catalog.md`
- Verify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

**Steps:**
1. Run targeted detection tests.
2. Run the full suite.
3. Mark the story resolved after successful verification.
