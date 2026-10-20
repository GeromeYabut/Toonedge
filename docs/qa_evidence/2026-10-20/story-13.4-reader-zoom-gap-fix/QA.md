# Story 13.4 — gap-centred pinch follow-up

PR #17 follow-up against base 4590813dffa2bb7a2b48fbae24760da9e90c0dcd. The source-confirmed gap/gutter relayout freeze is fixed: an active midpoint without a semantic page anchor is inverse-mapped through the new bounded presentation. Ordinary in-page anchoring and sticky magnification history are retained. No public API, schema, persistence or Reader navigation change.

## Focused regression and review

Two real-state regressions cover inter-page spacing and a horizontally clamped fitScreen gutter with viewport resize during decoded-metadata relayout. They establish nil semantic anchors, require no jump on the repeated1.2 sample, require correct scale1.4 and reachable translations on the next sample, and compare cancellation to an independently remapped baseline. Existing in-page/reset tests remain intact.

| Gate | Actual result | Exit | Seconds |
| --- | --- | --- | --- |
| Focused RED, tests only | 8 cases: original6 pass, new2 fail on continued scale/translation and lost focal; build succeeded | 1 expected | 134.981 |
| Focused GREEN, fix applied | 8/8 pass | 0 | 11.752 |
| Full package | 747 tests / 20 suites pass | 0 | 11.394 |
| Generic simulator Debug build, floor17.0 | arm64 and x86_64 build succeeded | 0 | 101.597 |

Four local dispatches total259.724 seconds against maximum1200 seconds. Local runtime is closed. No native UI tests or simulator devices were dispatched for this patch. iOS17 runtime remains waived; its compile/API floor is retained. The build emitted only the standard skipped AppIntents metadata extraction warning because there is no AppIntents.framework dependency.

The fresh independent reviewer, distinct from the proposal implementer, found no actionable findings after checking the complete patch, source bytes, surrounding code, tests and all four command receipts/log hashes. See [independent-review.md](independent-review.md), SHA256 0a186aaa5b50b5e1bf0cf3fb712d1b683b46b1fbb276fba8210204393eac9222.

## Exact local commands

Run from the isolated PR worktree. The focused command was run first with only the tests applied (RED), then after applying the source fix (GREEN):

```sh
swift test --package-path app --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-reader-zoom-gap-fix-20261020a/swiftpm" --jobs 1 --filter ReaderZoomStateTests
swift test --package-path app --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-reader-zoom-gap-fix-20261020a/swiftpm" --jobs 1
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-reader-zoom-gap-fix-20261020a/derived-data" -resultBundlePath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-reader-zoom-gap-fix-20261020a/simulator-build.xcresult" -jobs 1 build CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=17.0
```

Durable local evidence directory: /Users/geromeyabut/.codex/worktrees/reader-zoom-pinch-continuation/Toonedge/docs/qa_evidence/2026-10-20/story-13.4-reader-zoom-gap-fix. Each command has a complete log plus an argv/cwd/start/end/exit/hash receipt; full source envelopes, application receipts, preservation snapshot and controller gates remain there. Build bundle and disposable outputs remain in the fresh branch-isolated directory above, not /private/tmp. Build attachment export manifest is empty.

| Complete log | SHA256 |
| --- | --- |
| focused-red.log | c904360c6cbc230baac51533137ac4e869ca7fdac1b567f353b7855405b89eb7 |
| focused-green.log | d4a69c8110248e18ccbac1c06bd5523927829386f5d5525e3c99e92ded607d62 |
| package-full.log | c207d9c45cb834a81a70e46e93a48deb6bf65dda1ee7833ab34d0fcf0e875a7d |
| simulator-build.log | 0468936d94b1391b76b57d730635ff9951fa304548c31449061c94b2d8303eb6 |

## Source and preservation bindings

- Proposal envelope: 67372dbc76f57a577ae03b2ba787d36690de642090ad7a15ecd859cd35a4ae56. Complete before bytes match base; controller validated exact absolute destinations and untrimmed UTF8 bytes before each gated application.
- State applied SHA256: 597ef4bf7300fac9e2b6f0182c379daec917a5434488e9727a0f853440af3845.
- Tests applied SHA256: f0ecb6fdfa3db310bae1e0d03eb78f472cca01bc35d7bf23f5ad088ea33009d6.
- Exact two-file review diff: d5d7cd8afeccbad686f6f3a33416518b12477cbc8d1451c54cb482b39c5b2550.
- All154 prior evidence files and all pre-existing worktree bindings were verified unchanged before delivery. Protected screenshots were not read, staged, moved, modified or deleted. No stopped checkout was cleaned or reused. Completed-evidence credential/URL scans passed; build log contains no URLs and result attachments are empty.

Persistence remains parked. Historical native inequality and prior failed outcomes retain their existing qualifications; none is converted into a pass. This focused state regression and simulator compilation do not establish full native gesture coverage, genuine autosave, the clean-context matrix, actual VoiceOver, production navigation or production-safety clearance. Required PR Simulator Build remains a separate delivery gate. Do not merge or enable auto-merge.
