import Foundation
import Testing
@testable import ToonEdgeAppCore

// DEF-049: a year in a non-chapter title must not become a chapter number.

@Test func titleOnlyLabelIgnoresLeadingYearToken() {
    let label = ChapterNumericLabelExtractor.label(
        chapterNumber: nil,
        chapterLabel: "",
        title: "Best Academy Fantasy Manhwa 2026: 6 Series Reviewed"
    )

    #expect(label == nil)
}

@Test func titleOnlyLabelIgnoresYearInDatedBlogPath() {
    let label = ChapterNumericLabelExtractor.label(
        chapterNumber: nil,
        chapterLabel: "",
        title: "/blog/2025/11/best-manhwa"
    )

    #expect(label == nil)
}

@Test func explicitChapterKeywordKeepsYearSizedNumber() {
    let label = ChapterNumericLabelExtractor.label(
        chapterNumber: nil,
        chapterLabel: "",
        title: "Martial Peak Chapter 2026"
    )

    #expect(label == "2026")
}

@Test func explicitChapterLabelKeepsYearSizedNumber() {
    let label = ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "2026", title: "")

    #expect(label == "2026")
}

@Test func bareNonYearTitleNumberIsStillInferred() {
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "", title: "Solo Leveling - 120") == "120")
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "", title: "Series 3000") == "3000")
    #expect(ChapterNumericLabelExtractor.label(chapterNumber: nil, chapterLabel: "", title: "Series 1899") == "1899")
}

@Test func integerChapterNumberIgnoresYearInTitleFallback() {
    let number = ChapterURLInference.integerChapterNumber(
        chapterNumber: nil,
        chapterLabel: "",
        title: "Best Academy Fantasy Manhwa 2026"
    )

    #expect(number == nil)
}

@MainActor
@Test func readerCanonicalLabelForArticleTitleIsNotAYear() throws {
    let sourceURL = try #require(URL(string: "https://blog.example.test/blog/best-academy-fantasy-manhwa"))
    let session = MockReaderSession(
        seriesTitle: "blog.example.test",
        seriesURL: sourceURL,
        chapterTitle: "Best Academy Fantasy Manhwa 2026: 6 Series Reviewed",
        sourceURL: sourceURL,
        imageURLs: [try #require(URL(string: "https://blog.example.test/images/1.webp"))]
    )
    let viewModel = ReaderViewModel(session: session)

    #expect(viewModel.canonicalChapterLabel != "2026")
    #expect(viewModel.currentChapterDisplayLabel != "Chapter 2026")
}
