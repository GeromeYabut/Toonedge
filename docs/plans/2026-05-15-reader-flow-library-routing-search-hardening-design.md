# Reader Flow, Library Routing, and Search Hardening Design

## Intent

Make Reader the primary experience once a viable chapter exists, while preserving clear exits, faster local relaunch, and more trustworthy search/extraction behavior.

## Design

- Extend `MockReaderSession` with explicit series identity and metadata (`seriesID`, canonical `seriesURL`, source domain, cover/status/synopsis fields). Reader actions consume this payload directly rather than deriving library data from `sourceURL`.
- Keep the existing Browser → Reader presentation model for MVP. `x` exits the chapter to the series/index URL; `View Original Page` preserves the exact chapter return path.
- Add two Reader actions:
  - `Add to Library`: metadata save only
  - `Open in Library`: save if needed, then route to native Series Detail
- Reconstruct stored Reader sessions from persisted chapter payloads when ordered image URLs exist. Missing payloads deliberately fall back to Browser/detection.
- Keep query classification unchanged, but route search queries to Google and combine persisted history with existing local suggestion sources.
- Strengthen ad rejection in generic extraction by broadening explicit ad/banner/sidebar/promo exclusions while continuing to prefer false negatives over false positives.

## Tradeoffs

- This keeps the current Browser/Reader architecture instead of building a new browser coordinator, which is the right MVP tradeoff because the issue is routing and payload quality, not platform capability.
- Generic detection still uses a fallback canonical URL when profile metadata is unavailable, but Reader no longer guesses at save time; it uses the payload it was given.
- Search suggestion merging remains local and synchronous in the view layer, avoiding a larger async view-model rewrite for this slice.

## Testing focus

- Reader exit routing
- Search provider/history behavior
- Stored-session direct relaunch
- Ad exclusion regression
- Existing browser-to-reader and challenge-page behavior
