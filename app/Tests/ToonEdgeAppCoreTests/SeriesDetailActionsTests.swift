import Testing
@testable import ToonEdgeAppCore

@Test func savedSeriesControlShowsCollectionStateAsVisibleLabel() {
    let saved = SeriesDetailLibraryControlPresentation(isSaved: true, state: .planned)

    #expect(saved.title == "Planned")
    #expect(saved.systemImage == "bookmark.fill")
    #expect(saved.accessibilityLabel == "Saved series")
    #expect(saved.accessibilityValue == "Planned")
    #expect(saved.membershipActionTitle == "Remove from Library")
    #expect(saved.membershipActionIsDestructive)
}

@Test func unsavedSeriesControlOffersSave() {
    let unsaved = SeriesDetailLibraryControlPresentation(isSaved: false, state: .reading)

    #expect(unsaved.title == "Save")
    #expect(unsaved.systemImage == "bookmark")
    #expect(unsaved.accessibilityLabel == "Save series")
    #expect(unsaved.accessibilityValue == "Not saved")
    #expect(unsaved.membershipActionTitle == "Add to Library")
    #expect(!unsaved.membershipActionIsDestructive)
}

@Test func removalConfirmationNamesSeriesAndProgressLoss() {
    let confirmation = SeriesDetailRemovalConfirmation(seriesTitle: "Moonlit Edge")

    #expect(confirmation.title == "Remove Moonlit Edge from Library?")
    #expect(confirmation.message == "Your reading progress for this series will also be removed.")
    #expect(confirmation.confirmTitle == "Remove")
}

@Test func chapterRowHidesSecondaryLabelThatRepeatsTitle() {
    #expect(ChapterRowPresentation.secondaryLabel(title: "Chapter 1", chapterLabel: "1") == nil)
    #expect(ChapterRowPresentation.secondaryLabel(title: "chapter 12.5 ", chapterLabel: "12.5") == nil)
    #expect(ChapterRowPresentation.secondaryLabel(title: "12", chapterLabel: "12") == nil)
    #expect(ChapterRowPresentation.secondaryLabel(title: "The Long Night", chapterLabel: "4") == "Chapter 4")
}
