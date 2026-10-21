# Browser late-hydration fix — local verification

Branch: fix/browser-late-hydration. Base: 58d6738f78ae805ef716fb2221c9c2f1135d56ef.
Workspace: /Users/geromeyabut/.codex/worktrees/browser-late-hydration-fix/Toonedge
Build output: /Volumes/Seagate 2TB/ToonEdgeBuilds/Active/fix-browser-late-hydration-20261021a

The reproduced late-hydration scheduling gap is fixed locally. No push or merge is authorized by this continuation. DEF-047 remains open/tracked on draft PR #18; persistence, autosave and progress-safety investigation remain parked. DEF-036 historical live/device parity remains open.

## Change

BrowserWebView observes lightweight image-readiness changes in an isolated WebKit world. A first-event 500ms debounce coalesces changes; a fixed 30-second monotonic window allows at most four extra analyses. The first 512 images are fingerprinted, with attribute values capped at 2048 characters. The fingerprint preserves missing versus empty attributes and computed visible rendered height.

A serialized worker retains the existing initial analysis and legacy follow-up, coalesces pending work, and stops recovery after a viable current result. Native/document epochs, main-frame and WebView identity, URL/loading/pending-command checks protect extraction, cookie context, existing first-image preflight and delivery. Navigation, replacement and representable teardown cancel or invalidate stale work. Hints carry epoch/revision only; classifier thresholds, hard blocks, Reader dispositions and the existing first-image viability check remain mandatory. Missing bridge falls back to legacy behavior.

No dependency, schema, persistence interface or Reader implementation changed. The internal defaulted preflight dependency uses existing HTTPDataLoading injection; tests generate owned PNG bytes and separately decode that generated fixture with CGImageSourceCreateImageAtIndex. Production ReaderSessionImagePreflight retains its existing HTTP-status/nonempty-data and ImageIO source/type/frame-count checks for the first image; it does not decode pixels with CGImageSourceCreateImageAtIndex.

Historical proposer and task-review reports are preserved verbatim. Where they call the preflight decoded-image or decoding checks, the precise first-image container/source check above governs the current evidence claim. This continuation does not establish production pixel decoding before handoff, rendering of every session image, or mounted Reader usability.

## Actual command accounting

Exact argv, timestamps, actual exits and raw-log hashes are in [commands.json](commands.json). Raw logs and complete proposal/application envelopes remain durably in this directory, including unsuccessful attempts.

| Gate | Actual result |
| --- | --- |
| Existing scheduling-policy baseline | 3 tests passed, exit 0 |
| Original test-only RED | exit 1: missing automatic six-candidate analysis after owned 14-second hydration; manual six-candidate control passed |
| First GREEN | exit 1: WebKit overload compilation failure, no test result |
| API-corrected GREEN | exit 1: mutating-call Swift Testing macro compilation failure, no test result |
| Macro-corrected GREEN | exit 1: seven of eight functions passed; 104 issues from transient nil epoch polling; bitmap colorspace warnings retained |
| Review-specific test-only RED | exit 1: 12 intended missing analysis/handoff/preflight issues across visibility/empty-marker/empty-index; initial/noise/manual eligibility and safety controls passed |
| Corrected full focused GREEN | 8 functions / 16 parameter cases passed, zero issues, exit 0 |
| Full Swift package, jobs 1 | 755 tests in 21 suites passed, exit 0 |
| Generic iOS Simulator build, target 17.0 | arm64 and x86_64 build passed, exit 0 |

The eight focused functions cover late 14-second hydration; direct/immediate SPA routes; blocked/unreadable/visibility/marker/index readiness; same/different URL reload, replacement and teardown; deterministic deadline/attempt/stop boundaries; malformed/duplicate/wrong-source signals; changing-image budget exhaustion; and readiness during held preflight. Active duplicate/unrelated mutations consume no extra detector pass before a real readiness-only change.

The focused and package logs contain no warnings. The simulator build has one tooling warning: AppIntents metadata extraction skipped because no AppIntents.framework dependency exists. No compiler error or warning was reported.

## Review and boundaries

[Original independent task review](task-review.md) found an Important fingerprint collision and Minor active-noise coverage gap. Both were reproduced and corrected in one scoped wave. [Independent re-review](task-rereview.md) passes spec compliance and task quality with no remaining findings; its SHA256 is 833be6277245b5ca38ad3dd20dbd8a22751e920956150c243b04b777be1991bb. A fresh whole-branch review is a separate final gate, recorded in final-review.md and CLOSURE.md when completed.

These owned Mac tests establish actual detection and pending safe Reader handoff, not a mounted Reader UI or a new live-site/device acceptance result. No phone, live-site sampling or simulator UI suite was dispatched. Two-device UI release verification remains outstanding. iOS 17 runtime coverage remains waived; its API floor was compiled.

Recovery is finite: hydration beyond the deadline, after four consumed recovery attempts, beyond the first 512 images, or without an observed readiness signal can remain in Browser. The fix is not a promise of universal site parity or production/persistence-safety clearance.

## Preservation and retention

Before/after checks confirm all 40 prior checkout bindings/statuses and all 370 recorded prior artifact hashes are unchanged. Protected screenshot contents were not read, copied, staged, modified or deleted. No stopped checkout was reused or cleaned.

The mounted external volume UUID was verified with free-space and directory probes; build outputs are isolated from repositories and simulator data. The build-only xcresult activity log was inspected: 223 attachments contain numeric TaskMetrics only; zero media/screenshot attachments. The initial overly strict no-attachment assertion failed and is preserved alongside the corrected inspection. Raw machine metadata is local only. No copyrighted artwork, credentials, cookies or user session contents are included in the curated textual delivery.

Source SHA256: 5106d1f7f00d0cf3382f7fdd651f0660bca2c73696390b08a7b19e6efc76322a.
Test SHA256 used by passing runtime gates: 66905a79c820e1e31ac3abd5777e7306ab25a6849306eb27c9ca9c18a316c1cf. The staged whitespace check then found one redundant EOF blank line in the new test; exactly that newline was removed (full envelope retained), leaving executable tokens unchanged. Final test SHA256: aeebf4060bfe1596d7261a232d4956d36b34644018fc784a1281c476863e272d. No behavior changed after those passing gates.
