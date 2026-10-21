# Reader UX polish implementation plan

> Agentic workers use subagent-driven development. Controller alone mutates checkouts and dispatches verification; subagents write only designated proposal/report files.

Goal: implement the approved seven UX items, independently review and install on the user's iPhone; no merge.
Architecture: keep routing/coordinators outside presentation, use existing universal search, native zoom state and settings services. Read-only chapter resolution changes may repair recent-only navigation; persistence writes, progress gates and schema stay parked.
Tech: Swift6, SwiftUI/UIKit, iOS17 API floor, Swift Testing/XCTest, Xcode.

## Global constraints
- Every old artifact/stopped checkout remains preserved. Never copy or read protected screenshots. User-attached cover screenshots remain conversation references only.
- Native shared simulator04F65B71-EEB9-4085-BFBD-8B7406E480A2 is forbidden; focused owned fixtures may run on dedicated16e4582CDE9-27DB-4669-86AC-0631C1D7F2ED. Do not inspect/capture user phone reading content.
- All code applications have complete UTF8 before/after envelopes, exact absolute paths, SHA256 and applied-byte verification. No trimmed payloads. New files have before:null. Controller captures source/HEAD/status before edits.
- Agents may only write their task-N-proposal.json and task-N-report.md (reviewers their assigned reports). No agent runtime, source/Git mutation or test dispatch.
- Tests first for behavior; compile error alone is not expected behavioral RED. Existing API behavior regressions can establish RED before adding helper APIs/tests. Focused tests then full package jobs1, simulator/iPhone build, bounded targeted UI, independent review.
- Three stage reviews and one fresh broad final review. Material findings get concrete fixes and focused reruns. Do not stop for routine approvals within approved scope. Stop for actual blockers/scope changes/additional authority. No merge or remote branch deletion.

## Task1: Continue Reading routing
Files: HomeView.swift; read-only query/domain helpers in AppModels.swift and SwiftDataLibraryRepository.swift if needed; focused tests in existing app/Tests/ToonEdgeAppCoreTests. No store/commit/progress mutation changes.
Consumes: LibraryLifecycleManaging.continueReadingTarget, readerSession, existing Router browser/Reader transitions. Produces: reliable recent-only/saved resume, visible loading/retry, no empty routing.
- [ ] Proposal diagnoses root cause and gives complete staged tests/fix source envelopes, focused filter and report.
- [ ] Controller validates/applies existing-API regression tests only; verify expected failure for recent-only target.
- [ ] Apply minimal query/routing fix + any additional helper tests, run focused GREEN.
- [ ] Task reviewer verifies spec and quality from exact diff/receipts; commit reviewed task independently.

## Task2: Reader compact controls and zoom badge
Files: ReaderView.swift, a small shared chrome surface if needed, native ReaderSurfaceViewController.swift and focused Reader tests. Keep interaction state/policy/persistence untouched.
Consumes: actual state.presentation.scale and existing gesture terminal callbacks. Produces: transparent accessible chrome, compact spacing, a passive transient percentage overlay.
- [ ] Tests establish existing Reader/control behavior or policy gaps; stage helper-API tests with fix if needed.
- [ ] Controller applies minimal proposal and verifies focused cases, existing gap/sticky tests and relevant accessibility metrics.
- [ ] Reviewer checks applied-scale feedback, timer/cancellation/lifecycle, UI contrast/touch size and native isolation; commit reviewed stage.

## Task3: Dark shell, Home/Library layout and shared search
Files: AppShellView.swift, AppRouter.swift, HomeView.swift, LibraryView.swift, DownloadsView.swift, SettingsView.swift, Browser/Reader search entry wiring, design tokens/primitives, UX docs. Tests: router/search/appearance/home/library focused cases; owned UI fixture when needed.
Consumes: router.presentSearch, dismissSheet, existing Browser input flow. Produces: context-preserving single search flow from all approved entries; black default; compact Home/Library.
- [ ] Proposal maps current modal hierarchy and cancellation/selection routes; test existing behavior via existing API to demonstrate RED.
- [ ] Apply staged tests then source after expected RED; run focused GREEN and full package.
- [ ] Verify targeted owned native cases for dark Home/search, recent resume, Library controls, search cancellation from tabs and Reader, zoom badge/chrome. No broad persistence/clean-context matrix.
- [ ] Stage review; resolve concrete issues, commit stage; fresh whole-branch reviewer assesses full diff and stage records.

## Delivery and verification
Fresh W=/Users/geromeyabut/.codex/worktrees/reader-ux-polish/Toonedge; branch feature/reader-ux-polish; E=/Users/geromeyabut/.codex/worktrees/reader-ux-polish/Toonedge/docs/qa_evidence/2026-10-20/reader-ux-polish; outputs=/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-reader-ux-polish-20261020a. Disk UUID/write probe and capacity before runtime. Local allocation initially three RED/GREEN stage cycles, one final full package, one simulator build-for-testing/targeted suite up to8 native test methods, one signed iPhone build/install/launch. Reuse only this attempt's outputs; no old-output cleanup. Additional focused reruns require recorded actual failure/fix reason, stay within approved seven items. No automatic broad test expansion.
Record exact commands, completion/exit, case accounting, artifact hashes, attachment/privacy scans and review checkpoints in E. No source changes after final review without reviewer recheck. Install only exact reviewed signed build, without uninstall/reset; launch normal app without fixture flags. Preserve evidence and leave branch unmerged. No new PR is necessary unless user asks; local reviewable commits and final diff/QA are retained.

Progress ledger is E/progress.md; trust it across compaction. User has approved execution; no further design approval is pending.
