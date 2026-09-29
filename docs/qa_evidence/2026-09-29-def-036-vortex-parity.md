# DEF-036 live Vortex parity — 2026-09-29

Outcome: **Live limitation**. DEF-036 remains **Open**.

Both flows reached the same currently available chapter and visibly opened Reader. The direct target matched the in-site chapter identity. Each chapter flow produced one initial detection, no follow-up, one pending Reader presentation, and one visible Reader presentation after observation through the 12-second settle window.

## Sanitized live observations

```text
flow=in-site
host=vortexscans.org
path-shape=/series/:segment/chapter-:number
initial-detection-count=1
follow-up-count=0
confidence=high
score=114
candidates=40
parser-path=genericHeuristic
pending-presentations=1
visible-presentations=1
```

```text
flow=direct
host=vortexscans.org
path-shape=/series/:segment/chapter-:number
initial-detection-count=1
follow-up-count=0
confidence=high
score=168
candidates=39
parser-path=genericHeuristic
pending-presentations=1
visible-presentations=1
```

## Live limitations

- The original acceptance criteria require the same viable Reader session. The observed chapter identity and presentation behavior match, but the captured UI and logs do not establish equal Reader page lists or an equivalent stable payload identity. Candidate counts and scores differ; candidate count alone does not prove the final Reader payload. This evidence therefore does not justify closing DEF-036 or establish an app divergence.
- Counts above apply to the selected chapter route only. The preceding series page had one initial low-confidence detection and one bounded low-confidence follow-up; neither presented Reader.
- The prescribed stream did not emit the app's info-level events. In-site events were recovered with a read-only info-level log query. The first direct run visibly opened Reader, but its counts could not be recovered; the recorded direct metrics come from one supplemental direct launch with info-level streaming enabled. No further live attempts were made.
- The target was resolved with one successful bounded series-page read. Page HTML and artwork screenshots were not saved or committed. Raw category logs remain outside the repository in temporary storage; no full live URLs, query values, credentials, cookies, or session data are included here.

## Deterministic fixture evidence — separate scope

The independently recorded Task 2 fixture and route-policy run passed its six selected tests. That deterministic result verifies the sanitized fixture and bounded retry behavior; it does not establish equal live Reader payloads for these observations.
