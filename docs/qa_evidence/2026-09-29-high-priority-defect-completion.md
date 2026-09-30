# High-Priority Defect Completion Evidence Ledger

## Status and scope

Initial baseline recorded **2026-09-30 08:03:29 PDT**, followed by the Task 2 long-chapter results below. The filename retains the approved 2026-09-29 plan date. Final release verification is **pending**; this ledger does not close any defect or claim that the final gates have passed.

Sources: [release-verification plan](../superpowers/plans/2026-09-29-high-priority-release-verification.md) and [master execution plan](../superpowers/plans/2026-09-29-high-priority-defect-execution.md). Task 1 performed read-only environment and repository checks and created this ledger. It did not run tests, build the app, launch or change a simulator, inspect screenshot contents, or modify app code, tests, defect statuses, or protected screenshots.

## Repository baseline

| Field | Recorded value |
|---|---|
| Worktree | `/Users/geromeyabut/Developer/Toonedge/.worktrees/high-priority-release-verification` |
| Branch | `high-priority-release-verification` |
| HEAD before ledger creation | `560d74d3ed656647ea1078530eb4e2ccbd52276a` |
| HEAD subject | `docs: correct DEF-022 simulator evidence` |
| `git status --short --untracked-files=all` | Empty output; clean before ledger creation |

Read-only commands, run from this worktree:

```sh
git branch --show-current
git rev-parse HEAD
git log -1 --oneline
git status --short --untracked-files=all
xcodebuild -version
xcrun simctl list runtimes
xcrun simctl list devices available
```

All completed with exit code 0. Later gate entries must record the tested HEAD and any working-tree changes; this initial baseline does not describe future revisions.

## Toolchain and simulator inventory

- Xcode: **16.4**, build **16F6**.
- Available runtime: **iOS 18.6**, build **22G86**, identifier `com.apple.CoreSimulator.SimRuntime.iOS-18-6`. No other runtime appeared in the inventory.
- Simulator state below was observed through listing only; Task 1 did not change it.

| Device | Identifier | Observed state | Permission |
|---|---|---|---|
| iPhone 16e | `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` | Booted | Dedicated verification device |
| iPhone 16 Pro Max | `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` | Booted | Dedicated verification device |
| iPhone 16 Pro | `04F65B71-EEB9-4085-BFBD-8B7406E480A2` | Shutdown | Shared; never target |

The same runtime also listed SIm1, iPhone 16, iPhone 16 Plus, iPad Pro 11-inch (M4), iPad Pro 13-inch (M4), iPad mini (A17 Pro), iPad (A16), iPad Air 13-inch (M3), and iPad Air 11-inch (M3), all shutdown. They are outside the permitted device set. Run the two approved device gates sequentially, preserve unrelated data, and never erase a simulator.

## Protected screenshot integrity

The three protected files are untracked in the primary checkout, so they are absent from this isolated worktree. They were checked by path and hash only, without opening, copying, staging, or modifying their content.

Read-only commands:

```sh
git -C /Users/geromeyabut/Developer/Toonedge status --short --untracked-files=all -- \
  docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
shasum -a 256 \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
```

Both commands exited 0. Git reported `??` for each exact path. All hashes match the master plan:

| File | Observed and expected SHA-256 | Comparison |
|---|---|---|
| `manhuatop-chapter-label-top.png` | `7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8` | Match |
| `manhuatop-original-page.png` | `56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a` | Match |
| `webtoon-protected-reader-cta.png` | `49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5` | Match |

Repeat this comparison during the final audit. Do not stage these files.

## Package gate

**Pending — not executed by Task 1.** Record tested HEAD, exact command, exit code, Swift Testing count, failures/skips, and sanitized log location.

```sh
swift test --package-path app --jobs 1
```

## Focused UI and journey gates

**Partially verified.** Task 2 long-chapter traversal and explicit image recovery passed on both dedicated devices as recorded below. Retained-cache deletion with measured recalculation and relaunch, Settings update outcomes, adjacent routing, and protected-site browser-only final gates remain pending. Run new focused regressions before complete UI gates. Record VoiceOver and appearance findings separately below.

### Task 2 — long-chapter traversal and explicit recovery

Implementation commit: `6c932967f594357da609ce250fc4a5c640d444cd` (`test: verify long chapter traversal recovery`). It changes only fixture plumbing in `app/ToonEdge/ToonEdgeAppEntry.swift` and the focused journey in `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`. No production Reader implementation, schema, or production interface changed.

The focused test is `ToonEdgeUITests/ToonEdgeLongChapterUITests/testLongChapterTraversesFortyPanelsAndRecoversTransientImageFailure`, launched with `-uiTesting -resetTestData -readerHardeningFixture long-chapter`.

| Attempt | Device | Result | Elapsed test time | Result bundle |
|---|---|---|---|---|
| Initial RED | Dedicated iPhone 16e | Failed; development baseline | Not recorded here | `/private/tmp/toonedge-long-16e-red.xcresult` |
| Attempts 2–5 | Dedicated iPhone 16e | 0 passed, 1 failed each; panel 1 was not observed | Not retained | `/private/tmp/toonedge-long-16e-attempt2.xcresult` through `/private/tmp/toonedge-long-16e-attempt5.xcresult` |
| Attempts 6–10 | Dedicated iPhone 16e | 0 passed, 1 failed each; stationary panel-1 expectation failed | Not retained | `/private/tmp/toonedge-long-16e-attempt6.xcresult` through `/private/tmp/toonedge-long-16e-attempt10.xcresult` |
| Attempt 11 | Dedicated iPhone 16e | 0 passed, 1 failed; stationary panel-1 expectation exposed stale restored position and wrong scroll query | Not retained | `/private/tmp/toonedge-long-16e-attempt11.xcresult` |
| Final attempt 12 | Dedicated iPhone 16e, `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` | 1/1 passed, 0 failures | 165.134 seconds | `/private/tmp/toonedge-long-16e-attempt12.xcresult` |
| Final Pro Max | Dedicated iPhone 16 Pro Max, `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` | 1/1 passed, 0 failures | 176.122 seconds | `/private/tmp/toonedge-long-promax.xcresult` |

Read-only `xcresulttool` inspection confirmed that attempts 2–11 each contain one failed focused test. Attempts 2–5 span the discarded URL-protocol, localhost-listener, and initial cache-transport experiments; the exact experiment-to-bundle mapping was not retained, so this ledger does not invent one. Attempts 6–10 used the stationary page-1 assertion while the fixture bytes, decoding guard, and accessibility query were corrected. Attempt 11's safe hierarchy showed loaded/labeled images 27–33 with positive frames, proving that stale restored progress had opened near panel 30 and that `.scrollViews.firstMatch` selected Home behind Reader. The final fixture validates its replacement PNG with `UIImage`, supplies a fresh mock progress repository, and the test uses `reader.root` after asserting that it is the Reader scroll view. Page 1 is checked while stationary before traversal. These were fixture/test corrections, not evidence of a production Reader defect.

Fixture semantics and observed coverage:

- Forty ordered panel URLs use decodable, sanitized 1×1 PNG content from an injected fixture cache. Metadata is empty, and each cache lookup has an 80 ms synchronous delay, exercising fallback layout before the decoded image becomes available.
- Panel 20's first cache lookup deliberately misses. Its loopback URL (`127.0.0.1:1`) cannot supply the image, so the normal transport attempts produce one visible first-load failure. The test taps the visible **Retry** action; that explicit reload obtains the cached PNG and clears the failure. This is not a single failed HTTP request followed by automatic success.
- The test traverses all forty panels through the lazy Reader surface, checks loaded images and nonzero frames for panels 2–40, confirms the panel 20 failure clears, and finishes with displayed progress of **100%**. It does not instrument lazy-load allocation counts or measure performance/layout-shift bounds.

Classification: **deterministic fixture UI evidence only**. This does not validate live image transport, real delayed image metadata, remote-server recovery, or the memory/performance behavior of full-resolution chapter artwork. The loopback failure is intentional fixture transport; no live content is needed. No safe screenshot was captured for Task 2, so there is no standalone screenshot artifact to claim.

The recorded Task 2 runs targeted only the dedicated 16e and Pro Max; the shared iPhone 16 Pro was not targeted and protected screenshots were not modified. This ledger-only update runs no simulator commands or tests and does not re-hash protected files; their final integrity recheck remains required by the final audit.

Prior slice ledgers are context, not substitutes for these final gates:

- [DEF-020 numeric adjacency](2026-09-29-def-020-numeric-adjacency.md)
- [DEF-021 authoritative Continue](2026-09-29-def-021-authoritative-continue.md)
- [DEF-022 typed adjacent outcomes](2026-09-29-def-022-adjacent-outcomes.md)
- [DEF-036 Vortex parity](2026-09-29-def-036-vortex-parity.md)

## Complete UI suite — iPhone 16e

**Pending — planned command, not executed by Task 1.** Record tested HEAD, count, failures/skips, elapsed time, and log path.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-final-16e-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-final-16e.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Complete UI suite — iPhone 16 Pro Max

**Pending — planned command, not executed by Task 1.** Run after the 16e gate. Record tested HEAD, count, failures/skips, elapsed time, and log path.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-final-16promax-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-final-16promax.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Exact required build

**Pending — planned command, not executed by Task 1.** Record tested HEAD, exit code, build summary, warnings, and sanitized log path. Expected success marker is `** BUILD SUCCEEDED **`.

```sh
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-next-hardening-derived \
  build CODE_SIGNING_ALLOWED=NO
```

## Live versus fixture results

**Pending final audit.** Task 2 is deterministic fixture evidence only, with the transport and image-size limitations recorded above. Label every other result as live, deterministic fixture, package/repository, or manual inspection. Fixture evidence cannot close a live-only criterion. Reconcile DEF-036 with its focused ledger and keep it open if live in-site parity remains unavailable or nonviable. WEBTOON and protected GlobalComix must remain browser-only; do not authenticate, bypass protection, record protected content, or capture live protected screenshots.

## Accessibility and appearance review

**Pending.** Record Pass, Defect, or Limitation with device and setting for Home, Browser Clean Mode CTA, Reader chrome, Series Detail, Downloads, and Settings. Cover spoken VoiceOver order/labels/values/hints, headings and rotor usefulness, focus restoration, hidden chrome, once-only failure announcements, reachable Retry/Open Original, 44-point targets, increased contrast, and light/dark appearance on both dedicated device sizes. Accessibility-tree or package assertions alone are not spoken VoiceOver evidence.

## Final defect audit and compatibility

**Pending.** Map every DEF-020, DEF-021, DEF-022, and DEF-036 acceptance criterion to evidence; list completed and still-open defects, root causes, commits, files/interfaces, test results, and remaining release risks. No schema or production interface changed in Task 1. Audit migration/compatibility risk against later implementation changes before release claims. Recheck protected hashes and confirm the shared 16 Pro was never targeted.

## Artifact locations and durable retention

The prescribed local result paths are `/private/tmp/toonedge-final-16e.xcresult` and `/private/tmp/toonedge-final-16promax.xcresult`; the exact build uses `/private/tmp/toonedge-next-hardening-derived`. These are planned local working paths, **not durable CI artifacts**, and Task 1 does not assert that these future outputs exist.

Recommend a CI artifact set keyed by tested commit SHA and run ID containing both `.xcresult` bundles, sanitized screenshots, package/UI/build text logs, and a copy of this ledger, with **at least 30-day retention**. Record durable artifact URLs here after upload. Review exported attachments/logs for protected art, cookies, credentials, and sensitive full URLs before upload. Preserve prior failed results when rerunning; do not overwrite or delete evidence silently. Record each attempt and its actual path.

## Limitations and outstanding work

- Task 1 provides baseline and integrity observations; Task 2 adds the focused long-chapter journey on both dedicated devices. Package, remaining focused UI, complete UI, exact build, accessibility/appearance, live-site, and final defect gates remain unverified in this ledger.
- Local runtime/device inventory is a point-in-time observation, not proof of app behavior or simulator mutation history outside Task 1.
- No live content or protected screenshot contents were viewed or captured in this task.
- The final release claim requires fresh gates after review fixes and durable artifact publication; neither occurred in Task 1.

## Ledger validation

Run `git diff --check` after creating/updating this ledger and record its outcome with the task handoff. Stage only this ledger for the Task 1 commit; the baseline HEAD above intentionally identifies the revision before that documentation commit.
