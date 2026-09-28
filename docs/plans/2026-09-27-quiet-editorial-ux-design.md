# ToonEdge Quiet Editorial UX Design

**Date:** 2026-09-27
**Status:** Approved direction; implementation pending
**Scope:** Visual system, interaction hierarchy, gestures, motion, haptics, accessibility, and screen-level presentation
**Behavioral authority:** This document refines presentation only. The Architecture, PRD, and UX Requirements remain authoritative for module boundaries, product scope, and required behavior.

## 1. Objective

Make ToonEdge feel like a deliberately authored reading tool rather than a generic dashboard assembled from repeated cards. Content, reading position, typography, and artwork lead. Controls remain discoverable but visually recede until needed.

The defining choice is a **quiet editorial** system:

- borderless content groups by default
- hierarchy through type, spacing, alignment, artwork, and restrained motion
- elevated surfaces reserved for chrome, sheets, selected state, and transient feedback
- purple reserved for the primary action, current selection, and meaningful update state
- system-adaptive app chrome outside Reader
- explicit Reader canvas choices independent from app appearance

## 2. Non-goals and guardrails

- Do not change detection thresholds, parser behavior, site-profile policy, or protected-site handling.
- WEBTOON and protected GlobalComix remain browser-only.
- Do not add catalogs, recommendations, source marketplaces, browser tabs, or multi-page stitching.
- Keep View Original Page explicit in Reader and adjacent-load failure states.
- Do not infer chapter URLs or identities in presentation code.
- Do not add hidden gestures as the only path to an action.
- Do not use haptics for automatic detection, background work, scrolling, progress persistence, image loading, or cancellation.
- Preserve all local-first repository and persistence boundaries.

## 3. Visual language

### 3.1 Surface hierarchy

Use four surface roles:

1. **Canvas** — the screen background and normal content plane.
2. **Editorial group** — borderless content separated by whitespace or inset separators.
3. **Selected** — a restrained tint or checkmark for the current choice.
4. **Elevated** — browser/reader chrome, sheets, menus, and temporary feedback only.

`TECard` must no longer be the default grouping mechanism. Existing card call sites migrate intentionally; changing the primitive globally without screen verification is prohibited.

### 3.2 Shape

- artwork: 4–8 pt radius
- search fields and compact controls: 10–12 pt radius
- sheets and floating feedback: 16–20 pt radius
- category tags: capsule only when the text is genuinely categorical
- ordinary rows and sections: no enclosing shape

Avoid combining a visible border and a visible fill unless the boundary conveys a functional state.

### 3.3 Typography

- Use the default system design for body, metadata, navigation, and controls.
- Reserve rounded typography for a small branded or numeric accent, if retained at all.
- Use three dominant levels: title, body/action, metadata.
- Prefer regular body and metadata weights; repeated semibold labels flatten hierarchy.
- Use tabular digits for progress, chapter counts, and storage values.

### 3.4 Color and appearance

- App utility screens follow system light/dark appearance.
- Reader retains explicit Charcoal, Black, and Paper canvases.
- Use semantic adaptive foreground, background, separator, success, warning, and failure colors.
- Supply increased-contrast variants.
- Purple communicates primary action, selection, or update state; it is not decorative chrome.
- Never rely on color alone for reading, download, update, or selection state.

This intentionally supersedes the earlier global dark-first presentation direction while preserving a dark-capable immersive Reader. Apple recommends adaptive semantic colors and support for both appearances outside rare immersive contexts: <https://developer.apple.com/design/human-interface-guidelines/dark-mode>.

## 4. Interaction and motion

- Every custom button has a visible pressed state and at least a 44×44 pt hit region.
- Routine transitions use 160–220 ms opacity/position changes.
- Avoid springs for navigation, status, or list updates.
- Reduce Motion replaces movement with opacity or immediate state changes.
- Swipe and long-press actions always have a visible or VoiceOver-accessible alternative.
- Destructive swipe actions do not execute by full swipe when confirmation is required.
- Transient feedback must not be the only record of a failure or required recovery action.

## 5. Screen specifications

### 5.1 Home

- Retain a restrained product identity without creating a decorative hero.
- Keep search visually first.
- Remove the duplicate Settings control; Settings already exists as a primary tab.
- Prefer pull-to-refresh; move manual refresh to an overflow action if it remains necessary.
- Replace the bordered empty-state banner and duplicate full-width CTA with terse borderless copy.
- Use artwork-led Continue Reading rows/cards with progress as the primary color accent.
- Recently Updated and All Library rows must open Series Detail; they may not remain visually tappable no-ops.
- Preserve Home Continue stored-session and Browser-fallback launch-origin behavior.

### 5.2 Search

- Use a quiet filled search field without a decorative focus stroke.
- Render suggestions as whole-row borderless actions with spacing or inset separators.
- Treat `Supported`, `Link`, `Search`, and similar labels as tertiary metadata rather than pills.
- Preserve clipboard/recent-link/recent-search/common-site/search-action priority.
- Keep validation inline and recoverable.
- Support swipe-to-delete for history only when a visible Clear History action also exists.

### 5.3 Browser

- Emphasize the domain; show page title secondarily when space permits.
- Keep Reload in one location.
- Remove the decorative bottom-center `Browser` label.
- Use stable identifiers rather than visible text as UI-test anchors.
- Make the full Clean Mode surface tappable and at least 44 pt high.
- Keep low-confidence and browser-only pages free of the CTA.
- Preserve the live WebView behind browser-owned Reader and preserve exact View Original behavior.

### 5.4 Reader and Reader Settings

- Keep initial chrome hidden and retain single-tap show/hide on the reading surface.
- Do not add horizontal chapter swipes, double tap, pinch, long press, or edge gestures in this epic.
- Toolbar controls and scrolling must not toggle chrome.
- Add accessible Show Controls and Hide Controls actions.
- Keep explicit Previous, Next, Back, Library, Settings, and View Original actions.
- Present adjacent loading/failure as compact nonblocking feedback with Retry and Open Original when safe.
- Restyle Canvas choices as borderless selectable rows/swatches.
- Reader Settings must scroll at accessibility sizes and expose selected values.
- Use medium and large detents and an explicit Done action.

### 5.5 Library

- Comfortable remains cover-first; Compact and List remain progressively denser.
- Remove enclosing borders from collection items.
- Separate items using layout rhythm and, in dense modes, inset separators.
- Preserve persisted density, immediate in-memory filtering, resume-target metadata, update distinction, and missing-cover fallback.
- Filters and density choices expose selected semantics.
- At accessibility sizes, adapt the layout without overwriting the saved density preference.

### 5.6 Series Detail

- Use a compact publication-style header: cover, title, source/progress metadata, and one primary Continue action.
- Reduce status-chip count; keep collection, reading, update, and cache concepts distinct.
- Render chapter rows without enclosing cards.
- Communicate each state once: checkmark for read, progress for in progress, update marker for new, download symbol for retained/available cache.
- Preserve seeded and cached immediate entry, local-first hydration, background refresh, anchor positioning, and Library-origin Browser fallback.
- Chapter retention must not exist only in a hidden context menu; provide a visible menu/action and equivalent VoiceOver action.

### 5.7 Downloads

- Replace the introductory banner and summary card with a compact storage header.
- Render cached chapters as borderless rows.
- Keep a visible 44×44 remove action; swipe removal is optional and cannot replace it.
- Distinguish loading, empty, content, removal success, and removal failure.
- Failed removal preserves the row and provides Retry.
- Do not describe metadata-only retention as guaranteed offline availability.

### 5.8 Settings

- Use native editorial groups and separators rather than one card per section.
- Keep Reader Preferences, Storage Management, New Chapters, and About.
- Storage routes to Downloads and shows a concise trailing value.
- Update checking reports checking, updates found, no changes, partial failure, total failure, and unavailable states accurately.
- Add a separate Haptic Feedback preference.
- Keep About copy factual and remove internal/scaffold language.

## 6. Semantic haptics

Haptics complement visible state; they never replace it. The app exposes a single optional Haptic Feedback setting, default enabled. System controls retain their native behavior and do not receive duplicate custom feedback.

| Event | Feedback | Timing |
|---|---|---|
| A discrete custom selection changes | selection | after the value changes |
| Save to Library succeeds | success | after confirmed persistence |
| Retain/remove cache succeeds | success or light impact | after confirmed completion |
| Adjacent chapter transition succeeds | soft impact | after the new session becomes current |
| User-initiated adjacent load fails | warning | once per attempt, with visible recovery |
| Invalid URL is submitted | warning | when inline validation appears |
| Update check finds one or more updates | success | after the result is known |
| Update check finds no changes | none | visual feedback only |

Always silent:

- automatic Reader entry and Clean Mode availability
- scrolling, progress saves, page visibility, and image loading/retry
- brightness slider movement
- chrome show/hide and sheet open/close
- background update/cache work
- cancellation, stale completion, disabled actions, and no-ops

Apple recommends causal, consistent, short, optional haptics and warns against overuse: <https://developer.apple.com/design/human-interface-guidelines/playing-haptics>.

## 7. Accessibility requirements

- Support system light/dark, Increase Contrast, Reduce Motion, and Dynamic Type through accessibility sizes.
- Maintain a 44×44 pt minimum action region.
- Expose selected traits/values for filters, view modes, Reader fit, and canvas.
- Avoid opacity-only state distinctions.
- Provide meaningful combined labels for series and chapter rows.
- Announce update/removal failures without repeatedly announcing background work.
- VoiceOver must reach all actions offered by swipe or context menu.
- Literal spoken VoiceOver review is required on Home, Browser CTA, Reader chrome, Series Detail, Downloads, and Settings.

## 8. Engineering boundaries

- SharedUI owns semantic tokens, surface styles, control states, and motion policy.
- Feature views own composition and feature-specific copy.
- View models/services own operation outcomes; views do not infer success for haptics.
- A semantic feedback protocol maps feature events to system feedback behind dependency injection.
- Haptic preference remains separate from `ReaderSettings` to prevent stale Reader snapshots from overwriting an app-wide preference.
- No SwiftData schema migration is expected.

## 9. Success measures

- No ordinary screen reads as a stack of uniformly rounded cards.
- Search remains the dominant Home action without duplicate primary CTAs.
- Content rows remain understandable and tappable without borders.
- Utility screens work in system light and dark appearances.
- Reader remains calm, immersive, and explicit about source escape.
- Haptics occur only after meaningful user-caused outcomes and can be disabled.
- All automated gates and the physical-device haptic review in Story 12.8 pass.

## 10. References

- Apple layout and visual hierarchy: <https://developer.apple.com/design/human-interface-guidelines/layout>
- Apple buttons and pressed states: <https://developer.apple.com/design/human-interface-guidelines/buttons>
- Apple gestures: <https://developer.apple.com/design/human-interface-guidelines/gestures/>
- Apple context menus: <https://developer.apple.com/design/human-interface-guidelines/context-menus>
- Apple color: <https://developer.apple.com/design/human-interface-guidelines/color>
- Apple haptics: <https://developer.apple.com/design/human-interface-guidelines/playing-haptics>
