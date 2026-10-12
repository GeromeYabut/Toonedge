# Xcode 27 Cache Sendability Design

The cache must compile under Xcode 27 without changing storage behavior or weakening its concurrency guarantees. Use an internal, lock-protected file-operations wrapper instead of declaring a `FileManager` subclass `Sendable`. The user approved the approach and subsequently approved this written specification with “looks good!”.

## Scope and dependencies

This is a compatibility prerequisite for the Story 13.4 persistence investigation, not implementation of the proposed persistence writer. It depends on the existing file-backed cache and its store, lookup, and removal regression tests. The canonical architecture keeps asset storage in services, separate from SwiftUI and SwiftData metadata; this change preserves that boundary.

The isolated branch is `fix/xcode27-cache-sendability`, based on verified `origin/main` at `1da095aa37940802f7a27050b7430fe743db22b1`. Keep earlier stopped persistence worktrees and their evidence unchanged.

## Confirmed blocker

The unchanged baseline fails to compile with Xcode 27.0 build 27A266a and Swift 6.4. The cache stores and accepts `FileManager & Sendable`, then supplies a subclass declaring `@unchecked Sendable`. The compiler rejects the unavailable `FileManager` conformance at the public initializer and warns about the subclass declaration. No baseline test cases execute.

The reproduction log is `/Volumes/Seagate 2TB/ToonEdgeBuilds/Results/2026-10-09/fix-xcode27-cache-sendability/baseline.log`. This is a toolchain compatibility failure, not evidence of cache corruption or a persistence result.

## Selected approach

Define an internal `CacheFileOperating: Sendable` protocol containing only the operations used by the cache:

```swift
func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
func fileExists(atPath path: String) -> Bool
func removeItem(at url: URL) throws
```

An internal final `CacheFileOperations` class implements that protocol through composition. It owns a private, newly created `FileManager` and a private `NSLock`. Every access to that manager acquires the wrapper lock and releases it with `defer`, including throwing operations. The manager is never exposed, injected from outside, subclassed, or configured with a delegate. The wrapper alone declares `@unchecked Sendable`, with a comment documenting these invariants.

`FileBackedChapterAssetCache` stores `any CacheFileOperating`. Its public `init(rootDirectory:)` creates the default wrapper. Its internal injection initializer accepts the protocol so deterministic concurrency tests can supply a pausing file-operations double. The public cache protocols and signatures remain unchanged; the cache itself does not gain an unchecked conformance.

## Concurrency and storage behavior

Keep the existing reference-shared cache lifecycle lock. Value-type cache copies must continue sharing that lock across directory creation and atomic data writes, as well as lookup and removal. Per-operation wrapper locking does not replace this transaction boundary.

Lock order is cache lifecycle lock followed by wrapper lock. The wrapper never calls back into the cache or acquires its lifecycle lock. Root-directory initialization uses only the wrapper lock before the initialized cache is shared. Distinct independently initialized caches do not acquire a new cross-instance coordination guarantee.

Do not change deterministic namespaces, filenames, atomic writes, missing-directory removal handling, data contents, or error propagation. Wrapper errors pass through unchanged. No async conversion, actor migration, persistence schema change, UI change, or dependency addition is needed.

## Alternatives considered

Marking the entire cache unchecked and retaining a raw `FileManager` would reduce the diff but broaden the unchecked boundary. The selected wrapper makes ownership and serialization explicit while retaining checked cache conformance. An actor-based filesystem service would require changing synchronous cache interfaces and callers; that is unnecessary for this compatibility fix.

## Affected files

- `app/Sources/ToonEdgeAppCore/Core/Services/Implementations/FileBackedChapterAssetCache.swift`: replace the unavailable composition type and subclass with the internal protocol and wrapper, keeping these small cache-specific units together.
- `app/Tests/ToonEdgeAppCoreTests/CacheStorageTests.swift`: adapt the existing pausing double to composition and retain its real filesystem behavior, semaphore coordination, and assertions. Add focused wrapper coverage for directory creation, existence lookup, removal, and thrown filesystem errors.
- A separate QA evidence document records exact commands, results, toolchain, and remaining limitations after implementation.

## Acceptance and verification

1. Reproduce the compiler failure before production edits. Record the compile failure as the RED evidence for compatibility, not as an assertion failure from an executed test.
2. Add focused tests before implementation. Verify wrapper operations against real temporary filesystem entries and verify errors propagate. The existing cross-copy store/removal and store/lookup tests must remain intact and pass after their dependency seam is adapted.
3. Run focused cache tests, then `swift test --package-path app --jobs 1` using a branch-isolated scratch directory. Record warnings rather than hiding or weakening them.
4. Build the ToonEdge scheme for a generic iOS Simulator destination with signing disabled and branch-isolated derived data. Do not operate the protected shared simulator.
5. Require an independent task review and a broad final review before calling the fix ready. No push, PR, or merge is included without authorization.

Verify the external build volume UUID, free space, and a direct directory-creation probe before writing build outputs. If the approved volume is unavailable, use a unique `/private/tmp/toonedge-...` fallback and report it. Never change the active SDK to make a gate pass.

## Persistence investigation remains separate

Only after the compatibility gates and reviews pass may a fresh bounded persistence validation be prepared. It must retain the approved diagnostic predicates, seven-row seed controls, privacy checks, runtime budget, and stop conditions. It must not modify a stopped investigation in place or treat this compatibility fix as evidence that SwiftData identity comparison or production adoption is safe.

A fresh investigation must explicitly record the compatibility commit it consumes. If that commit has not been integrated into `main`, resolve the branch dependency against the repository's current-main worktree requirement before execution rather than silently running on an unapproved stacked branch.
