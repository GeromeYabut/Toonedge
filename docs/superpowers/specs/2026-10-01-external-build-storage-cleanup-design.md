# ToonEdge External Build Storage and Conservative Cleanup Design

**Date:** 2026-10-01

**Status:** Approved concept; awaiting written-spec review

## Goal

Reclaim approximately 16 GiB from the Mac's nearly full internal SSD without losing source code, test evidence, or unrelated user data. Preserve the reclaimed data on the connected Seagate volume and make external build storage the documented default for future ToonEdge agents.

## Current Evidence

- The internal APFS container has approximately 3.7 GB free and is 98.5% used.
- The external volume is mounted at `/Volumes/Seagate 2TB`, uses Journaled HFS+, and has approximately 1.58 TB free.
- The current connection is limited to USB 2.0 speed. This is adequate for archival storage but slower than the internal SSD for compilation.
- macOS currently denies this Codex process write access to the removable volume with `Operation not permitted`. No migration may begin until a write preflight succeeds.
- ToonEdge-named temporary artifacts under `/private/tmp` consume approximately 10.63 GiB.
- SwiftPM `.build` directories in clean historical ToonEdge worktrees consume approximately 2.76 GiB in total.
- The current Story 13.1 worktree has two uncommitted entries and is excluded from cleanup.
- Xcode DerivedData consumes approximately 3.07 GiB. It is predominantly Chep and shared module data rather than ToonEdge data, but it is rebuildable and may be preserved externally as part of this user-authorized Mac cleanup.
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

Expected total recovery: approximately 16 GiB, subject to normal filesystem allocation differences.

## Copy and Verification Rules

- Create a manifest containing every source and destination path before copying.
- Use a metadata-preserving copy suitable for APFS-to-HFS+ migration.
- Never overwrite an existing archive path. Abort on collision.
- For every tree, record source and destination file counts and allocated/logical byte counts.
- Run a read-only recursive comparison after copying. A mismatch blocks source removal.
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

## Known Limitation and Required User Action

The current Codex process cannot write to `/Volumes/Seagate 2TB` because macOS removable-volume privacy controls deny access. Before implementation, the user must grant the Codex application removable-volume access in macOS Privacy & Security settings, or otherwise provide an external directory that the process can write. The migration must remain blocked until a direct directory-creation preflight succeeds.
