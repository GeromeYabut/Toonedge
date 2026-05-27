# Fixture-Backed Profile Templates Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add fixture-backed compatibility coverage and refactor site handling into reusable templates plus thin domain registrations.

**Architecture:** `SiteProfileTemplate` defines shared compatibility behavior. `SiteProfile` references a template and optionally overrides selector hints. Detection behavior remains unchanged while duplication is reduced.

**Tech Stack:** Swift, Swift Testing, JSON test resources

---

### Task 1: Add fixture-backed tests

**Files:**
- Create: `app/Tests/ToonEdgeAppCoreTests/Fixtures/*.json`
- Modify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`

**Steps:**
1. Add failing tests that load representative JSON page-analysis fixtures.
2. Add failing tests proving each compatibility bucket still produces the expected result.
3. Add a failing test proving related Asura domains share the same template.

### Task 2: Add reusable templates

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Detection/SiteProfiles/SiteProfileRegistry.swift`

**Steps:**
1. Introduce `SiteProfileTemplate`.
2. Refactor `SiteProfile` to reference a template with optional selector-hint overrides.
3. Rebuild the default registry using shared templates.

### Task 3: Verify no behavior regression

**Files:**
- Verify: `app/Tests/ToonEdgeAppCoreTests/DetectionEngineTests.swift`
- Verify: `docs/site_rendering_research_catalog.md`

**Steps:**
1. Run targeted detection tests.
2. Run the full package suite.
3. Confirm docs and code both describe bucketed behavior rather than bespoke per-site parsing.
