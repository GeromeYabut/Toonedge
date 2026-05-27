# ToonEdge UX Brief

## 1. Product Summary

ToonEdge is an iPhone-first reading app that turns cluttered manhwa webpages into a clean, immersive reader. It combines a smart browser, automatic chapter-page detection, a native reading mode, a persistent personal library, and update tracking.

The experience should feel like a smart reading browser with a personal library attached, not just a library app and not just a browser.

## 2. UX Objective

Help users get from “I found or want to find a chapter” to “I am reading comfortably” with as little friction as possible.

The UX should optimize for:
- immediate entry into reading
- clean mobile readability
- confidence in automatic behavior
- fast resumption of ongoing series
- low mental overhead

## 3. Primary User Problem

Users currently read on cluttered manhwa sites that are hard to use on iPhone. Common pain points:
- spam and distractions around the chapter
- images that do not fit the screen well
- awkward zooming and scrolling
- inconsistent chapter navigation
- difficulty remembering where they left off
- no clean way to track ongoing series

## 4. Core UX Promise

ToonEdge should make reading feel native, simple, and trustworthy.

The user should be able to:
- search the web or paste a link from the Home screen
- open content inside the app
- have chapter pages recognized automatically
- enter clean reading mode with minimal friction
- save progress without thinking about it
- return later and resume instantly

## 5. Experience Principles

### Reading first
Every major interaction should shorten the path to reading.

### Trust before magic
Automatic behavior is valuable only when it feels accurate. Auto-entry into Reader Mode should feel helpful, not invasive.

### Start anywhere
Users should be able to start from search, URL paste, clipboard, recent links, or their library.

### Escape is always available
When Reader Mode opens, users must still be able to get back to the original page easily.

### Premium focus
The reader should feel calm, immersive, and deliberate.

### Collection Ownership

Users should feel like ToonEdge is maintaining a curated personal collection, not just browser history.

The Library should feel:
- organized
- visual
- collectible
- status-aware
- alive with updates

## 6. Target User Behaviors

Primary behavior loops:
- resume an in-progress chapter from library
- search for a new series or chapter
- paste a copied link and open it quickly
- open a detected chapter and convert to Reader Mode
- follow a series and check for updates

## 7. Information Architecture

Top-level navigation:
- Home / Library
- Browser presented from Home/Search rather than as a required MVP tab
- Downloads
- Settings

The Home screen should act as both:
- a reading dashboard
- a universal entry point into web reading

## 8. Core UX Flows

### Flow A — Resume reading
1. User opens ToonEdge
2. Continue Reading is visible near the top
3. User taps a series card
4. App opens the last-read chapter at the last-read position

### Flow B — Search and discover
1. User taps the Home search bar
2. Search overlay opens
3. User enters a query or pastes a link
4. Browser or search results load
5. Detection runs on the loaded page
6. If confidence is high, Reader Mode opens automatically
7. If medium, user sees “Read in Clean Mode” and can convert

### Flow C — Save a new series
1. User reads a detected chapter
2. User chooses to follow or save
3. Series appears in library
4. New chapters can later be flagged

### Flow D — Read update
1. User sees a “New” or updated indicator in library
2. User opens the series
3. New chapter is highlighted
4. User starts reading

## 9. Screen Roles and UX Intent

### Home
The Home screen should present two equal entry points:
- continue from saved reading
- start a new session from the web

UX goals:
- make the search bar visually dominant near the top
- communicate “search or paste a manhwa link”
- keep library content immediately below for low-friction resumption
- support quick scanning of progress and updates

### Library UX Goals

The Library should:
- make progress visually scannable
- reduce cognitive load when resuming reading
- encourage collection building
- make updates easy to notice
- support large libraries gracefully

### Search Overlay
The search overlay is where ToonEdge becomes more than a library app.

UX goals:
- feel instant and lightweight
- reduce typing effort
- help users decide quickly between opening a link and running a search
- make clipboard use feel natural without being pushy

Design guidance:
- clipboard suggestion should be prominent but not disruptive
- recent searches should be easy to reuse
- suggested domains should feel like shortcuts, not a content catalog
- the search overlay should visually separate “open directly” from “search broadly”

### Smart Browser
The Browser screen bridges search and reading.

UX goals:
- preserve familiar browser behaviors
- keep detection visible but not noisy
- support quick conversion to Reader Mode
- maintain context so the user can go back

### Series Detail
The Series Detail page should be the user’s organized view of a followed title.

UX goals:
- make chapter selection simple
- clearly differentiate new, unread, and read chapters
- make the “next best action” obvious
- support download/caching where appropriate

### Reader
The Reader is the highest-value screen in the product.

UX goals:
- remove all clutter
- make the chapter feel native to the phone
- make controls discoverable but unobtrusive
- support uninterrupted long-session reading

### Downloads
Downloads should primarily support reassurance and utility:
- what is available offline
- how much storage is used
- how to remove cached items

### Settings
Settings should remain intentionally light in v1:
- reading preferences
- storage management
- update behavior
- app info

## 10. Search UX Requirements

Search should function as a unified entry system, not just a text field.

Functional expectations:
- accepts both URLs and search queries
- routes both into the in-app browser
- supports clipboard suggestions
- supports recent searches and recent links
- triggers detection only after the destination page loads

UX expectations:
- users should not have to decide whether they are “in search mode” or “in browser mode”
- search suggestions should feel local and immediate
- search should support novice behavior and power-user speed equally well

## 11. Detection UX Requirements

Detection is both a system feature and a UX event.

### High-confidence behavior
- auto-enter Reader Mode
- show subtle confirmation such as “Opened in Clean Reader”
- preserve easy access back to the original page

### Medium-confidence behavior
- show a visible but non-blocking CTA such as “Read in Clean Mode”
- let the user choose

### Low-confidence behavior
- remain in browser
- no forced behavior

Because ToonEdge auto-enters Reader Mode at high confidence, the thresholds must be conservative. Trust is more important than maximum conversion rate.

## 12. Tone and Visual Direction

The current direction is:
- dark-mode first
- high-contrast surfaces
- violet / purple accent
- rounded, premium cards
- immersive gradients and glass effects in task-focused surfaces like Reader and Browser overlays

The key is to use it consistently:
- Home should feel structured and editorial
- Browser should feel capable but restrained
- Reader should feel immersive and calm

## 13. UX Risks

### Home still feels too library-first
The Home structure is strong for saved reading, but the search bar must clearly read as the primary new-session entry point.

### Search may feel detached from reading
If the transition from search to browser to detection to reader is not visually coherent, the app may feel like multiple tools stitched together.

### Auto-entry could break trust
If Reader Mode opens on the wrong pages, users may feel the product is hijacking browsing.

### Series Detail may be over-decorated
The hero treatment may be visually strong, but the main job of this screen is chapter selection and status clarity.

## 14. Recommended UX Priorities for Next Iteration

1. Strengthen the Home search bar as the primary “start reading” entry point.
2. Make the browser-to-reader transition feel more intentional and polished.
3. Add explicit “View Original Page” affordance in Reader Mode.
4. Tighten state design for search: idle, focused, typing, suggestions, search results.
5. Tighten state design for detection: high-confidence auto-open, medium-confidence CTA, no-match browser-only.
6. Make read/unread/new/download states more systematic across Home and Series Detail.

## 15. UX Mockups
1. UX Mockups are available under the mockups folder. There are folders named after the screens, and png files within them to reference. Please feel free to reference UX mockups when making UX decisions.
