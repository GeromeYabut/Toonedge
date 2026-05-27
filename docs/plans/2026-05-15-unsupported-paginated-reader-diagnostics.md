# Unsupported Paginated Reader Diagnostics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add explicit paginated-reader classification and diagnostics while preserving browser-only behavior for MVP.

**Architecture:** Extend the existing shared template model with one research-backed negative-control template. Detection behavior stays conservative; only the classification and diagnostics become more precise.

**Tech Stack:** Swift, Swift Testing, JSON fixtures

---

### Task 1: Add negative-control tests

**Files:**
- Create: `app/Tests/ToonEdgeAppCoreTests/Fixtures/mangahere_paginated_single_page.json`
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

### Task 2: Extend classification and diagnostics

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Models/DetectionModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/Services/ProfileAwareChapterDetector.swift`

### Task 3: Verify

**Steps:**
1. Run targeted detection tests.
2. Run the full package suite.
3. Mark the story resolved after verification.
