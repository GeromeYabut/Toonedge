# ToonEdge Reader Release-Hardening Evidence — 2026-09-26

## Baseline

- Branch: `story-11.27-unseen-adjacent-reader-loading`
- Starting revision: `4a0211841cd4707eebed7bffa3342aa3455f1f7d`
- Initial worktree: only the three protected third-party screenshots were untracked.
- Dedicated simulator used: iPhone 16e `4582CDE9-27DB-4669-86AC-0631C1D7F2ED`.
- Shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` was not targeted.

## DEF-036 — Vortex route parity

### Deterministic tests

- RED: the delayed-SPA route test initially failed because generic low-confidence Vortex results did not request a follow-up.
- GREEN: `swift test --package-path app --jobs 1 --filter 'vortex|browserDetectionRetryPolicyAllowsOnlyOneFollowUpPerURL|browserSessionFollowUpWaitsForDelayedSPAContentToSettle'`
- Result: 4 tests passed, 0 failures.
- Coverage proves one bounded host-scoped follow-up, duplicate suppression, a longer Vortex settle interval, and an ordered viable Reader session from the sanitized fixture.

### Live iPhone 16e result

- Initial control run: series-to-chapter navigation settled on chapter 168 at low confidence (`score=33`, `candidates=1`); a direct chapter 168 load reached high confidence (`score=160`, `candidates=41`) and produced one pending and one visible Reader presentation.
- Remediated route runs: the initial chapter result and the single 12-second follow-up both remained low confidence (`score=33`, `candidates=1`). A later direct control produced the same low result, so the site no longer supplied a viable direct baseline during final revalidation.
- No challenge signal, authentication bypass, protected-viewer interaction, or aggressive retry loop was used.
- Result bundles from diagnostic runs are under `/private/tmp/toonedge-live-vortex-derived/Logs/Test/`; these are temporary host artifacts and should be retained by CI when live compatibility checks are run.
- Conclusion: deterministic app behavior is improved, but DEF-036 remains open because live in-site/direct Reader parity could not be verified against a viable final control.
