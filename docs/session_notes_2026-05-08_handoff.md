# ToonEdge Session Notes — 2026-05-08

## Session Goal
Prepare the project for Session 2 by reviewing the product, UX, architecture, and epic docs; resolving planning ambiguities; and confirming the MVP foundation is clear enough to begin implementation.

## Repo Guidance
- Follow root `AGENTS.md`.
- Use docs in this priority order:
  1. Architecture for technical boundaries and module ownership
  2. PRD for product scope and MVP boundaries
  3. UX requirements for user-facing behavior and interaction states
  4. UX brief for intent and visual direction
  5. Epics/stories for delivery sequence
- UX requirements are the behavioral source of truth unless they conflict with PRD scope.
- Mockups are visual/layout references only. If docs and mockups conflict, follow docs and call out the conflict.

## Key Documents
- `docs/architecture.md` links to `docs/toonedge_architecture_doc.md`
- `docs/prd.md` links to `docs/toonedge_prd.md`
- `docs/ux-requirements.md` links to `docs/toonedge_ux_requirements_doc.md`
- `docs/ux-brief.md` links to `docs/toonedge_ux_brief.md`
- `docs/epics-and-stories.md` links to `docs/toonedge_epics_and_stories.md`

## Decisions Made
- MVP bottom tabs are Home, Library, Downloads, and Settings.
- Browser is launched from Home/Search and preserved behind Reader for “View Original Page”; it is not a required bottom tab.
- SwiftData is the MVP persistence store behind repository protocols.
- Manual offline-retain downloads are deferred. MVP should scaffold Downloads and support recent cache visibility/removal first.
- Update checks run on foreground, pull-to-refresh, and selected series open. Background refresh is future.
- Detection thresholds are now defined in the architecture doc.
- Launch site policy now has three tiers:
  - `enabledPublic`: ComicFury, The Duck Webcomics, generic creator-owned/self-hosted webcomic pages.
  - `approvedNonPromoted`: Asura Scans, ManhwaTop, ManhuaTop, ManhwaClan, MangaBuddy, Vortex Scans, Flame Scans/Flame Comics, RoliaScan.
  - `browserOnly`: WEBTOON, Tapas, MANGA Plus, GlobalComix paid/login/protected-reader pages, and sources requiring auth/DRM/blob/canvas/anti-bot bypass.
- Approved non-promoted sources should render correctly in Reader when the user explicitly opens a page/URL and detection passes.
- Approved non-promoted sources must not appear as suggestions, recommendations, onboarding examples, source lists, or catalog entries.
- Clarification from user: content from approved non-promoted sources should still be saveable to Library after the user opens it. “No catalog entries” means no app-driven source discovery/promotion, not no saving.

## Architecture State
- Proposed Xcode folder/module tree is documented in `docs/toonedge_architecture_doc.md` under “5.12 Proposed Xcode Project Structure”.
- Module breakdown is documented under “5. Module Breakdown”.
- Required modules are covered:
  - AppShell
  - Home/Search
  - Browser
  - Detection
  - Reader
  - Library
  - Downloads/Cache
  - Settings
  - Shared UI / Design System
  - Persistence / Repositories

## Detection Policy
- Detection runs only after browser page load and page stabilization.
- High confidence auto-opens Reader.
- Medium confidence shows “Read in Clean Mode”.
- Low confidence remains in Browser.
- Conservative high-confidence thresholds are required; false positives are worse than false negatives.
- Hard gates, candidate image filters, scoring model, and confidence thresholds are documented in `docs/toonedge_architecture_doc.md` under section 9.5.

## Epic 1 Recommendation
Epic 1 story order is documented in `docs/toonedge_epics_and_stories.md`:
1. Story 1.1 — Set up project structure
2. Story 1.3 — Implement design tokens and shared UI primitives
3. Story 1.2 — Implement app shell and navigation
4. Story 1.4 — Create root routing and modal presentation framework

## Session 2 Readiness
Ready to move to Session 2. Criteria verified:
- clear proposed folder/module tree
- clean module breakdown
- contradictions and missing requirements identified
- recommended Epic 1 order documented
- no obvious MVP misunderstandings

## Remaining Clarifications / Open Items
- Add one explicit sentence to the docs before or during Session 2:
  “Approved non-promoted sources may be saved to the user’s Library after the user explicitly opens a series/chapter URL; the restriction is against app-driven discovery, suggestions, recommendations, or source catalogs.”
- Fixture validation still needs to be performed when Detection/SiteProfiles are implemented. This means testing positive and negative representative pages to ensure chapter pages pass and listing/search/catalog pages do not auto-open Reader.
- Current repo has no initial commit yet. `git status` shows all files untracked.

## Recommended Next Agent Start
Start Session 2 with Epic 1, Story 1.1:
- Set up the Xcode/SwiftUI project structure only.
- Create folders/modules per architecture doc.
- Establish dependency injection and mock service protocols.
- Do not implement real Browser, Detection, Reader, Library persistence, or site parsing yet.
- Keep the first slice thin and compilable.
