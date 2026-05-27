# Unsupported Paginated Reader Diagnostics Design

## Goal

Make paginated single-image readers explicit in the detection model without expanding Reader support beyond MVP scope.

## Architecture

Add `paginatedSinglePage` as a compatibility class and shared template. It represents chapter pages that expose one image at a time plus page navigation, which require post-MVP stitching before they can become clean Reader sessions.

`mangahere.cc` becomes the first registered example:

- support tier: `browserOnly`
- template: `paginatedSinglePage`

Detection keeps these pages low confidence, but diagnostics use a dedicated parser path so QA can distinguish:

- `browserOnlyProfile`
- `unsupportedPaginatedProfile`
- `browserSessionProfile`
- generic low-confidence pages

## Behavior

- paginated readers remain in Browser
- no Reader CTA
- no retry recommendation
- diagnostics explain that the page is unsupported because it is paginated, not because detection merely failed

## Testing

Add a normalized fixture for a MangaHere-style single-page reader and tests that verify:

- registry classification
- low-confidence suppression
- dedicated paginated parser path
- compatibility-class reporting

## Out of Scope

- multi-page fetch
- stitching
- chapter reconstruction
- any public source catalog behavior
