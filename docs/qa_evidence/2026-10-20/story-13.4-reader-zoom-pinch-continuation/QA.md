# Reader zoom continuation — scoped QA

Approved plan blob: b94a31121583458be0a7ed2bfeffbd5b62285d27. Actual Reader integration is present locally; focused native zoom gates pass. Independent final disposition is in reviews/final-broad.md and is required before the local commit.

## What changed and why

The original requested0.54 inward pinch produced only0.551216634 native magnification from known2x. All62accepted samples remained above1.03 snap entry; presentation exactly followed2*raw. The failing test never exercised the sticky detent. One supported test-only change requests0.50 instead. No policy threshold, velocity, original assertion or product behavior was changed.

A bounded DEBUG observer records native input only under both existing UI-testing/fixture flags. An initial proposal publishing growing JSON on every sample was rejected independently and never applied. The accepted observer records in memory during changed callbacks and publishes at lifecycle/first-anomaly boundaries. All original handler statements remain. Observer overhead is qualified, not claimed zero.

## Results

| Gate | Actual result |
| --- | --- |
| Focused package | 11 tests / four suites PASS |
| Full package on final package source | 745 tests /20 suites PASS |
| Native builds1/2 | Both exit0; all6 main-app bundle files identical |
| Observation16e, original0.54 | One case, one known failure, exit65; retained as failure |
| Final16e, corrected0.50 | One case, zero failures, exit0 |
| Pro Max | All6 original cases, zero failures, exit0 |

Final16e trace:132 complete rows, stable session/pipeline/geometry, known2x inward57eligible samples, native endpoint0.511120139, held1x without below-baseline crossing. Separate deeper pinch ends0.806738414 after baseline hold/breakthrough. All focal/reset<=2pt, eleven reset observations>1s, release/pan/chrome/bounds assertions pass.

Pro Max trace:121 complete rows, inward60eligible samples from2x, endpoint0.500011561, held1x with no below-baseline crossing; independent deeper pinch ends0.782789220. The six cases cover pinch/sticky/release/pan/reset; taps/fixed chrome/owned Original Page; long/short containers/loading; delayed decoded dimensions/retry; viewport/fit/spacing anchors; chapter/pipeline replacement/delayed restore rejection.

The five earlier passing16e cases are carried forward under the approved basis, with exact unchanged test/common-helper bytes and unchanged production behavior. build-equivalence-and-test-binding.json proves the whole prior test is recovered by removing only the exclusive attachment additions and restoring0.54. They remain individual passes from a failed full run; no fresh all-six16e suite is claimed.

New attempt:8 completed device-case executions,7 passed and1 failed diagnostic observation. Prior attempt remains5passed/8failed. Historical persistence five-of-six/native inequality is unresolved.

## Budget and bindings

One shared25minute allocation began17:28:22.702026Z at first package dispatch; cutoff17:48:22.702026Z, deadline17:53:22.702026Z. Last native command ended17:43:52.900252Z, about15m30s after start. Used exactly2package invocations,2builds,3UI dispatches and8cases; no reruns/extra candidate. runtime-closed.json forbids further source/runtime.

- W: /Users/geromeyabut/.codex/worktrees/reader-zoom-pinch-continuation/Toonedge
- Branch: feature/story-13.4-reader-zoom-pinch-continuation
- Fetched origin/main:4e2d55b4371ec645bac962a21d781e90572abf8c
- Imported dependency HEAD:b87212b7b0f993a752dce9e48a270ac3d8eac13f
- O: /Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-reader-zoom-pinch-continuation-20261020a
- Dedicated iOS18.6 devices:16e4582CDE9-27DB-4669-86AC-0631C1D7F2ED and ProMax29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4. Shared16Pro never targeted.
- iOS17 API/deployment and macOS14 package floors retained. iOS17 runtime remains waived.

## Preservation, reviews and retention

Source-pins-final.json binds14 final source/test/project files. Only2 differ from the accepted stopped integration: DEBUG observer and exclusive test attachment/one stimulus literal. Complete amendment diff and full proposal/preimage/envelope/applied hashes remain in packages/, proposals/ and patches/. Distinct implementer, stage reviewer and broad reviewer were used; controller alone applied source and dispatched commands.

All197 old scoped evidence files and14 old source files retain their hashes. All36 pre-existing worktree HEAD/branch bindings are preserved, with only this new worktree added. The structured receipt corrects the prior narrative's35 count; no binding changed. The primary checkout has only its same3protected screenshot pathnames and2authorized planning documents untracked. Protected payloads were never opened/copied/staged/modified/deleted.

Both build attachment manifests are empty. All3 UI bundles were exported: failed observation includes one owned video plus numeric trace/plists; passing bundles contain only owned numeric trace JSON. Full-duration1fps controller visual sampling observed only owned grid/Reader/placeholder/default dedicated simulator content. privacy-final.json records completed scans and limitations, with no credential-pattern hits or sensitive URLs. Public Apple plist DTD metadata and explicit public-host test-fixture paths are safe source/test output. Sampling and heuristic scans are not exhaustive proofs.

Exact runtime argv, UTC/exits/full logs and hashes are retained in *.result.json and *.log. Controller setup/patch/dispatch receipts are retained in controller-receipts-*.json. Products1/2 are byteverified in their original internal staging directories and immutable durable O/Products-build-N archives; result bundles remain on verified UUID7C6E7CE1-D8D5-3041-AA58-DC000A724A29. No evidence relies solely on private tmp.

## Limits

Persistence remains PARKED. ReaderViewModel, repositories/schema/stores and commit-side progress safety were not changed. Genuine autosave, progress safety, full clean-context/native gesture matrices, actual VoiceOver and production release remain separately approved work. The restore case establishes canvas/identity behavior, not persistence safety. No push, PR, merge or cleanup. This continuation validates focused zoom; it does not repair a demonstrated product-policy defect or establish production safety.
