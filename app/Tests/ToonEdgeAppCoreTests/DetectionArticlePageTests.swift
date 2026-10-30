import Foundation
import Testing
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif
@testable import ToonEdgeAppCore

// DEF-049: editorial pages with a few portrait covers must never auto-open Reader Mode.
// Fixtures model the reported article's structure with authored hosts and image URLs only.

private func articlePage(
    url: String = "https://chapterreviews.example.test/blog/best-academy-fantasy-manhwa",
    title: String = "Best Academy Fantasy Manhwa 2026: 6 Series Reviewed",
    imageCount: Int = 6,
    width: Double = 460,
    height: Double = 650,
    ogType: String? = "article",
    hasArticleElement: Bool = true,
    proseCharacterCount: Int = 6_000
) throws -> DetectionPageAnalysis {
    var page = DetectionPageAnalysis(
        pageURL: try #require(URL(string: url)),
        title: title,
        documentHeight: 14_000,
        viewportWidth: 390,
        images: (1...imageCount).map { index in
            DetectionImageCandidate(
                src: "https://chapterreviews.example.test/images/posts/best-academy-fantasy-manhwa-cover-\(index).webp",
                lazySources: [], srcset: nil, width: width, height: height,
                top: Double(index) * 1_800, left: 0,
                className: nil, id: nil, alt: "Series \(index) cover art", parentSignature: "prose ARTICLE"
            )
        },
        viewportHeight: 844
    )
    page.ogType = ogType
    page.hasArticleElement = hasArticleElement
    page.proseCharacterCount = proseCharacterCount
    return page
}

@Test func reportedArticleShapeDoesNotAutoOpenAndOffersCleanModeAtMost() throws {
    let result = ProfileAwareChapterDetector().detect(page: try articlePage())

    #expect(result.readerEntryDisposition != .automatic)
    #expect(result.readerEntryDisposition == .recommended)
    #expect(result.confidence == .medium)
}

@Test func articleWithLargeCoversStillCapsAtCleanModePrompt() throws {
    let page = try articlePage(imageCount: 8, width: 900, height: 1_350)
    let result = GenericChapterDetector().detect(page: page)

    #expect(result.score >= 78)
    #expect(result.readerEntryDisposition == .recommended)
    #expect(result.diagnostics.messages.contains("articleShaped=true"))
}

@Test func articleMarkedChapterPageKeepsAutomaticEntry() throws {
    // Some WordPress manga themes mark real chapter pages og:type=article.
    let page = try articlePage(
        url: "https://reader.example.test/manga/moonlit-edge/chapter-12/",
        title: "Moonlit Edge Chapter 12",
        imageCount: 8, width: 900, height: 1_350
    )
    let result = GenericChapterDetector().detect(page: page)

    #expect(result.readerEntryDisposition == .automatic)
    #expect(!result.diagnostics.messages.contains("articleShaped=true"))
}

@Test func articleSignalsNeedSubstantialProse() throws {
    let page = try articlePage(imageCount: 8, width: 900, height: 1_350, proseCharacterCount: 200)
    let result = GenericChapterDetector().detect(page: page)

    #expect(!result.diagnostics.messages.contains("articleShaped=true"))
}

@Test func genreWordsAloneAreNotChapterEvidence() throws {
    let genre = try articlePage(url: "https://reviews.example.test/blog/best-academy-fantasy-manhwa",
        title: "Best Academy Fantasy Manhwa", ogType: nil, hasArticleElement: false, proseCharacterCount: 0)
    let neutral = try articlePage(url: "https://reviews.example.test/blog/best-academy-fantasy-series",
        title: "Best Academy Fantasy Series", ogType: nil, hasArticleElement: false, proseCharacterCount: 0)

    #expect(GenericChapterDetector().detect(page: genre).score == GenericChapterDetector().detect(page: neutral).score)
}

@Test func chapterWordInHostIsNotChapterEvidence() throws {
    let chapterHost = try articlePage(url: "https://chapterreviews.example.test/blog/best-academy-fantasy-series",
        title: "Best Academy Fantasy Series", ogType: nil, hasArticleElement: false, proseCharacterCount: 0)
    let neutralHost = try articlePage(url: "https://reviews.example.test/blog/best-academy-fantasy-series",
        title: "Best Academy Fantasy Series", ogType: nil, hasArticleElement: false, proseCharacterCount: 0)

    #expect(GenericChapterDetector().detect(page: chapterHost).score == GenericChapterDetector().detect(page: neutralHost).score)
}

@Test func legacyPayloadWithoutArticleSignalsDecodesConservatively() throws {
    let json = #"{"pageURL":"https://example.test/chapter-1","title":"Chapter 1","documentHeight":1,"viewportWidth":390,"images":[]}"#
    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: Data(json.utf8))

    #expect(page.ogType == nil)
    #expect(page.hasArticleElement == false)
    #expect(page.proseCharacterCount == 0)
}

#if canImport(JavaScriptCore)
@Test func pageAnalysisScriptReportsArticleSignalsExcludingCommentProse() throws {
    let context = try #require(JSContext())
    context.evaluateScript("""
    const style = () => ({ display: 'block', visibility: 'visible', opacity: '1' });
    const node = (tagName, attributes = {}, text = '', parent = null) => ({
      tagName, attributes, innerText: text, hidden: false, parentElement: parent,
      id: attributes.id || '', className: attributes.class || '',
      getAttribute(name) { return this.attributes[name] || null; },
      hasAttribute(name) { return Object.hasOwn(this.attributes, name); },
      getBoundingClientRect: () => ({ width: 390, height: 40, top: 0, left: 0 }),
      matches: () => false, querySelectorAll: () => []
    });
    const article = node('ARTICLE');
    const comments = node('SECTION', { id: 'comments' });
    const paragraphs = [node('P', {}, 'a'.repeat(1500), article), node('P', {}, 'b'.repeat(700), article),
      node('P', {}, 'c'.repeat(5000), comments)];
    const ogType = node('META', { property: 'og:type', content: ' Article ' });
    globalThis.window = { location: { href: 'https://reviews.example.test/blog/post' }, innerWidth: 390, innerHeight: 844,
      scrollX: 0, scrollY: 0, getComputedStyle: style };
    globalThis.URL = class { constructor() { this.protocol = 'https:'; } };
    globalThis.document = { title: 'Post', images: [], body: { innerText: '', scrollHeight: 4000 },
      documentElement: { scrollHeight: 4000, innerHTML: '' },
      querySelector: (selector) => selector === 'meta[property="og:type"]' ? ogType : null,
      querySelectorAll: (selector) => selector === 'article' ? [article] : selector === 'p' ? paragraphs : [] };
    """)
    #expect(context.exception == nil)
    let json = try #require(context.evaluateScript(PageAnalysisScript.javaScript)?.toString())
    #expect(context.exception == nil)
    let page = try JSONDecoder().decode(DetectionPageAnalysis.self, from: Data(json.utf8))

    #expect(page.ogType == "article")
    #expect(page.hasArticleElement)
    #expect(page.proseCharacterCount == 2_200)
}
#endif
