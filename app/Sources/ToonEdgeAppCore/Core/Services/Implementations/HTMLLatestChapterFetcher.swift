import Foundation

public struct URLSessionHTTPDataLoader: HTTPDataLoading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL) async throws -> HTTPDataResponse {
        let (data, response) = try await session.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPDataResponse(data: data, statusCode: statusCode)
    }

    public func data(for request: URLRequest) async throws -> HTTPDataResponse {
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPDataResponse(data: data, statusCode: statusCode)
    }
}

public struct HTMLLatestChapterFetcher: SeriesLatestChapterFetching {
    private let httpClient: any HTTPDataLoading
    private let now: @Sendable () -> Date
    private let diagnosticsLogger: (any UpdateCacheDiagnosticsLogging)?

    public init(
        httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader(),
        now: @escaping @Sendable () -> Date = Date.init,
        diagnosticsLogger: (any UpdateCacheDiagnosticsLogging)? = nil
    ) {
        self.httpClient = httpClient
        self.now = now
        self.diagnosticsLogger = diagnosticsLogger
    }

    public func latestChapterSnapshot(for series: LibrarySeriesSummary) async throws -> SeriesLatestChapterSnapshot? {
        guard let url = series.canonicalURL,
              ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        do {
            let response = try await httpClient.data(from: url)
            guard (200..<300).contains(response.statusCode) else {
                return nil
            }

            let html = String(decoding: response.data, as: UTF8.self)
            let snapshot = HTMLLatestChapterParser.parse(
                html: html,
                baseURL: url,
                seriesID: series.id,
                checkedAt: now()
            )
            await diagnosticsLogger?.log(
                .latestChapterParseCompleted(
                    host: url.host() ?? "unknown-host",
                    parser: "generic-html-anchor",
                    found: snapshot != nil
                )
            )
            return snapshot
        } catch {
            return nil
        }
    }
}

public enum HTMLLatestChapterParser {
    public static func parse(
        html: String,
        baseURL: URL,
        seriesID: UUID,
        checkedAt: Date = Date()
    ) -> SeriesLatestChapterSnapshot? {
        anchors(in: html)
            .compactMap { anchor -> Candidate? in
                guard let number = chapterNumber(in: anchor.searchText) else {
                    return nil
                }

                return Candidate(
                    label: normalizedChapterLabel(from: number),
                    number: number,
                    sourceURL: URL(string: anchor.href, relativeTo: baseURL)?.absoluteURL
                )
            }
            .max { lhs, rhs in lhs.number < rhs.number }
            .map {
                SeriesLatestChapterSnapshot(
                    seriesID: seriesID,
                    latestChapterLabel: $0.label,
                    sourceURL: $0.sourceURL,
                    checkedAt: checkedAt
                )
            }
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

            let href = String(html[hrefRange])
            let text = stripTags(String(html[textRange]))
            return Anchor(href: href, text: text)
        }
    }

    private static func chapterNumber(in text: String) -> Double? {
        let pattern = #"\b(?:chapter|chap|ch)\.?\s*([0-9]+(?:[.-][0-9]+)?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let rawNumber = String(text[numberRange]).replacingOccurrences(of: "-", with: ".")
        return Double(rawNumber)
    }

    private static func normalizedChapterLabel(from number: Double) -> String {
        if number == number.rounded() {
            return "\(Int(number))"
        }

        return String(number)
    }

    private static func stripTags(_ value: String) -> String {
        value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    }

    private struct Anchor {
        var href: String
        var text: String

        var searchText: String {
            "\(text) \(href)"
        }
    }

    private struct Candidate {
        var label: String
        var number: Double
        var sourceURL: URL?
    }
}
