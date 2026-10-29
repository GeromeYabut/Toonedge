# Browser late-hydration execution plan

Base: 58d6738f78ae805ef716fb2221c9c2f1135d56ef. Branch: fix/browser-late-hydration.
Workspace: /Users/geromeyabut/.codex/worktrees/browser-late-hydration-fix/Toonedge
Evidence: /Users/geromeyabut/.codex/worktrees/browser-late-hydration-fix/Toonedge/docs/qa_evidence/2026-10-21/browser-late-hydration-fix
Disposable build output: /Volumes/Seagate 2TB/ToonEdgeBuilds/Active/fix-browser-late-hydration-20261021a

Outcome: repair the reproduced same-URL image hydration scheduling gap. DEF-036 historical/device parity remains unresolved. DEF-047 remains tracked on draft PR #18. Persistence remains parked. No push or merge.

## Design and patch binding
Follow docs/superpowers/specs/2026-10-21-browser-late-hydration-design.md.
Exact untrimmed before/after code is the implementation appendix: /Users/geromeyabut/.codex/worktrees/browser-late-hydration-fix/Toonedge/docs/qa_evidence/2026-10-21/browser-late-hydration-fix/task-1-proposal.json, SHA256 a179687e380c05e99a168f40a2dfdd4e96c05936f7f2662972b9f1c22d77379c.
Only BrowserWebView.swift and BrowserHydrationRecoveryTests.swift may change as product/test code.
Preserve initial 750ms and legacy 12s scheduling. Add image readiness hints in isolated WebKit world with fixed 30s uptime window, 500ms first-event debounce and four additional analyses. Fingerprint first 512 images, attributes capped at 2048 characters. Classifier, hard blocks, cookie context, existing first-image ImageIO source/type/count preflight and source guards remain mandatory. Navigation, replacement and teardown invalidate asynchronous work.

## Controller-owned sequence
1. Validate complete envelope, absolute destinations, base ancestry, full UTF8 bytes and hashes using apply-proposal.py.
2. Apply RED test only; run swift test --package-path app --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/fix-browser-late-hydration-20261021a/swiftpm" --jobs 1 --filter BrowserHydrationRecoveryTests. Require actual semantic missing automatic six-candidate analysis after 14-second owned hydration, with manual six-candidate control. Compile/harness failure is not RED.
3. Apply GREEN source and expanded tests only after meaningful RED. Verify applied hashes. Run same focused filter. Tests cover direct/immediate routes, 14-second late hydration, hard blocks, unreadable preflight, stale navigation/replacement/teardown, finite deadline/budget, malformed/source messages, mutation storm and coalescing during preflight.
4. Run swift test --package-path app --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/fix-browser-late-hydration-20261021a/swiftpm" --jobs 1.
5. Build ToonEdge Debug for generic iOS Simulator with deployment target17.0, signing disabled, jobs1, unique derived data and xcresult paths within bound output. No device or shared simulator dispatch.
6. Independent task review by reviewer distinct from proposer: complete base diff, brief, actual receipts, spec and quality. Resolve important findings as one bounded proposal wave, focused retests, review.
7. Local independently reviewable code commit, then fresh whole-branch review versus base58d6738. No source change after final review without recheck.
8. Record case accounting, command receipts, reviews, limitations, privacy scan and before/after preservation verification. Retain durable evidence in workspace; inspect attachments before retention. Commit curated textual QA. Do not push or merge.

## Gates and stop conditions
Actual completion/exit is inspected after each setup, mutation and test dispatch. Preserve every unsuccessful result. Stop on meaningful unresolved failures, unsafe/stale handoff, unbounded scheduling, changed approved scope, missing authority or privacy/preservation failure. Reviewers write only assigned reports; controller owns checkout/runtime. No live-site or phone evidence claimed. Bounded generated content proves scheduling and pending handoff, not historical site equality or mounted Reader usability. Finite window/four attempts/first512images can miss later or out-of-budget hydration.

## Existing prerequisites
Fresh branch/base, 40 prior checkout statuses and 370 prior artifact hashes recorded. External UUID verified with free space and exclusive mkdir probe. Mac/Xcode/API prerequisites recorded. Three existing policy tests passed actualexit0. Protected screenshots excluded.
