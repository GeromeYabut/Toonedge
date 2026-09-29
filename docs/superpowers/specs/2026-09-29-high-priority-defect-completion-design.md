# High-Priority Defect Completion Design

**Date:** 2026-09-29

**Branch baseline:** `story-11.27-unseen-adjacent-reader-loading` at `063b82edcc7f6267b14442329b7edf3b9d1eff44`

**Scope:** Complete DEF-036 and close the remaining release-evidence gaps around implemented DEF-020, DEF-021, and DEF-022.

## Objective

Finish the remaining high-priority reader hardening without reopening proven implementations unnecessarily. DEF-036 is the only open defect and requires live Vortex parity evidence. DEF-020, DEF-021, and DEF-022 remain implemented; this work adds the missing end-to-end simulator journeys and revalidates their behavior against the current quiet-editorial integration revision.

The result must preserve conservative detection, browser-only protected sources, explicit View Original Page recovery, local-first persistence, and the existing single-chapter Reader scope.

## Current state

### DEF-036 — open

The app observes committed main-frame routes, deduplicates repeated URL/KVO/navigation callbacks, and permits one bounded Vortex-specific settled-content follow-up after a low-confidence result. Sanitized SPA fixture coverage passes. A prior live direct load produced a viable Reader session, but the final live series-to-chapter and direct controls both later became nonviable. Live parity therefore remains unproven.

### DEF-020 — implemented

`SwiftDataLibraryRepository` resolves numeric adjacency from canonical chapter identity rather than Recent ordering. It prefers an exact stored `current ± 1` payload and otherwise uses `ChapterURLInference` only for supported numeric URL shapes. Repository tests already prove sparse chapters 1, 155, and 169 resolve chapter 155 to 154 and 156, or no target when inference is unsafe.

The remaining gap is a deterministic simulator journey through the visible Reader controls.

### DEF-021 — implemented

Continue selection is independent of Recent display ordering, prioritizes the newest active in-progress chapter, and reconciles newly discovered adjacent chapters into the saved series. Package tests already cover immediate selection, repository reconstruction, and adjacent discovery.

The remaining gap is a deterministic simulator journey proving the Series Detail CTA label and destination across return and relaunch boundaries.

### DEF-022 — implemented

Adjacent loading preserves typed timeout, challenge/rate-limit, unavailable, low-confidence, and nonviable-image failures. Known safe targets expose Retry and Open Original. Retry is explicit and backed off; no automatic loop occurs. Diagnostics are sanitized. Existing UI coverage proves challenge recovery and Open Original after failure.

The remaining gap is a consolidated simulator matrix covering the other typed outcomes, normal adjacent success, and navigation recovery after both success and failure.

## Chosen approach

Use an evidence-first completion sequence:

1. Revalidate DEF-036 live before changing production code.
2. Add only missing deterministic simulator coverage for DEF-020–022.
3. Change production code only when a new failing regression demonstrates an observable defect.
4. Finish with release-hardening journeys and complete automated gates.

This approach avoids duplicating the existing numeric resolver, Continue-target reconciliation, or typed failure model. It also prevents live-site variability from being encoded as broad site-specific behavior.

## Architecture and ownership

### Route parity boundary

`BrowserViewModel` and the existing WebKit coordination layer continue to own main-frame URL observation, route settling, follow-up scheduling, and presentation deduplication. Detection confidence and Reader viability remain detector-owned. No view-level timer or parallel route observer will be introduced.

The live comparison records two independent flows:

- Vortex series page → in-site chapter transition.
- Direct load of that identical final chapter URL.

For each flow, evidence must identify the sanitized host/path shape, committed route, settle/follow-up decisions, detection-pass count, confidence, viable image count, parser path, and Reader presentation count. Full sensitive URLs, cookies, headers, and captured artwork are excluded.

If both flows produce the same viable Reader session and schedule one effective detection sequence, DEF-036 closes without code changes. If Vortex is unavailable or both controls are nonviable, DEF-036 remains open and fixture evidence is reported separately. If the flows diverge, the observed callback/content sequence becomes the input for one failing integration regression before remediation.

### Numeric adjacency boundary

The repository/domain resolver remains the only source of numeric adjacent identity and URL inference. Reader views consume the resolved previous/next targets and never infer adjacency from Recent or visible list ordering.

A sanitized UI fixture will seed chapters 1, 155, and 169, open Reader at chapter 155, and provide safely inferable chapter URLs. Its visible Previous and Next actions must attempt chapter 154 and 156 respectively. A companion unsafe-pattern state must disable or gracefully fail adjacency rather than select chapter 1 or 169.

The fixture may expose deterministic diagnostic labels or accessibility values, but it must not introduce a test-only production resolver.

### Continue-target boundary

The lifecycle repository remains authoritative for progress, recent-reading reconciliation, and `continueReadingTarget(for:)`. Series Detail consumes the returned snapshot/target; it does not select a primary chapter from view ordering.

A sanitized UI fixture will begin with stored chapter 1 and newer chapter 3 progress. It must prove:

- Returning from Reader refreshes Series Detail to `Continue Chapter 3`.
- The CTA opens chapter 3.
- Relaunch/repository reconstruction retains chapter 3.
- A chapter discovered through adjacent Reader navigation becomes the persisted Continue target.
- Older unfinished chapter 1 never replaces the newer active target.

Planned or unread series without progress retain their current first-readable behavior.

### Adjacent-failure boundary

`AdjacentReaderSessionLoading`, `AdjacentReaderSessionLoadError`, and `AdjacentChapterLoadFailure` remain the typed interfaces. `ReaderViewModel` owns operation tokens, explicit retry, backoff, cancellation, and state replacement. `ReaderView` owns only presentation and actions.

Sanitized deterministic fixtures will cover:

- Timeout.
- Challenge/rate limit.
- Unavailable.
- Low confidence.
- Nonviable images.
- Normal adjacent success.

Every failure must retain the current Reader session. When a safe target is known, Retry and Open Original remain available. Repeated taps while loading produce one request. Retry occurs only after explicit user action and observes the existing conservative delay. Success installs one viable adjacent session and preserves Back/View Original origin behavior.

## Test-fixture strategy

Shared fixture plumbing is established before parallel test work so isolated agents do not collide in `ToonEdgeAppEntry.swift`.

The fixture contract should use one namespaced launch argument with a small typed scenario value, for example:

```text
-readerHardeningFixture numeric-adjacency
-readerHardeningFixture continue-target
-readerHardeningFixture adjacent-timeout
-readerHardeningFixture adjacent-unavailable
-readerHardeningFixture adjacent-low-confidence
-readerHardeningFixture adjacent-nonviable
-readerHardeningFixture adjacent-success
```

The fixture layer supplies sanitized repository/service dependencies through existing protocols. Individual UI-test slices should then modify only their assigned test files unless a failing regression requires an owning production file.

No live page HTML, artwork, cookies, authentication state, or protected content may enter fixtures or result artifacts.

## Work slices

### Slice A — DEF-036 live parity

- Inspect current route policy and regression coverage.
- Capture a direct and in-site control on the dedicated iPhone 16e.
- Close with evidence only if parity is viable and proven.
- Otherwise keep open for site unavailability/nonviability, or add one observed-sequence regression and minimal production fix if the app diverges.
- Commit independently as either evidence-only closure or a focused route remediation.

### Slice B — DEF-020 visible numeric adjacency

- Add the sparse numeric Reader fixture.
- Prove chapter 155 targets 154/156 and never 1/169.
- Prove stored exact payload preference and unsafe-inference graceful failure through existing resolver behavior.
- Avoid production changes unless the UI journey exposes a defect.
- Commit independently.

### Slice C — DEF-021 authoritative Continue journey

- Add the chapter 1/newer chapter 3 fixture.
- Prove immediate Reader return, CTA label/destination, relaunch persistence, and adjacent discovery.
- Keep Recent ordering assertions separate from CTA assertions.
- Avoid production changes unless the UI journey exposes a defect.
- Commit independently.

### Slice D — DEF-022 typed-failure matrix

- Extend sanitized adjacent fixtures for missing typed outcomes and normal success.
- Prove actionable copy, safe target retention, one explicit retry, no automatic loop, and session preservation.
- Prove Back and View Original after adjacent success and failure.
- Commit independently.

### Slice E — release hardening and evidence

- Traverse a deterministic long chapter with delayed dimensions and one transient image failure.
- Revalidate retained-cache removal and measured-storage recalculation.
- Revalidate Settings update-found, no-update, partial/total failure, and unavailable-service outcomes.
- Run protected WEBTOON/GlobalComix fixtures and any authorized live controls without bypassing protection.
- Run complete UI suites on both dedicated simulators and the exact required build.
- Record commands, counts, `.xcresult` paths, limitations, live-versus-fixture distinctions, and artifact-retention guidance.
- Update defect status only after its acceptance criteria are satisfied.

## Parallel execution model

Work proceeds in waves:

1. **Baseline and shared fixture contract:** one integration owner records status/hashes and lands the namespaced fixture plumbing.
2. **Parallel evidence/test work:** one agent owns DEF-036 live parity, one owns DEF-020 UI coverage, and one owns DEF-021 UI coverage. All use isolated worktrees from the same fixture-foundation revision and exclusive simulator/result paths.
3. **DEF-022 and integration:** after the Reader fixture/test files from DEF-020 are integrated, a dedicated agent extends the adjacent outcome matrix to avoid overlapping Reader test ownership.
4. **Independent reviews:** each slice receives spec-compliance and code-quality review before integration.
5. **Final gates:** one integration owner runs both complete simulator suites and writes the final evidence ledger.

Parallel agents must not edit the same checkout. Any slice needing `ToonEdgeAppEntry.swift` after the shared fixture contract must stop and coordinate instead of creating a conflicting fixture path.

## Simulator and artifact isolation

- Dedicated iPhone 16e: `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`.
- Dedicated iPhone 16 Pro Max: `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`.
- Shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` must not be targeted.
- Each agent receives a unique `/private/tmp/toonedge-<slice>-derived` path and unique `.xcresult` path.
- Live Vortex work exclusively leases the iPhone 16e during its run.
- Simulator state changes are limited to the dedicated devices and restored when the check requires appearance/accessibility modification.

## TDD and evidence protocol

For every discovered defect or missing journey:

1. Name the exact acceptance criterion.
2. Add the smallest failing regression.
3. Run it and record the expected failure.
4. Make the smallest owning-layer change.
5. Run the focused regression.
6. Run `swift test --package-path app --jobs 1`.
7. Run the affected simulator journey on a dedicated device.
8. Record sanitized evidence and limitations.
9. Update status only when every criterion passes.
10. Commit the slice with exact-file staging.

Evidence must distinguish package integration tests, sanitized UI fixtures, and live-site outcomes. Fixture success cannot close a live-only acceptance criterion.

## Final automated gates

At minimum:

```bash
swift test --package-path app --jobs 1
```

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-high-priority-ui-16e-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-high-priority-ui-16e.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-high-priority-ui-promax-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-high-priority-ui-promax.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-next-hardening-derived \
  build CODE_SIGNING_ALLOWED=NO
```

Expected build result: `** BUILD SUCCEEDED **`.

## Guardrails

- WEBTOON and protected GlobalComix remain browser-only.
- Do not bypass authentication, challenges, paywalls, rate limits, or protected viewers.
- Do not add catalogs, source marketplaces, or recommendations.
- Detection remains conservative; false positives are worse than false negatives.
- Reader always retains View Original Page.
- Multi-page stitching remains out of scope.
- Reuse `ChapterNumericLabelExtractor`, `ChapterURLInference`, repository/lifecycle interfaces, and existing typed adjacent-load models.
- Do not introduce a second chapter parser, view-level adjacency resolver, or parallel route observer.
- Do not introduce a SwiftData migration unless a new failing regression proves it unavoidable; the approved design expects no migration.
- Preserve the three protected local screenshots untracked and unchanged.

## Completion criteria

This effort is complete when:

- DEF-036 is either closed by viable live parity evidence or remains explicitly open with the current live limitation documented; it is never silently closed from fixture evidence.
- DEF-020’s visible Reader journey proves 155 navigates to 154/156 rather than 1/169.
- DEF-021’s visible Series Detail journey proves chapter 3 immediately, after relaunch, and after adjacent discovery.
- DEF-022’s visible matrix proves every typed failure, explicit recovery, normal success, and origin-aware Back/View Original behavior.
- Release-hardening journeys and all automated gates pass.
- Every slice is independently committed and reviewed.
- Evidence contains no copyrighted page captures or sensitive session data.
- The protected screenshots retain their recorded hashes and the shared iPhone 16 Pro remains untouched.
