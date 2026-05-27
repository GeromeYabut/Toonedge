# Third-Batch Template Validation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Validate whether a third research batch reveals a genuinely new compatibility bucket.

**Architecture:** Research-first hardening only. Existing runtime templates remain unchanged unless direct inspection proves they are insufficient.

**Tech Stack:** Markdown docs, live HTTP inspection

---

### Task 1: Inspect the batch

**Sites:**
- `mangadex.org`
- `comick.io`
- `mangareader.to`
- `toonily.com` blocked control

### Task 2: Update research documentation

**Files:**
- Modify: `docs/site_rendering_research_catalog.md`
- Modify: `docs/toonedge_epics_and_stories.md`

### Task 3: Verify

**Steps:**
1. Confirm the catalog records direct-fetch outcomes rather than inferred support.
2. Confirm no new runtime template was added without direct evidence.
