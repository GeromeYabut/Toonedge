# Independent Browser late-hydration task re-review

Spec verdict: pass for the scoped task review. Task-quality verdict: pass. Both original findings are resolved; no remaining Critical, Important, or Minor findings in this reviewed correction wave. Full-package/build gates and the separate final broad review remain controller-owned. This is not merge or release approval.

## Exact review identity

Base `58d6738f78ae805ef716fb2221c9c2f1135d56ef`; package header HEAD `b205a2a3e01b20ac624344edcc6e19c144269d52` plus the working files below. Independently read and hashed the complete current task diff and both current sources:

- `task-rereview-package.diff`: `bb948d1f7bb28f666f8018983838a754876e9f557638884f6000908d2fb080af`.
- `app/Sources/ToonEdgeAppCore/Features/Browser/WebView/BrowserWebView.swift`: `5106d1f7f00d0cf3382f7fdd651f0660bca2c73696390b08a7b19e6efc76322a`.
- `app/Tests/ToonEdgeAppCoreTests/BrowserHydrationRecoveryTests.swift`: `66905a79c820e1e31ac3abd5777e7306ab25a6849306eb27c9ca9c18a316c1cf`.

Read the correction report and controller verification note, then the entire current diff once in three nonoverlapping sections. Independently inspected the actual review-specific RED and focused GREEN receipts and logs. No tests, builds, browser, simulator, device, source edits, or Git mutations were dispatched by this reviewer. Only this new report was written; `task-review.md` is preserved. No additional unchanged-code inspection was necessary: the named parser and presentation risks inspected in the original review still supply the relevant context.

## Resolution of original findings

Important fingerprint collision: resolved at `BrowserWebView.swift:189`, `:195`, and `:199`. The descriptor now records computed visible rendered height with the same visibility/geometry conditions used by extraction, and distinguishes a missing attribute (`null`) from a present empty value. The change is limited to the local fingerprint. It does not change classification, hard blocks, preflight, bridge payload, debounce, finite window, attempt budget, or stop-after-viable-result behavior.

`BrowserHydrationRecoveryTests.swift:163` adds parameter cases for inherited visibility, absent-to-empty page marker, and absent-to-empty index marker within the existing safety test. Actual extraction/detection controls at `:236` and `:261` establish unavailable pre-change results and automatic post-change eligibility. The visibility case starts with three invisible candidates; marker/index cases start with zero candidates. Assertions at `:275` through `:280` require one additional real detector pass, the current Reader session with the expected images, and one decoded-image preflight. This tests the previously suppressed readiness distinctions rather than merely checking the descriptor implementation.

Minor active-noise coverage: resolved at `BrowserHydrationRecoveryTests.swift:246`. Duplicate source writes and irrelevant span mutations now run on unavailable pages while recovery remains active. Assertions verify no new detector pass and no preflight, followed by an actual semantic readiness change that still produces exactly one additional pass and safe handoff. The original post-handoff noise test remains useful for the stopped-worker case. The suite stays at eight test functions.

## Harness corrections

At `BrowserHydrationRecoveryTests.swift:52`, optional epoch polling tolerates expected bridge installation gaps; definitive `epoch()` reads still require a value. The stale-navigation wait at `:298` still requires a nonnil changed epoch, a settled view, and fresh low analysis. Stale-delivery/message/replacement/teardown assertions remain intact.

At `BrowserHydrationRecoveryTests.swift:442`, the owned PNG uses explicit sRGB Core Graphics drawing and ImageIO encoding. ImageIO decode verification remains, and production `ReaderSessionImagePreflight` still decodes the supplied bytes. This removes the previous bitmap colorspace warning without bypassing viability checks.

## Actual verification evidence

`review-regression-red-receipt.json` records exit 1, no timeout, using the readiness safety filter. Its log shows successful compilation and exactly twelve intended semantic issues: four missing recovery/handoff/preflight assertions for each visibility, marker, and index case. Initial-state, active-noise, manual post-change eligibility, blocked-content, and unreadable-image controls did not fail. Log SHA recorded by the receipt: `eee4c3b327f79c7b424bbaa6b7ada7b436392d28585775aad267272816a051e6`.

`focused-green-reviewed-receipt.json` records exit 0, no timeout, using the full `BrowserHydrationRecoveryTests` filter with `--jobs 1`. The actual log confirms all eight functions / sixteen cases pass, including the original 14-second route, readiness-only cases, safety, stale epochs, replacement/teardown, finite budget, malformed sources, and preflight coalescing. Testing took 52.359 seconds; the receipt records 70.989 seconds wall time. No warnings appear in the inspected log. Log SHA recorded by the receipt: `434507e7264dd27e076eeb3b9c95cf44a2093f4ff7ca6633c12525ab166a21af`.

These are controller-run results, not proposer rationale or reviewer-dispatched runtime. Earlier semantic RED, compilation failures, and transient-polling failure remain historical evidence; they are not silently relabeled as passing attempts.

## Scope and remaining verification

The chosen 30-second fixed window, 500ms coalescing, four extra analyses and first-512-image fingerprint are retained. Generation/document/source/main-frame/URL/loading guards, serialized analysis/preflight, teardown, weak handler ownership, minimal epoch/revision bridge messages, fallback and safe Reader entry remain intact in the complete current task diff. No persistence/autosave/progress/schema changes, PR18 edits, new dependency, API-floor change, push, or merge are part of this correction. DEF-047 remains open/tracked on draft PR18 and persistence remains parked.

Full-package and iOS17-floor simulator build gates have not been verified by this report. Mounted Reader UI, live-site/device acceptance, and runtime memory/leak profiling remain outside this owned regression review. The finite window/budget and first-512 limit remain deliberate recovery coverage bounds. Proceed to the already assigned controller gates and fresh broad review; no additional task-specific correction is requested.
