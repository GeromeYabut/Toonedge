# Browser-Session Retry Lifecycle Design

## Goal

Allow browser-session profiles to wait for one post-load DOM stabilization pass before deciding whether Reader conversion is safe.

## Scope

This story adds a bounded two-pass lifecycle for known `browserSession` profiles:

1. first pass after page load marks the profile as retry-eligible but keeps the page in Browser,
2. one follow-up pass runs after a short delay,
3. the follow-up pass may promote into normal reader behavior only if the DOM now contains viable ordered image candidates.

## Architecture

`DetectionResult` gains retry metadata so Browser can distinguish:

- ordinary low-confidence results,
- first-pass browser-session results that deserve one retry,
- follow-up results that should not loop forever.

`ProfileAwareChapterDetector` stays responsible for domain policy. `BrowserWebView.Coordinator` stays responsible for scheduling page analysis. `BrowserViewModel` remains a consumer of the final detection result rather than owning extraction logic.

## Behavior

- Unknown domains: unchanged.
- Embedded/hydrated profiles: unchanged.
- Browser-session profile first pass: low confidence, no reader session, `retryRecommended = true`.
- Browser-session profile follow-up with viable candidates: reuse existing detection scoring and normal browser confidence behavior.
- Browser-session follow-up without viable candidates: low confidence, no further retries.
- Challenge pages: always low confidence and never retry-promoted.

## Testing

Add tests for:

- browser-session initial pass recommends one retry,
- retry analysis on the same profile can promote to a reader session,
- retry exhaustion remains low confidence,
- challenge pages never recommend retry,
- browser retry policy only allows one follow-up analysis per URL.

## Out of Scope

- full browser-session extractor implementation
- repeated polling
- new site registrations
- referer/header-aware image loading
