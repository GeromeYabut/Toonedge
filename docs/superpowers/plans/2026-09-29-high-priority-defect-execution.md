# High-Priority Defect Completion Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete live DEF-036 revalidation and close the remaining end-to-end release-evidence gaps around implemented DEF-020, DEF-021, and DEF-022.

**Architecture:** Work begins with one shared, typed UI-fixture contract, then splits into independently reviewable defect slices in isolated worktrees. Existing repository, chapter-label, URL-inference, Reader-loading, and route-observation interfaces remain authoritative; production changes require a failing regression in the owning layer.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, SwiftData, WebKit, XCUITest, iOS 18.6 simulators, OSLog, Git worktrees.

## Global Constraints

- Baseline branch: `story-11.27-unseen-adjacent-reader-loading`.
- Approved design baseline: `9db0a2601bc5d8c5934dc51dd7b0cb58d6312c63`.
- Preserve the three protected screenshots untracked and unchanged.
- Never target shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- Use dedicated iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` and iPhone 16 Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` only.
- WEBTOON and protected GlobalComix remain browser-only.
- Never bypass authentication, challenges, paywalls, rate limits, or protected viewers.
- Detection remains conservative; false positives are worse than false negatives.
- Reader always retains View Original Page.
- Multi-page stitching remains out of scope.
- Reuse `ChapterNumericLabelExtractor`, `ChapterURLInference`, `SwiftDataLibraryRepository`, and the existing typed adjacent-load interfaces.
- No SwiftData migration is expected.
- Stage exact files and commit each completed slice independently.
- Fixture evidence cannot close a live-only acceptance criterion.

## Plan Index

| Slice | Plan | Commit intent |
|---|---|---|
| Foundation | [Shared hardening fixture contract](2026-09-29-reader-hardening-fixture-foundation.md) | `test: add reader hardening fixture contract` |
| DEF-036 | [Vortex live route parity](2026-09-29-def-036-vortex-live-parity.md) | evidence-only or `fix: preserve Vortex route parity` |
| DEF-020 | [Numeric adjacency UI hardening](2026-09-29-def-020-numeric-adjacency.md) | `fix: enforce numeric reader adjacency` |
| DEF-021 | [Authoritative Continue journey](2026-09-29-def-021-authoritative-continue.md) | `test: verify authoritative continue journey` |
| DEF-022 | [Typed adjacent outcome matrix](2026-09-29-def-022-adjacent-outcomes.md) | `test: verify typed adjacent outcomes` |
| Final | [Release hardening and evidence](2026-09-29-high-priority-release-verification.md) | `test: complete high-priority defect verification` |

## Dependency Graph

```text
Fixture foundation
├── DEF-036 live parity (read-only unless divergence)
└── DEF-020 numeric adjacency
           └── DEF-021 authoritative Continue
                     └── DEF-022 typed adjacent matrix
All reviewed slices
           └── Final release verification
```

DEF-036 and DEF-020 may run in parallel after the foundation lands. DEF-021 follows DEF-020, and DEF-022 follows DEF-021, because all three intentionally extend the same app-entry fixture switch and UI-test file. This ordering removes predictable integration conflicts while keeping the live Vortex work independent. Final verification waits for every accepted slice.

## Worktree and simulator assignments

| Worker | Branch | Worktree | Simulator | Derived data |
|---|---|---|---|---|
| Integration/foundation | `story-reader-hardening-foundation` | `.worktrees/story-reader-hardening-foundation` | none | `/private/tmp/toonedge-hardening-foundation-derived` |
| DEF-036 | `def-036-vortex-live-parity` | `.worktrees/def-036-vortex-live-parity` | iPhone 16e exclusive | `/private/tmp/toonedge-def036-derived` |
| DEF-020 | `def-020-numeric-adjacency-ui` | `.worktrees/def-020-numeric-adjacency-ui` | iPhone 16 Pro Max | `/private/tmp/toonedge-def020-derived` |
| DEF-021 | `def-021-authoritative-continue-ui` | `.worktrees/def-021-authoritative-continue-ui` | iPhone 16 Pro Max | `/private/tmp/toonedge-def021-derived` |
| DEF-022 | `def-022-adjacent-outcome-matrix` | `.worktrees/def-022-adjacent-outcome-matrix` | iPhone 16e | `/private/tmp/toonedge-def022-derived` |
| Final integration | current integration branch | primary checkout | both, sequentially | unique final paths in final plan |

The integration owner creates worktrees through `superpowers:using-git-worktrees`, verifies their baselines, and removes none until all commits are integrated and reviewed.

## Wave 0: Baseline

- [ ] Record `git status --short --untracked-files=all`, `git branch --show-current`, and `git rev-parse HEAD`.
- [ ] Hash the three protected files without opening them:

```bash
shasum -a 256 \
  docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
```

Expected hashes:

```text
7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8
56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a
49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5
```

- [ ] Run the baseline package suite:

```bash
swift test --package-path app --jobs 1
```

Expected: 418 or more tests pass with 0 failures.

- [ ] Implement and review the fixture-foundation plan.
- [ ] Fast-forward or merge the foundation commit into the integration branch.
- [ ] Create DEF-036 and DEF-020 worktrees from the same reviewed foundation revision.

## Wave 1: Parallel DEF-036 and DEF-020 work

- [ ] Dispatch DEF-036 using `2026-09-29-def-036-vortex-live-parity.md`.
- [ ] Dispatch DEF-020 using `2026-09-29-def-020-numeric-adjacency.md`.
- [ ] Give every worker its exact branch, worktree, simulator lease, derived-data path, result-bundle path, protected-file rules, and exact allowed files.
- [ ] Require a spec-compliance review and a code-quality review for each returned commit.
- [ ] Keep DEF-036 open when the live site is unavailable or nonviable; integrate its evidence without changing status.

## Wave 2: DEF-021

- [ ] Create the DEF-021 worktree from the integrated foundation plus DEF-020 revision.
- [ ] Execute `2026-09-29-def-021-authoritative-continue.md`.
- [ ] Review repository reconstruction evidence separately from the deterministic UI fixture persistence evidence.
- [ ] Integrate the reviewed DEF-021 commit.

## Wave 3: DEF-022

- [ ] Create the DEF-022 worktree from the integrated foundation plus DEF-020 and DEF-021 revisions.
- [ ] Execute `2026-09-29-def-022-adjacent-outcomes.md`.
- [ ] Review typed copy, target preservation, retry timing, request-count assertions, and post-success origin routing.
- [ ] Integrate the reviewed DEF-022 commit.

## Wave 4: Final verification

- [ ] Execute `2026-09-29-high-priority-release-verification.md` in the integration checkout.
- [ ] Do not update `docs/defects.md` until each defect’s acceptance criteria are satisfied.
- [ ] Request one final independent review of all commits and the evidence ledger.
- [ ] Re-run `git diff --check`, the full package suite, both complete UI suites, and the exact build after review fixes.
- [ ] Re-hash protected evidence and confirm the shared simulator was never targeted.

## Review checkpoints

Every slice must answer:

1. What acceptance criterion was exercised?
2. What failed before the change?
3. Which owning interface changed, if any?
4. What focused and full gates passed afterward?
5. Was the result live, fixture-based, or both?
6. What remains unverified?
7. Are the protected screenshots still untracked and unchanged?

No slice may claim success based only on a code diff or an unexecuted test.

## Execution handoff

Use subagent-driven development. The controller owns integration, simulator leases, protected-file verification, and final gates. Defect workers own only their assigned worktrees and files. Reviews occur before integration, not after several slices have accumulated.
