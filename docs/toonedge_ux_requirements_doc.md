# ToonEdge UX Requirements Document

## Document purpose
This document is the Codex-facing UX source of truth for ToonEdge. It translates the PRD and current Stitch mocks into implementation-ready UX requirements, screen behavior, state definitions, and interaction rules.

This document should be used together with:
- Product Requirements Document
- UX Brief
- Architecture / Technical Design Doc
- Epic / Story Breakdown
- agents.md

If this document conflicts with the PRD on product scope, the PRD wins. If this document conflicts with implementation details in the architecture doc, the UX behavior here still governs the user-facing result.

---

## 1. Product UX summary

ToonEdge is a smart reading browser with a personal library attached. It helps users:
- search the web or paste a chapter link
- open content inside the app
- detect supported manhwa/manga pages
- convert those pages into a clean native reader
- save and resume reading progress
- track new chapter availability

The core UX goal is to reduce friction between “I want to read this” and “I am comfortably reading this now.”

### Product UX principles
1. **Reading first**  
   Every major interaction should shorten the path to reading.
2. **Trust before magic**  
   Automatic behavior should only happen when confidence is high.
3. **Start anywhere**  
   Users should be able to begin from search, URL paste, library resume, or recent activity.
4. **Escape is always available**  
   Reader Mode must never trap the user away from the original page.
5. **Search is a primary feature**  
   Search is not a utility; it is a first-class entry point.

---

## 2. Core user flows

### Flow A — Start from web search
1. User opens Home.
2. User taps the universal search/URL field.
3. User enters a search query.
4. App opens search results in the in-app browser.
5. User taps a result.
6. Destination page loads.
7. Detection runs.
8. High confidence: Reader Mode auto-opens.
9. Medium confidence: app shows “Read in Clean Mode.”
10. Low confidence: app remains in browser mode.

### Flow B — Start from pasted URL
1. User opens Home.
2. User pastes a chapter or series URL.
3. App opens the URL in the browser.
4. Detection runs after load.
5. Reader conversion follows confidence rules.

### Flow C — Resume from library
1. User opens Home or Library.
2. User taps a Continue Reading or in-progress series entry.
3. App restores the last-read chapter and last-read position.

### Flow D — Save a new series
1. User reads a detected chapter.
2. User follows/saves the series.
3. The series appears in Library.
4. The series becomes eligible for update checks.

### Flow E — View original page
1. User is in Reader Mode.
2. User taps “View Original Page.”
3. App returns to the corresponding browser page state.

### Flow F — Read a new update
1. App surfaces a new chapter badge.
2. User opens the series.
3. New chapter is clearly marked.
4. User starts reading from Series Detail or Home.

---

## 3. Global UX rules

### 3.1 Navigation model
Top-level navigation supports:
- Home
- Library
- Downloads
- Settings

Browser is presented from Home/Search and preserved behind Reader Mode; it is not a required MVP bottom-tab destination.

The first tab must support both:
- new search-based reading sessions
- returning to saved reading

### 3.2 Search model
The universal search field must:
- accept URLs and search queries
- visually communicate dual-purpose use
- route both input types into browser flows
- never be treated as library-only search
- reuse persisted recent searches and links in visible suggestions, with actual user-entered recent searches prioritized over canned examples

### 3.3 Detection model
Detection occurs only after a page has loaded in the in-app browser.

Confidence behavior:
- **High confidence** → auto-enter Reader Mode
- **Medium confidence** → show non-blocking reader CTA
- **Low confidence** → remain in browser

### 3.4 Reader model
Reader Mode must:
- feel immersive and calm
- minimize chrome by default
- allow immediate return to the source page
- preserve reading progress automatically
- toggle chrome on content taps in both directions: one tap reveals controls, the next hides them
- use a back button instead of a generic `x`
- make back origin-aware:
  - Library-launched Reader sessions return to native Series Detail
  - Browser-auto-opened Reader sessions return to the source series/index page
- keep `View Original Page` as the explicit path back to the exact chapter URL
- keep the Reader `Library` action deterministic: it always opens the Library root

### 3.5 State consistency
Across screens, the product must use consistent visual/state language for:
- new content
- unread content
- in-progress content
- read content
- downloaded content
- unsupported or non-extractable content

### 3.6 Quiet editorial presentation

The visual direction is defined in `docs/plans/2026-09-27-quiet-editorial-ux-design.md`.

- Borderless editorial groups are the default; repeated outlined cards are not.
- Typography, spacing, alignment, artwork, and restrained motion establish hierarchy.
- Elevated surfaces are reserved for navigation/reader chrome, sheets, selected state, and transient feedback.
- Utility screens follow system light/dark appearance; Reader canvas remains an explicit reading preference.
- Purple is reserved for primary action, selection, and meaningful update state.
- Custom controls provide visible pressed states and at least 44×44-point hit regions.
- Haptics are optional, semantic, and limited to meaningful user-caused outcomes.

---

## 4. Screen specifications

# 4.1 Home Screen

## Purpose
Home is the primary launchpad for both search-based reading and saved reading.

## UX goals
- Make search the primary hero interaction.
- Make Continue Reading immediately accessible.
- Surface saved reading and updates without overwhelming search.

## Required UI elements
- universal search / URL field as the topmost primary content element
- optional restrained product identity after the search field; Settings remains available through the primary Settings tab
- Continue Reading section
- Recently Updated section
- All Library or equivalent saved collection section
- bottom navigation

## Required behavior
- Tapping the search field opens search entry state or overlay.
- Tapping a continue-reading card opens the last-read chapter.
- Tapping a library card opens Series Detail.
- Tapping a recently updated card opens Series Detail.

## Required states
- populated state
- empty or first-use state
- refresh/update state
- library-with-updates state

## Home search bar requirements
The Home search field must:
- use placeholder copy similar to “Search or enter URL” or “Search the web or paste a chapter link”
- visually read as a browser entry point, not an internal filter
- support focus, typing, and suggestion states
- support URL or search query submission

## Content hierarchy rules
Visual priority should be:
1. search / URL field
2. Continue Reading
3. Recently Updated
4. All Library

## Interaction rules
- Pull to refresh may refresh updates and recent state.
- Home does not duplicate Settings as an accessory action, and manual refresh does not visually compete with search.
- Long press on library items may open utility actions in later implementation, but this is optional for MVP.
- Home should never auto-open reader without the user intentionally choosing/opening content first.

## Acceptance criteria
- Search is visually and functionally primary.
- Saved reading remains easy to resume.
- Home does not feel like a passive library-only screen.

---

# 4.2 Search Overlay / Search Entry State

## Purpose
Provide a fast, low-friction entry into web reading.

## UX goals
- Reduce typing effort.
- Surface likely next actions quickly.
- Distinguish openable links from reusable searches.

## Required UI elements
- focused input field
- clear/cancel action
- suggestions list
- clipboard suggestion when available
- bounded saved-Library matches for nonempty queries
- recent searches
- recent links
- recent/common sites

## Suggestion priority order
1. Open copied link
2. Exact saved-title match
3. Prefix/token saved-title matches
4. Recent links
5. Recent searches
6. Recent/common sites
7. Explicit “Search for …” action

## Required suggestion behaviors
- Clipboard suggestions must only appear when relevant.
- Suggestions must be tappable rows.
- Suggestions must be visually differentiated by type.
- Ordinary saved, history, and site results are deduplicated by typed destination identity. The final explicit web action is exempt: when the query exactly matches a copied URL, keep `Open copied link` first and the explicit web action last, even if both have the same browser-input destination. Suppress duplicate ordinary rows for that destination.
- Saved matches are labeled as Library content, show local lifecycle/resume context when available, and open native Series Detail without creating web-search history.
- Empty queries do not list the Library as a catalog; saved matching is local and does not fetch details or make network requests per keystroke.

## Required states
- idle focused state
- typing state
- clipboard-available state
- no-history state

## Interaction rules
- Submit URL → open browser directly.
- Submit search query → open browser search results.
- Cancel returns to Home.

## Acceptance criteria
- Search entry feels immediate.
- Users do not need to know whether they are entering a URL or a search query.
- Suggestions help accelerate entry rather than distract.

---

# 4.3 Browser — Search Results State

## Purpose
Show web search results inside ToonEdge and help users choose a supported source.

## UX goals
- Keep the experience familiar enough to behave like a browser.
- Highlight supported sources without making unsupported sources unusable.
- Make it clear that extraction happens after the user opens a result.

## Required UI elements
- browser/search field in app bar
- result list
- source favicon / site identity
- result title and snippet
- supported-source tag where applicable
- bottom browser controls

## Required behavior
- Tapping a result opens the destination page.
- Supported-source labeling may be shown in result rows.
- Search results must still allow non-supported results to open.

## Required states
- search results loaded
- search results with supported source labels
- unsupported/general result rows
- no results state

## Interaction rules
- Search results themselves do not auto-convert to Reader Mode.
- Detection runs only after a result page loads.

## Acceptance criteria
- Search results feel like a browser search result page, not a built-in catalog.
- Supported-source information is additive, not blocking.

---

# 4.4 Browser — Destination Page / Detection States

## Purpose
Serve as the bridge between browsing and Reader Mode.

## UX goals
- Preserve browsing familiarity.
- Make conversion to Reader Mode obvious when appropriate.
- Avoid aggressive false positives.

## Required UI elements
- address/search field or visible URL area
- back / forward / refresh or equivalent controls
- page content area
- optional detection banner / CTA
- optional high-confidence auto-open confirmation

## Required detection states
### Low confidence
- No reader CTA is shown.
- User remains in browser mode.
- Manual reader attempt may still be exposed.

### Medium confidence
- Show a clear but non-blocking CTA such as “Read in Clean Mode.”
- User must tap to enter Reader Mode.

### High confidence
- Auto-enter Reader Mode.
- Show a brief transition or toast such as “Opening in Clean Reader…”
- Transition should feel smooth, not jarring.

## Required behavior
- Detection must happen after page stabilization.
- Browser state must be preserved so the user can return to the source page.
- The user must never lose the current page due to conversion.

## Acceptance criteria
- Browser remains usable regardless of detection success.
- Medium-confidence CTA is obvious.
- High-confidence auto-open does not feel abrupt.

---

# 4.5 Reader Screen

## Purpose
Provide the cleanest possible mobile reading experience for extracted chapter content.

## UX goals
- Remove all non-reading clutter.
- Support long-session reading.
- Keep controls accessible but hidden by default.
- Preserve trust with an explicit route back to the source page.

## Required UI elements
- full-width or fit-width vertical reading canvas
- minimal top chrome (when visible)
- minimal bottom chrome (when visible)
- progress indicator
- chapter navigation controls where available
- settings entry point
- explicit “View Original Page” action

## Required default behavior
- Reader content is the primary focus.
- Chrome should be minimal or hidden by default.
- Tapping the reading surface toggles chrome visibility.
- Progress saves automatically during or after reading.

## Required reader controls
- origin-aware back button
- chapter context (series title + chapter title/number)
- chapter navigation or chapter selector
- progress indicator
- settings
- view original page

## Required settings
- fit width
- fit screen
- page spacing toggle
- brightness or reading-brightness aid
- background / canvas options if included in v1 implementation

## Required states
- normal reading state
- chrome visible state
- settings sheet visible state
- loading reader state
- failed extraction / unreadable content fallback state

## Interaction rules
- Back from a Library-launched Reader returns to that series' native Series Detail screen.
- Back from a Browser-auto-opened Reader returns to the source series/index page.
- “View Original Page” must return to the browser page.
- Reader `Library` action always routes to the Library root, not Series Detail.
- Reader must not prominently show product branding in active reading chrome.
- Reader should preserve the user’s place even if the screen is dismissed and reopened.

## Acceptance criteria
- Reader feels immersive and calm.
- Escape hatch is clear and reliable.
- Progress persists correctly.

---

# 4.6 Series Detail Screen

## Purpose
Present a saved series and its chapter list in a utility-first way.

## UX goals
- Make it easy to continue reading.
- Make chapter states obvious.
- Support update awareness and download awareness.

## Required UI elements
- series header / hero area
- follow/save state
- primary continue-reading CTA
- synopsis or metadata summary
- chapter list
- sort/filter affordances if included

## Header rules
- Hero area can exist, but it must not push chapter utility too far down.
- Primary CTA should be progress-aware, e.g. “Continue Chapter 142.”

## Chapter row state system
Every chapter row must be able to represent:
- New
- Unread
- In Progress
- Read
- Downloaded

### New state
- visually distinguished with a badge or highlight
- should not be mistaken for generic unread

### Unread state
- clearly available to start
- may use a dot, label, or neutral download icon if not downloaded

### In Progress state
- must show progress within the chapter
- should visually outrank simple unread/read status

### Read state
- must be clearly completed
- should not rely only on reduced opacity if that harms accessibility

### Downloaded state
- should be represented separately from read/unread when relevant

## Required behavior
- Tapping the primary CTA resumes the latest in-progress chapter.
- Tapping any chapter row opens that chapter.
- New chapters must be distinguishable at a glance.

## Required states
- followed series with active reading
- followed series with new chapter
- completed series
- missing cover / fallback state

## Acceptance criteria
- Chapter rows are systematic and easy to scan.
- Continue reading is obvious.
- The screen prioritizes chapter utility over decorative presentation.

---

# 4.7 Library Screen

## Purpose
Show the user’s saved reading collection and current reading organization.

## UX goals
- Provide an at-a-glance snapshot of active reading.
- Support browsing saved titles.
- Highlight progress and recent activity.
- Manage planned reading
- Show reading progress
## Required UI elements
- title / app bar
- segmented control or view control if applicable (e.g. Recent / Reading / Planned)
	- Changing segments should animate quickly, preserve scroll position if feasible, update visible filtering immediately
- progress or summary banner
- library grid or list
- series cards
- bottom navigation

## Required card content
Each series card should support:
- cover art
- title
- progress indicator
- chapter status summary
- new chapter badge
- completion badge
- missing cover fallback state
- recent activity metadata
- update badge when applicable

## Required states
- reading library state
- planned state
- recent state
- empty library state
- missing cover fallback
	- render branded fallback artwork
	- Preserve layout consistency
	- avoid broken image presentation

## Interaction rules
- Tapping a card opens Series Detail.
- Filter or segmented controls must change visible subsets clearly.

## Library organization delivery

Story 13.5 adds sorting only: recent activity, title, and fixed unread-updates-first order. Direction controls apply only to activity and title. Existing lifecycle segments, collection density, card navigation, and genuine empty states remain unchanged. Organization preferences persist locally; Reset restores Recent and activity descending without changing density. Sorting does not hide titles within the selected segment.

Story 13.9 separately adds multi-select source filtering from the user's saved domains, an active-source summary, and Reset for source-filtered empty results. Do not show source controls as placeholders in Story 13.5. The split does not approve a particular control placement or sheet interaction; those UI proposals still require review.

## Acceptance criteria
- Library communicates reading status, not just saved ownership.
- Progress and update state are readable without entering the title.

---

# 4.8 Downloads Screen

## Purpose
Provide lightweight management of downloaded or cached chapters.

## UX goals
- Make offline access predictable.
- Keep the screen utility-focused.
- Avoid turning Downloads into a second Library.

## Required UI elements
- storage usage summary
- downloaded/cached items list
- remove/delete controls

## Required states
- downloads present
- empty downloads
- storage pressure / high usage state (optional)

## Interaction rules
- Tapping a downloaded chapter opens it if supported by implementation.
- Remove action must be straightforward.

## Acceptance criteria
- Users can understand what is stored offline and how much space it uses.

---

# 4.9 Settings Screen

## Purpose
Provide low-complexity controls for reading behavior and storage management.

## UX goals
- Keep settings lean for v1.
- Surface only high-value controls.

## Required settings groups
- Reader Preferences
- Storage Management
- Check for New Chapters / update preferences
- About ToonEdge

## Required behavior
- Settings entries should be clearly grouped.
- Settings should not contain speculative or post-MVP complexity.

## Acceptance criteria
- Settings feel focused and useful, not bloated.

---

## 5. Cross-screen behavior requirements

### 5.1 Return to source page
Wherever Reader Mode is entered from Browser, the user must be able to return to the corresponding source page.

### 5.2 Save and follow behavior
When a user engages with a series enough to justify saving, the UI should make follow/save state available without interrupting reading.

### 5.3 Progress persistence
Progress must persist across:
- app background/foreground
- screen transitions
- return visits to the same chapter

### 5.4 Update surfacing
New chapter availability should be visible in:
- Home / Recently Updated
- Library cards
- Series Detail chapter list

### 5.5 Empty / loading / error handling
Every major screen should support the following where applicable:
- empty state
- loading state
- soft error state
- retry affordance if the action is recoverable

---

## 6. UX copy guidance

### Search field
Preferred copy patterns:
- “Search or enter URL”
- “Search the web or paste a chapter link”

### Detection CTA
Preferred copy patterns:
- “Read in Clean Mode”
- “Opening in Clean Reader…”
- “View Original Page”

### Chapter state labels
Recommended consistent labels:
- New
- Unread
- In Progress
- Read
- Downloaded

---

## 7. Accessibility and interaction notes

### Accessibility requirements
- Do not rely on opacity alone to communicate chapter state.
- Badges, text, and icons should work together.
- Tap targets should remain comfortably touch-friendly.
- Reader chrome should remain usable in dark environments.

### Motion requirements
- Reader auto-open should use subtle transition motion.
- Detection CTA should animate in a restrained way.
- Motion should support comprehension, not feel flashy.

---

## 8. Implementation notes for Codex

### Use this document to drive:
- screen-level component breakdown
- state modeling
- navigation transitions
- acceptance criteria for UI stories

### Do not use this document to infer:
- unsupported post-MVP features
- backend requirements not present in the architecture doc
- multi-page chapter stitching behavior in MVP

### When a behavior is ambiguous
Prefer the following order:
1. maintain a low-friction path to reading
2. preserve user trust
3. avoid aggressive automation
4. keep the interface calm and minimal

---

## 9. MVP-required screen/state checklist

### Home
- [ ] populated state
- [ ] empty state
- [ ] search-first hierarchy
- [ ] continue reading section
- [ ] recently updated section
- [ ] library section

### Search overlay
- [ ] focused state
- [ ] typing state
- [ ] clipboard suggestion
- [ ] recent searches
- [ ] recent links
- [ ] common sites

### Browser search results
- [ ] results list
- [ ] supported source tag
- [ ] search result tap through

### Browser destination
- [ ] low-confidence state
- [ ] medium-confidence CTA
- [ ] high-confidence auto-open state

### Reader
- [ ] minimal reading state
- [ ] chrome visible state
- [ ] settings sheet
- [ ] view original page
- [ ] progress indicator

### Series detail
- [ ] continue reading CTA
- [ ] chapter list
- [ ] chapter state system
- [ ] new chapter visibility

### Library
- [ ] series cards with progress
- [ ] status grouping / segmented control if used
- [ ] missing cover fallback

### Downloads
- [ ] storage summary
- [ ] downloaded items
- [ ] remove action

### Settings
- [ ] reader preferences
- [ ] storage management
- [ ] update check preference entry
- [ ] about

---

## 10. Definition of UX complete for implementation

A screen or flow is UX-complete for Codex implementation when:
- its purpose is clear
- required states are defined
- required actions are defined
- transition-in and transition-out behavior is defined
- the screen supports the relevant product trust model
- MVP boundaries are not violated
