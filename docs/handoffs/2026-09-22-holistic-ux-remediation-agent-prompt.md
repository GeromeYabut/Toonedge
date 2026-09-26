# ToonEdge UX Remediation Agent Prompt

Copy the prompt below into a new Codex task rooted at `/Users/geromeyabut/Developer/Toonedge`.

---

You are implementing the defects found in ToonEdge's 2026-09-22 hands-on simulator review.

Start by reading, in this order:

1. `AGENTS.md`
2. `docs/toonedge_architecture_doc.md`
3. `docs/toonedge_prd.md`
4. `docs/toonedge_ux_requirements_doc.md`
5. `docs/defects.md`, especially DEF-035 through DEF-046
6. `docs/qa_reports/2026-09-22-holistic-ux-quality-review.md`
7. `docs/superpowers/plans/2026-09-22-holistic-ux-remediation.md`

Execute the remediation plan task by task. Use test-driven development and keep every slice independently buildable and reviewable. Resolve all twelve open defects, DEF-035 through DEF-046, including protected-reader policy, Vortex in-site detection, Comizy image viability, large-text tab navigation, Downloads scrolling and accessibility, malformed URL validation, canonical chapter labels, Home fallback routing, Settings completion, large-text search copy, Library loading state, and Settings accessibility semantics.

Preserve the current uncommitted work. Before editing, record `git status --short` and the current revision. Do not reset, clean, stash, overwrite, or reformat unrelated files. Do not close or alter the shared iPhone 16 Pro; use a dedicated simulator such as the existing iPhone 16e. Do not bypass challenges, authentication, paywalls, or protected viewers. WEBTOON and protected GlobalComix pages must remain browser-only.

For each slice:

- Write a failing regression test first.
- Make the smallest architecture-aligned change.
- Run the focused tests and `swift test --package-path app --jobs 1`.
- Build and exercise the affected journey in a dedicated iPhone simulator.
- Record exact commands, results, screenshots/logs, and remaining limitations.
- Update the corresponding entry in `docs/defects.md` only after its acceptance criteria pass.

Add an XCUITest target because the observed Dynamic Type, tab-bar, Downloads, cold-relaunch, and accessibility regressions cannot be protected by model-only tests. Add sanitized site fixtures for Vortex, Comizy, ManhuaTop, MangaKatana, and MangaPill; never include copyrighted page images or credentials.

Do not declare the effort complete until all acceptance gates in `docs/superpowers/plans/2026-09-22-holistic-ux-remediation.md` have been run. If a live site is unavailable or has changed, keep that defect open, verify with the fixture, and clearly separate the site limitation from the app result.

At the end, report:

- Defects completed and defects still open
- Files and interfaces changed
- Unit, integration, UI, fixture, build, and live-simulator verification results
- Any migrations or compatibility risks
- Evidence paths
- Confirmation that pre-existing uncommitted work and the shared simulator were preserved

---
