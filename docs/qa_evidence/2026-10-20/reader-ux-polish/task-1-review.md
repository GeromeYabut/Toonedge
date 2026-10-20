# Task 1 independent review

Verdict: changes required — one P2 finding.

## P2 — Resolve recent chapter aliases to the saved chapter before returning the target

`SwiftDataLibraryRepository.swift:275–282` returns `recent.chapterID` even when the recent source URL belongs to an existing saved chapter. Real Reader records use `session.id` (`ReaderViewModel.swift:339–341`, `ReaderProgressGate.swift:88`); the saved-session constructor at repository lines 315–327 does not supply an ID, so `MockReaderSession` creates a fresh UUID. Thus a normal read of a saved chapter can leave a recent chapter UUID different from its StoredChapter ID.

`reconcileSavedSeriesProgress(with:)` already finds that saved chapter by source URL and sets the saved series timestamp to the recent timestamp. The new `>=` comparison selects the recent UUID on this tie. `readerSession(forChapterID:)` then misses the saved record and takes the recent reconstruction at lines 331–343, dropping previous/next chapters and replacing saved status/synopsis with defaults. With no recent images it takes Browser recovery despite an available saved retained session. This regresses retained-session priority and chapter navigation for saved titles.

Resolve the selected recent source URL to the corresponding saved chapter identity before returning its target, preserving newer recent-only chapters as fallback. Add a regression using distinct recent/session and StoredChapter IDs with the same source URL; assert saved target identity, adjacency and metadata, including a recent record with no images while the saved chapter retains images. The added metadata test uses the same chapter UUID for both records and therefore cannot expose this production path.

## Scope and behavior assessment

The diff stays within the approved repository read-query, Home routing and test scope. No schema, storage-writing method, autosave or progress-gate changes appear in the reviewed diff. Recent-only target selection uses the same summary identity mapping as Home and validates HTTP(S) fallback URLs. Saved-first session construction preserves metadata when its supplied chapter UUID actually resolves; the alias case above defeats that intent.

Home adds visible loading and retry for a nil target, serializes taps, checks cancellation/request identity/router origin after both awaits, and cancels on disappearance, scene inactivity and router changes. Static inspection found no additional concrete lifecycle bug. There is no timeout, and these SwiftUI behaviors have no executed lifecycle/UI coverage in this focused receipt; simulator verification remains necessary. The tests cover retained recent images and URL fallback but do not exercise the asynchronous Home states or prove all persistence writes absent at runtime. Existing snapshot reconciliation writes are unchanged.

## Evidence and limits

Reviewed approved spec, task-1 brief, corrected proposal report, exact task-1-review.diff, complete affected repository/Home code and related model/Reader identity paths. Base supplied by controller: `af452bbdf0b23545a46ff7ab6b9a0b5d22e1786a`.

Inspected controller GREEN receipt: exit 0, four test functions passed (recent-only function has two argument cases). Filter: `task1ContinueReading|swiftDataRepositoryReconcilesRecentReadingWithSavedChapterContinueTarget|swiftDataRepositorySavesProgressAndRestoresContinueReadingTarget`. Independently hashed its 2,046-byte log: `8f4d47794d9d13df126209d5547326eedda484a34e0cf5002b02842d341d4ef8`, matching receipt. Controller reported behavioral RED for both recent-only cases and original saved-metadata pass. No tests/builds/simulators rerun by reviewer. No source/index/ref/GitHub mutations performed; only this review report was written.
