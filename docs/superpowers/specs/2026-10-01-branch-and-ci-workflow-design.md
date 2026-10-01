# ToonEdge Branch and CI Workflow Design

**Date:** 2026-10-01  
**Status:** Approved for implementation planning  
**Current verified revision:** `0b15960655262072850ebe7e7ac791688f996975`

## Goal

Replace the long-lived story branch as ToonEdge's default integration branch with a protected `main` branch, establish a balanced pull-request CI gate, and encode the workflow in repository instructions so future contributors and coding agents follow it consistently.

The workflow must preserve the existing verified history and protected local QA evidence. It must not rewrite published history, force-push, or broadly delete old branches and worktrees.

## Current State

- GitHub's default branch is `story-11.27-unseen-adjacent-reader-loading`.
- No local or remote `main` branch exists.
- The default branch and local checkout both point to verified revision `0b15960`.
- The package suite passes 433 tests, and the release ledger records complete two-device UI and simulator-build gates.
- Multiple historical defect and Story 12 worktrees remain locally. They may contain source-branch commits that were integrated by cherry-pick, so branch ancestry alone is insufficient justification for deletion.
- Three protected third-party screenshots intentionally remain untracked in the primary checkout and must never enter Git history or CI artifacts.

## Chosen Approach

Use a protected-trunk workflow with short-lived branches and a balanced required CI set.

Alternatives considered:

1. Keep the existing story branch as the default. This avoids migration work but preserves misleading branch semantics and encourages continued direct accumulation.
2. Require the complete two-device UI suite on every pull request. This maximizes automated coverage but adds roughly 25–30 minutes of simulator time, consumes substantially more CI capacity, and increases exposure to hosted-simulator instability.
3. **Chosen:** require package tests and an unsigned simulator build on every pull request, while keeping the complete UI matrix as a manual release workflow with retained result bundles.

## Branch Model

### Stable branch

- `main` is the only long-lived integration branch.
- `main` is created at the current verified revision without rewriting history.
- GitHub's default branch is changed to `main` only after the remote branch exists and resolves to the expected commit.
- Direct feature development on `main` is prohibited.

### Short-lived branches

New work branches from current `origin/main` using one of these prefixes:

- `feature/<concise-scope>` for product work
- `fix/<defect-or-scope>` for defects
- `chore/<concise-scope>` for tooling, CI, and maintenance
- `docs/<concise-scope>` for documentation-only work

Story and defect identifiers may follow the prefix, for example `fix/def-036-vortex-parity`. Branches should describe one reviewable outcome and should not become rolling integration branches.

Dependent work may use a stacked branch only when the dependency is explicit. The pull request must identify its parent and be retargeted to `main` after the parent merges.

### Pull-request lifecycle

1. Fetch and verify current `origin/main`.
2. Record branch, HEAD, and status before editing.
3. Create an isolated worktree and short-lived branch from `origin/main`.
4. Implement with focused commits and the repository's TDD requirements.
5. Run focused tests and the relevant local verification gates.
6. Push only with user authorization and open a pull request into `main`.
7. Merge only after required checks pass and review conversations are resolved.
8. Remove the merged worktree and local branch after confirming the remote merge.

Agents must not push, merge, delete remote branches, or modify GitHub settings without explicit user authorization.

## Required Pull-Request CI

Create `.github/workflows/ci.yml` with stable job names that can be referenced by branch protection.

### Triggers and permissions

- Run for pull requests targeting `main`.
- Run for pushes to `main` as post-merge verification.
- Permit manual dispatch for diagnosis.
- Grant read-only repository contents permission.
- Use concurrency keyed by workflow and ref, cancelling superseded runs on the same pull request.

### `Package Tests`

- Run on a GitHub-hosted macOS runner.
- Execute `swift test --package-path app --jobs 1`.
- Preserve the serial job setting used by local release verification.
- Fail the required check on any nonzero exit.

### `Simulator Build`

- Run on a GitHub-hosted macOS runner.
- Build the `ToonEdge` Debug scheme with code signing disabled.
- Use the generic iOS Simulator destination rather than a named device or pinned runtime, keeping the required PR check resilient to hosted-runner device inventory changes.
- Store DerivedData under the runner's temporary directory.
- Fail the required check unless `xcodebuild` exits successfully.

The CI workflow should use GitHub-maintained checkout and artifact actions only. Third-party Xcode-selection actions are out of scope; the workflow uses the runner's supported default Xcode toolchain and reports it in logs.

## Manual Release UI Workflow

Create `.github/workflows/release-ui.yml` as a manually dispatched workflow rather than a required pull-request check.

- Run the complete `ToonEdgeUITests` suite on an iPhone 16e and iPhone 16 Pro Max matrix when those simulator device types are available on the selected runner.
- Generate a distinct `.xcresult` bundle for each device.
- Upload result bundles and sanitized logs with 30-day retention, even when a test job fails.
- Never upload screenshots or attachments until they have been reviewed for protected artwork, credentials, cookies, session data, and sensitive URLs.
- Document hosted-runner device/runtime availability failures as environment limitations; do not silently substitute a different device while claiming exact-device coverage.

Local release verification remains authoritative when hosted runners cannot supply the required device/runtime combination.

## GitHub Protection

After both workflow files are merged into `main`, configure protection for `main`:

- Require a pull request before merging.
- Require the `Package Tests` and `Simulator Build` status checks to pass and require branches to be current with `main`.
- Require conversation resolution.
- Block force pushes and branch deletion.
- Keep administrator bypass available for repository recovery; bypass must not be used for routine product work.
- Do not require an approving review count initially, because ToonEdge currently has a single active maintainer. Add one required approval when another regular reviewer is available.

If the repository's GitHub plan does not support a requested protection rule, record the exact unsupported rule and apply the strongest available subset rather than claiming full protection.

## Repository Instructions for Future Agents

Extend `AGENTS.md` with a mandatory branch-and-delivery section:

- Treat `main` as the stable base and refresh `origin/main` before creating work.
- Never use a story branch as the default integration branch.
- Use an isolated worktree and one short-lived branch per reviewable outcome.
- Preserve unrelated and untracked user files.
- Follow TDD for behavior changes and run focused plus package verification.
- Keep commits independently reviewable; do not mix unrelated refactors.
- Open pull requests into `main` and wait for required CI.
- Never push, merge, alter GitHub settings, or delete remote state without user authorization.
- Clean up only branches/worktrees proven merged and free of unique work.
- Retain the protected screenshot restrictions and simulator safety rules already documented for ToonEdge.

Add a contributor-facing guide at `docs/branching_and_release_workflow.md` with commands, naming examples, CI expectations, release evidence rules, and recovery guidance. `AGENTS.md` remains the normative instruction source for agents; the guide is the operational reference for humans and agents.

## Migration Sequence

1. Write and approve this design and its implementation plan on an isolated documentation branch.
2. Create local `main` at verified revision `0b15960` and push it without changing the existing branch.
3. Confirm remote `main` resolves to the expected revision.
4. Change GitHub's default branch to `main`.
5. Create `chore/branch-pipeline` from `origin/main` in an isolated worktree.
6. Add `AGENTS.md`, the workflow guide, required CI, and manual release UI workflow.
7. Validate YAML structure, shell commands, package tests, and a local unsigned simulator build.
8. Push the chore branch, open a pull request into `main`, and merge it after available checks pass.
9. Apply and verify `main` protection using the workflow's exact status-check names.
10. Confirm a fresh short-lived branch and pull request target `main` by default.
11. Retain the old story branch temporarily as a rollback reference; delete it only after the new default branch and protection are independently verified and the user authorizes deletion.
12. Audit historical local worktrees and branches separately. Report which are byte/patch-equivalent to integrated history before requesting cleanup authorization.

## Failure Handling and Recovery

- If pushing `main` fails, leave the existing default branch unchanged.
- If changing the default branch fails, preserve both branches and report the GitHub permission or authentication blocker.
- If the bootstrap pull request fails CI, fix it on `chore/branch-pipeline`; do not bypass the failure by committing directly to `main`.
- If branch protection cannot be configured, keep the workflows and instructions, record the missing protection, and do not state that `main` is protected.
- If a workflow name changes, update required status checks in the same maintenance operation to avoid permanently blocking merges.
- Rollback consists of restoring the previous default branch. No history rewrite is needed because `main` begins at an existing verified commit.

## Validation and Acceptance Criteria

The migration is complete only when all of the following are observed:

- Local and remote `main` exist at the intended verified ancestry.
- GitHub reports `main` as the default branch.
- `AGENTS.md` and the workflow guide describe the same branch lifecycle and authority boundaries.
- Pull requests into `main` run stable `Package Tests` and `Simulator Build` checks.
- The manual release workflow defines the two-device UI matrix and 30-day artifact retention.
- GitHub reports the supported protection rules as enabled for `main`.
- A repository status check confirms the three protected screenshots remain untracked and hash-identical.
- No shared simulator was targeted and no protected artwork entered Git history or CI configuration.
- Any unsupported GitHub feature, unavailable hosted simulator, or unauthenticated settings operation is recorded as a limitation rather than silently skipped.

## Out of Scope

- Rewriting or squashing the existing 114-commit published history.
- Automatically deleting historical branches or worktrees.
- Adding third-party CI services.
- Running the full two-device UI matrix on every pull request.
- App Store deployment, signing, TestFlight, release-note automation, or semantic-version automation.
