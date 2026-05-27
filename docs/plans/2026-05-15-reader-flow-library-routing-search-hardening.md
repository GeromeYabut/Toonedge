# Reader Flow, Library Routing, and Search Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Reader exits explicit, enable direct library relaunch from stored payloads, wire real search history into suggestions, and harden ad exclusion.

**Architecture:** Extend the existing reader-session domain model, add a narrow repository reconstruction API, keep browser/reader coordination intact, and add router state for native library-detail handoff. Search remains local-first by layering persisted history over the current suggestion source.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing

---

### Task 1: Document the story
- Update PRD, UX, architecture, defects, and epics docs.
- Add focused design and handoff notes under `docs/plans/`.

### Task 2: Lock routing/search/persistence behavior with tests
- Add failing tests for Google query URLs, Reader `x` routing, native library-detail routing, persisted-history suggestions, stored-session reconstruction, and large-ad exclusion.

### Task 3: Extend session and routing models
- Add explicit series metadata to reader sessions.
- Add router support for source-series exit and pending library-detail destination.

### Task 4: Reuse persisted data
- Add repository API to rebuild reader sessions from stored chapters.
- Prefer direct Reader launch from stored payloads; use Browser fallback when payloads are incomplete.

### Task 5: Harden UX behavior
- Make chrome toggle reliable while visible.
- Add `Open in Library`.
- Switch default search provider to Google.
- Merge persisted history into visible suggestions.

### Task 6: Verify
- Run targeted regressions.
- Run the full package test suite.
- Manually verify Reader chrome, Reader exits, library relaunch, and search history reuse on device/simulator.
