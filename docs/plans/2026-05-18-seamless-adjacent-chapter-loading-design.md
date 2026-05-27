# Seamless adjacent chapter loading from app-originated Reader sessions

## Story

Story 11.23 — Seamless adjacent chapter loading from app-originated Reader sessions.

## User intent

When a user is already reading inside ToonEdge, `Next` and `Previous` should feel like Reader-native chapter navigation. If the chapter was opened from Home or Library, the app should not visibly bounce the user out to Browser just to fetch the next chapter. Browser can remain the underlying extraction tool, but it should not become the user-facing transition.

## Current behavior

- Stored adjacent chapter payloads can open directly in Reader.
- Browser-origin Reader sessions can use the visible browser flow for adjacent chapters.
- App-originated sessions can fall back to Browser/detection when an adjacent chapter is not stored, but this may visibly interrupt the Reader experience.

## Target UX

The preferred user experience is:

1. User taps `Next` or `Previous`.
2. Reader remains visible on the current chapter.
3. The tapped control shows a small loading state, such as a spinner or disabled pressed state.
4. If the next chapter is already stored, Reader swaps almost immediately.
5. If the next chapter is not stored, ToonEdge loads and analyzes it in the background.
6. On success, Reader replaces the current session with the adjacent chapter and resets to the top of the chapter.
7. On failure, Reader stays on the current chapter and shows a small, recoverable message such as “Couldn’t open next chapter in Reader.”

The user should never see a blank Reader. The user should not lose their current chapter if the adjacent chapter fails. `View Original Page` remains the explicit escape hatch to the live source chapter.

## Recommended implementation approach

Use a hidden adjacent-loader service that reuses the existing Browser/detection machinery without presenting Browser as the active route.

### Why this is the recommended path

- It preserves current MVP guardrails: existing detection thresholds, challenge-page suppression, ad filtering, and site profiles still decide whether Reader is safe.
- It avoids building a second parser stack that could drift from Browser extraction behavior.
- It gives app-originated Reader sessions the same capability as Browser-origin sessions without changing the user-facing navigation model.

## Suggested architecture

Introduce a small service interface owned outside SwiftUI views:

```swift
protocol AdjacentReaderSessionLoading {
    func loadAdjacentSession(
        from url: URL,
        preserving origin: ReaderLaunchOrigin
    ) async throws -> MockReaderSession
}
```

The concrete implementation should:

- check `LibraryLifecycleManaging.readerSession(forSourceURL:)` first for a stored-payload fast path
- otherwise load the URL using a non-presented web extraction path
- run the same page analysis and detector pipeline used by Browser
- require a high-confidence viable Reader session before returning
- enrich the returned session with:
  - original launch origin
  - canonical series/index URL
  - series metadata
  - adjacent previous/next chapter URLs

The Reader view model should own loading state, not the SwiftUI view:

```swift
enum AdjacentChapterLoadState: Equatable {
    case idle
    case loading(direction: ReaderChapterDirection)
    case failed(direction: ReaderChapterDirection, message: String)
}
```

## UX states

### Stored payload available

- Disable the tapped `Next`/`Previous` button briefly.
- Swap Reader session directly.
- Reset scroll to the top of the newly loaded chapter.
- Announce/update title and chapter label.

### Unstored payload loading

- Keep the current chapter visible.
- Show progress in chrome, preferably only near the tapped control.
- Keep content scrolling available unless the user is actively tapping another chapter-navigation action.
- Prevent duplicate next/previous requests while one is in flight.

### Failure

- Stay on the current chapter.
- Re-enable controls.
- Show a non-blocking toast/banner:
  - “Couldn’t open next chapter in Reader.”
  - optional action: `View Original Page`
- Do not automatically present Browser unless the user chooses an escape route.

## Alternatives considered

### Alternative A — Continue visible Browser fallback

This is the current safe fallback. It is simpler and reuses existing behavior, but it breaks the immersive Reader flow and feels like a mode switch.

### Alternative B — Native HTTP-only chapter fetcher

This could be fast for simple static pages, but many sources rely on client-side rendering, lazy-loaded attributes, challenge pages, or profile-specific DOM behavior. It risks creating a second extraction path and increasing blank/false-positive Reader sessions.

### Alternative C — Hidden Browser/detection loader

Recommended. It keeps extraction behavior consistent with Browser while making the transition feel Reader-native.

## Risks and guardrails

- Hidden web loading can consume memory if multiple loads are allowed. Allow only one adjacent load per Reader session at a time.
- Some sites may block background or non-visible web views. If that happens, fail safely and leave the current chapter intact.
- Do not lower confidence thresholds for convenience. False negatives are acceptable; blank Reader sessions are not.
- Preserve launch context across chapter swaps. Adjacent navigation should not convert a Home-origin session into a Browser-origin session.

## Acceptance criteria

- App-originated `Next`/`Previous` does not visibly present Browser when an unstored adjacent chapter must be fetched.
- Stored adjacent payloads still open immediately.
- Unstored adjacent chapters load through the same detection and viability gates used by Browser.
- Failed adjacent loading leaves the current Reader session unchanged.
- Back returns to the original app launch context after one or more adjacent chapter transitions.
- Tests cover success, failure, stored fast path, preserved origin, and duplicate-load prevention.
