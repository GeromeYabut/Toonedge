# Site Profile Compatibility Classes Design

## Goal

Harden chapter detection by teaching site profiles *how* a supported site exposes reader content, not only which selectors it tends to use.

## Scope

This slice adds four compatibility classes:

- `embeddedHTML`: reader content is present in the analyzed DOM and can use current detection immediately
- `hydratedDOM`: reader content becomes usable after lazy-source hydration but still resolves from the page DOM
- `browserSession`: initial HTML is insufficient; ToonEdge must not rely on generic initial-response conversion yet
- `browserOnly`: reader conversion is intentionally suppressed

The first registrations are limited to representative researched sites:

- `asurascans.com` -> `embeddedHTML`
- `mangakatana.com` -> `hydratedDOM`
- `mangafire.to` -> `browserSession`
- `manhwatop.com` -> `browserOnly`

## Architecture

`SiteProfile` gains a compatibility field while preserving the existing support-tier and selector-hint model. `ProfileAwareChapterDetector` uses the compatibility class to decide whether to:

- run the current site-profile path,
- run the current site-profile path while surfacing a hydration-aware diagnostic,
- suppress unsafe generic conversion for profiles that require a richer browser-session extractor,
- or continue the existing browser-only low-confidence behavior.

The generic detector remains the fallback for unknown domains.

## Data Flow

1. Browser page analysis arrives as `DetectionPageAnalysis`.
2. `SiteProfileRegistry` resolves a domain match.
3. `ProfileAwareChapterDetector` branches on compatibility class.
4. Embedded/hydrated classes reuse current scoring and candidate normalization.
5. Browser-session and browser-only classes return low-confidence results with explicit diagnostics.

## Error Handling

- Challenge signals continue to override positive detection.
- Browser-session profiles fail closed for now rather than over-promising conversion.
- Unknown domains continue using generic heuristics unchanged.

## Testing

Add fixture-style tests for:

- embedded HTML profile emits a reader session
- hydrated DOM profile emits a reader session and class-aware diagnostics
- browser-session profile stays low confidence even if generic-looking images exist
- browser-only profile remains suppressed
- default registry wires the four representative sites
- promoted suggestions still exclude approved non-promoted sources

## Out of Scope

- implementing browser-session extraction itself
- broad site expansion beyond the four seed profiles
- referer/header-aware image loading
- public catalogs, recommendations, notifications, sync, or chapter stitching
