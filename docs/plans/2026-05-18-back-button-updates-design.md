# Back button updates

## Goal

Replace the Reader's generic `x` exit affordance with an origin-aware back button while keeping Library and exact-source exits unambiguous.

## Target behavior

- Reader shows a back button instead of an `x`.
- If Reader was launched from Library, back returns to the native Series Detail page for that series.
- If Reader was auto-opened from a browser/web flow, back returns to the canonical source series/index page.
- `View Original Page` continues to open the exact chapter URL.
- The Reader `Library` action always opens the Library root, never conditionally routes to Series Detail.

## Design notes

- Reader needs explicit launch-origin context in its routing/session payload; back behavior should not be inferred from URL shape alone.
- The three exits serve different user intents:
  - **Back**: return to where this reading session came from
  - **View Original Page**: inspect the exact live chapter page
  - **Library**: jump to the Library root
- Existing browser-owned Reader behavior should remain coordinated with the live Browser flow; this story changes routing semantics, not the browser architecture.

## Acceptance criteria

1. Reader chrome uses a back button, not `x`.
2. Library-origin Reader back returns to Series Detail.
3. Browser-origin Reader back returns to the canonical series/index URL.
4. `View Original Page` still opens the exact chapter URL.
5. Reader `Library` action always opens the Library root.
6. Tests cover both back origins plus the two explicit non-back exits.
