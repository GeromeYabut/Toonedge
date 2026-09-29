# High-Priority Release Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for any newly exposed defect, superpowers:systematic-debugging for failures, and superpowers:verification-before-completion before making release claims. Begin only after reviewed DEF-036, DEF-020, DEF-021, and DEF-022 slices are integrated.

**Goal:** Complete the remaining release-hardening journeys across both dedicated device sizes, preserve safety boundaries, and produce one durable evidence ledger.

**Architecture:** Prefer existing production services and deterministic sanitized fixtures. Add fixture plumbing only where an external condition cannot be controlled. Any observed product defect returns to RED-first implementation in its owning layer and receives a separate fix commit before this verification commit.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI, XCUITest, XCTest result bundles, iOS 18.6 simulators.

## Safety baseline

- Never target shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- Use iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED` and iPhone 16 Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4` only.
- Do not erase either simulator; preserve unrelated data and state.
- Never capture or commit copyrighted page artwork, protected content, cookies, credentials, or complete sensitive URLs.
- WEBTOON and protected GlobalComix remain browser-only.

---

### Task 1: Establish final baseline and artifact locations

**Files:**
- Create: `docs/qa_evidence/2026-09-29-high-priority-defect-completion.md`

- [ ] Record branch, HEAD, `git status --short --untracked-files=all`, Xcode version, simulator runtimes, and the two permitted simulator identifiers.
- [ ] Hash the three protected screenshots and compare them with the hashes in the master plan.
- [ ] Create the ledger with sections for package, focused UI, complete UI on each device, exact build, live versus fixture results, accessibility/appearance review, limitations, and durable artifact recommendations.
- [ ] Use these durable local paths in commands:

```text
/private/tmp/toonedge-final-16e.xcresult
/private/tmp/toonedge-final-16promax.xcresult
/private/tmp/toonedge-next-hardening-derived
```

Recommend CI upload of `.xcresult`, sanitized screenshots, and text logs with at least 30-day retention; local `/private/tmp` paths are not durable CI artifacts.

### Task 2: Verify long-chapter traversal and transient recovery

**Files:**
- Modify if needed: `app/ToonEdge/ToonEdgeAppEntry.swift`
- Modify if needed: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`
- Test first if defect found: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`

- [ ] Add a typed `long-chapter` fixture only if no existing deterministic fixture covers all requirements. It must use 40 sanitized 1x1 fixture images, delayed dimensions, and exactly one first-attempt transient failure that succeeds on explicit/normal retry.
- [ ] Traverse from first through final panel, confirming lazy loading, stable order, updated progress, delayed-dimension layout stability, recovery from the one transient failure, and no permanently blank panel.
- [ ] Repeat the journey in compact width on iPhone 16e and the widest supported layout on iPhone 16 Pro Max.
- [ ] If any failure appears, add the smallest package/UI regression before changing Reader code; commit that fix separately.

### Task 3: Verify retained-cache deletion and measured recalculation

**Files:**
- Modify if needed: `app/ToonEdge/ToonEdgeAppEntry.swift`
- Modify if needed: `app/ToonEdgeUITests/ToonEdgeOfflineUITests.swift`
- Test first if defect found: `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`

- [ ] Seed one retained chapter by writing sanitized bytes through `ChapterAssetCaching`, record matching retained metadata, and use `CacheStorageMeasurementService` rather than an estimated-only mock.
- [ ] Open Downloads and record the measured byte summary and retained count.
- [ ] Remove the retained chapter through the visible control.
- [ ] Assert the row disappears, its chapter directory is removed, retained count becomes zero, and the measured storage summary recalculates to zero/no tracked local storage.
- [ ] Relaunch once and assert the deletion remains reflected.

### Task 4: Verify Settings update-check outcomes

**Files:**
- Modify if needed: `app/ToonEdgeUITests/ToonEdgeSettingsUITests.swift`
- Modify if needed: `app/ToonEdge/ToonEdgeAppEntry.swift`

- [ ] Exercise success-with-update via `-seedUpdateSuccess`.
- [ ] Exercise successful no-update via `-seedUpdateNoChange`.
- [ ] Exercise partial failure via `-seedUpdateFailure`.
- [ ] Add a deterministic total-service-failure fixture only if the existing failure fixture does not reach the true error state.
- [ ] For each, assert loading disables duplicate submission, the final message is distinct and actionable, and the screen remains usable.

### Task 5: Complete spoken accessibility and appearance review

**Surfaces:** Home, Browser Clean Mode CTA, Reader chrome, Series Detail, Downloads, Settings.

- [ ] On iPhone 16e, enable VoiceOver and inspect spoken order, labels, values, hints, headings, rotor usefulness, focus restoration after sheets/Reader dismissal, and 44-point action targets.
- [ ] Specifically verify Reader failure feedback announces once, Retry/Open Original are reachable, and focus does not jump into hidden chrome.
- [ ] Repeat the critical path with increased contrast.
- [ ] Review all six surfaces in light and dark mode on iPhone 16e.
- [ ] Review truncation, safe-area placement, readable widths, and chrome reachability in light and dark mode on iPhone 16 Pro Max.
- [ ] Record observations as Pass, Defect, or Limitation. Any behavior defect gets a RED test and separate fix commit; subjective polish goes to the quiet-editorial backlog, not this defect-closure commit.

### Task 6: Verify routing and protected-site guardrails

- [ ] After successful adjacent navigation, assert Back follows launch origin and View Original opens the current Chapter 2 URL.
- [ ] After each adjacent-load failure family, assert Back remains available and Open Original uses the preserved safe adjacent target.
- [ ] Re-run protected WEBTOON and GlobalComix fixture journeys; assert Clean Mode is absent and Reader never auto-opens.
- [ ] If a live protected page is used, do not authenticate, bypass challenges, record page content, or save screenshots. Record only sanitized route-policy outcomes.
- [ ] Confirm Vortex live Next/Previous evidence from the DEF-036 ledger; if the site was unavailable/nonviable, retain that limitation and keep DEF-036 open.

### Task 7: Run all automated final gates

- [ ] Run all new focused package and UI regressions first.
- [ ] Run the complete package suite:

```bash
swift test --package-path app --jobs 1
```

- [ ] Run the complete UI suite on iPhone 16e:

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=4582CDE9-27DB-4669-86AC-0631C1D7F2ED' \
  -derivedDataPath /private/tmp/toonedge-final-16e-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-final-16e.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] Run the complete UI suite on iPhone 16 Pro Max:

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -destination 'platform=iOS Simulator,id=29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4' \
  -derivedDataPath /private/tmp/toonedge-final-16promax-derived \
  test -only-testing:ToonEdgeUITests \
  -resultBundlePath /private/tmp/toonedge-final-16promax.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] Run the exact required build:

```bash
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' \
  -derivedDataPath /private/tmp/toonedge-next-hardening-derived \
  build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] Run `git diff --check` and capture final test counts/result-bundle paths in the ledger.

### Task 8: Final defect audit and commit

**Files:**
- Modify only when justified: `docs/defects.md`
- Modify: `docs/qa_evidence/2026-09-29-high-priority-defect-completion.md`

- [ ] Audit every acceptance criterion for DEF-020, DEF-021, DEF-022, and DEF-036 against its focused ledger and final gates.
- [ ] Keep DEF-036 open if live in-site parity could not be completed, even when the deterministic fixture passes.
- [ ] List defects completed/still open, root causes, commits, files/interfaces, all test results, live versus fixture evidence, migration/compatibility risk, and remaining release risks.
- [ ] Re-hash the protected screenshots, confirm they remain untracked, and record that the shared iPhone 16 Pro was never targeted.
- [ ] Stage only the final ledger and any justified defect status change:

```bash
git add \
  docs/defects.md \
  docs/qa_evidence/2026-09-29-high-priority-defect-completion.md
git commit -m "test: complete high-priority defect verification"
```

If `docs/defects.md` did not change, omit it from staging. Never stage the three protected screenshots.
