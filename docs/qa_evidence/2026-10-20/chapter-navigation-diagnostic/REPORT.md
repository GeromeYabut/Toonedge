# Disabled adjacent chapter controls — Mac diagnosis

Status: reproduced on the Mac against installed source HEAD `2683bfce87b722410f50b4d673c809147f7030a9` (branch HEAD `e9551dcbbc74422b6ad771d6b8d776d91ac16f3f` adds QA only). No production fix, phone connection, device action, push or merge performed. Persistence investigation remains parked.

## Confirmed cause

Home Continue Reading calls `continueReadingTarget`, then `readerSession(forChapterID:)`. The newly added recent-image reconstruction at SwiftDataLibraryRepository.swift:334 builds a Reader session without `previousChapter` or `nextChapter`; both default to nil. It does not reuse the existing neighbor inference or saved neighbor metadata.

Two entry paths reach it:
- Recent-only reading, where no StoredChapter/StoredSeries pair exists.
- Saved chapter with an empty retained chapter-image list, even when that chapter already has explicit adjacent links. This branch returns before `adjacentChapters` is called.

ReaderViewModel.swift:84–89 exposes navigation only when each session target is non-nil. ReaderView.swift:440/462 uses that availability to disable the buttons. Both unavailable targets therefore produce exactly the grey Previous/Next symptom while chapter images still render.

StoredRecentReading retains images and chapter identity but has no adjacent-link fields. This diagnosis does not require a schema change: the saved-empty case already has neighbor metadata, and recognized numeric source URLs can use existing session-construction inference. Unknown/non-numeric routes must retain a safe fallback rather than simply enabling buttons with invented destinations.

The screenshot alone cannot establish the phone's entry path or actual session fields. A pending adjacent load can also temporarily disable both controls, but this test reproduces the no-target cause from idle. User confirmation of Home/Library resume versus direct Browser entry remains useful. No live source page or phone database was inspected.

## Executed Mac reproduction

All authored metadata uses owned.toonedge.test, chapter 199 and an inert image URL. SwiftData is in memory; no artwork or network fetch is used. The real repository, real ReaderViewModel and real ReaderChromeLayout are exercised.

| Scenario | Images restored | Previous/Next targets | Controls enabled |
| --- | --- | --- | --- |
| Recent only | yes | nil / nil | false / false |
| Saved, chapter images empty, recent images present | yes | nil / nil despite saved explicit links | false / false |
| Saved, chapter images present | yes | chapter 198 / chapter 200 | true / true |

`mac-resume-navigation-v2`: compiled and executed one parameterized test with three cases; two cases failed the intended enabled-control expectations (four issues), saved-complete control produced no issue. Exit 1 is expected diagnostic RED, not a passing suite.

`detector-navigation-control`: two existing tests passed, exit 0: explicit detected links and numeric URL inference. This establishes an available working construction path, not live-site navigation or guaranteed existence of the adjacent chapters.

The first diagnostic attempt failed compilation because its fixture omitted required `publishedAt`; it is retained as a harness error, not behavioral RED. Version 2 corrected only that initializer.

## Recommended bounded correction

Repair read-only resumed-session assembly: preserve saved chapter metadata/adjacent links when recent images supply the payload, and use the established chapter-target resolution for supported recent-only identities. Test both directions, first-chapter/unknown-route safety, then exercise actual next/previous transition in an owned simulator fixture. Do not mask the problem by removing button disabling. No autosave/schema/progress-write work is needed for the reproduced paths.

No fix was applied in this diagnostic request. The intentionally failing reproducer is retained in this evidence directory outside the active app test-discovery path, so it does not alter the previously delivered package. Complete commands, exits and hashes remain in adjacent receipts/logs. Prior evidence/checkouts and protected screenshots were untouched; the user photo was not copied into QA.
