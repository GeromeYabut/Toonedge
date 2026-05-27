# ToonEdge Codex Agent Instructions

## Mission
You are implementing ToonEdge, an iPhone-first app that converts cluttered manhwa chapter webpages into a clean native reader experience.

Your job is to deliver the app incrementally, with clean architecture, testable code, and strict respect for MVP scope.

Do not attempt to build the entire product at once. Build in thin vertical slices.

---

## Source of Truth

Use documents in this priority order:

1. Architecture / Technical Design Doc for technical boundaries, module ownership, and persistence/service architecture
2. Product Requirements Document for product scope and MVP boundaries
3. Screen Specification / UX Requirements for user-facing behavior, interaction states, and screen acceptance criteria
4. UX Brief for intent and visual direction
5. Epic / Story Breakdown for delivery sequencing

If documents conflict, do not guess silently. Flag the conflict clearly. For user-facing behavior, use the UX requirements document as the behavioral source of truth unless it conflicts with PRD scope.
Use mockups/screenshots/Stitch exports as visual and layout references only.  
Use the UX requirements doc as the behavioral source of truth.  
If mockups and docs conflict, follow the docs and explicitly call out the conflict.

---

## Product Summary

ToonEdge is:
- a smart reading browser
- with a personal library attached

It is not:
- a hosted content platform
- a curated content marketplace
- a generic manga catalog app

Key product behaviors:
- Home includes a universal search / URL bar
- Search input can be URL or web query
- Query/search results open in the in-app browser
- Detection runs after page load
- High-confidence chapter pages auto-open in Reader Mode
- Medium-confidence pages show “Read in Clean Mode”
- Low-confidence pages remain in browser
- Reader must always support “View Original Page”
- Library, progress, update checks, and cache are local-first
- Multi-page chapter stitching is NOT MVP

---

## Working Style

### 1. Work story by story
For each task:
- identify the story being implemented
- state dependencies
- implement only what is required for that story
- leave extension points for future work

### 2. Build thin vertical slices
Prefer:
- one fully working search flow
over:
- many incomplete screens

Prefer:
- a mock-backed end-to-end flow
over:
- scaffolding all features with no working behavior

### 3. Separate layers cleanly
Do not mix:
- SwiftUI view code
- persistence
- parsing
- browser coordination
- scoring logic

UI must not own parsing or persistence details directly.

### 4. Use stable interfaces
Where a subsystem is not complete yet:
- define a protocol or interface
- provide a mock implementation
- keep UI and feature code unblocked

### 5. Respect MVP boundaries
Do NOT implement unless explicitly requested:
- multi-page chapter stitching
- cloud sync
- recommendations
- social/community features
- ML-based detection
- browser tabs

---

## Architecture Expectations

Use a modular structure, with clear boundaries such as:
- AppShell
- Home/Search
- Browser
- Detection
- Reader
- Library
- Cache/Downloads
- Settings
- Shared UI / Design System
- Persistence / Repositories

Recommended principles:
- dependency injection
- repository pattern for persistence
- feature-level view models / controllers
- isolated parsing/detection services
- testable business logic

---

## UX Expectations

Follow these UX rules carefully:

### Search
- The Home search bar is a primary feature, not a secondary utility
- It must accept URLs and search queries
- The user should not need to think about input type
- Search suggestions should feel immediate and local-first

### Detection
- Detection should be conservative for high-confidence auto-open
- False positives are worse than false negatives
- High-confidence: auto-open Reader Mode
- Medium-confidence: show CTA
- Low-confidence: do nothing

### Reader
- Reader should feel immersive and calm
- Keep chrome minimal
- Always include a way to return to the original page
- Do not place product branding prominently in reader chrome

### Home
- Home is search-first and library-supported
- Continue Reading should be highly accessible
- Search should visually dominate over decorative content

---

## Implementation Process

For each story:
1. Summarize the story in 3–6 bullets
2. Identify affected modules/files
3. Note assumptions
4. Implement the smallest working slice
5. Add tests where logic is non-trivial
6. Report:
   - what was completed
   - what remains
   - risks / known gaps

---

## Output Expectations

When asked to implement work, provide:
- code changes
- a brief explanation of the approach
- any schema/interface updates
- tests added
- follow-up recommendations

When asked to plan work, provide:
- story breakdown
- dependencies
- risks
- suggested order of implementation

Do not provide excessive prose when code or specific implementation detail is needed.

---

## Testing Expectations

At minimum, add tests for:
- search input classification
- heuristic scoring
- confidence mapping
- library/progress persistence
- update-check comparison logic

Add integration/UI tests for key flows when feasible:
- Home search to browser
- browser to reader auto-open
- medium-confidence CTA flow
- resume reading
- return to original page

---

## Performance Expectations

Be careful with:
- long vertical image chapters
- repeated page detection runs
- large local caches
- main-thread work in browser or reader flows

Prefer:
- lazy loading
- lightweight parsing passes
- background-friendly decoding/caching where appropriate

---

## Safety / Product Guardrails

Do not:
- hardcode piracy-oriented catalogs
- make assumptions that all sites share identical DOM structure
- auto-open Reader Mode aggressively without confidence thresholding
- remove the user’s ability to view the original page

Do:
- build site-profile support cleanly
- fall back to generic heuristics
- degrade gracefully when parsing fails

---

## If You Are Missing Information

If a required detail is missing:
- make the smallest reasonable assumption
- document it clearly
- avoid blocking unless the decision is truly product-critical

Flag missing information when it affects:
- architecture direction
- data model stability
- MVP scope
- UX trust behaviors

---

## Preferred Delivery Order

Unless instructed otherwise, prioritize implementation in this order:
1. app shell + design tokens
2. Home + search bar + search overlay
3. browser shell
4. input classification
5. reader shell with mock data
6. detection engine
7. browser → reader conversion
8. local library + progress
9. series detail
10. cache/download basics
11. update checks
12. hardening and tests

---

## Definition of Done

A story is done when:
- behavior matches the story’s acceptance criteria
- code compiles and runs
- logic is placed in the correct layer
- tests are present for non-trivial logic
- known limitations are stated explicitly
