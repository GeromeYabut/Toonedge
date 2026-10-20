# Story 13.4 — synthetic Reader zoom

User authorized parking persistence and implementing zoom in the owned synthetic Reader fixture. This is a reviewable fixture slice, not full Story 13.4 or production-safety acceptance. No production progress/persistence changes, Reader adoption, PR, push, or merge.

## Bindings and launch

- Fresh worktree: /Users/geromeyabut/.codex/worktrees/reader-zoom-synthetic-fixture/Toonedge
- Branch: feature/story-13.4-synthetic-reader-zoom
- Base and fetched origin/main: 4e2d55b4371ec645bac962a21d781e90572abf8c
- Frozen execution plan: docs/superpowers/plans/2026-10-20-story-13.4-synthetic-reader-zoom.md (blob 60878accba49e1229cf7b9763e37fe60e147b1da).
- Durable commands/results/reviews: story-13.4-synthetic-zoom/ adjacent directory.
- Xcode outputs: /Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-synthetic-reader-zoom.T0Cuje
- Debug launch arguments: `-uiTesting -readerZoomFixture` (both required; normal Reader route retained).
- Dedicated iOS 18.6 devices: iPhone 16e 4582CDE9-27DB-4669-86AC-0631C1D7F2ED; iPhone 16 Pro Max 29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4. Shared iPhone 16 Pro never targeted.
- Native budget began 15:44:40.760865Z, new-work cutoff 16:34:40.760865Z, absolute deadline 16:44:40.760865Z on 2026-10-20. Final test child finished 16:01:57.838139Z. No budget renewal.

## Implemented behavior

Transient geometry/state separated from UIKit and SwiftUI. One native scroll owner supports pinch focal anchoring, inspection pan, sticky .75–3 scale, double-tap/reset, bounded visible-page reuse, and 80↔3-page session replacement. Reset acknowledgments use current session/revision/request identity and actual converted native fiducial geometry. Fixed chrome supports single-tap hiding plus accessible Enlarge/Shrink/Reset and owned Original Page sheet. Pages are vector drawings; fixture performs no network or persistence work.

## Actual verification and failure accounting

| Gate | Actual result |
| --- | --- |
| Unchanged geometry baseline | exit 0; 19 tests / 2 suites |
| Zoom state RED | exit 1; missing new type, expected |
| Initial GREEN compile | exit 1; Swift Testing mutating-receiver macro issue |
| Corrected focused GREEN | exit 0; 6 tests / 1 suite |
| Full package regression | exit 0; 734 tests / 16 suites |
| Final native build-for-testing | exit 0 |
| Final iPhone 16e | exit 0; 3 tests, 0 failures |
| Final iPhone 16 Pro Max | exit 0; 3 tests, 0 failures |

Each phase .result.json contains exact argv, actual child exit, timestamps, log byte count and SHA-256; complete .log files are retained. The baseline exact argv is in the frozen plan/controller record. Final .xcresult summaries independently agree with both device IDs, OS18.6 and 3/0 counts.

Native cases cover real pinch/pan/reset with eleven native fiducial frame observations spanning more than one second, with all four frame values within 2pt; double-tap/single-tap chrome and Original Page coexistence; and actual native container bounds/reuse/shrink/session replacement. Final six device-case executions all passed.

Retained failed attempts are not relabeled passes: initial external-products installation failed before any zoom case (Missing bundle ID); controller stopped its exact owned child, child -15 / wrapper 241. First internal-staged 16e run was 2/3 (immediate chrome observation); first test-only wait correction was 0/1 (incorrect element nonexistence assumption). Final test waits for actual non-hittability and retains the original assertion; no app implementation was changed to satisfy these waits. The pure test compiler fix likewise retains assertions.

External-product install boundary followed documented existing project recovery: immutable internal copies of only built products, each byte-verified against external originals. All three staging versions and external artifacts preserved. They are disposable product copies; exact commands/results and source/evidence retention are durable in this worktree, not solely /private/tmp.

## Privacy and preservation

Protected screenshots were never payload-read, copied, staged, moved, changed, or deleted. Prior stopped checkouts, evidence and historical results remain preserved. Persistence's historical native inequality remains unresolved; the prior 5/6 diagnostic result has not been promoted to a pass.

Final passing bundles exported no matching attachments. The two failed UI bundles' exported attachments are event plists, owned fixture UI hierarchy/snapshot data, and two videos. Controller decoded/scanned complete plist/text payloads and inspected one-second contact-sheet samples of both recordings: default dedicated simulator springboard/launch plus owned vector fixture and Original Page sheet; no source artwork or sensitive page content observed. Sampling is not a frame-by-frame video audit. Credential pattern scan over retained textual evidence returned no matches. URL matches were reserved example.test test fixtures and public repository origin. Original interrupted install bundle has no Info.plist and cannot be opened by xcresulttool; it is preserved as incomplete, not repaired or represented as valid. Build-only bundles report zero tests/unknown, appropriately not counted as runtime passes.

## Reviews and limits

Independent stage source review accepted spec and quality; subsequent test-only corrections and final evidence gate are retained in reviews/. Distinct broad final review accepted the fixture with no blocking findings; full response is retained in reviews/broad-final.md (SHA-256 864ace59b55d663713605504bea93addff5b553bdbb48aa9c26f0d761b0999bf). Controller completed all34 prior-worktree binding and source/log preservation checks. Reviewer clarified that reset fidelity uses eleven observations over more than one second, not continuous measurement.

Deferred: progress safety, autosave, full clean-context matrix, production persistence, production Reader integration, native cancellation and active resize continuity, delayed real images/pipeline/memory-pressure coverage, actual VoiceOver and Reduce Motion. iOS17 runtime remains waived; API floor17 and package macOS14 remain required. This synthetic success does not resolve historical native inequality or clear production adoption.

## Final source pins

- app/Tests/ToonEdgeAppCoreTests/ReaderZoomFixtureStateTests.swift: 6507 bytes; SHA-256 7ac3a1e3e7b3d88eaa135c2617fe856bfc22ed2537d44b6d6632722a15789780
- app/Sources/ToonEdgeAppCore/Features/Reader/Interaction/ReaderZoomFixtureState.swift: 13626 bytes; SHA-256 63176b5b55af8c93d63d7cb1a76ecbe7edb0cae6ce329119c798b1fe7d5198de
- app/Sources/ToonEdgeAppCore/Features/Reader/Presentation/ReaderZoomFixtureViewController.swift: 15905 bytes; SHA-256 09c91b6981431362e48b690afc96181f144b0bae4a4196f55867c979d9617eb0
- app/ToonEdge/ReaderZoomFixtureRoot.swift: 5385 bytes; SHA-256 829c0a59a65606961008ff855409f576f02642c2e4c656c4e0f5310856f6dacd
- app/ToonEdgeUITests/ToonEdgeReaderZoomUITests.swift: 7163 bytes; SHA-256 ba7048b0bef2406fe89e668e0ace9f1df216ca846c6a9df99116f912f59c659f
- app/Sources/ToonEdgeAppCore/Features/Reader/Interaction/ReaderStickyBaselineZoomPolicy.swift: 3091 bytes; SHA-256 679e11205bdb3042c9565eb6c6943a23a6fcee5b062ee7acfcf6f52fb8d2242f
- app/ToonEdge/ToonEdgeAppEntry.swift: 49834 bytes; SHA-256 0c1cb2400c0e31da5f045302820f44f6246e9562fed4157bd34651efb754f8e3
- app/ToonEdge.xcodeproj/project.pbxproj: 56412 bytes; SHA-256 c7f909eb4e77a7156bee66d81d6c5a70319450f819653fa1f6fb40947ff92740
