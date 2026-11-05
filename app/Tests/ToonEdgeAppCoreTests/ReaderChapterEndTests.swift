import CoreGraphics
import Foundation
import Testing
@testable import ToonEdgeAppCore

private final class PipelineToken {}

@Test func selectionReachesChapterEndOnlyWhenFinalPageBottomIsVisible() throws {
    let pipelineID = ObjectIdentifier(PipelineToken())
    let viewport: CGFloat = 800

    let finalBottomVisible = try #require(ReaderViewportPageSelector.selection(
        frames: [1: CGRect(x: 0, y: -600, width: 390, height: 700), 2: CGRect(x: 0, y: 100, width: 390, height: 700)],
        viewportHeight: viewport, pipelineID: pipelineID, lastPageIndex: 2
    ))
    let tallFinalPageStillScrolling = try #require(ReaderViewportPageSelector.selection(
        frames: [2: CGRect(x: 0, y: -100, width: 390, height: 2_000)],
        viewportHeight: viewport, pipelineID: pipelineID, lastPageIndex: 2
    ))
    let tallFinalPageBottom = try #require(ReaderViewportPageSelector.selection(
        frames: [2: CGRect(x: 0, y: -1_200, width: 390, height: 2_000)],
        viewportHeight: viewport, pipelineID: pipelineID, lastPageIndex: 2
    ))
    let middleOfChapter = try #require(ReaderViewportPageSelector.selection(
        frames: [0: CGRect(x: 0, y: -100, width: 390, height: 700), 1: CGRect(x: 0, y: 600, width: 390, height: 700)],
        viewportHeight: viewport, pipelineID: pipelineID, lastPageIndex: 2
    ))

    #expect(finalBottomVisible.reachedChapterEnd)
    #expect(!tallFinalPageStillScrolling.reachedChapterEnd)
    #expect(tallFinalPageStillScrolling.index == 2)
    #expect(tallFinalPageBottom.reachedChapterEnd)
    #expect(!middleOfChapter.reachedChapterEnd)
}

@Test func chapterEndRevealsControlsOncePerChapterAfterScrollingIntoTheEnd() {
    var policy = ReaderChapterEndPolicy()

    let results = [false, true, false, true].map { policy.shouldRevealControls(reachedChapterEnd: $0) }

    #expect(results == [false, true, false, false])
}

@Test func chapterThatOpensAtItsEndKeepsReaderImmersive() {
    var shortChapter = ReaderChapterEndPolicy()
    var resumedAtEnd = ReaderChapterEndPolicy()

    let short = [true, true].map { shortChapter.shouldRevealControls(reachedChapterEnd: $0) }
    let resumed = [true, false, true].map { resumedAtEnd.shouldRevealControls(reachedChapterEnd: $0) }

    #expect(short == [false, false])
    #expect(resumed == [false, false, true])
}

@Test func chapterEndOffersNextChapterAsPrimaryAction() {
    let next = MockChapter(title: "Chapter 13", sourceURL: URL(string: "https://example.test/series/chapter-13")!)
    let presentation = ReaderChapterEndPresentation(currentChapterLabel: "Chapter 12", nextChapter: next)

    #expect(presentation.title == "End of Chapter 12")
    #expect(presentation.primaryAction == .nextChapter)
    #expect(presentation.primaryActionTitle == "Next: Chapter 13")
    #expect(presentation.announcement == "End of Chapter 12. Next: Chapter 13 is available.")
}

@Test func chapterEndWithoutNextChapterOffersOriginalPage() {
    let presentation = ReaderChapterEndPresentation(currentChapterLabel: "Chapter 12", nextChapter: nil)

    #expect(presentation.title == "You’re caught up")
    #expect(presentation.primaryAction == .viewOriginalPage)
    #expect(presentation.primaryActionTitle == "View Original Page")
    #expect(presentation.announcement == "You’re caught up. Check the original page for newer chapters.")
}
