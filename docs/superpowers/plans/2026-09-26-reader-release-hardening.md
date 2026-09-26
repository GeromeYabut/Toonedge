# Reader Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revalidate DEF-036, close DEF-020 through DEF-022 with regression-first slices, and complete the requested release-hardening evidence pass.

**Architecture:** Keep route observation in `BrowserWebView`, numeric chapter identity and safe URL inference in domain/repository helpers, Continue selection in the repository-backed Series Detail projection, and adjacent loading/error classification in the Reader loading service. UI views consume typed state and expose actions without owning parsing, persistence, or retry policy.

**Tech Stack:** Swift 6, SwiftUI, WebKit, SwiftData, Swift Testing, XCTest/XCUITest, Xcode 16.4, iOS 18.6 simulators.

## Global Constraints

- Preserve the three protected untracked screenshots without reading, editing, staging, moving, or deleting them.
- Never use the shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- WEBTOON and protected GlobalComix remain browser-only.
- Do not bypass authentication, challenges, paywalls, rate limits, or protected viewers.
- Multi-page chapter stitching remains out of scope.
- Every production behavior change starts with a focused failing regression and recorded RED result.
- Run the focused test, `swift test --package-path app --jobs 1`, simulator journey, documentation update, and independent commit for each completed defect.

---

### Task 1: Revalidate DEF-036 Vortex route observation

**Files:**
- Inspect: `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/BrowserExperienceTests.swift`
- Fixture: `app/Tests/ToonEdgeAppCoreTests/Fixtures/vortex_spa_chapter_169.json`
- Modify only if live reproduction fails: the smallest route-policy/test surface matching the observed callbacks
- Evidence: `docs/qa_evidence/2026-09-26-reader-release-hardening.md`

**Interfaces:**
- Consumes: `BrowserDetectionNavigationPolicy.shouldSchedule(url:isLoading:)`.
- Produces: one detection schedule per settled main-frame route and one Reader presentation per viable result.

- [x] Inspect route observation, debounce, deduplication, fixture, and presentation diagnostics.
- [x] Run focused fixture/policy regressions.
- [x] Exercise series page to chapter and direct chapter loads on the dedicated iPhone 16e while capturing sanitized logs.
- [ ] If both paths match, document evidence and close DEF-036 without production changes.
- [x] If they differ, add the smallest failing integration regression for the observed callback sequence, verify RED, implement the minimal route fix, and repeat verification.
- [x] Run the full package suite, update `docs/defects.md`, and commit the slice.

### Task 2: Close DEF-020 numeric Reader adjacency

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift` only if a shared resolver is still missing
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift` only if current behavior fails
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Evidence: `docs/qa_evidence/2026-09-26-reader-release-hardening.md`

**Interfaces:**
- Consumes: `ChapterNumericLabelExtractor` and `ChapterURLInference`.
- Produces: stored-payload-first numeric `current - 1` / `current + 1` adjacent references, never Recent ordering.

- [x] Add focused sparse 1/155/169 regressions for next 156, previous 154, stored 156 payload preference, and unsafe-inference graceful failure.
- [x] Run each new test and record the expected RED result; if behavior already exists, strengthen the test at the unresolved interface until it proves the defect boundary.
- [x] Implement only the missing domain/repository behavior.
- [x] Run focused and full package tests, exercise Reader controls on a fixture/dedicated simulator, update the defect/evidence docs, and commit.

### Task 3: Close DEF-021 authoritative Continue target

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift` only if selection semantics fail
- Modify: `app/Sources/ToonEdgeAppCore/Core/Persistence/Repositories/SwiftDataLibraryRepository.swift` only if reconciliation or reconstruction fails
- Test: `app/Tests/ToonEdgeAppCoreTests/LibraryExperienceTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/PersistenceLifecycleTests.swift`
- Evidence: `docs/qa_evidence/2026-09-26-reader-release-hardening.md`

**Interfaces:**
- Consumes: canonical chapter labels, progress `lastReadAt`, and recent-reading reconciliation.
- Produces: one repository-backed latest-active Continue target independent from Recent display order.

- [x] Add chapter 1 / newer chapter 3 regressions for immediate return, repository reconstruction, and adjacent discovery.
- [x] Verify RED for every missing acceptance path.
- [x] Implement the smallest selector/reconciliation correction.
- [x] Run focused and full package tests, exercise Series Detail return/resume on the dedicated simulator, update docs, and commit.

### Task 4: Close DEF-022 typed adjacent-load failures

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/AdjacentReaderSessionLoader.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Core/Domain/AppModels.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/ViewModels/ReaderViewModel.swift`
- Modify: `app/Sources/ToonEdgeAppCore/Features/Reader/Views/ReaderView.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/AdjacentReaderSessionLoaderTests.swift`
- Test: `app/Tests/ToonEdgeAppCoreTests/ReaderExperienceTests.swift`
- Add sanitized deterministic fixtures only when needed
- Evidence: `docs/qa_evidence/2026-09-26-reader-release-hardening.md`

**Interfaces:**
- Produces: typed timeout, challenge/rate-limit, unavailable, low-confidence, and non-viable-image errors with safe target URL and sanitized diagnostics.
- Produces: non-blocking Retry and Open Original actions with conservative user-initiated retry/backoff.

- [x] Add failing challenge, rate-limit, timeout, unavailable, low-confidence, and non-viable-image loader regressions.
- [x] Add failing Reader state/action regressions proving target preservation, actionable copy, Retry, Open Original, and no automatic loop.
- [x] Implement typed classification and sanitized diagnostics in the loader.
- [x] Implement Reader failure state/actions and a conservative user-initiated retry policy.
- [x] Verify normal stored and hidden adjacent navigation remains unchanged.
- [x] Run focused/full tests, fixture UI journey, update docs, and commit.

### Task 5: Release-hardening verification

**Files:**
- Modify/add focused tests and deterministic launch fixtures only where a listed journey lacks coverage
- Update: `docs/qa_evidence/2026-09-26-reader-release-hardening.md`
- Update: `docs/qa_reports/2026-09-22-holistic-ux-quality-review.md`

- [ ] Run long-chapter delayed-dimension/transient-failure traversal.
- [ ] Exercise live Vortex Next/Previous when available.
- [x] Exercise retained-cache deletion and measured-storage recalculation.
- [x] Exercise Settings update success/no-update/failure fixtures.
- [ ] Review VoiceOver/focus order on Home, Browser CTA, Reader, Series Detail, Downloads, and Settings.
- [x] Verify light, dark, increased contrast, iPhone 16e, and iPhone 16 Pro Max.
- [x] Verify back and View Original after adjacent success/failure.
- [x] Verify protected sites never expose Clean Mode or Reader.
- [x] Run package tests, complete UI tests on both dedicated simulators, and the exact iPhone 16e build command.
- [x] Record result bundles, limitations, durable artifact-retention recommendations, protected screenshot hashes/status, and shared-device non-use.
