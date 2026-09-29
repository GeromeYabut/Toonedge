# DEF-020 Numeric Reader Adjacency Evidence — 2026-09-29

## Scope and status

DEF-020 is resolved. The verified slice ensures that numeric Reader navigation uses `current - 1` and `current + 1`, never sparse Recent ordering. The evidence below is an audit of the Task 1–3 reports in `.git/worktrees/def-020-numeric-adjacency-ui/sdd/`; it records their results without rerunning simulators or live-site actions.

## Root cause and implementation commits

- Repository root cause: numeric adjacency could accept stale explicit previous/next links (chapter 1 and chapter 169) ahead of the required numeric neighbors. The resolver now prefers an exact stored numeric target, accepts an explicit target only when its canonical URL chapter identity matches the requested number, and otherwise uses conservative URL inference.
- Fixture transport root cause, distinct from repository resolution: the direct Reader fixture's adjacent-success loader generated a new session UUID. The full-screen cover is keyed by the presented session ID, so a successful fixture load dismissed the visible Reader even though the resolved target was correct. The fixture-only loader now preserves the existing session ID.
- Domain commits: `cd4ddd5` (`fix: reject stale explicit numeric chapter links`) and `c62981b` (`fix: validate explicit links by canonical chapter identity`).
- Fixture/UI commits: `3383d6a` (`test: add numeric reader adjacency fixtures`), `6df4832` (`test: cover numeric reader adjacency navigation`), and `63e2e24` (`test: assert exact numeric reader chapter labels`).

## RED evidence

Before the repository change, the focused stale-link regression for chapter 155 failed with four issues: explicit previous chapter 1 was selected instead of chapter 154, and explicit next chapter 169 was selected instead of chapter 156. The command exited 1 after the build succeeded.

```sh
swift test --package-path app --jobs 1 --filter swiftDataRepositoryRejectsNonAdjacentExplicitLinkForNumericChapter
```

The initial fixture UI run also reproduced a transport-only failure: the unsafe test passed, while the two visible adjacent journeys lost `reader.root` after their named control taps because the direct fixture replaced its cover identity. This was not a repository-navigation failure.

## GREEN evidence

### Repository

- Initial focused GREEN: 6 Swift Testing tests passed after the first stale-link correction.
- Canonical-identity review focused GREEN: 9 Swift Testing tests passed, including stale explicit-link rejection, stored numeric payload preference, safe inference, unsafe graceful absence, and misleading series-number rejection.
- Full package gate: 425 Swift Testing tests passed, 0 failures.

These tests prove sparse stored chapters 1, 155, and 169 resolve chapter 155 to chapter 154 and chapter 156 when safely resolvable, rather than to chapters 1 and 169. When the source URL is unsafe, no sparse adjacent target is exposed.

### Visible Reader journeys

After the fixture session-ID correction and exact-label test hardening, the dedicated iPhone 16 Pro Max focused suite passed all 3 `ToonEdgeNumericAdjacencyUITests` in 19.476 seconds:

- Chapter 155 `Next` opens exactly Chapter 156, never Chapter 169.
- Chapter 155 `Previous` opens exactly Chapter 154, never Chapter 1.
- The unsafe numeric fixture has disabled adjacent controls instead of presenting sparse targets.

Command destination: dedicated iPhone 16 Pro Max `29E33EEE-8A11-457F-8F7F-BDF2D44A9FE4`. Result bundle: `/private/tmp/toonedge-def020-numeric-adjacency.xcresult`.

## Simulator limitation and recovery

The first post-correction focused reruns exited 70 before tests launched because `CoreSimulatorService` became invalid and the required destination could not be resolved. No simulator was booted, closed, erased, restarted, or otherwise modified during that outage; no alternate simulator was targeted.

After natural service recovery, the controller reran the exact focused suite outside the sandbox against only the dedicated Pro Max. It passed 3 of 3 tests and produced the result bundle above. The shared iPhone 16 Pro `04F65B71-EEB9-4085-BFBD-8B7406E480A2` was never targeted and remained Shutdown.

## Protected artifacts and remaining limitations

From the primary checkout, the three protected QA screenshots remain untracked and their SHA-256 values match the previously recorded values:

```text
7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8  manhuatop-chapter-label-top.png
56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a  manhuatop-original-page.png
49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5  webtoon-protected-reader-cta.png
```

Remaining limitation: explicit numeric links whose URL does not expose a chapter identity recognized by the existing canonical extractor are deliberately rejected and may fall through to stored-target or safe-inference resolution. This slice does not prove arbitrary site URL semantics or same-series ownership beyond the existing canonical extraction rules. The result bundle is under `/private/tmp` and should be retained by CI as a durable artifact.
