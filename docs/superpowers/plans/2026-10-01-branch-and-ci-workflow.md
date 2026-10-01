# ToonEdge Branch and CI Workflow Implementation Plan

> **Execution adjustment (2026-10-01):** At the user's direction, GitHub verification was simplified to the unsigned `Simulator Build` check. Package, integration, and exact-device simulator UI tests remain local gates; the hosted release UI workflow described below was removed.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `main` as ToonEdge's protected default branch, add balanced required pull-request CI plus a manual two-device release UI workflow, and make the branch lifecycle mandatory for future agents.

**Architecture:** Bootstrap `main` at the already verified revision without rewriting history, then deliver repository instructions and GitHub Actions through a short-lived `chore/branch-pipeline` pull request. Apply GitHub protection only after the workflow checks exist, and treat authenticated GitHub settings, stale-worktree cleanup, and protected local evidence as separately verified state.

**Tech Stack:** Git and Git worktrees, GitHub repository settings, GitHub Actions YAML, Swift Package Manager, Xcode `xcodebuild`, macOS hosted runners, Markdown.

## Global Constraints

- Preserve published history: no rebase, force-push, or destructive reset.
- Create `main` at verified revision `0b15960655262072850ebe7e7ac791688f996975`.
- Required PR checks are exactly `Package Tests` and `Simulator Build`.
- Required PR CI runs package tests serially and performs an unsigned generic iOS Simulator Debug build.
- Complete UI tests remain manual release gates for iPhone 16e and iPhone 16 Pro Max, with 30-day artifact retention.
- Use only GitHub-maintained checkout and artifact actions; do not add third-party Xcode-selection actions.
- Do not delete the existing remote story branch during this plan.
- Do not delete historical local branches or worktrees during this plan; audit and report them separately.
- Do not push, merge, change GitHub settings, or delete remote state without explicit user authorization. The user's approval of this plan authorizes the bootstrap operations enumerated here, but any new scope still requires authorization.
- Preserve the three protected local screenshots as untracked, byte-identical files; never upload or stage them.
- Never target shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.

---

## File Map

- Modify: `AGENTS.md` — normative instructions for future agents.
- Create: `docs/branching_and_release_workflow.md` — contributor operations, examples, evidence, cleanup, and recovery.
- Create: `.github/workflows/ci.yml` — required package-test and generic simulator-build jobs.
- Create: `.github/workflows/release-ui.yml` — manually dispatched two-device UI matrix and retained artifacts.
- Carry forward: `docs/superpowers/specs/2026-10-01-branch-and-ci-workflow-design.md` — approved design.
- Carry forward: `docs/superpowers/plans/2026-10-01-branch-and-ci-workflow.md` — this execution plan.

No application source, persistence schema, fixtures, or product behavior changes in this migration.

---

### Task 1: Bootstrap and select `main`

**Files:**
- No repository file changes.

**Interfaces:**
- Consumes: verified commit `0b15960655262072850ebe7e7ac791688f996975` and remote `origin`.
- Produces: local and remote `main`, with GitHub default branch set to `main`.

- [ ] **Step 1: Revalidate the bootstrap source and protected evidence**

Run from `/Users/geromeyabut/Developer/Toonedge`:

```bash
git branch --show-current
git rev-parse HEAD
git status --short --untracked-files=all
git ls-remote --symref origin HEAD
shasum -a 256 \
  docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
```

Expected:

- Current HEAD is `0b15960655262072850ebe7e7ac791688f996975`.
- Only the three protected screenshots are untracked.
- Hashes are, in order:
  - `7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8`
  - `56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a`
  - `49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5`

- [ ] **Step 2: Create local `main` without changing the primary checkout**

```bash
git branch main 0b15960655262072850ebe7e7ac791688f996975
git rev-parse main
```

Expected: `main` resolves to the exact verified revision.

- [ ] **Step 3: Push `main` and verify its remote SHA**

```bash
git push -u origin main
git ls-remote origin refs/heads/main
```

Expected: remote `main` resolves to `0b15960655262072850ebe7e7ac791688f996975`.

- [ ] **Step 4: Change GitHub's default branch through the authenticated repository settings UI**

Open `https://github.com/GeromeYabut/Toonedge/settings/branches`, change the default branch from `story-11.27-unseen-adjacent-reader-loading` to `main`, and confirm the warning dialog. Do not delete the old branch.

If GitHub authentication or permissions are unavailable, stop this task after Step 3 and report that both branches are preserved but the default branch is unchanged.

- [ ] **Step 5: Verify the remote default branch**

```bash
git remote set-head origin --auto
git symbolic-ref refs/remotes/origin/HEAD
git ls-remote --symref origin HEAD
```

Expected: both commands identify `refs/heads/main`.

---

### Task 2: Create the pipeline branch and repository guidance

**Files:**
- Modify: `AGENTS.md`
- Create: `docs/branching_and_release_workflow.md`
- Carry forward: `docs/superpowers/specs/2026-10-01-branch-and-ci-workflow-design.md`
- Carry forward: `docs/superpowers/plans/2026-10-01-branch-and-ci-workflow.md`

**Interfaces:**
- Consumes: `origin/main` from Task 1 and design/plan commits from `docs/branch-pipeline-design`.
- Produces: normative agent rules and contributor instructions on `chore/branch-pipeline`.

- [ ] **Step 1: Create an isolated worktree from current `origin/main`**

```bash
git fetch origin main
git check-ignore -q .worktrees
git worktree add \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/chore-branch-pipeline \
  -b chore/branch-pipeline origin/main
```

Expected: a clean worktree on `chore/branch-pipeline` based on `origin/main`.

- [ ] **Step 2: Carry the approved design and plan into the pipeline branch**

From the new worktree:

```bash
git cherry-pick 0b15960..docs/branch-pipeline-design
```

Expected: Git applies the design commit followed by the plan commit; both documentation files exist and the worktree is clean.

- [ ] **Step 3: Add mandatory branch rules to `AGENTS.md`**

Append this section after `## Definition of Done`:

```markdown

---

## Branch and Delivery Workflow

- Treat `main` as the stable integration branch. Fetch and verify `origin/main` before starting new work.
- Never implement product work directly on `main` and never use a story branch as a rolling integration branch.
- Create one short-lived branch per reviewable outcome using `feature/`, `fix/`, `chore/`, or `docs/`.
- Use an isolated worktree based on current `origin/main`; record branch, HEAD, and `git status --short --untracked-files=all` before editing.
- Preserve unrelated user work and all untracked evidence. Never reset, clean, stash, or discard it without explicit authorization.
- Use test-driven development for behavior changes. Run focused tests, then `swift test --package-path app --jobs 1`, and proportionate build/UI gates.
- Keep commits independently reviewable and do not combine unrelated refactors.
- Push only with user authorization. Open pull requests into `main` and wait for required `Package Tests` and `Simulator Build` checks.
- Merge, alter GitHub settings, or delete remote branches only with explicit user authorization.
- After a confirmed merge, remove only worktrees and branches proven merged and free of unique changes.
- Never stage, move, modify, or delete the protected local files `docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png`, `docs/qa_evidence/2026-09-22/manhuatop-original-page.png`, or `docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png`.
- Never target shared iPhone 16 Pro simulator `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- Follow `docs/branching_and_release_workflow.md` for commands, CI, release evidence, and recovery.
```

- [ ] **Step 4: Create the contributor workflow guide**

Create `docs/branching_and_release_workflow.md` with these sections and exact commands:

````markdown
# ToonEdge Branching and Release Workflow

## Stable Branch

`main` is the only long-lived integration branch. It must remain releasable and is changed through pull requests with required CI.

## Start Work

```sh
git fetch origin main
git worktree add .worktrees/fix-def-036 -b fix/def-036-vortex-parity origin/main
git -C .worktrees/fix-def-036 status --short --untracked-files=all
```

Use `feature/`, `fix/`, `chore/`, or `docs/`. Keep one reviewable outcome per branch.

## Verify Work

Run focused regressions first, then:

```sh
swift test --package-path app --jobs 1
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/toonedge-pr-build \
  build CODE_SIGNING_ALLOWED=NO
git diff --check
```

Use the complete two-device UI workflow for release candidates and high-risk Reader, Browser, persistence, cache, or accessibility changes.

## Pull Requests

Push only with authorization. Target `main`, keep the branch current, resolve review conversations, and require `Package Tests` plus `Simulator Build` before merge.

## Release Evidence

Retain `.xcresult` bundles, sanitized logs, and safe screenshots for at least 30 days. Never upload copyrighted page art, credentials, cookies, session data, complete sensitive URLs, or the three protected local screenshots.

The protected local screenshots are the three files under `docs/qa_evidence/2026-09-22/` named `manhuatop-chapter-label-top.png`, `manhuatop-original-page.png`, and `webtoon-protected-reader-cta.png`. Keep them untracked and unchanged. Never target shared iPhone 16 Pro simulator `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.

## Cleanup

After the merge is confirmed:

```sh
git worktree remove .worktrees/fix-def-036
git worktree prune
git branch -d fix/def-036-vortex-parity
```

Delete a remote branch only with explicit authorization. Do not delete a branch or worktree that has unique commits or uncommitted files.

## Recovery

If CI fails, fix the short-lived branch. Do not bypass a product failure by committing directly to `main`. If GitHub protection blocks recovery, use administrator bypass only with explicit authorization and document the reason.
````

- [ ] **Step 5: Validate instruction consistency**

```bash
rg -n "origin/main|Package Tests|Simulator Build|explicit.*authorization|protected" \
  AGENTS.md docs/branching_and_release_workflow.md
git diff --check
```

Expected: both documents name the same base, checks, authority boundary, and protected-evidence rule; `git diff --check` emits nothing.

- [ ] **Step 6: Commit the guidance**

```bash
git add \
  AGENTS.md \
  docs/branching_and_release_workflow.md \
  docs/superpowers/specs/2026-10-01-branch-and-ci-workflow-design.md \
  docs/superpowers/plans/2026-10-01-branch-and-ci-workflow.md
git commit -m "docs: establish protected main workflow"
```

---

### Task 3: Add balanced required CI

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: repository package and Xcode project.
- Produces: stable required check names `Package Tests` and `Simulator Build`.

- [ ] **Step 1: Create `.github/workflows/ci.yml`**

```yaml
name: CI

"on":
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  package-tests:
    name: Package Tests
    runs-on: macos-15
    timeout-minutes: 15
    steps:
      - name: Check out repository
        uses: actions/checkout@v4
      - name: Report toolchain
        run: |
          swift --version
          xcodebuild -version
      - name: Run package tests
        run: swift test --package-path app --jobs 1

  simulator-build:
    name: Simulator Build
    runs-on: macos-15
    timeout-minutes: 20
    steps:
      - name: Check out repository
        uses: actions/checkout@v4
      - name: Report toolchain
        run: xcodebuild -version
      - name: Build unsigned simulator app
        run: |
          xcodebuild \
            -project app/ToonEdge.xcodeproj \
            -scheme ToonEdge \
            -configuration Debug \
            -destination 'generic/platform=iOS Simulator' \
            -derivedDataPath "$RUNNER_TEMP/toonedge-ci-derived" \
            build CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 2: Parse and assert the required workflow structure**

```bash
ruby -e '
require "yaml"
w = YAML.safe_load(File.read(".github/workflows/ci.yml"), aliases: true)
raise "missing triggers" unless w.key?("on")
jobs = w.fetch("jobs")
raise "missing package job" unless jobs.fetch("package-tests").fetch("name") == "Package Tests"
raise "missing build job" unless jobs.fetch("simulator-build").fetch("name") == "Simulator Build"
raise "unexpected permissions" unless w.fetch("permissions") == {"contents" => "read"}
'
```

Expected: exit 0 with no output.

- [ ] **Step 3: Execute the workflow commands locally**

```bash
swift test --package-path app --jobs 1
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/toonedge-branch-pipeline-build \
  build CODE_SIGNING_ALLOWED=NO
```

Expected: 433 package tests pass and `** BUILD SUCCEEDED **` appears.

- [ ] **Step 4: Commit required CI**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add balanced pull request checks"
```

---

### Task 4: Add the manual release UI workflow

**Files:**
- Create: `.github/workflows/release-ui.yml`

**Interfaces:**
- Consumes: `ToonEdgeUITests`, hosted simulator inventory, and GitHub artifact storage.
- Produces: manual two-device release evidence with 30-day retention.

- [ ] **Step 1: Create `.github/workflows/release-ui.yml`**

```yaml
name: Release UI

"on":
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: release-ui-${{ github.ref }}
  cancel-in-progress: false

jobs:
  ui-tests:
    name: UI Tests — ${{ matrix.device_name }}
    runs-on: macos-15
    timeout-minutes: 60
    strategy:
      fail-fast: false
      matrix:
        include:
          - device_name: iPhone 16e
            artifact_name: iphone-16e
          - device_name: iPhone 16 Pro Max
            artifact_name: iphone-16-pro-max
    steps:
      - name: Check out repository
        uses: actions/checkout@v4
      - name: Report available simulator inventory
        run: |
          xcodebuild -version
          xcrun simctl list devices available
      - name: Run complete UI suite
        run: |
          set -o pipefail
          result="$RUNNER_TEMP/toonedge-${{ matrix.artifact_name }}.xcresult"
          log="$RUNNER_TEMP/toonedge-${{ matrix.artifact_name }}.log"
          xcodebuild \
            -project app/ToonEdge.xcodeproj \
            -scheme ToonEdge \
            -destination "platform=iOS Simulator,name=${{ matrix.device_name }}" \
            -derivedDataPath "$RUNNER_TEMP/toonedge-${{ matrix.artifact_name }}-derived" \
            test -only-testing:ToonEdgeUITests \
            -resultBundlePath "$result" \
            CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$log"
      - name: Upload sanitized release evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: toonedge-ui-${{ matrix.artifact_name }}
          retention-days: 30
          if-no-files-found: error
          path: |
            ${{ runner.temp }}/toonedge-${{ matrix.artifact_name }}.xcresult
            ${{ runner.temp }}/toonedge-${{ matrix.artifact_name }}.log
```

- [ ] **Step 2: Parse and assert manual-only release semantics**

```bash
ruby -e '
require "yaml"
w = YAML.safe_load(File.read(".github/workflows/release-ui.yml"), aliases: true)
triggers = w.fetch("on")
raise "release workflow must be manual only" unless triggers.keys == ["workflow_dispatch"]
job = w.fetch("jobs").fetch("ui-tests")
devices = job.fetch("strategy").fetch("matrix").fetch("include").map { |x| x.fetch("device_name") }
raise "wrong devices" unless devices == ["iPhone 16e", "iPhone 16 Pro Max"]
upload = job.fetch("steps").find { |x| x["uses"] == "actions/upload-artifact@v4" }
raise "missing 30-day retention" unless upload.fetch("with").fetch("retention-days") == 30
'
```

Expected: exit 0 with no output.

- [ ] **Step 3: Confirm artifact paths exclude protected repository evidence**

```bash
rg -n "path:|qa_evidence|manhuatop|webtoon-protected|xcresult|\.log" \
  .github/workflows/release-ui.yml
```

Expected: upload paths include only the runner-temporary `.xcresult` and log; no protected screenshot path appears.

- [ ] **Step 4: Commit the manual workflow**

```bash
git add .github/workflows/release-ui.yml
git commit -m "ci: add manual release UI matrix"
```

---

### Task 5: Verify the pipeline branch locally

**Files:**
- No new files.

**Interfaces:**
- Consumes: Tasks 2–4 repository changes.
- Produces: verified branch ready for review and GitHub execution.

- [ ] **Step 1: Re-run both workflow structure assertions**

Run the exact Ruby assertions from Task 3 Step 2 and Task 4 Step 2.

Expected: both exit 0 with no output.

- [ ] **Step 2: Run complete package verification**

```bash
swift test --package-path app --jobs 1
```

Expected: 433 tests pass with 0 failures.

- [ ] **Step 3: Run the generic simulator build**

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/toonedge-branch-pipeline-final-build \
  build CODE_SIGNING_ALLOWED=NO
```

Expected: exit 0 and `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Audit scope and protected evidence**

```bash
git diff origin/main...HEAD --check
git diff --stat origin/main...HEAD
git status --short --untracked-files=all
git -C /Users/geromeyabut/Developer/Toonedge status --short --untracked-files=all
```

Expected:

- The pipeline worktree is clean.
- Branch diff contains only the two documentation files, `AGENTS.md`, and the two workflows.
- The primary checkout still lists only the three protected screenshots as untracked.

---

### Task 6: Deliver and merge the bootstrap pull request

**Files:**
- No new local files.

**Interfaces:**
- Consumes: verified `chore/branch-pipeline`.
- Produces: merged repository instructions and workflows on `main`.

- [ ] **Step 1: Push the short-lived branch**

```bash
git push -u origin chore/branch-pipeline
```

Expected: remote branch exists without force-push.

- [ ] **Step 2: Open a pull request into `main`**

Use the authenticated GitHub web UI at `https://github.com/GeromeYabut/Toonedge/compare/main...chore/branch-pipeline` with:

```text
Title: Establish protected main and balanced CI

Body:
- documents the short-lived branch/worktree lifecycle for humans and agents
- adds required package-test and unsigned simulator-build checks
- adds a manual two-device release UI workflow with 30-day artifacts

Verification:
- swift test --package-path app --jobs 1
- generic iOS Simulator Debug build with signing disabled
- workflow YAML structure assertions
```

- [ ] **Step 3: Inspect GitHub Actions results**

Expected checks:

- `Package Tests` succeeds.
- `Simulator Build` succeeds.

If either fails, inspect its log, reproduce locally where possible, fix the branch, rerun local validation, and push a new focused commit. Do not merge a failing product check.

- [ ] **Step 4: Merge the pull request through GitHub**

Use a normal merge or squash merge without force-push. Confirm the resulting `main` SHA and the pull request's merged state.

- [ ] **Step 5: Update and verify local `main`**

```bash
git fetch origin main
git switch main
git merge --ff-only origin/main
git rev-parse HEAD
git status --short --untracked-files=all
```

Expected: local `main` matches `origin/main`; only the protected screenshots remain untracked in the primary checkout.

---

### Task 7: Protect `main` and validate the default path

**Files:**
- No repository file changes.

**Interfaces:**
- Consumes: merged CI jobs on `main`.
- Produces: GitHub protection tied to exact job names.

- [ ] **Step 1: Configure `main` protection in GitHub settings**

At `https://github.com/GeromeYabut/Toonedge/settings/branches`, add a rule for `main` with:

- Require a pull request before merging.
- Required approving reviews: 0.
- Require status checks to pass before merging.
- Require branches to be up to date before merging.
- Required checks: `Package Tests`, `Simulator Build`.
- Require conversation resolution before merging.
- Do not allow force pushes.
- Do not allow branch deletion.
- Do not include administrators, preserving emergency recovery.

If GitHub does not expose one of these controls for the repository plan, record the missing control and enable the strongest supported subset.

- [ ] **Step 2: Verify default branch and protection state**

Read back GitHub's default-branch and protection pages. Record each enabled rule and any unsupported rule. Do not infer protection from the presence of workflow files.

- [ ] **Step 3: Confirm new work defaults to `main`**

```bash
git remote set-head origin --auto
git symbolic-ref refs/remotes/origin/HEAD
git ls-remote --symref origin HEAD
```

Expected: `origin/HEAD` and remote `HEAD` both identify `main`.

- [ ] **Step 4: Remove the merged pipeline worktree and local branch**

Only after confirming the pull request merged and the worktree is clean:

```bash
git -C /Users/geromeyabut/Developer/Toonedge/.worktrees/chore-branch-pipeline status --short --untracked-files=all
git worktree remove /Users/geromeyabut/Developer/Toonedge/.worktrees/chore-branch-pipeline
git worktree prune
git branch -d chore/branch-pipeline
```

Do not delete the remote story branch or any historical worktree in this task.

---

### Task 8: Audit legacy branches and produce the handoff

**Files:**
- No repository changes unless the user separately requests an audit ledger.

**Interfaces:**
- Consumes: final `main`, existing local worktrees, branch graph, and protected-file baseline.
- Produces: cleanup recommendations and a complete migration report.

- [ ] **Step 1: Inventory local and remote state**

```bash
git branch --all --verbose --no-abbrev
git worktree list
git ls-remote --heads origin
```

- [ ] **Step 2: Classify each historical branch without deleting it**

For each local worktree branch, record:

```bash
for branch_name in \
  def-020-numeric-adjacency-ui \
  def-021-authoritative-continue-ui \
  def-022-adjacent-outcome-matrix \
  def-036-vortex-live-parity \
  story-12.1-adaptive-editorial-foundation \
  story-12.2-home-search-editorial-entry \
  story-12.3-browser-editorial-chrome \
  story-12.4-reader-editorial-controls \
  story-12.5-library-series-editorial-surfaces \
  story-12.6-downloads-settings-utilities \
  story-12.7-semantic-haptics \
  story-12.8-editorial-release-qa \
  story-reader-hardening-foundation \
  docs/branch-pipeline-design
do
  if git merge-base --is-ancestor "$branch_name" main; then
    echo "$branch_name ancestry=merged"
  else
    echo "$branch_name ancestry=not-merged"
  fi
  git log --oneline "main..$branch_name"
  git cherry main "$branch_name"
done

for worktree_path in \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/def-020-numeric-adjacency-ui \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/def-021-authoritative-continue-ui \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/def-022-adjacent-outcome-matrix \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/def-036-vortex-live-parity \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.1-adaptive-editorial-foundation \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.2-home-search-editorial-entry \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.3-browser-editorial-chrome \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.4-reader-editorial-controls \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.5-library-series-editorial-surfaces \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.6-downloads-settings-utilities \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.7-semantic-haptics \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-12.8-editorial-release-qa \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/story-reader-hardening-foundation \
  /Users/geromeyabut/Developer/Toonedge/.worktrees/docs-branch-pipeline-design
do
  git -C "$worktree_path" status --short --untracked-files=all
done
```

Classification:

- **Safe ancestry cleanup candidate:** branch is an ancestor of `main`, worktree is clean, and no unique commits exist.
- **Patch-equivalent review candidate:** source commits are not ancestors but `git cherry` reports no unique patches; require user approval before deletion.
- **Retain:** unique commits or uncommitted files exist.

- [ ] **Step 3: Revalidate protected evidence and final code**

```bash
swift test --package-path app --jobs 1
git status --short --untracked-files=all
shasum -a 256 \
  docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
```

Expected: 433 tests pass; only the protected screenshots are untracked; all hashes match the Global Constraints.

- [ ] **Step 4: Report completion and limitations**

Report:

- local/remote/default `main` SHA
- pull request URL and merge SHA
- required CI results
- manual release workflow availability
- enabled and unsupported protection rules
- files and instructions changed
- protected screenshot status/hashes
- shared simulator untouched confirmation
- legacy branch/worktree cleanup classifications
- retained rollback branch and any remaining pipeline risks

Do not claim branch protection or exact-device hosted UI coverage unless it was directly observed.
