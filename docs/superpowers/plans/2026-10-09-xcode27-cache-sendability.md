# Xcode 27 Cache Sendability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Restore cache compilation under Xcode 27 while preserving its filesystem and concurrency behavior.

**Architecture:** An internal Sendable protocol provides three filesystem operations through a private, lock-protected FileManager wrapper. The existing cache lifecycle lock continues to serialize complete file transactions across cache copies.

**Tech Stack:** Swift 6, Foundation, Swift Testing, SwiftPM, Xcode 27.

## Global Constraints

- The public cache protocols and signatures remain unchanged; the cache itself does not gain an unchecked conformance.
- Keep the existing reference-shared cache lifecycle lock.
- Do not change deterministic namespaces, filenames, atomic writes, missing-directory removal handling, data contents, or error propagation.
- No async conversion, actor migration, persistence schema change, UI change, or dependency addition is needed.
- Keep earlier stopped persistence worktrees and their evidence unchanged.
- No push, PR, or merge is included without authorization.
- Never change the active SDK to make a gate pass.

## Execution context

Approved spec: `docs/superpowers/specs/2026-10-09-xcode27-cache-sendability-design.md`, committed at `233d520c272e34b81c4b193b742e5aa05e9ed3c7` and approved by the user's “looks good!”. Work in `/Users/geromeyabut/.codex/worktrees/cache-xcode27-compatibility/Toonedge` on `fix/xcode27-cache-sendability`, rooted at verified `origin/main` `1da095aa37940802f7a27050b7430fe743db22b1`.

The already captured unchanged baseline failed at compilation with the unavailable FileManager conformance and executed no test cases. That failure is authorized to be fixed. Baseline log: `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/baseline.log`.

Build-volume verification for execution confirmed UUID `7C6E7CE1-D8D5-3041-AA58-DC000A724A29`, 1.4 TiB free, and direct probe `/Volumes/Seagate 2TB/ToonEdgeBuilds/cache-xcode27-execution-probe.De3poN`. Use the branch-specific directories in the commands below; no other agent writes those outputs. Recheck if the mount changes. Do not operate simulator `04F65B71-EEB9-4085-BFBD-8B7406E480A2` or touch any protected September 22 screenshots.

Controller relays apply_patch, test/build, and local commit commands when the managed worktree or build directory is outside sandbox write roots. Implementers prepare exact patch files in `/private/tmp` with apply_patch, then request the relay; do not silently skip failed commands. Shell relays use `set -e` when applying patches before subsequent operations, and retain pipeline exit codes with `set -o pipefail`.

## Task 1: Cache wrapper compatibility and regression gates

**Files:**
- Modify: `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift`
- Modify: `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`
- Create: `docs/qa_evidence/2026-10-09/xcode27-cache-sendability.md`

**Interfaces:**
- Consumes: existing `ChapterAssetCaching` and `ChapterAssetRemoving`, public `init(rootDirectory: URL) throws`, and all existing cache methods unchanged.
- Produces: internal `CacheFileOperating: Sendable`, internal final `CacheFileOperations`, and internal `init(rootDirectory: URL, fileManager: any CacheFileOperating) throws`.

- [ ] **Step 1: Add real filesystem tests before production edits.** Insert the following before the existing cache tests, reusing their `temporaryDirectory()` helper:

```swift
@Test func cacheFileOperationsCreatesNestedDirectory() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let files = CacheFileOperations()
    let nested = root.appendingPathComponent("nested/child", isDirectory: true)
    #expect(!files.fileExists(atPath: nested.path))
    try files.createDirectory(at: nested, withIntermediateDirectories: true)
    #expect(files.fileExists(atPath: nested.path))
}

@Test func cacheFileOperationsRemovesRealFile() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let files = CacheFileOperations()
    let file = root.appendingPathComponent("panel.asset")
    try Data([1, 2, 3]).write(to: file)
    #expect(files.fileExists(atPath: file.path))
    try files.removeItem(at: file)
    #expect(!files.fileExists(atPath: file.path))
}

@Test func cacheFileOperationsPropagatesCreationErrorAndReleasesLock() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let files = CacheFileOperations()
    let blocker = root.appendingPathComponent("file")
    try Data([1]).write(to: blocker)
    #expect(throws: CocoaError.self) {
        try files.createDirectory(at: blocker.appendingPathComponent("child"), withIntermediateDirectories: true)
    }
    let valid = root.appendingPathComponent("valid", isDirectory: true)
    try files.createDirectory(at: valid, withIntermediateDirectories: true)
    #expect(files.fileExists(atPath: valid.path))
}

@Test func cacheFileOperationsPropagatesRemovalErrorAndReleasesLock() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let files = CacheFileOperations()
    #expect(throws: CocoaError.self) { try files.removeItem(at: root.appendingPathComponent("missing")) }
    let valid = root.appendingPathComponent("valid", isDirectory: true)
    try files.createDirectory(at: valid, withIntermediateDirectories: true)
    #expect(files.fileExists(atPath: valid.path))
}
```

- [ ] **Step 2: Run focused RED, retaining complete output.**

```sh
set -o pipefail
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-xcode27-cache-sendability' --jobs 1 --filter cacheFileOperations 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/wrapper-red.log'
```

Expected: nonzero compile failure from the unchanged unavailable FileManager conformance and/or the not-yet-defined wrapper. No runtime assertion is expected at this compatibility RED gate. Report the actual diagnostics; do not describe this as executed failing tests.

- [ ] **Step 3: Implement the approved wrapper and adapt the existing test double.** Change the cache's private `fileManager` type and its internal initializer parameter to `any CacheFileOperating`. The public initializer constructs `CacheFileOperations()`. Replace the old subclass with:

```swift
protocol CacheFileOperating: Sendable {
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func fileExists(atPath path: String) -> Bool
    func removeItem(at url: URL) throws
}

// The owned manager never escapes or receives a delegate/configuration change.
// Every manager access is serialized; the cache separately locks whole transactions.
final class CacheFileOperations: CacheFileOperating, @unchecked Sendable {
    private let fileManager = FileManager()
    private let lock = NSLock()

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }

    func fileExists(atPath path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return fileManager.fileExists(atPath: path)
    }

    func removeItem(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        try fileManager.removeItem(at: url)
    }
}
```

In both existing cross-copy race tests, rename the pausing double to `PausingChapterDirectoryFileOperations`. Retain all semaphore coordination and assertions unchanged. Replace the old subclass definition with:

```swift
private final class PausingChapterDirectoryFileOperations: CacheFileOperating {
    let pausedDirectory: URL
    let storeEntered = DispatchSemaphore(value: 0)
    let resumeStore = DispatchSemaphore(value: 0)
    private let files = CacheFileOperations()

    init(pausedDirectory: URL) { self.pausedDirectory = pausedDirectory }

    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        if url == pausedDirectory {
            storeEntered.signal()
            guard resumeStore.wait(timeout: .now() + 5) == .success else {
                throw URLError(.timedOut)
            }
        }
        try files.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
    }

    func fileExists(atPath path: String) -> Bool { files.fileExists(atPath: path) }
    func removeItem(at url: URL) throws { try files.removeItem(at: url) }
}
```

- [ ] **Step 4: Run focused GREEN, then full SwiftPM and Simulator build gates.**

```sh
set -o pipefail
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-xcode27-cache-sendability' --jobs 1 --filter 'cacheFileOperations|chapterRemovalWaitsForInFlightStoreAcrossCacheCopies|cachedAssetLookupWaitsForInFlightStoreAcrossCacheCopies' 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/wrapper-green.log'
```

Expected: six focused cases pass, with no unavailable FileManager conformance warnings or errors. If new unrelated toolchain failures appear, report them before expanding scope.

```sh
set -o pipefail
swift test --package-path app --scratch-path '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/SwiftPM/fix-xcode27-cache-sendability' --jobs 1 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/package-green.log'
```

Expected: all package tests pass, including four new cases. Record actual count and warnings.

```sh
set -eo pipefail
xcodebuild -project app/ToonEdge.xcodeproj -scheme ToonEdge -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath '/Volumes/Seagate 2TB/ToonEdgeBuilds/Active/DerivedData/fix-xcode27-cache-sendability' build CODE_SIGNING_ALLOWED=NO 2>&1 | tee '/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/simulator-build.log'
git diff --check
```

Expected: BUILD SUCCEEDED and clean diff. This is a compile gate, not simulator UI testing. Never mask a nonzero build exit with a later command's success.

- [ ] **Step 5: Record QA, self-review, and commit only this outcome.** Write the QA document using the exact executed commands, source hashes, exit codes, test counts, warning summaries, verified environment, and remaining persistence scope. State whether UI tests were run. Include evidence paths and the fresh-run dependency condition from the approved spec; do not claim persistence safety. The controller verifies the evidence before relaying the local commit:

```sh
git diff --check
git add app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift docs/qa_evidence/2026-10-09/xcode27-cache-sendability.md
git diff --cached --check
git commit -m 'fix: isolate cache FileManager for Xcode 27'
git rev-parse HEAD
git status --short --untracked-files=all
```

- [ ] **Step 6: Require task and final reviews.** A fresh task reviewer checks spec compliance and code quality from the diff, brief, and evidence report. A separate final reviewer checks the whole branch. Reviewers do not repeat passed test suites. Critical or Important findings receive one focused fix wave and covering-test evidence before re-review. Record Minor findings in the progress ledger. Do not start fresh persistence diagnostics while a compatibility gate or review remains unresolved.
