# Quiet Editorial Multi-Agent Execution Guide

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:using-git-worktrees before implementation and superpowers:subagent-driven-development inside each story worktree. Every implementer uses superpowers:test-driven-development; every story receives an independent task review before integration.

## Objective

Execute Epic 12 without allowing multiple agents to edit the same checkout or collide in shared Swift files. Parallel implementation is allowed only in isolated worktrees based on the same reviewed integration revision.

## Plan index

| Story | Plan |
|---|---|
| 12.1 | `docs/superpowers/plans/2026-09-27-story-12.1-adaptive-editorial-foundation.md` |
| 12.2 | `docs/superpowers/plans/2026-09-27-story-12.2-home-search-editorial-entry.md` |
| 12.3 | `docs/superpowers/plans/2026-09-27-story-12.3-browser-editorial-chrome.md` |
| 12.4 | `docs/superpowers/plans/2026-09-27-story-12.4-reader-editorial-controls.md` |
| 12.5 | `docs/superpowers/plans/2026-09-27-story-12.5-library-series-editorial-surfaces.md` |
| 12.6 | `docs/superpowers/plans/2026-09-27-story-12.6-downloads-settings-utilities.md` |
| 12.7 | `docs/superpowers/plans/2026-09-27-story-12.7-semantic-haptics.md` |
| 12.8 | `docs/superpowers/plans/2026-09-27-story-12.8-editorial-release-qa.md` |

## Dependency graph

```text
12.1 Adaptive foundation
  ├─ 12.2 Home + Search ───────────────┐
  ├─ 12.3 Browser ─────────────────────┤
  ├─ 12.4 Reader ──────────────────────┤
  ├─ 12.5 Library + Series Detail ─────┤
  └─ 12.6 Downloads + Settings ────────┤
                                       v
                           12.7 Semantic haptics
                                       v
                           12.8 Integration + QA
```

Story 12.7 waits because it touches outcome sites in every screen story. Story 12.8 waits for all implementation branches.

## Safe concurrency waves

The controller plus three workers fits the current four-slot limit.

### Wave 0 — planning baseline

1. Commit the design, story, and plan documents.
2. Record `git status --short`, `git rev-parse HEAD`, and branch.
3. Hash the three protected screenshots for later unchanged verification.
4. Run `swift test --package-path app --jobs 1` as the baseline.

### Wave 1 — foundation, serial

- One implementer: Story 12.1.
- One independent reviewer after implementation.
- Merge only after focused tests, full Swift suite, build, and visual appearance checks pass.

No screen story begins before the Story 12.1 interface is merged and documented.

### Wave 2A — three isolated screen worktrees in parallel

- Agent A: Story 12.2 Home + Search.
- Agent B: Story 12.3 Browser.
- Agent C: Story 12.5 Library + Series Detail.

These branches share only the already-merged Story 12.1 contracts. They must not edit each other's feature files. If a worker discovers that a SharedUI API must change, it stops and reports the requested change to the controller; it does not mutate the shared contract independently.

Simulator work is leased separately from source work:

- Agent A may lease iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`.
- Agent B may lease iPhone 16 Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`.
- Agent C completes source/unit work, then waits for one lease before UI/manual verification.
- The controller records the active lease; only one worker may install, change accessibility/appearance state, run UI tests, or interact with a given simulator at a time.
- Each story uses a distinct DerivedData/result path such as `/private/tmp/toonedge-story-12.2-derived` and `/private/tmp/toonedge-story-12.2-results`.
- A worker cannot report DONE until its leased simulator checks finish and the controller releases the lease.

### Wave 2B — two isolated screen worktrees in parallel

- Agent D: Story 12.4 Reader.
- Agent E: Story 12.6 Downloads + Settings.

Start from the integration revision after Wave 2A is merged. Story 12.4 and 12.6 may both touch Settings-related tests, so the controller must inspect the changed-file sets before merging. If both modify the same test method, merge sequentially and resolve by retaining both behaviors.

Wave 2B uses the same lease queue: one story leases the 16e, the other the Pro Max, with distinct DerivedData/result paths. No worker may change the other simulator's state.

### Wave 3 — haptics, serial

- One implementer: Story 12.7.
- It starts from all reviewed screen stories and adds feedback at authoritative outcome sites.
- One independent reviewer verifies event counts, silent events, preference isolation, and actor boundaries.

### Wave 4 — integration and QA, serial

- One integration worker: Story 12.8.
- One final whole-branch reviewer using the complete merge-base-to-HEAD review package.
- Finish with the branch-completion workflow only after all Critical/Important findings are resolved.

## Worktree and branch setup

Use the platform's native worktree option when creating a Codex task. If operating manually, first follow `superpowers:using-git-worktrees` and verify the repository-local worktree directory is ignored.

Suggested integration and story branches:

```text
epic-12-quiet-editorial
story-12.1-adaptive-editorial-foundation
story-12.2-home-search-editorial-entry
story-12.3-browser-editorial-chrome
story-12.4-reader-editorial-controls
story-12.5-library-series-editorial-surfaces
story-12.6-downloads-settings-utilities
story-12.7-semantic-haptics
story-12.8-editorial-release-qa
```

Never run multiple implementation agents in the same checkout. Read-only research/review agents may share a checkout; writers may not.

## Protected local evidence

These files remain untracked in the primary checkout and must never be read by workers, copied into worktrees, edited, moved, staged, or committed:

- `docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png`
- `docs/qa_evidence/2026-09-22/manhuatop-original-page.png`
- `docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png`

The controller records hashes before Wave 1 and after Story 12.8 without opening the images. Every worker brief repeats these exact paths.

## Controller checklist per story

1. Update the story worktree from the reviewed integration HEAD.
2. Run the baseline focused and full Swift tests.
3. Extract only that story's plan/brief for the implementer.
4. Dispatch one implementer with exact scope, protected evidence rules, simulator rules, and report path.
5. Require TDD, focused tests, full Swift suite, dedicated-simulator manual exercise, evidence, and an independent commit.
   Before accepting a focused filter, run `swift test --package-path app list` and verify the filter matches at least one named test; a zero-test success is a failed gate.
6. Generate a review package from the recorded story base to story HEAD.
7. Dispatch an independent reviewer for spec compliance and code quality.
8. Send Critical/Important findings back to a fixer and re-review.
9. Merge the reviewed story into the integration branch.
10. Run the integration focused tests plus `swift test --package-path app --jobs 1`.
11. Record the integrated commit and review verdict in a durable progress ledger.

## Implementer dispatch template

```text
You are implementing ToonEdge Epic 12, Story 12.2, in an isolated worktree. Your assigned simulator lease is iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`; use `/private/tmp/toonedge-story-12.2-derived` and `/private/tmp/toonedge-story-12.2-results`. Do not use another simulator.

Read first:
- AGENTS.md
- docs/plans/2026-09-27-quiet-editorial-ux-design.md
- docs/superpowers/plans/2026-09-27-story-12.2-home-search-editorial-entry.md

The story plan is your exact scope. Use superpowers:test-driven-development for every behavior change. Preserve architecture, PRD, UX requirements, conservative detection, browser-only protected sites, and View Original Page. Do not edit unrelated features or broad-format files. Do not read, copy, edit, move, stage, or commit `docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png`, `docs/qa_evidence/2026-09-22/manhuatop-original-page.png`, or `docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png`. Do not use the shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.

Before editing, record branch, HEAD, and status. Run the story's focused baseline. Implement task-by-task with failing regression first, focused pass, full Swift suite, dedicated-simulator manual exercise, safe evidence, and independently reviewable commits.

If a SharedUI contract outside the plan must change, stop and report the requested interface change instead of editing it unilaterally.

Return DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED; commits; exact test/build commands and results; evidence paths; remaining risks; and confirmation of protected evidence/simulator safety.
```

## Reviewer dispatch template

```text
Review ToonEdge Epic 12, Story 12.2 for both spec compliance and code quality.

Read:
- the extracted story brief
- the implementer report
- the base-to-HEAD review package

Verify every acceptance criterion, TDD evidence, feature ownership, accessibility, appearance behavior, product guardrails, test quality, and absence of unrelated refactors. Treat protected-site policy, View Original Page, local-first persistence, numeric chapter semantics, and shared-simulator safety as binding constraints.

Return separate verdicts for Spec Compliance and Code Quality. List Critical, Important, and Minor findings with file/line evidence. Do not re-run tests already evidenced unless the report is incomplete or a finding specifically requires it.
```

## Merge and conflict rules

- Merge Story 12.1 before any screen story.
- Merge Story 12.5 before Story 12.7 so the haptics story targets the extracted `SeriesDetailView.swift` path.
- Merge screen branches one at a time and run the full Swift suite after each merge.
- Shared files requiring special attention:
  - `SharedUI/DesignSystem/ToonEdgeDesignSystem.swift`
  - `SharedUI/Components/ToonEdgePrimitives.swift`
  - `App/DependencyInjection/AppDependencies.swift`
  - `Features/Settings/Views/SettingsView.swift`
  - `ToonEdgeUITests/ToonEdgeAccessibilityUITests.swift`
  - `ToonEdge/ToonEdgeAppEntry.swift`
- Resolve conflicts by preserving both reviewed behaviors, never by accepting an entire side wholesale.
- Do not rebase or force-push a worker branch while its review is active.

## Required final report

- Stories completed and still open.
- Commit per story and final integration commit.
- Files/interfaces added or changed.
- Unit, fixture, integration, UI, build, simulator, VoiceOver, appearance, motion, and physical haptic results.
- Live-site versus fixture-only results.
- Migration/compatibility risks.
- Evidence and result-bundle paths.
- Remaining release risks.
- Confirmation that protected screenshots stayed untracked/unchanged.
- Confirmation that the shared iPhone 16 Pro remained untouched.
