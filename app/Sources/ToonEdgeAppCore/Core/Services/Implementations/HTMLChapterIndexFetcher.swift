import Foundation

public struct HTMLChapterIndexFetcher: SeriesChapterIndexFetching {
    private let httpClient: any HTTPDataLoading
    private let now: @Sendable () -> Date

    public init(
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.now = now
    }

    public func chapterIndexSnapshot(for series: LibrarySeriesSummary) async throws -> ChapterIndexSnapshot? {
        guard let url = series.canonicalURL,
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        let response = try await httpClient.data(from: url)
        guard (200..<300).contains(response.statusCode) else {
            return nil
        }

        let html = String(decoding: response.data, as: UTF8.self)
        let snapshot = HTMLChapterIndexParser.parse(
            html: html,
            baseURL: url,
            seriesID: series.id,
            checkedAt: now()
        )
        return snapshot.entries.isEmpty ? nil : snapshot
    }
}

public enum HTMLChapterIndexParser {
    public static func parse(
        html: String,
        baseURL: URL,
        seriesID: UUID,
        checkedAt: Date = Date()
    ) -> ChapterIndexSnapshot {
        let entriesByURL = Dictionary(
            anchors(in: html).compactMap { anchor -> (String, ChapterIndexEntry)? in
                guard let sourceURL = URL(string: anchor.href, relativeTo: baseURL)?.absoluteURL,
                      let number = chapterNumber(in: anchor.searchText) else {
                    return nil
                }

                let label = normalizedChapterLabel(from: number)
                let title = anchor.text.isEmpty ? "Chapter \(label)" : anchor.text
                return (
                    sourceURL.absoluteString,
                    ChapterIndexEntry(
                        title: title,
                        chapterLabel: label,
                        chapterNumber: number,
                        sourceURL: sourceURL,
                        checkedAt: checkedAt
                    )
                )
            },
            uniquingKeysWith: { existing, _ in existing }
        )

        let entries = entriesByURL.values.sorted {
            switch ($0.chapterNumber, $1.chapterNumber) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            default:
                return $0.sourceURL.absoluteString < $1.sourceURL.absoluteString
            }
        }

        return ChapterIndexSnapshot(seriesID: seriesID, entries: entries, checkedAt: checkedAt)
    }

    private static func anchors(in html: String) -> [Anchor] {
        let pattern = #"<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let hrefRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            return Anchor(
                href: String(html[hrefRange]),
                text: stripTags(String(html[textRange]))
            )
        }
    }

    private static func chapterNumber(in text: String) -> Double? {
        let pattern = #"\b(?:chapter|chap|ch)\.?\s*([0-9]+(?:[.-][0-9]+)?)\b|/chapter[-/]([0-9]+(?:[.-][0-9]+)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        for index in 1..<match.numberOfRanges {
            guard let tokenRange = Range(match.range(at: index), in: text) else {
                continue
            }
            return Double(String(text[tokenRange]).replacingOccurrences(of: "-", with: "."))
        }

        return nil
    }

    private static func normalizedChapterLabel(from number: Double) -> String {
        if number == number.rounded(.towardZero) {
            return "\(Int(number))"
        }
        return String(number)
    }

    private static func stripTags(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Anchor {
        var href: String
        var text: String

        var searchText: String {
            "\(text) \(href)"
        }
    }
}
