## Task 3: Final Verification and Documentation Status

**Files:**
- Modify: `docs/toonedge_epics_and_stories.md`

**Interfaces:**
- Consumes:
  - Story 11.39 documentation.
  - Passing focused Library tests from Task 2.
- Produces:
  - Story 11.39 marked `implemented`.
  - Full verification results.

- [ ] **Step 1: Mark Story 11.39 implemented**

In `docs/toonedge_epics_and_stories.md`, change:

```markdown
### Story 11.39 — Library summary card demotion
**Status:** planned
```

to:

```markdown
### Story 11.39 — Library summary card demotion
**Status:** implemented
```

- [ ] **Step 2: Run focused Library tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 3: Run full package tests**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 4: Build the iPhone simulator target**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: pass. If the build fails with `Operation timed out` while opening source files, rerun once with:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' -jobs 1 build
```

Expected: pass.

- [ ] **Step 5: Optional simulator visual check**

If simulator inspection is available, launch Library in the simulator and verify:

- No large summary card appears between filters and the collection.
- Count text appears inline above the collection.
- View-mode control remains reachable.
- Refresh icon appears only when update refresh service exists.
- More cover artwork is visible above the fold than before.
