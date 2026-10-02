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
  -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/fix-def-036-vortex-parity" \
  build CODE_SIGNING_ALLOWED=NO
git diff --check
```

Run the complete two-device UI suite locally for release candidates and high-risk Reader, Browser, persistence, cache, or accessibility changes. Use only the dedicated iPhone 16e and iPhone 16 Pro Max simulators documented in the project instructions.

## External Build Paths

When `/Volumes/Seagate 2TB` is mounted with volume UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29` and a directory-creation probe succeeds, keep disposable build output under `/Volumes/Seagate 2TB/ToonEdgeBuilds`. Use a filesystem-safe branch key and never share one mutable output directory between concurrent agents.

```sh
swift test \
  --package-path app \
  --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-def-036-vortex-parity" \
  --jobs 1

xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/fix-def-036-vortex-parity" \
  build CODE_SIGNING_ALLOWED=NO
```

Store result bundles and sanitized logs under a date and branch-key subdirectory of `ToonEdgeBuilds/Results`; for example, `ToonEdgeBuilds/Results/2026-10-02/fix-def-036-vortex-parity/`. If the verified volume is unavailable, use a unique `/private/tmp/toonedge-...` path, report the fallback, and archive or remove it after verification. Never create `/Volumes/Seagate 2TB` when the drive is absent, and never place source worktrees or simulator data on the external drive.

## Pull Requests

Push only with authorization. Target `main`, keep the branch current, resolve review conversations, and require `Simulator Build` before merge. Package, integration, and simulator UI tests remain local verification gates for now; record their commands and results in the pull request or QA evidence.

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
