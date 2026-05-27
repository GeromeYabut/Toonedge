# Site Rendering Research Batch 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce the first evidence-backed site-rendering research batch for eight representative manga/manhwa sites.

**Architecture:** This is documentation-first product hardening work. Research from live series and chapter pages feeds `docs/site_rendering_research_catalog.md`; it does not create in-app catalogs, recommendations, or new source promotion behavior.

**Tech Stack:** Markdown docs, web research, live HTTP inspection

---

### Task 1: Select the batch

**Files:**
- Modify: `docs/site_rendering_research_catalog.md`

**Steps:**
1. Select eight sites spanning public platforms, aggregators, and scanlation-style readers.
2. Prefer sites likely to expose different rendering patterns.
3. Keep all work internal and non-promotional.

**Selected batch**
- `MangaFire`
- `MangaKatana`
- `Asura Scans`
- `Toonily`
- `Kai Scans`
- `MangaBuddy`
- `Bato.to`
- `ManhwaTop`

### Task 2: Find live examples

**Files:**
- Modify: `docs/site_rendering_research_catalog.md`

**Steps:**
1. Find one live series page per site.
2. Find one live chapter page per site where accessible.
3. If blocked or unavailable, record that explicitly rather than inferring behavior.

### Task 3: Classify rendering patterns

**Files:**
- Modify: `docs/site_rendering_research_catalog.md`

**Steps:**
1. Inspect page source or live response characteristics.
2. Record layout, extraction path, delivery pattern, ordering source, and risks.
3. Distinguish generic-reader candidates from selector-hint or browser-only candidates.

### Task 4: Write batch findings

**Files:**
- Modify: `docs/site_rendering_research_catalog.md`

**Steps:**
1. Update the queue rows for the eight sites.
2. Add per-site write-ups for each researched site.
3. Add a batch summary identifying common implementation needs.

### Task 5: Verify documentation

**Files:**
- Verify: `docs/site_rendering_research_catalog.md`

**Steps:**
1. Confirm all eight sites have status and notes.
2. Confirm each profiled site has both a series and chapter example or an explicit blocker.
3. Confirm wording preserves the non-catalog product guardrail.
