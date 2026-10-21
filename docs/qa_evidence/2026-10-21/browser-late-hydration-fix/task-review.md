# Independent Browser late-hydration task review

Spec verdict: changes required. Task-quality verdict: changes required. One Important correctness finding and one Minor coverage finding; no Critical findings. This is the assigned task review, not the later full-branch review or a release approval.

## Reviewed identity and method

Base: `58d6738f78ae805ef716fb2221c9c2f1135d56ef`. Package header HEAD: `b205a2a3e01b20ac624344edcc6e19c144269d52` plus working source. Reviewed `task-1-brief.md`, proposer report, overload-correction report, the complete `task-review-package.diff`, then the precise test macro correction. The initial tool output truncated the middle of the diff; only the omitted middle was retrieved separately. Current source hashes were independently read:

- `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`: `d47c32f80c85e3312ab1dba42cc7a267f945eb132cfb30e697a2868bed8faa89`.
- `app/Tests/ToonEdgeAppCoreTests/BrowserHydrationRecoveryTests.swift`: `0b51603afd3b47f00504038412cb3607b130c152af86b3cf31dde8bc2156050c`.

The macro correction evaluates each mutating policy call into a local Bool before `#expect`; call order and expectations are retained. No tests, builds, browser, simulator, device, Git mutations, or production edits were performed by this reviewer. Only this report is written.

## Findings

### Important — readiness fingerprint suppresses real semantic changes

`app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift:189` (fingerprint at lines 186–192).

`(image.getAttribute(key) || '')` maps both missing attributes and present empty attributes to the same descriptor. The observer explicitly watches `data-reader-page-image` and `data-reader-index`, but adding either as a boolean-style empty attribute can leave the fingerprint unchanged. `PageAnalysisScript.swift:64` uses `hasAttribute`, and `GenericChapterDetector.swift:160` and `:217` use those semantic hints for candidate admission and scoring. A concrete case is six existing chapter images narrower than 320px, with chapter class metadata but no Reader marker: initial generic analysis excludes them; adding `data-reader-page-image=""` can make them candidates, yet recovery suppresses that mutation and leaves the Browser result stale. This is within the first 512 images and inside the window, so it is not an accepted budget/coverage limit.

The same descriptor also omits computed visibility. Changing an ancestor's `visibility:hidden` to visible is observed, but image rect dimensions and immediate-parent id/class can remain identical; extraction's `renderedHeight` changes through `toonEdgeIsVisible`, while this fingerprint does not. This matters while recovery is active; it is not a request to override the approved stop-after-viable-result policy.

Preserve absent versus present attribute state and the lightweight visibility state needed by extraction. Add owned, readiness-only regression cases while keeping the detector, entry policy, debounce, bounds, and preflight unchanged. The regression should establish the pre-change result and show the actual additional detector pass/safe result after only marker or visibility changes. Static source establishes the descriptor collision; runtime reproduction is for the controller and has not been claimed here.

### Minor — noise test runs only after recovery is stopped

`app/Tests/ToonEdgeAppCoreTests/BrowserHydrationRecoveryTests.swift:141` (mutation loop at lines 144–148).

`immediateRoutesRetainSafeHandoffAndIgnoreNoise` waits for a viable pending Reader session before applying duplicate attributes and unrelated DOM mutations. Production has already called `stopRecovery` at that point. The assertion verifies no work after successful handoff, but does not validate active-observer duplicate/irrelevant mutation suppression. The changing-image budget test exercises real changes, and the malformed-message test exercises native revision suppression; neither substitutes for this check. Extend/parameterize an existing test while recovery remains active on a low/unavailable page, preserving the eight-function scope. Assert that noise consumes no extra analysis, then a real readiness change still produces one.

## Positive spec checks

The production delta stays in Browser scheduling/lifecycle with a defaulted preflight dependency; the detector, classifier thresholds, hard-block rules and decoded-image preflight remain unchanged. The fixed 30-second monotonic window, 500ms first-event coalescing, four extra analyses and first-512 descriptor limit match the chosen bounds. The worker serializes extraction/preflight and coalesces pending work. Main-frame, WebView identity, URL/loading, pending-command, generation and installed document epoch checks surround asynchronous extraction/cookie/preflight/delivery stages. The weak script-handler proxy and both representable dismantle hooks provide explicit teardown. Bridge payload contains epoch/revision only. A missing bridge retains the native-guarded legacy path. Viable results stop recovery; unavailable results retain Browser fallback.

No persistence/autosave/progress/schema changes, new dependency, PR18 changes, merge, or floor changes appear in the reviewed task source. DEF-047 remains outside this task and must remain open/tracked on draft PR18.

## Named unchanged-code checks

- Risk: moving extraction into an isolated content world could depend on page-world globals. Inspected `PageAnalysisScript.swift` DOM/global accesses and extraction body; it uses DOM/platform APIs and its own injected helper declarations, with no observed page-owned global dependency.
- Risk: new teardown invalidation might remove Reader presentation during normal handoff. Inspected `BrowserViewModel.navigationDidStart`, handoff methods, and `BrowserView` presentation/browser composition. Navigation invalidation clears pending state; the mounted Browser remains beneath the browser-owned Reader overlay, and the established owned session is separate. No additional defect established.
- Risk supporting the fingerprint finding: inspected only the semantic-marker extraction, visible-height calculation, and corresponding generic candidate/scoring paths. These show the omitted distinctions affect actual detection inputs.
- Read the branch/release workflow for review boundaries. No broader unchanged subsystem or historical artifact audit was performed.

## Evidence and cannot-verify items

Independently read `focused-red-receipt.json` and `focused-red.log`: exit 1 after a successful compile, with exactly the missing automatic six-candidate analysis assertion failing after the 14-second fixture; no manual-control assertion failed. This is meaningful semantic RED evidence.

Controller reports the first GREEN failed WebKit overload compilation, and the corrected GREEN then failed only the mutating Swift Testing assertion expansion. The precise corrections were reviewed. At report completion, `focused-green-macro-corrected` is still pending; there is no passing focused runtime receipt and no GREEN claim. Full package and iOS17-floor simulator build gates are also not verified. Mounted Reader UI, live-site/device acceptance, runtime memory/leak behavior, and the two newly identified readiness cases remain unverified. Proposer rationale is not treated as runtime evidence.

Resolve the Important finding and relevant coverage in one scoped correction wave, preserve each failed attempt, obtain meaningful focused RED/GREEN evidence for the correction, then finish the controller-owned package/build gates and separate fresh full-branch review. Do not merge or advance parked persistence work on this report.
