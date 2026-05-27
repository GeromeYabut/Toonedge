# Reader next and previous chapter navigation

## Goal

Make Reader `Next` and `Previous` controls functional so users can move between adjacent manhwa chapters while staying inside the Reader experience.

## Target behavior

- `Next` opens the next chapter in Reader Mode.
- `Previous` opens the previous chapter in Reader Mode.
- The user remains inside Reader rather than being bounced back through Browser between chapters.
- The newly opened Reader session updates:
  - chapter title / label
  - exact chapter source URL
  - progress state
  - available previous / next links
- When no adjacent chapter exists, the matching control is disabled or hidden.
- When an adjacent URL exists but does not yield a viable Reader session, ToonEdge fails safely and does not open a blank/incomplete Reader chapter.

## Design notes

- Adjacent-chapter navigation should use explicit previous/next chapter references from extraction or stored payloads, not URL guessing.
- Chapter transitions should reuse the existing Reader-session creation path so viability gates, ad filtering, and challenge-page suppression still apply.
- Stored library payloads may later provide a fast path for adjacent chapters, but the MVP behavior can rely on the current browser/detection pipeline when no stored payload exists.
- `View Original Page`, origin-aware Back, and Library routing remain separate from chapter navigation.

## Acceptance criteria

1. Reader `Next` opens the next adjacent chapter in Reader when a valid adjacent chapter exists.
2. Reader `Previous` opens the previous adjacent chapter in Reader when a valid adjacent chapter exists.
3. Reader title, source URL, progress, and adjacent-link state update after each transition.
4. First/last chapter states do not expose unusable chapter-navigation actions.
5. Failed or unsafe adjacent extraction does not create an empty Reader session.
6. Tests cover next, previous, disabled-edge states, and failed-adjacent fallback.
