import Testing
@testable import ToonEdgeAppCore

@Test func readerZoomFeedbackUsesAppliedPercentAndBaseline() {
    #expect(ReaderZoomFeedback.percentage(scale: 0.75) == "75%")
    #expect(ReaderZoomFeedback.percentage(scale: 1) == "100%")
    #expect(ReaderZoomFeedback.percentage(scale: 1.374) == "137%")
    #expect(ReaderZoomFeedback.percentage(scale: 3) == "300%")
    #expect(ReaderZoomFeedback.percentage(scale: .nan) == "100%")
    #expect(ReaderZoomFeedback.percentage(scale: .infinity) == "100%")
}
