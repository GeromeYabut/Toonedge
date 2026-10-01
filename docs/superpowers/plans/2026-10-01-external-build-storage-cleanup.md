# ToonEdge External Build Storage Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reclaim approximately 16 GiB from the internal SSD through a verified preserve-first migration to the Seagate drive and make external build storage the documented default for future ToonEdge work.

**Architecture:** Treat the external drive as build-output and evidence storage, never as a source or simulator volume. Copy each explicit candidate to a dated archive, verify content before deleting the internal copy, then validate future SwiftPM and Xcode output directly on branch-isolated external paths.

**Tech Stack:** macOS HFS+/APFS filesystems, `diskutil`, `ditto`, `find`, `diff`, Git worktrees, Swift Package Manager, Xcode `xcodebuild`, Markdown.

## Global Constraints

- The required volume is exactly `/Volumes/Seagate 2TB`, volume UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29`, Journaled HFS+.
- Abort before copying or deleting if that volume is absent, has a different UUID, is read-only, or a direct directory-creation probe fails.
- Archive root is exactly `/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean`.
- Never overwrite an existing archive path.
- Copy first, compare source and destination, and remove only an exact source path that passed verification.
- Never remove a repository root, worktree root, home directory, volume root, unresolved variable, or wildcard-expanded parent.
- Preserve the dirty `feature/story-13.1-reader-continuity` worktree and its `app/.build` directory.
- Preserve the primary checkout and its `app/.build` directory during the migration.
- Preserve the three protected screenshots as untracked, byte-identical files and never copy them to the external drive.
- Do not move or erase simulator devices, runtimes, `iOS DeviceSupport`, application support, Codex sessions, downloads, or unrelated caches.
- Never target shared iPhone 16 Pro simulator `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- Do not push, merge, alter GitHub settings, or delete remote branches without separate explicit authorization.

---

### Task 1: Establish the migration safety baseline

**Files:**
- Create externally: `/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/`
- No repository changes.

**Interfaces:**
- Consumes: mounted Seagate volume, current repository/worktree state, protected-file hashes.
- Produces: validated archive directories and pre-migration evidence used by Tasks 2–6.

- [ ] **Step 1: Verify the exact external volume and free space**

Run:

```sh
diskutil info "/Volumes/Seagate 2TB"
df -k "/Volumes/Seagate 2TB"
```

Expected:

- Volume UUID is `7C6E7CE1-D8D5-3041-AA58-DC000A724A29`.
- Filesystem is Journaled HFS+.
- `Volume Read-Only` is `No`.
- At least 25 GiB is available.

- [ ] **Step 2: Verify process-level write access without retaining probe data**

```sh
mkdir "/Volumes/Seagate 2TB/.toonedge-migration-write-probe"
rmdir "/Volumes/Seagate 2TB/.toonedge-migration-write-probe"
```

Expected: both commands exit 0 and the probe path does not remain.

- [ ] **Step 3: Confirm build processes are quiescent**

```sh
pgrep -fl 'Xcode|xcodebuild|swift-build|swift-test|swift-frontend' || true
```

Expected: no active compilation or test process. If one exists, stop this task without terminating it and identify its owner before continuing.

- [ ] **Step 4: Create new archive and active-output directories**

```sh
mkdir -p \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/private-tmp" \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/worktree-builds" \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/xcode-derived-data" \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests" \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM" \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData" \
  "/Volumes/Seagate 2TB/ToonEdgeBuilds/Results"
```

Expected: all paths are new or empty. Abort if any dated archive subdirectory already contains data.

- [ ] **Step 5: Record repository, protected-evidence, and disk baselines**

```sh
git -C /Users/geromeyabut/Developer/Toonedge branch --show-current
git -C /Users/geromeyabut/Developer/Toonedge rev-parse HEAD
git -C /Users/geromeyabut/Developer/Toonedge status --short --untracked-files=all
shasum -a 256 \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
git -C /Users/geromeyabut/Developer/Toonedge/.worktrees/story-13.1-reader-continuity status --porcelain=v1 --untracked-files=all
df -k /System/Volumes/Data "/Volumes/Seagate 2TB"
```

Expected protected hashes, in order:

```text
7d2afc1a38bdf99c1899a2704c16b80df106cf855c25fe818e80f7cbdfb688f8
56ec7f3cadc27e13cfe6525ec805b6321c64d6e283c60345cd41757df71e000a
49ae9b28d92dfb7bbbd5f69e27f77f5fe117724085163e22f210bc10d4175db5
```

Record the two Story 13.1 status lines verbatim for final comparison.

---

### Task 2: Preserve and remove ToonEdge temporary artifacts

**Files:**
- Consume: explicit top-level paths matching `/private/tmp/toonedge*`
- Create externally: `Archive/2026-10-01-conservative-clean/private-tmp/*`
- Create externally: `Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt`

**Interfaces:**
- Consumes: Task 1 archive and safety baseline.
- Produces: verified external copies and approximately 10.63 GiB reclaimed internally.

- [ ] **Step 1: Generate and inspect the exact source manifest**

```sh
find /private/tmp -mindepth 1 -maxdepth 1 -name 'toonedge*' -print \
  | LC_ALL=C sort \
  > "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt"
wc -l "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt"
while IFS= read -r source_path; do
  case "$source_path" in
    /private/tmp/toonedge?*) du -s -k "$source_path" ;;
    *) printf 'Unsafe candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt"
```

Before copying, read the manifest and confirm every line begins with `/private/tmp/toonedge` and no line equals `/private/tmp`.

- [ ] **Step 2: Check that no candidate is held by an active process**

```sh
lsof 2>/dev/null \
  | rg '/private/tmp/toonedge' \
  || true
```

Expected: no active build or test process references a candidate. If output appears, exclude that exact path and record the reduced recovery estimate.
Remove every excluded path from `private-tmp-sources.txt`, then re-read the complete manifest before continuing.

- [ ] **Step 3: Copy every manifested source into the new archive**

Run this guarded loop over the inspected manifest. It rejects a non-ToonEdge source and any pre-existing destination before copying:

```sh
while IFS= read -r source_path; do
  case "$source_path" in
    /private/tmp/toonedge?*) ;;
    *) printf 'Unsafe candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
  source_name=$(basename "$source_path")
  destination_path="/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/private-tmp/$source_name"
  test ! -e "$destination_path" || exit 1
  /usr/bin/ditto "$source_path" "$destination_path" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt"
```

- [ ] **Step 4: Verify each source/destination pair**

For every copied pair, run the following verification loop:

```sh
while IFS= read -r source_path; do
  case "$source_path" in
    /private/tmp/toonedge?*) ;;
    *) printf 'Unsafe candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
  source_name=$(basename "$source_path")
  destination_path="/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/private-tmp/$source_name"
  diff -qr "$source_path" "$destination_path" || exit 1
  test "$(find "$source_path" -print | wc -l | tr -d ' ')" = \
    "$(find "$destination_path" -print | wc -l | tr -d ' ')" || exit 1
  test "$(find "$source_path" -type f -exec stat -f '%z' {} + | awk '{sum += $1} END {print sum+0}')" = \
    "$(find "$destination_path" -type f -exec stat -f '%z' {} + | awk '{sum += $1} END {print sum+0}')" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt"
```

Expected: every `diff -qr` exits 0 and both comparisons match.

- [ ] **Step 5: Remove only verified internal sources**

Only after the entire Step 4 loop exits 0, run this guarded loop. It rejects the parent path and any entry outside the inspected manifest namespace:

```sh
while IFS= read -r source_path; do
  case "$source_path" in
    /private/tmp/toonedge?*) rm -rf -- "$source_path" || exit 1 ;;
    *) printf 'Unsafe removal candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/private-tmp-sources.txt"
```

Expected: the source is absent and the external destination remains readable.

- [ ] **Step 6: Measure the completed slice**

```sh
du -s -k "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/private-tmp"
find /private/tmp -mindepth 1 -maxdepth 1 -name 'toonedge*' -print
df -k /System/Volumes/Data
```

Expected: no migrated source remains unless it was explicitly excluded as active; reclaimed space is recorded.

---

### Task 3: Preserve and remove inactive worktree build output

**Files:**
- Consume: `app/.build` from clean historical worktrees listed below.
- Create externally: one named worktree directory under `Archive/2026-10-01-conservative-clean/worktree-builds/`, containing its copied `.build` directory.

**Interfaces:**
- Consumes: clean worktree status and Task 1 archive.
- Produces: verified copies and approximately 2.5 GiB additional internal recovery.

- [ ] **Step 1: Revalidate every candidate worktree**

Candidates:

```text
def-020-numeric-adjacency-ui
def-021-authoritative-continue-ui
def-022-adjacent-outcome-matrix
def-036-vortex-live-parity
story-12.1-adaptive-editorial-foundation
story-12.2-home-search-editorial-entry
story-12.3-browser-editorial-chrome
story-12.4-reader-editorial-controls
story-12.5-library-series-editorial-surfaces
story-12.6-downloads-settings-utilities
story-12.7-semantic-haptics
story-12.8-editorial-release-qa
story-reader-hardening-foundation
```

Write the candidate names above verbatim to `manifests/worktree-build-sources.txt`, one name per line. Then run:

```sh
while IFS= read -r worktree_name; do
  case "$worktree_name" in
    def-020-numeric-adjacency-ui|def-021-authoritative-continue-ui|def-022-adjacent-outcome-matrix|def-036-vortex-live-parity|story-12.1-adaptive-editorial-foundation|story-12.2-home-search-editorial-entry|story-12.3-browser-editorial-chrome|story-12.4-reader-editorial-controls|story-12.5-library-series-editorial-surfaces|story-12.6-downloads-settings-utilities|story-12.7-semantic-haptics|story-12.8-editorial-release-qa|story-reader-hardening-foundation) ;;
    *) printf 'Unexpected worktree: %s\n' "$worktree_name" >&2; exit 1 ;;
  esac
  worktree_path="/Users/geromeyabut/Developer/Toonedge/.worktrees/$worktree_name"
  test -z "$(git -C "$worktree_path" status --porcelain=v1 --untracked-files=all)" || exit 1
  test -d "$worktree_path/app/.build" || exit 1
  test -z "$(lsof +D "$worktree_path/app/.build" 2>/dev/null)" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/worktree-build-sources.txt"
```

Expected: empty Git status and no open files. Exclude any candidate that fails either check.

- [ ] **Step 2: Copy each exact `.build` directory**

```sh
while IFS= read -r worktree_name; do
  worktree_path="/Users/geromeyabut/Developer/Toonedge/.worktrees/$worktree_name"
  destination_path="/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/worktree-builds/$worktree_name/.build"
  test ! -e "$destination_path" || exit 1
  mkdir -p "$(dirname "$destination_path")" || exit 1
  /usr/bin/ditto "$worktree_path/app/.build" "$destination_path" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/worktree-build-sources.txt"
```

Abort on a pre-existing destination.

- [ ] **Step 3: Verify and remove each copied `.build` directory**

Verify every worktree pair before removing any source:

```sh
while IFS= read -r worktree_name; do
  worktree_path="/Users/geromeyabut/Developer/Toonedge/.worktrees/$worktree_name"
  source_path="$worktree_path/app/.build"
  destination_path="/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/worktree-builds/$worktree_name/.build"
  diff -qr "$source_path" "$destination_path" || exit 1
  test "$(find "$source_path" -print | wc -l | tr -d ' ')" = \
    "$(find "$destination_path" -print | wc -l | tr -d ' ')" || exit 1
  test "$(find "$source_path" -type f -exec stat -f '%z' {} + | awk '{sum += $1} END {print sum+0}')" = \
    "$(find "$destination_path" -type f -exec stat -f '%z' {} + | awk '{sum += $1} END {print sum+0}')" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/worktree-build-sources.txt"
```

Only after this entire loop exits 0, re-run the allowlist guard from Step 1 and remove only each listed `.build` directory:

```sh
while IFS= read -r worktree_name; do
  case "$worktree_name" in
    def-020-numeric-adjacency-ui|def-021-authoritative-continue-ui|def-022-adjacent-outcome-matrix|def-036-vortex-live-parity|story-12.1-adaptive-editorial-foundation|story-12.2-home-search-editorial-entry|story-12.3-browser-editorial-chrome|story-12.4-reader-editorial-controls|story-12.5-library-series-editorial-surfaces|story-12.6-downloads-settings-utilities|story-12.7-semantic-haptics|story-12.8-editorial-release-qa|story-reader-hardening-foundation)
      rm -rf -- "/Users/geromeyabut/Developer/Toonedge/.worktrees/$worktree_name/app/.build" || exit 1 ;;
    *) printf 'Unsafe removal candidate: %s\n' "$worktree_name" >&2; exit 1 ;;
  esac
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/worktree-build-sources.txt"
```

Expected: worktree source and Git metadata remain; only ignored build output is absent.

- [ ] **Step 4: Prove excluded work remains untouched**

```sh
git -C /Users/geromeyabut/Developer/Toonedge/.worktrees/story-13.1-reader-continuity status --porcelain=v1 --untracked-files=all
test -d /Users/geromeyabut/Developer/Toonedge/.worktrees/story-13.1-reader-continuity/app/.build
test -d /Users/geromeyabut/Developer/Toonedge/app/.build
```

Expected: Story 13.1 status exactly matches Task 1 and both excluded `.build` paths remain.

- [ ] **Step 5: Measure the completed slice**

```sh
du -s -k "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/worktree-builds"
df -k /System/Volumes/Data
```

Record copied and reclaimed totals.

---

### Task 4: Preserve and clear existing Xcode DerivedData

**Files:**
- Consume: children of `/Users/geromeyabut/Library/Developer/Xcode/DerivedData`
- Create externally: `Archive/2026-10-01-conservative-clean/xcode-derived-data/*`

**Interfaces:**
- Consumes: Task 1 process preflight and archive.
- Produces: verified copies and approximately 3.07 GiB additional internal recovery.

- [ ] **Step 1: Reconfirm Xcode is inactive and list exact children**

```sh
pgrep -fl 'Xcode|xcodebuild|swift-build|swift-test|swift-frontend' || true
find /Users/geromeyabut/Library/Developer/Xcode/DerivedData \
  -mindepth 1 -maxdepth 1 -print \
  | LC_ALL=C sort \
  > "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/derived-data-sources.txt"
sed -n '1,200p' "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/derived-data-sources.txt"
```

Expected: no active build process. Stop rather than terminating an active process.

- [ ] **Step 2: Copy each exact DerivedData child**

```sh
while IFS= read -r source_path; do
  case "$source_path" in
    /Users/geromeyabut/Library/Developer/Xcode/DerivedData/?*) ;;
    *) printf 'Unsafe candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
  child_name=$(basename "$source_path")
  destination_path="/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/xcode-derived-data/$child_name"
  test ! -e "$destination_path" || exit 1
  /usr/bin/ditto "$source_path" "$destination_path" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/derived-data-sources.txt"
```

Abort on a pre-existing destination.

- [ ] **Step 3: Verify and remove only copied children**

Verify every DerivedData pair before removing any source:

```sh
while IFS= read -r source_path; do
  case "$source_path" in
    /Users/geromeyabut/Library/Developer/Xcode/DerivedData/?*) ;;
    *) printf 'Unsafe candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
  child_name=$(basename "$source_path")
  destination_path="/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/xcode-derived-data/$child_name"
  diff -qr "$source_path" "$destination_path" || exit 1
  test "$(find "$source_path" -print | wc -l | tr -d ' ')" = \
    "$(find "$destination_path" -print | wc -l | tr -d ' ')" || exit 1
  test "$(find "$source_path" -type f -exec stat -f '%z' {} + | awk '{sum += $1} END {print sum+0}')" = \
    "$(find "$destination_path" -type f -exec stat -f '%z' {} + | awk '{sum += $1} END {print sum+0}')" || exit 1
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/derived-data-sources.txt"
```

Only after the entire verification loop exits 0, run:

```sh
while IFS= read -r source_path; do
  case "$source_path" in
    /Users/geromeyabut/Library/Developer/Xcode/DerivedData/?*) rm -rf -- "$source_path" || exit 1 ;;
    *) printf 'Unsafe removal candidate: %s\n' "$source_path" >&2; exit 1 ;;
  esac
done < "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/manifests/derived-data-sources.txt"
```

Never remove `/Users/geromeyabut/Library/Developer/Xcode/DerivedData` itself.

- [ ] **Step 4: Measure the completed slice**

```sh
du -s -k /Users/geromeyabut/Library/Developer/Xcode/DerivedData
du -s -k "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean/xcode-derived-data"
df -k /System/Volumes/Data
```

Expected: the internal DerivedData parent is empty or nearly empty and the external archive contains the verified children.

---

### Task 5: Encode external storage rules for future agents

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/branching_and_release_workflow.md`
- Modify: `docs/superpowers/specs/2026-10-01-external-build-storage-cleanup-design.md`

**Interfaces:**
- Consumes: verified external layout and actual migration limitations.
- Produces: normative agent policy and contributor commands.

- [ ] **Step 1: Add `External Build Storage` to `AGENTS.md`**

Append this section after `## Branch and Delivery Workflow`:

```markdown

---

## External Build Storage

- Prefer `/Volumes/Seagate 2TB/ToonEdgeBuilds` for ToonEdge build outputs when the exact external volume is mounted and writable.
- Before writing, verify volume UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29`, available space, and direct directory-creation access. Never create the volume mount-point directory when the drive is absent.
- Keep repositories, active worktrees, simulator runtimes, and simulator devices on the internal disk.
- Use branch-isolated external paths for Xcode `-derivedDataPath`, SwiftPM `--scratch-path`, `.xcresult` bundles, and sanitized logs.
- Quote external paths because the volume name contains a space.
- If the drive is absent or unwritable, use a unique `/private/tmp/toonedge-...` fallback, report the fallback, and archive or remove it after verification.
- Review result-bundle attachments before retention. Never retain copyrighted page artwork, credentials, cookies, session secrets, or sensitive URLs.
- Never move or copy the three protected local screenshots to external build storage.
- Never reformat, repartition, eject, rename, or broadly clean the external drive without explicit user authorization.
```

- [ ] **Step 2: Update the workflow guide with exact commands**

Add `## External Build Paths` before `## Pull Requests` in `docs/branching_and_release_workflow.md`:

```markdown
## External Build Paths

When `/Volumes/Seagate 2TB` is mounted as volume UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29` and is writable, keep disposable output under `/Volumes/Seagate 2TB/ToonEdgeBuilds`. Use a filesystem-safe branch key and never share one mutable build directory between concurrent agents.

```sh
swift test \
  --package-path app \
  --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/docs-external-build-storage-cleanup" \
  --jobs 1

xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/docs-external-build-storage-cleanup" \
  build CODE_SIGNING_ALLOWED=NO
```

For this branch, store result bundles and sanitized logs under `ToonEdgeBuilds/Results/2026-10-01/docs-external-build-storage-cleanup/`. For later branches, create the same two-level date and filesystem-safe branch-name layout. If the verified volume is unavailable, use a unique `/private/tmp/toonedge-...` path and report the fallback. Never create `/Volumes/Seagate 2TB` when the drive is absent, and never place source worktrees or simulator data on the external drive.
```

- [ ] **Step 3: Mark the design implemented with measured results**

Change its status to `Implemented` only after Tasks 2–4 finish, and append the actual internal bytes reclaimed, external archive size, exclusions, and manifest path.

- [ ] **Step 4: Validate documentation consistency**

```sh
rg -n "Seagate 2TB|7C6E7CE1|scratch-path|derivedDataPath|protected|private/tmp" \
  AGENTS.md \
  docs/branching_and_release_workflow.md \
  docs/superpowers/specs/2026-10-01-external-build-storage-cleanup-design.md
git diff --check
```

Expected: all three documents agree on the drive, preflight, preferred paths, fallback, protected evidence, and safety boundaries.

- [ ] **Step 5: Commit the completed policy**

```sh
git add \
  AGENTS.md \
  docs/branching_and_release_workflow.md \
  docs/superpowers/specs/2026-10-01-external-build-storage-cleanup-design.md
git commit -m "docs: adopt external build storage workflow"
```

---

### Task 6: Validate the migrated workflow and final state

**Files:**
- No additional repository files.

**Interfaces:**
- Consumes: Tasks 1–5 migration and policy.
- Produces: completion evidence and a branch ready for user-authorized delivery.

- [ ] **Step 1: Run the complete package suite on external SwiftPM storage**

```sh
mkdir -p "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/docs-external-build-storage-cleanup"
swift test \
  --package-path app \
  --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/docs-external-build-storage-cleanup" \
  --jobs 1
```

Expected: 433 tests pass with 0 failures.

- [ ] **Step 2: Run the generic simulator build on external DerivedData**

```sh
mkdir -p "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/docs-external-build-storage-cleanup"
xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/docs-external-build-storage-cleanup" \
  build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify reclaimed space and archive integrity**

```sh
df -k /System/Volumes/Data "/Volumes/Seagate 2TB"
du -s -k "/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean"
find /private/tmp -mindepth 1 -maxdepth 1 -name 'toonedge*' -print
du -s -k /Users/geromeyabut/Developer/Toonedge
```

Expected: approximately 16 GiB more internal free space, with differences explained for exclusions and filesystem allocation.

- [ ] **Step 4: Verify protected and active work remain unchanged**

```sh
git -C /Users/geromeyabut/Developer/Toonedge status --short --untracked-files=all
shasum -a 256 \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-chapter-label-top.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/manhuatop-original-page.png \
  /Users/geromeyabut/Developer/Toonedge/docs/qa_evidence/2026-09-22/webtoon-protected-reader-cta.png
git -C /Users/geromeyabut/Developer/Toonedge/.worktrees/story-13.1-reader-continuity status --porcelain=v1 --untracked-files=all
```

Expected: the primary checkout lists only the three protected screenshots; their hashes match Task 1; Story 13.1 status matches the baseline exactly.

- [ ] **Step 5: Audit branch scope**

```sh
git diff origin/main...HEAD --check
git diff --stat origin/main...HEAD
git status --short --untracked-files=all
```

Expected: only the design, plan, `AGENTS.md`, and workflow-guide documentation differ from `origin/main`; the documentation worktree is clean after commits.

- [ ] **Step 6: Report without pushing**

Report:

- internal space before and after;
- external archive size and path;
- every migrated category and exclusion;
- package and build results;
- protected screenshot hashes;
- Story 13.1 preservation;
- shared simulator untouched;
- local commits created;
- that push, pull request, merge, remote deletion, and historical worktree deletion still require explicit authorization.
