# ToonEdge External Build Storage and Conservative Cleanup Design

**Date:** 2026-10-01

**Status:** Implemented on 2026-10-02

## Goal

Reclaim approximately 16 GiB from the Mac's nearly full internal SSD without losing source code, test evidence, or unrelated user data. Preserve the reclaimed data on the connected Seagate volume and make external build storage the documented default for future ToonEdge agents.

## Current Evidence

- The internal APFS container had 4,781,292 KiB free before migration and has 17,643,664 KiB free after migration.
- The external volume is mounted at `/Volumes/Seagate 2TB`, uses Journaled HFS+, and has approximately 1.58 TB free.
- The current connection is limited to USB 2.0 speed. This is adequate for archival storage but slower than the internal SSD for compilation.
- The write preflight passed after Full Disk Access was enabled for the app. The external volume has 1.42 TiB free after the migration.
- 164 verified ToonEdge temporary artifacts were copied to the archive and removed locally. Ten mismatched paths and thirteen result bundles with image attachments were retained locally; two transient agent report files disappeared independently and remained excluded.
- Twelve clean, inactive historical worktree `.build` directories were archived and removed locally. The active DEF-020 worktree, primary checkout, and Story 13.1 worktree remained excluded.
- Ten Xcode DerivedData children, including Chep and shared caches, were archive-copied and removed locally. The internal DerivedData parent is now empty.
- The three protected screenshots in the primary ToonEdge checkout must remain untracked and byte-identical. They must not be copied to external build storage.

## Chosen Approach

Use a preserve-first migration rather than symlinks or immediate deletion:

1. Verify the exact mounted volume, available space, filesystem, and process-level write access.
2. Confirm no active build or test process is using a candidate path.
3. Copy each candidate into a new dated archive on the external volume.
4. Verify each copied tree by file count, byte count, and a no-difference comparison before removing its internal source.
5. Remove only explicit, validated source paths after successful verification.
6. Measure reclaimed internal space and retained external size.

Alternatives rejected:

- Symlinking existing build directories to the external drive would make builds fail when the drive is disconnected and would couple every worktree to a slow removable volume.
- Deleting all rebuildable data immediately would reclaim space faster but would not honor the request to move as much as practical.
- Moving repositories or simulator devices would add performance, reliability, and state-management risks outside the conservative scope.

## External Directory Layout

The drive root is never assumed to exist merely because the path string is valid. Agents must verify the mounted volume before creating directories.

```text
/Volumes/Seagate 2TB/ToonEdgeBuilds/
├── Active/
│   ├── DerivedData/<branch-key>/
│   └── SwiftPM/<branch-key>/
├── Results/<YYYY-MM-DD>/<branch-key>/
└── Archive/2026-10-01-conservative-clean/
    ├── private-tmp/
    ├── worktree-builds/
    ├── xcode-derived-data/
    └── manifests/
```

`branch-key` is a filesystem-safe form of the current branch name. Source worktrees remain on the internal SSD.

## Migration Scope

### 1. ToonEdge temporary artifacts

Move explicit top-level entries matching `/private/tmp/toonedge*` into the dated archive. These include DerivedData directories, result bundles, sanitized logs, and repeated test attempts. Before migration, list the exact paths and confirm no active process holds them open.

Potential recovery: approximately 10.63 GiB.

### 2. Inactive worktree SwiftPM output

Move only `app/.build` directories from clean, inactive historical worktrees. Exclude:

- the primary `main` checkout;
- `feature/story-13.1-reader-continuity`, because it contains uncommitted work;
- any worktree used by a running process or newly found to be dirty.

The worktree source, Git metadata, and branch remain in place. SwiftPM can rebuild the moved data if the worktree is used again.

Potential recovery: approximately 2.5 GiB after exclusions.

### 3. Existing Xcode DerivedData

Move the current contents of `~/Library/Developer/Xcode/DerivedData` into the dated archive while Xcode and `xcodebuild` are inactive. Recreate an empty internal DerivedData directory only if Xcode requires it. Do not move `iOS DeviceSupport`, simulator runtimes, or simulator devices.

Potential recovery: approximately 3.07 GiB.

Observed total recovery: 12,862,372 KiB of internal free space. The lower-than-archive delta reflects filesystem allocation, retained temporary artifacts, and externally archived copies with filesystem metadata.

## Copy and Verification Rules

- Create a manifest containing every source and destination path before copying.
- Use a metadata-preserving copy suitable for APFS-to-HFS+ migration.
- Never overwrite an existing archive path. Abort on collision.
- For every tree, record source and destination file counts and allocated/logical byte counts.
- Run a read-only comparison after copying. Use a symlink-preserving `rsync -ain --delete` comparison for trees containing recursive package links; a mismatch blocks source removal.
- Delete only the exact source that passed verification. Never delete a parent directory, unresolved variable, wildcard expansion, worktree root, repository root, home directory, or volume root.
- If copying is interrupted, retain both source and partial destination, mark the destination incomplete, and resume or restart without deletion.
- After cleanup, record internal free space, external archive size, and the manifest path.

## Future-Agent Storage Policy

Update `AGENTS.md` and `docs/branching_and_release_workflow.md` with these rules:

- Prefer `/Volumes/Seagate 2TB/ToonEdgeBuilds` for build outputs only when the exact volume is mounted and writable.
- Do not create `/Volumes/Seagate 2TB` as an ordinary directory when the drive is absent. Fail the preflight instead.
- Use external paths for:
  - Xcode `-derivedDataPath`;
  - SwiftPM `--scratch-path`;
  - local `.xcresult` bundles;
  - sanitized logs and reviewed safe screenshots.
- Keep repositories, active worktrees, simulator runtimes, and simulator devices on the internal disk.
- Quote every external path because the volume name contains a space.
- Use a branch-specific subdirectory to prevent concurrent agents from sharing mutable build state.
- If the drive is unavailable, fall back to a unique `/private/tmp/toonedge-...` path, report the fallback, and clean or archive it after verification.
- Never move, copy, stage, or modify the three protected local screenshots.
- Review result-bundle attachments before long-term retention. Do not retain copyrighted page artwork, credentials, cookies, session secrets, or sensitive URLs.
- Never reformat, repartition, eject, rename, or broadly clean the external drive without explicit user authorization.

Example commands:

```sh
swift test \
  --package-path app \
  --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/<branch-key>" \
  --jobs 1

xcodebuild \
  -project app/ToonEdge.xcodeproj \
  -scheme ToonEdge \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/<branch-key>" \
  build CODE_SIGNING_ALLOWED=NO
```

## Safety Boundaries

- Do not touch shared iPhone 16 Pro simulator `04F65B71-EEB9-4085-BFBD-8B7406E480A2`.
- Do not erase the dedicated simulators as part of this cleanup.
- Do not modify or remove Story 13.1 uncommitted work.
- Do not remove application support, Codex sessions, personal downloads, or unrelated caches in this pass.
- Do not change application source, product behavior, schemas, fixtures, or tests.
- Do not push, merge, or change GitHub settings without separate explicit authorization.

## Validation and Acceptance Criteria

The cleanup is complete only when:

- the external write preflight succeeds;
- the dated archive and manifest exist on the verified Seagate volume;
- every removed source has a verified external copy;
- approximately 16 GiB is reclaimed, or the actual lower total is explained path by path;
- the Story 13.1 worktree remains byte-for-byte untouched by the cleanup;
- the protected screenshots remain untracked and match their baseline SHA-256 hashes;
- the primary checkout remains on clean `main` apart from the protected screenshots;
- the shared simulator remains untouched;
- future-agent instructions contain the external-path preflight, preferred paths, fallback, isolation, sanitization, and safety rules.

## Implementation Record

- Preflight confirmed the expected volume UUID, Journaled HFS+ filesystem, writable status, and a successful visible-directory create/list/remove probe.
- Archive root: `/Volumes/Seagate 2TB/ToonEdgeBuilds/Archive/2026-10-01-conservative-clean`.
- Archive size: 17,355,716 KiB: `private-tmp` 11,644,960 KiB, `worktree-builds` 2,468,952 KiB, and `xcode-derived-data` 3,241,620 KiB.
- The temporary-artifact archive was attachment-scanned before removal: 809 attachment files totaling 21,167 KiB, with JSON, XML, text, empty, or opaque diagnostic types and no image MIME types. Result bundles with attachment records were excluded before copying.
- The DerivedData archive was attachment-scanned before removal: 372 attachment files totaling 15,049 KiB, with JSON, XML, text, empty, or opaque diagnostic types and no image MIME types.
- All removed paths have corresponding manifests and verification logs under the archive `manifests/` directory. Worktree and DerivedData verification completed before their sources were removed.
- `swift test --package-path app --scratch-path "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/docs-external-build-storage-cleanup" --jobs 1` passed 433 tests with 0 failures.
- The required Debug build passed using external DerivedData and the dedicated iPhone 16e destination: `xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=18.6' -derivedDataPath "/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/docs-external-build-storage-cleanup" build CODE_SIGNING_ALLOWED=NO` produced `** BUILD SUCCEEDED **`.
- Protected screenshot SHA-256 values and the primary-checkout status were captured before migration and must be revalidated after final build gates.
