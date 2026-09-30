# DEF-022 Typed Adjacent Outcomes Evidence — 2026-09-29

## Scope and status

DEF-022 is resolved against deterministic package and UI fixtures. Reader adjacent navigation preserves five typed failures, keeps the current chapter visible, offers explicit recovery for a known safe target, and does not retry until the user asks. The success fixture continues to replace the Reader session normally.

This verification did not intentionally trigger a live-site challenge or rate limit. It is fixture-only evidence for failure classification and recovery behavior; it does not claim that a third-party site's current challenge implementation was reproduced live.

## Acceptance matrix

All scenarios start from the same sanitized Chapter 1 Reader fixture with `.homeContinueReading` launch context and a known Chapter 2 target at `https://fixture.example/series/chapter-2`.

| Outcome | Reader message or result | Recovery and stability evidence |
| --- | --- | --- |
| Timeout | `Chapter timed out.` | Chapter 1 remains visible; Retry and Open Original remain enabled; no automatic retry. |
| Challenge/rate limit | `Reader access is temporarily limited.` | Chapter 1 remains visible; Retry and Open Original remain enabled; explicit Retry succeeds after the conservative delay. |
| Unavailable | `Chapter unavailable in Reader.` | Chapter 1 remains visible; Retry and Open Original remain enabled; no automatic retry. |
| Low confidence | `Chapter could not be verified.` | Chapter 1 remains visible; Retry and Open Original remain enabled; no automatic retry. |
| Non-viable images | `No usable chapter images found.` | Chapter 1 remains visible; Retry and Open Original remain enabled; no automatic retry. |
| Success | Chapter 2 replaces Chapter 1 | Failure feedback is absent; View Original opens the Chapter 2 fixture URL; Back returns Home without stale feedback. |

Open Original was exercised for every failure row and opened the reserved Chapter 2 fixture address. The challenge fixture was the only failure configured to succeed after an explicit Retry. The other failure fixtures remain deterministic and do not simulate an unrequested recovery.

## Package verification

Focused diagnostics and recovery commands:

```sh
swift test --package-path app --jobs 1 --filter AdjacentReaderSessionLoaderTests
swift test --package-path app --jobs 1 --filter adjacentFeedback
swift test --package-path app --jobs 1 --filter adjacentChallengeFailurePreservesTargetAndRetriesOnlyAfterUserAction
```

Results:

- `AdjacentReaderSessionLoaderTests`: 13 passed, 0 failed.
- `adjacentFeedback`: 2 passed, 0 failed.
- Explicit challenge retry: 1 passed, 0 failed.
- The parameterized `adjacentFailureWaitsForExplicitRetry(reason:)` regression covers timeout, challenge/rate limit, unavailable, low confidence, and non-viable images. It observes each failure beyond the default delay and proves the loader is still called once until the user explicitly requests Retry.

Full package gate:

```sh
swift test --package-path app --jobs 1
```

Result: 427 Swift Testing tests passed, 0 failures, in 4.305 seconds. The runner also emitted the expected separate XCTest summary of 0 tests before the Swift Testing run.

The production retry delay remains 1.5 seconds (`1_500_000_000` nanoseconds). There is no automatic retry loop.

## Sanitized diagnostics

`OSLogAdjacentReaderSessionLoadDiagnosticsLogger` formats only these fields:

- direction
- elapsed milliseconds
- typed failure reason
- target host
- detection confidence
- parser path
- challenge signal names

The diagnostic value type has no full-URL, cookie, request-header, or session-data field. The target is reduced to its host before logging. The focused challenge regression starts with a URL containing `?session=secret` and verifies that the recorded diagnostic contains only `example.com`, along with the typed reason, direction, parser path, and named challenge signals. No complete sensitive URL, query string, cookie, credential, or Reader session payload is logged.

## UI journey evidence

The focused `ToonEdgeAdjacentFailureUITests` result bundle is:

```text
/private/tmp/toonedge-def022.xcresult
```

Read-only result inspection reported `Passed`: 4 passed, 0 failed, 0 skipped on the dedicated iPhone 16e (`4582CDE9-27DB-4669-86AC-0631C1D7F2ED`), iOS 18.6. The four tests cover explicit challenge Retry, all five typed failure/Open Original rows, normal adjacent success/View Original, and success/Back navigation without stale feedback.

An earlier build-only failure is retained separately at:

```text
/private/tmp/toonedge-def022-missing-fixture-initializer.xcresult
```

That initial invocation did not reach the UI assertions because the actor-backed fixture loader lacked its explicit `init(scenario:)`. The compile defect was corrected in commit `dba917f`; the successful bundle above is the authoritative result.

The fixture matrix uses only `fixture.example` and `images.example.test`, generated labels, and sanitized deterministic content. It neither contacts a live source nor attempts to bypass authentication, challenges, paywalls, rate limits, or protected viewers.

## Screenshots, artifacts, and limitations

A durable fixture-only image is stored at [DEF-022 Adjacent Outcome Chapter 1](2026-09-29/def-022-adjacent-outcome-chapter-1.png). It was captured on the dedicated iPhone 16e after launching the `adjacent-timeout` fixture, manually revealing Reader chrome, and running:

```sh
xcrun simctl launch --terminate-running-process 4582CDE9-27DB-4669-86AC-0631C1D7F2ED com.toonedge.app -uiTesting -resetTestData -readerHardeningFixture adjacent-timeout
xcrun simctl io 4582CDE9-27DB-4669-86AC-0631C1D7F2ED screenshot docs/qa_evidence/2026-09-29/def-022-adjacent-outcome-chapter-1.png
```

Visual inspection confirmed that it shows only generated `Adjacent Outcome Fixture` / `Chapter 1` labels and native Reader chrome. It contains no third-party artwork, live URL, protected content, or user data. The image documents the sanitized fixture surface; the automated result bundle remains the evidence for the typed failure and recovery assertions.

The successful `.xcresult` is currently under `/private/tmp` and is not durable. CI should retain the successful result bundle, the sanitized package-test log, the safe screenshot, and the evidence ledger as downloadable artifacts, with a retention period appropriate for release sign-off. The initial compile-failure bundle may be retained temporarily for audit/debug history but should not replace the successful bundle in release reporting.

The three protected local screenshots in the primary checkout remained untracked and byte-identical:

```text
7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8  manhuatop-chapter-label-top.png
56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a  manhuatop-original-page.png
49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5  webtoon-protected-reader-cta.png
```

The shared iPhone 16 Pro (`04F65B71-EEB9-4085-BFBD-8B7406E480A2`) was not targeted. The recorded UI run and later screenshot follow-up launched and captured only on the dedicated iPhone 16e; no other simulator was targeted.

Remaining limitation: live-site Next/Previous behavior and a naturally occurring rate-limit/challenge were not exercised in this slice. The deterministic fixtures are the release evidence for typed outcomes; live-site availability remains a separate environmental check.
