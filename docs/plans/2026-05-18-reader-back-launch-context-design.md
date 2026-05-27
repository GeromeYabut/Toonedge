# Reader back returns to launch context

## Goal

Refine Reader Back so it behaves like native navigation for app-origin sessions while preserving the source-index return behavior for web-origin sessions.

## Target behavior

- If Reader auto-opened from a web/browser flow, Back opens the canonical source series/index page.
- If Reader was launched from Home `Continue Reading`, Back returns to Home.
- If Reader was launched from Library Series Detail, Back returns to that Series Detail page.
- `View Original Page` still opens the exact chapter URL.
- The Reader `Library` action still opens the Library root.

## Design notes

- Back should represent the user's prior product context, not merely “leave the chapter.”
- Reader needs explicit launch-context data, likely richer than the current coarse launch-origin enum:
  - browser / web flow
  - home continue-reading
  - library series detail with series ID
  - possibly direct/other future app launch contexts
- The routing layer should consume that context directly rather than attempting to infer prior navigation from the chapter URL.
- This story supersedes the narrower Back behavior from Story 11.20 without changing the semantics of `View Original Page` or `Library`.

## Acceptance criteria

1. Browser-origin Reader Back returns to the canonical source series/index page.
2. Home Continue Reading Reader Back returns to Home.
3. Library-detail Reader Back returns to the same native Series Detail page.
4. `View Original Page` remains exact-chapter routing.
5. `Library` remains Library-root routing.
6. Tests cover all three Back origins independently.
