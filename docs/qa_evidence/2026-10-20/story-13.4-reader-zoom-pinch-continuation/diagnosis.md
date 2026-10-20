# Sticky pinch observation and candidate decision

Observation run: observe-16e.result.json exit65, one case/one known detent assertion failure; all other original assertions passed. This remains a failed test, never acceptance.

Trace: attachments-observe-16e/46BBD5AF-D8FE-420F-B9E6-4E87D5873162.json,118256 bytes,SHA256467591656cf3ddbdddebc3c81ef561409adcd2aa20d3f48513eceb2256bf91b7. Complete three began/changed/ended lifecycles, sequential sample IDs and exact counts, no active/truncated/overflow/incomplete flags, stable origin/current session/pipeline identity. Every delivered changed sample eligible, finite, in bounds with focal state; geometry revision4 stable.

Second gesture: known2x start, requested0.54,62changed samples. Minimum/end recognizer magnification0.5512166340663233. Minimum/end presentation1.1024332681326465. Across every accepted sample, maximum absolute error from2*raw is2.220446049250313e-16. No accepted input reached1.03. Thus this observed failure did not exercise snap entry; no policy defect is demonstrated by this sequence.

Third gesture: known2x/requested0.35,41eligible samples, end raw0.35733534609875606 and below-baseline presentation0.8067384144909142. The existing breakthrough assertions passed. Observed inward endpoint gains (raw/requested) are1.0207715445672653 and1.0209581317107317. Applying this measured endpoint range to the sole authorized0.50 candidate predicts unsnapped presentation about1.02077–1.02096, below1.03 entry. The observed dense contraction suggests little residual motion after entry, rather than the additional0.88 contraction required for breakthrough.

This endpoint forecast is a calibration hypothesis. It cannot establish how a different native gesture will be sampled, guarantee detent holding, or clear another device. Require the original fresh native input/sample/lifecycle assertions, held1x with pinchBelowfalse, original separate0.35breakthrough, release/pan/reset/focal/bounds checks in a new passing case. No threshold, velocity, assertion, policy or product behavior change is allowed. If independent causal review rejects this forecast or finds ambiguous/rejected input, stop rather than trying another parameter.

Boundary-only DEBUG observer still adds capture/publication overhead. It reproduced the same endpoint as the prior uninstrumented failure, but zero observer impact is not proven. Its gated nature and all source/test bindings remain independently reviewed.

Stage causal gate pending at creation. This report alone authorizes no source/runtime beyond the approved conditional path. Persistence remains parked; historical native inequality/production/progress safety remain unresolved.
