# Independent whole-branch Browser hydration review

## Verdict

Ready for the scoped local late-hydration outcome, with one Minor documentation correction recommended. No Critical or Important finding was established in the reviewed executable changes. The owned regression demonstrates recovery and pending eligible Reader handoff; this verdict does not authorize push, merge, release, or closure of historical live/device parity or parked persistence work.

## Reviewed identity and method

Reviewed the complete branch range `58d6738f78ae805ef716fb2221c9c2f1135d56ef` through `192e10e06d57210aee7c4d160421701281f49c5e`, including both commits, production/test changes, design, plan, defect update and curated evidence. The supplied `final-review-package.diff` is 113253 bytes, SHA256 `cb8505127e34766130e3b0d8189e5b7327954cc5ab98560ad3d66a3888947e2f`, independently verified. Read changed code once from that diff; a truncated documentation segment was retrieved separately. Read the task brief and branch/release workflow. Prior review conclusions were contextual evidence, not proof of correctness.

Current production SHA256: `5106d1f7f00d0cf3382f7fdd651f0660bca2c73696390b08a7b19e6efc76322a`. Current test SHA256: `aeebf4060bfe1596d7261a232d4956d36b34644018fc784a1281c476863e272d`. Independently verified both hashes and the full EOF correction envelope: tested test bytes hash to `66905a79c820e1e31ac3abd5777e7306ab25a6849306eb27c9ca9c18a316c1cf`; the final file differs only by removal of one final newline. Production bytes did not change in that correction.

No test, build, browser, simulator, device, Git mutation, or source mutation was dispatched by this reviewer. Only this report was written.

## Strengths

- The implementation follows the selected slice: Browser scheduling and lifecycle, with one focused test file. It retains the initial delay and legacy retry path, existing detection/disposition logic, hard-block checks, cookie/request context and existing first-image preflight. No persistence, progress, autosave, dependency or schema change appears in the range.
- Recovery is explicitly bounded by monotonic uptime, a non-sliding 30-second window, four additional attempts and 500ms first-event coalescing. The local fingerprint covers the first 512 images and preserves missing versus empty semantic attributes and computed visible height. Duplicate and irrelevant mutations are tested while recovery is active, followed by a meaningful mutation that still succeeds.
- Main-actor coordination serializes extraction and preflight, coalesces pending work, and stops recovery on a viable result. Navigation generation, installed document epoch, source WebView, main-frame, URL, loading and pending-command checks protect asynchronous boundaries. Old task completion cannot clear a newer generation's worker.
- The isolated-world bridge sends only epoch/revision. Hints request classification rather than bypassing eligibility. Weak handler ownership, explicit handler removal, cancellation, and both representable dismantle hooks address lifecycle retention and stale work.
- Regression coverage uses real WKWebView, PageAnalysisScript and ProfileAwareChapterDetector. The original 14-second route reproduces the missing automatic pass, and the new suite checks safe pending handoff, blocked/unreadable fallback, same-URL reload, different navigation, replacement, teardown, malformed/source messages, finite budget and in-flight coalescing. The preflight test dependency supplies owned bytes without replacing the production preflight implementation.

## Findings

### Critical

None established.

### Important

None established.

### Minor — qualify the production preflight/decoding claim

`docs/qa_evidence/2026-10-21/browser-late-hydration-fix/REPORT.md:13` says image decoding remains mandatory, and `:15` says tests retain real ImageIO decoding in the discussion of production preflight. Related prose calls this a decoded-image preflight.

The unchanged `app/Sources/ToonEdgeAppCore/Features/Reader/Loading/ReaderPageImageLoader.swift:34` implementation checks successful HTTP data, constructs an ImageIO source, and checks its type and frame count (`:39` through `:42`). It does not call `CGImageSourceCreateImageAtIndex` to decode pixels. That decoding call exists in the new owned PNG fixture at `app/Tests/ToonEdgeAppCoreTests/BrowserHydrationRecoveryTests.swift:457`. Therefore these gates establish preservation of the existing first-image ImageIO viability check and decoding of the generated fixture, not mandatory production pixel decoding before delivery or successful rendering of every session image.

Qualify the current summary to distinguish those facts. This is an evidence/documentation correction; changing the existing preflight implementation would expand this task. Preserve historical reports rather than rewriting their findings. The executable recovery fix is not blocked by this wording issue.

## Named checks outside the diff

- **Isolated-world compatibility:** inspected `PageAnalysisScript.swift` for page-owned JavaScript globals and its visibility/semantic extraction. It uses DOM/platform APIs and local helper declarations; no page-world global dependency was identified. The corrected fingerprint tracks the inherited-visibility and absent-to-empty marker distinctions used by extraction.
- **Handoff versus teardown:** inspected BrowserView's browser-owned Reader composition and pending-session observation, and BrowserViewModel navigation invalidation/presentation methods. The BrowserWebView remains under the Reader overlay; navigation invalidation clears pending detection state while an established browser-owned session has separate ownership. No teardown-induced normal handoff loss was established.
- **Preflight preservation and evidence accuracy:** inspected only ReaderSessionImagePreflight in ReaderPageImageLoader.swift. Its existing HTTP/first-image ImageIO checks remain in the recovery path; this inspection supports the Minor wording finding above.
- **Runtime receipts versus summaries:** read the original RED, review-specific RED and final focused GREEN logs in full; inspected their actual receipts. Inspected the full-package/build receipts and actual log result, warning and compiler-target records. All five inspected logs independently hash to their receipts. No broad audit of unchanged subsystems, earlier checkout preservation, protected images or retained result-bundle attachments was performed.

## Verification and limits

The original RED compiled and failed exactly the missing automatic six-candidate analysis assertion after the 14-second fixture; the manual control did not fail. The review-specific RED compiled and recorded twelve expected missing-analysis/handoff/preflight issues across visibility, marker and index cases; its initial/noise/manual and safety controls did not fail. The final focused log passes eight functions comprising sixteen parameter cases, with no issues. The full package receipt records exit 0 and the log reports 755 tests in 21 suites passed. The simulator receipt records exit 0; the log contains successful arm64 and x86_64 compilation targeting iOS 17.0 and BUILD SUCCEEDED. Its AppIntents metadata warning is tooling-related. Earlier failed attempts remain represented in the branch evidence and are not counted as successful gates.

The fixed window and attempt policy are directly boundary-tested; the real changing-image storm exercises the four-attempt limit. The suite does not directly demonstrate real-time 30-second observer expiry, missing-bridge installation failure, runtime leak freedom, or long-page performance. Source inspection supports those paths but is not runtime proof. Fingerprinting and observation are deliberately partial: unobserved transitions, transitions beyond the first 512 images, and readiness after deadline/budget exhaustion may remain in Browser.

Mac WebKit tests reach pending Reader handoff. They do not mount or exercise Reader UI, prove iPhone WebKit parity, verify every chapter image, or establish live-site acceptance. The iOS build establishes compilation against the deployment floor, not iOS 17 runtime behavior. The repository's two-device UI release/high-risk validation has not been performed in this continuation; release confidence must not be inferred from this local verdict. These are material coverage limits, but they do not negate the reproduced and repaired bounded scheduling defect.

DEF-036 historical live/device parity remains open. DEF-047 remains separately open/tracked on draft PR18; persistence remains parked. The reviewed scope and evidence support recording this bounded local fix, with the Minor summary correction, while retaining those outstanding acceptance boundaries.
