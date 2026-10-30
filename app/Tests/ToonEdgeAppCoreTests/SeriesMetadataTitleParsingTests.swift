import Foundation
import Testing
@testable import ToonEdgeAppCore

// DEF-048: series titles must survive apostrophes, entities and site-name suffixes.

private let seriesURL = URL(string: "https://asurascans.com/comics/a-villains-will-to-survive-3ebcc5a9")!

private func parsedTitle(_ head: String, baseURL: URL = seriesURL) -> String? {
    HTMLSeriesMetadataParser.parse(html: "<html><head>\(head)</head></html>", baseURL: baseURL)?.title
}

@Test func seriesTitleKeepsApostropheInDoubleQuotedContent() {
    let title = parsedTitle("""
    <meta property="og:site_name" content="Asura Scans">
    <meta property="og:title" content="A Villain's Will to Survive | Asura Scans">
    """)

    #expect(title == "A Villain's Will to Survive")
}

@Test func seriesTitleKeepsDoubleQuoteInSingleQuotedContent() {
    let title = parsedTitle(#"<meta property='og:title' content='The "Hero" Returns'>"#)

    #expect(title == #"The "Hero" Returns"#)
}

@Test func seriesTitleKeepsApostropheWhenContentPrecedesProperty() {
    let title = parsedTitle(#"<meta content="A Villain's Will to Survive" property="og:title">"#)

    #expect(title == "A Villain's Will to Survive")
}

@Test func seriesTitleDecodesHTMLEntities() {
    let title = parsedTitle(#"<meta property="og:title" content="The Extra&#x27;s Academy &amp; Guide &#39;Two&#39; &quot;Three&quot;">"#)

    #expect(title == #"The Extra's Academy & Guide 'Two' "Three""#)
}

@Test func seriesTitleStripsSuffixMatchingSourceHostWithoutSiteName() {
    let title = parsedTitle(#"<meta property="og:title" content="Solo Leveling – Asura Scans">"#)

    #expect(title == "Solo Leveling")
}

@Test func seriesTitlePreservesIntrinsicDashSegments() {
    let title = parsedTitle("""
    <meta property="og:site_name" content="Asura Scans">
    <meta property="og:title" content="Re:Zero – Starting Life in Another World | Asura Scans">
    """)

    #expect(title == "Re:Zero – Starting Life in Another World")
}

@Test func seriesTitleFallsBackToTwitterTitleWithApostrophe() {
    let title = parsedTitle(#"<meta name="twitter:title" content="A Villain's Will to Survive | Asura Scans">"#)

    #expect(title == "A Villain's Will to Survive")
}

@Test func seriesCoverMatchesVisibleImageWhoseAltContainsApostrophe() throws {
    let html = """
    <html>
      <head><meta property="og:title" content="A Villain's Will to Survive | Asura Scans"></head>
      <body>
        <img alt="Asura Scans" src="/logo.webp" width="120" height="40">
        <img alt="A Villain's Will to Survive" src="/uploads/villain-cover.webp" width="400" height="600">
      </body>
    </html>
    """

    let metadata = try #require(HTMLSeriesMetadataParser.parse(html: html, baseURL: seriesURL))

    #expect(metadata.coverImageURL?.absoluteString == "https://asurascans.com/uploads/villain-cover.webp")
}
