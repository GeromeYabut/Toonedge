# Reader UX polish delivery — 2026-10-20

All seven approved UX items are implemented and installed on the physical iPhone. Independent stage reviews and the fresh whole-branch review approve delivery with four nonblocking coverage follow-ups. Branch `feature/reader-ux-polish` remains local and unmerged; no push or PR was performed.

## Delivered behavior

1. Dark default appearance and pure black canvas, preserving explicit Reader canvas settings.
2. Continue Reading opens the retained chapter session for recent-only and saved entries, with source fallback, loading and Retry.
3. Translucent dark Reader chrome with legible foreground; opaque accessibility fallback.
4. Compact Reader chrome and navigation spacing with 44-point minimum targets and large-text layout.
5. Applied zoom percentage feedback during zoom, followed by a short fade.
6. Home title, compact search and spacing. The existing shared URL/query search is available across Home, Library, Downloads, Settings, Browser address and revealed Reader controls. Cancel preserves context; selection commits after dismissal.
7. Compact right-aligned Library summary and plain trailing controls, with selected-layout emphasis and large-text fallback.

No new schema or preference store was introduced. Repository changes resolve read-only resume targets; persistence writes, autosave policy and progress fences were not changed.

## Exact source and delivery binding

- Base: `58d6738f78ae805ef716fb2221c9c2f1135d56ef`.
- Installed/reviewed source HEAD: `2683bfce87b722410f50b4d673c809147f7030a9`.
- Installed source tree: `829796dacdcc2f4c170268b59f79cec74e808687`.
- Workspace: `/Users/geromeyabut/.codex/worktrees/reader-ux-polish/Toonedge`.
- Durable build/result/product archives: `/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-reader-ux-polish-20261020a`.
- Device: iPhone 16 Pro, iOS 18.7.8. Bundle `com.toonedge.app`, existing development team, in-place install without uninstall/reset.
- Signed build, codesign/profile/device eligibility and `MinimumOSVersion=17.0` verified.
- Normal launch: no fixture arguments; injected child environment removed. Running process PID 88443 matched the newly installed executable. This establishes installation/launch, not a physical-device UX acceptance run. No phone screen or reading content was captured.
- One launch CLI attempt rejected an empty environment dictionary before dispatch (exit 64); corrected invocation succeeded. Both receipts retained.
- Later QA-only commits do not change the installed source binding.

## Verification and accounting

| Gate | Result | Evidence |
| --- | --- | --- |
| Resume regression | RED reproduced; corrected GREEN 5 functions; independent review clear | task-1-review-green-receipt.json; task-1-review-2.md |
| Zoom/chrome focused logic | 29 tests passed; native HUD 2/2 passed | task-2 review and command receipts |
| Shared-search routing logic | RED reproduced; corrected focused GREEN 10/10 | task-3 correction receipts and review-2 |
| Final compact layout correction | Focused 5/5; AX wrapping RED then GREEN | task-3-fix3-package-green-receipt.json; task-3-progress-native-red-receipt.json |
| Final full package | 760 tests in 20 suites passed, exit 0 | full-package-v2-receipt.json |
| Native integration | Eight unique methods: five unchanged earlier passes plus three affected methods rerun and passed | native-case-accounting-final.json |
| Native visual checks | Owned fixture normal/large-text screenshots inspected; one-line percentage and contained controls | task-3-privacy-green.json |
| Final independent source review | Spec PASS; quality PASS with nonblocking coverage follow-ups | final-review.md |
| Signed iPhone build | Passed, exit 0; signature and API floor verified | iphone-build-receipt.json; iphone-product-verification.json |
| In-place install / normal launch / running PID | Passed | iphone-install-receipt.json; iphone-launch-v2-receipt.json; iphone-process-check-receipt.json |
| Preservation | 38 prior checkout bindings/statuses and 209 artifact bytes/hashes matched | preservation-after.json |

Native execution used the dedicated iPhone 16e **iOS 18.6 runtime**, compiled with SDK 27.0. iOS 17 runtime remains waived; its API floor was required and passed. The native result is explicitly **not one all-eight final-binary run**. Initial 5-pass/3-fail integration and all RED/failure/infrastructure attempts are preserved as such. The eight-unique-method ceiling was retained, with focused corrective reruns. One fresh signed iPhone build and one successful install were used.

## Independent review limits

The final review records four P3 coverage gaps, with no established production defect: sustained pinch/HUD timer lifecycle; saved-empty/recent-image fallback; actual second WebKit completion rather than optimistic address assignment; delayed Home resume loading/cancellation/retry. Native search cancellation establishes tested tab/organization and Reader identity/pipeline/scale preservation, not every navigation depth or exact scroll offset.

Historical persistence/native inequality remains unresolved. This bounded UX work is not production persistence-safety clearance. Genuine autosave, full clean-context matrix and all parked persistence work remain separately scoped. No merge is authorized.

## Evidence retention and privacy

Full commands, actual exits, timestamps and log SHA256 values are retained in adjacent command receipts; raw logs, complete patch envelopes/bases and applied-hash records remain in this durable workspace. Product stages have byte-verified external archives; temporary staging is not the sole evidence copy. `artifact-index-v2.json` catalogs retained local files; curated QA/review/manifests are committed separately from bulky raw records and device-detail output.

Fixture media uses generated owned art. Earlier owned fixture screenshots/videos were inspected; final GREEN exports contain two owned Reader screenshots. Signed-build and completed build-only attachment inventories contain zero media. The interrupted `task-2-native-red-valid.xcresult` is incomplete and not exportable, retains no claimed result and was stopped before UI dispatch. Phone reading content and protected screenshot contents were not inspected or retained. Existing source test URL literals are fixture bytes, not captured browsing history; credential scan results are recorded separately.

All old evidence and stopped checkouts remain preserved. No reset, clean, stash, checkout removal or broad output cleanup occurred.
