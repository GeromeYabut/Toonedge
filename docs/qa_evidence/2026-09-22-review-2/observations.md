# Firsthand UI observation notes

These are manually transcribed from CUA accessibility/screenshot results, not raw diagnostic confidence logs.

- iPhone 16e fresh-build empty Home: Search the web or paste a chapter link; Settings; Check for new chapters; No saved reading yet; Start a web reading session. Accessibility-large screenshot visually truncates Search th….
- Search initial suggestions: Open copied link, https://example.com/series/chapter-12, Paste; example.com sample chapter; webtoons sample list; new manhwa chapters; moonlit edge chapter 13; webtoons.com / Supported reader source; tapas.io / Open site; globalcomix.com / Supported reader source.
- Typed garden comic → Search for "garden comic". Submitted → www.google.com/search?q=garden%20comic. Google results visible, Garden Comics result followed; Back restored Google, Forward restored gardencomics.com title. Destination body blank; cause unisolated.
- Reopened search: garden comic now a recent search. Clipboard row still canned. Paste bridge attempt inserted prior simulator clipboard, not intended URL; cleared without submission.
- Typed https:// → Browser with Lock, https://, Refresh, disabled Back/Forward, Browser label; blank white content. No validation message. Subsequent recent links included https://.
- Settings at accessibility-large: Settings scaffold; Reader preferences, storage, update checks, and app info belong here. Rectangle; Reader Canvas; Charcoal; Enter Full Screen; Reader Fit; Fit Width. Screenshot showed only Home and Settings tabs. No editable controls exposed for these rows.
- Text size reset to large for subsequent fixture tests.
- Typed http://127.0.0.1:8765/ → ordinary text page and five fixture links rendered; no conversion; Lock icon exposed despite HTTP.
- /medium/ → QA three panels; Read in Clean Mode; ToonEdge found a likely chapter page; action button Description: Bookmark, ID: book. Click opened native numbered panels, no web heading.
- Two scroll/drag attempts on original medium page did not move it; cannot claim scroll restoration at nonzero offset.
- Tapped Reader surface → Back, 127.0.0.1, QA three panels, Open Home, Retain Chapter Offline, Add to Library, View Original Page, Reader Settings, Previous/Next disabled, progress 50%. Reader panels 1 and part of 2 visible. Original Browser controls also remained in returned accessibility tree.
- View Original Page → original Three panels heading and top of panel 1. No immediate re-entry. Browser Back → fixture index.
- Tapped series/chapter-1/ → automatic native Reader, QA panel 1 then panel 2 visible. Revealed chrome → QA Journey Chapter 1, Chapter 1, Next/Previous available, 0% displayed at that observation.
- Tapped Reader Settings. Desktop focus unexpectedly changed to iPhone 16 Pro, but later direct screenshot of 16e confirmed sheet open: Fit Width selected, Fit Screen, Page Spacing off, Brightness Aid slider at left, Charcoal selected, Black, Paper. No settings mutations verified.
- CUA repeatedly returned stale Simulator Window menu and element-ID errors. After restart control briefly worked. Later focus switched between devices; no stable control recovered for remaining journeys. Questions asking for foreground/control coordination were sent.
- Pro Max same build launched; settled screenshot shows empty Home, readable start action, four tabs; search label truncated at end but retains search/web/paste meaning. No further large-device interaction claimed.
