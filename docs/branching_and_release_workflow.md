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
