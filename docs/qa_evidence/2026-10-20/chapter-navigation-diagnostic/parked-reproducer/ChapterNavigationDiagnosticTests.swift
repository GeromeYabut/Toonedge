import Foundation
import SwiftData
import Testing
@testable import ToonEdgeAppCore

// Diagnostic only: authored chapter metadata and in-memory storage; no network/artwork.
enum ChapterNavigationDiagnosticCase: String, CaseIterable {
    case recentOnly, savedWithEmptyImages, savedWithImages
}

@MainActor
@Test(arguments: ChapterNavigationDiagnosticCase.allCases)
func chapterNavigationDiagnosticResumePreservesUsableDirections(_ scenario: ChapterNavigationDiagnosticCase) async throws {
    let schema = Schema([StoredSeries.self, StoredChapter.self, StoredProgress.self,
                         StoredSearchHistory.self, StoredRecentReading.self])
    let container = try ModelContainer(for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    let repository = SwiftDataLibraryRepository(modelContext: container.mainContext,
        modelContainer: container, usesModelContextIO: false)
    let seriesID = UUID(), chapterID = UUID()
    let seriesURL = URL(string: "https://owned.toonedge.test/comics/navigation-fixture")!
    let sourceURL = seriesURL.appendingPathComponent("chapter/199")
    let previousURL = seriesURL.appendingPathComponent("chapter/198")
    let nextURL = seriesURL.appendingPathComponent("chapter/200")
    let images = [URL(string: "https://images.owned.toonedge.test/generated-page.jpg")!]
    if scenario != .recentOnly {
        try await repository.addToLibrary(LibrarySeriesInput(
            id: seriesID, title: "Owned Navigation Fixture", canonicalURL: seriesURL,
            sourceDomain: "owned.toonedge.test", coverImageURL: nil, status: "Ongoing",
            synopsis: "Authored diagnostic fixture.", latestKnownChapterLabel: "199",
            libraryState: nil, chapters: [
                LibraryChapterInput(id: chapterID, title: "Owned Chapter 199",
                    chapterLabel: "199", chapterNumber: 199, sourceURL: sourceURL,
                    previousChapterURL: previousURL, nextChapterURL: nextURL,
                    imageURLs: scenario == .savedWithImages ? images : [], publishedAt: nil)
            ]), context: .reader)
    }
    try await repository.recordRecentReading(RecentReadingInput(
        seriesID: seriesID, chapterID: chapterID, seriesTitle: "Owned Navigation Fixture",
        seriesURL: seriesURL, sourceDomain: "owned.toonedge.test",
        chapterTitle: "Owned Chapter 199", chapterLabel: "199", sourceURL: sourceURL,
        imageURLs: images, progress: ReaderProgress(currentImageIndex: 0, totalImageCount: 1),
        readAt: Date(timeIntervalSince1970: 1_900_000_000)))
    let target = try #require(await repository.continueReadingTarget(for: seriesID))
    let session = try #require(await repository.readerSession(forChapterID: target.chapterID))
    let model = ReaderViewModel(session: session)
    let layout = ReaderChromeLayout.actions(launchOrigin: .homeContinueReading,
        isLibraryAvailable: true, isSavedToLibrary: scenario != .recentOnly,
        canNavigatePrevious: model.canNavigatePrevious, canNavigateNext: model.canNavigateNext)
    print("NAV_DIAGNOSTIC case=\(scenario.rawValue) retainedImages=\(session.imageURLs.count) previous=\(session.previousChapter != nil) next=\(session.nextChapter != nil) previousEnabled=\(layout.isEnabled(.previousChapter)) nextEnabled=\(layout.isEnabled(.nextChapter))")
    #expect(session.imageURLs == images)
    #expect(layout.isEnabled(.previousChapter), "Numeric chapter 199 should expose previous navigation")
    #expect(layout.isEnabled(.nextChapter), "Numeric chapter 199 should expose next navigation")
}
