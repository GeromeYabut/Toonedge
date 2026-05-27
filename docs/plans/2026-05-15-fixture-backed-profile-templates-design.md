# Fixture-Backed Profile Templates Design

## Goal

Reduce future site-profile duplication by separating shared handling behavior from thin site registrations and by locking the current compatibility buckets to fixture-backed tests.

## Research Basis

Batch 1 site research showed repeated behavior families:

- embedded page data in HTML
- lazy-source hydration
- browser-session-driven readers
- challenge-gated/browser-only pages

Those are reusable handling patterns. Domains still need local metadata, but they should not each need a bespoke strategy implementation by default.

## Architecture

Introduce `SiteProfileTemplate` as the reusable behavior layer. Each template owns:

- compatibility class
- default extraction strategy

`SiteProfile` remains the site registration layer and owns:

- domain
- support tier
- optional site-specific selector overrides
- a template reference

This preserves domain-specific diagnostics while letting multiple sites share the same underlying handling policy.

## Fixtures

Add test fixtures for four representative page analyses:

- `asura_embedded_html.json`
- `mangakatana_hydrated_dom.json`
- `mangafire_browser_session.json`
- `manhwatop_browser_only.json`

The fixtures represent normalized `DetectionPageAnalysis` payloads rather than raw HTML. That keeps the tests stable and directly tied to the detector contract while leaving room to add raw HTML fixtures later.

## Behavior

- `asurascans.com` and `asuracomic.net` reuse the embedded-HTML template
- `mangakatana.com` uses the hydrated-DOM template
- `mangafire.to` uses the browser-session template
- `manhwatop.com` uses the browser-only template
- future sites can join an existing template unless research proves they need a new one

## Testing

Add tests that:

- load the JSON fixtures from test resources
- prove each fixture maps to the expected detection result
- prove multiple Asura domains reuse the same template behavior
- prove site-level overrides still preserve domain-specific diagnostics

## Out of Scope

- custom parsers
- browser-session extraction internals
- automatic fixture capture
- broad profile rollout beyond the current representative set
