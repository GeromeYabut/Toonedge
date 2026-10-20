# Independent review — Story 13.4 gap-centred pinch fix

**Result: no actionable findings. The narrow fix meets its plan and is suitable for the controller’s remaining delivery gates.** This does not clear the broader native gesture matrix, persistence adoption, or production safety.

Reviewer: `/root/gap_fix_independent_review`, independently dispatched from the proposal implementer. Reviewed uncommitted two-file patch against `4590813dffa2bb7a2b48fbae24760da9e90c0dcd` on `feature/story-13.4-reader-zoom-pinch-continuation` in the designated isolated worktree. No test/build/simulator dispatch, checkout/index/reference mutation, GitHub action, or persistence investigation was performed. This report is the reviewer’s only write.

## Scope and source binding

Read `AGENTS.md`, scoped `plan.md`, `implementation-report.md`, complete `review-package.diff`, proposal envelope and both application receipts. Reviewed full `ReaderZoomState`, fitted layout, presentation transform, semantic geometry, sticky scale policy and production `ReaderSurfaceViewController`, plus complete state tests and fitted-layout/transform tests. Consulted Reader architecture/UX requirements, PRD and the original source-confirmed gesture finding.

The proposal’s complete before bytes match the pinned base source, and complete after bytes match the working files. Both SHA256 pairs agree with application receipts. The current two-file Git diff equals the review package byte-for-byte, checked again after all local gates completed:

- `review-package.diff`: `d5d7cd8afeccbad686f6f3a33416518b12477cbc8d1451c54cb482b39c5b2550`.
- `proposals.json`: `67372dbc76f57a577ae03b2ba787d36690de642090ad7a15ecd859cd35a4ae56`.
- State after: `597ef4bf7300fac9e2b6f0182c379daec917a5434488e9727a0f853440af3845`.
- Tests after: `f0ecb6fdfa3db310bae1e0d03eb78f472cca01bc35d7bf23f5ad088ea33009d6`.

## Specification and quality assessment

`ReaderZoomState.swift:321–327` preserves the projected active midpoint and, when no semantic anchor exists, inverse-maps it through the already installed bounded presentation. Thus replaying the same scale reconstructs the remapped translation; the next cumulative magnification continues from existing policy history. Using the actual bounded translation also removes the stale logical gutter point after clamping. No arbitrary page identity is assigned to the prior blank space.

The existing in-page branch still constructs presentation from its semantic anchor and retains the corresponding new-geometry focal point. Scale policy/history is untouched. Committed state and both rollback transforms are independently remapped before focal rebasing; frozen reading projection, reset invalidation/acknowledgement and cancellation paths are unchanged. The change stays in transient interaction state, introduces no API/schema update, and adds no parsing, persistence or view ownership.

The regressions at `ReaderZoomStateTests.swift:108–198` establish an actual inter-page gap and fitScreen gutter with nil semantic anchors. The gutter case forces horizontal clamping and changes viewport dimensions as metadata resolves. Both require unchanged presentation on a repeated 1.2 sample, then reachable focal-preserving translation on both axes at cumulative 1.4. Explicit strict bounds prevent a clamped target from hiding an error. The gutter continuation must move away from translation x=0, distinguishing correct rebasing from merely preserving the stale focal. Cancellation is compared against a separate baseline state remapped without a pinch; frozen anchor and baseline eligibility are checked. These are meaningful state regressions, with existing in-page/reset cases retained.

## Independently inspected controller receipts

All four receipt log lengths and SHA256 values match the saved complete logs. The reviewer inspected result summaries and the focused failures, rather than rerunning work:

- Focused RED: exit 1, 8 cases; original 6 pass, new 2 fail with continued scale remaining 1.2 instead of 1.4, translation errors and nil projected focal. Compilation succeeds. Log SHA256 `c904360c6cbc230baac51533137ac4e869ca7fdac1b567f353b7855405b89eb7`.
- Focused GREEN: exit 0, 8/8 pass. Log SHA256 `d4a69c8110248e18ccbac1c06bd5523927829386f5d5525e3c99e92ded607d62`.
- Full package, jobs 1: exit 0, 747 tests in 20 suites pass; both new cases appear as passed. Log SHA256 `c207d9c45cb834a81a70e46e93a48deb6bf65dda1ee7833ab34d0fcf0e875a7d`.
- Generic iOS Simulator Debug build, jobs 1, signing disabled: exit 0, `BUILD SUCCEEDED`. Receipt explicitly sets deployment target 17.0; complete log contains arm64 and x86_64 iOS 17.0 simulator link targets. Only observed warning is skipped AppIntents metadata extraction without a framework dependency. Log SHA256 `0468936d94b1391b76b57d730635ff9951fa304548c31449061c94b2d8303eb6`.

The four dispatches total approximately 259.724 seconds, within the scoped allocation. They provide macOS package execution and simulator compilation evidence, not iOS 17 runtime or fresh native interaction acceptance. Existing runtime waiver, historical qualifications and parked persistence work remain unchanged. Controller privacy/attachment preservation checks and required PR Simulator Build CI are separate delivery gates; no merge is authorized by this review.
