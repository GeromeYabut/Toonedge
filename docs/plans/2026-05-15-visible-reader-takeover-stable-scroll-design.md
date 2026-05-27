# Visible Reader Takeover And Stable Long-Page Scrolling Design

## Goal

Harden the browser-to-reader handoff and remove the strongest known source of upward-scroll jitter in long manhwa chapters.

## Scope

- Add explicit presentation-state diagnostics for browser-detected Reader sessions.
- Keep Browser-owned Reader presentation as the intended MVP flow.
- Preserve per-page image dimensions from detection into Reader sessions when available.
- Size unloaded page placeholders from known aspect ratios rather than a fixed `430pt` fallback.

## Design

### Browser handoff

The current architecture already intends for `BrowserView` to own detected Reader presentation. The first hardening step is therefore observability, not a speculative rewrite. `BrowserViewModel` will expose a compact presentation-state diagnostic value that distinguishes:

- no detected reader
- pending browser-owned reader
- browser-owned reader visible

This gives tests and QA a direct way to prove whether detection reached the browser-owned path. If live simulator evidence still shows Reader behind Browser while the state says visible, that becomes evidence for a later presentation-architecture change.

### Reader layout stability

`DetectionImageCandidate` already carries width and height. `GenericChapterDetector` will retain those dimensions as `ReaderPageMetadata` beside the ordered `imageURLs` in `MockReaderSession`.

`ReaderImagePanel` will use:

1. detected page aspect ratio when available
2. fixed fallback height only when no metadata exists

This keeps placeholder height close to final rendered height before image decode, which prevents large vertical expansion above the viewport on long webtoon chapters.

### Non-goals

- No multi-page stitching
- No source marketplace behavior
- No browser rewrite unless diagnostics prove the current path is structurally insufficient

## Testing

- Browser tests verify the presentation diagnostic transitions from pending to visible.
- Detection tests verify extracted image dimensions are preserved in detected Reader sessions.
- Reader tests verify placeholder height is derived from metadata for tall pages and falls back when metadata is absent.

