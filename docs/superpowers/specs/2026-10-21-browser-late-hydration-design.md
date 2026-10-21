# Browser late-hydration recovery design

User request, 2026-10-21: fix the reproduced Browser late-hydration timing gap with a focused regression and independent review. This implements the bounded content-readiness direction presented in the prior diagnosis. DEF-047 remains tracked separately; persistence stays parked; no merge is authorized.

## Problem and outcome

The production Browser observes navigation/URL changes, waits 750 ms for initial detection and gives Vortex low-confidence content one follow-up 12 seconds later. The owned Mac reproduction added valid chapter images 14 seconds after an in-site route: both automatic passes saw zero candidates while a later manual pass found six/high.

A lightweight document image/readiness change signal should request a new detection pass for the current navigation. Coalesce changes, limit additional analyses and observation time, and stop after safe Reader eligibility. Missing messages, analysis failure or exhausted bounds preserve Browser fallback.

## Chosen approach

Use document content observation with native navigation/document identity guards. A longer fixed delay still misses later content; repeated full-page polling adds unnecessary work. The content signal schedules existing extraction/detection rather than granting Reader permission.

The implementation must reject stale document/navigation, subframe, wrong-WebView and malformed events; prevent concurrent or duplicate recovery delivery; cancel on teardown and navigation; avoid handler/task retention cycles. Exact debounce/window/budget values and their boundary tests are recorded with the implementation proposal before application.

Reuse the existing confidence disposition, hard blocks, source URL checks, cookie/request context and image preflight. A defaulted internal preflight dependency may use its existing HTTPDataLoading interface for owned test data; production behavior remains the default. The existing first-image preflight checks HTTP data and ImageIO source/type/frame count; it does not perform pixel decoding. The owned test separately decodes its generated PNG.

## Files and verification

One focused task modifies existing BrowserWebView.swift and adds BrowserHydrationRecoveryTests.swift. Keeping production code in its registered file avoids project-registration changes.

Controller alone applies complete byte/hash-validated patch envelopes and runs tools. A proposal agent supplies staged RED/GREEN source; independent reviewers write reports only. The baseline policy tests, old-API 14-second semantic RED, focused GREEN including safe owned image handoff and lifecycle/bounds negatives, full package jobs1 and iOS17-floor simulator build form the gates. No live-site sampling or physical-phone run is needed to fix this controlled gap.

The fix does not establish historical live-site causality, all-page Reader rendering or physical-iPhone parity. Existing DEF-036 historical limits remain recorded. Preserve every failed result and all previous checkouts/evidence; do not touch protected screenshot contents.
