## Task 4: Documentation Status and Verification

**Files:**
- Modify: `docs/defects.md`
- Modify: `docs/toonedge_epics_and_stories.md`

- [ ] **Step 1: Mark documentation implemented**

After code verification passes, update:

```markdown
## DEF-029 — Series Detail seeded shell can show placeholder cover despite visible Library artwork

**Status:** Implemented
```

```markdown
### Story 11.43 — Series Detail local-ready instant entry
**Status:** implemented
```

```markdown
### Story 11.44 — Series Detail fixed header with independently scrolling chapters
**Status:** implemented
```

- [ ] **Step 2: Run focused Library tests**

Run:

```bash
swift test --package-path app --filter LibraryExperienceTests
```

Expected: pass.

- [ ] **Step 3: Run persistence tests if Task 1 touched repository code**

Run:

```bash
swift test --package-path app --filter PersistenceLifecycleTests
```

Expected: pass. If repository code was not touched, this command is still recommended but not required for the defect.

- [ ] **Step 4: Run full test suite**

Run:

```bash
swift test --package-path app
```

Expected: pass.

- [ ] **Step 5: Build the app**

Run:

```bash
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual simulator check if available**

Open a saved Library series with known cover and local indexed chapters where the reader is not at the edge, for example `100/200`.

Expected:
- Series Detail does not show the `Loading series` banner for normal Library-origin navigation.
- If a hydrated snapshot was cached this session, Series Detail shows the full header and Continue immediately.
- If no hydrated snapshot was cached yet, the seed shell may appear briefly while local detail loads, but no network refresh blocks hydration.
- Cover artwork remains consistent between Library, seeded shell, and hydrated detail when a local cover URL exists.
- Header/Continue stay visible while chapter rows scroll.

---

## Execution Notes

- Implement in the order above. DEF-029 is first because the fixed header will make cover quality more prominent.
- Story 11.43 should not attempt to solve first-ever app-launch synchronous repository hydration. It should guarantee instant re-entry from the in-memory hydrated detail cache and immediate actionability once local detail exists, with no network refresh gating.
- Story 11.44 should be layout-only. If the fixed header exposes unrelated stale chapter-target behavior, stop and document that separately instead of folding it into this story.
