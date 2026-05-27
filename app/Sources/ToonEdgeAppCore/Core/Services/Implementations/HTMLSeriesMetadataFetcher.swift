import Foundation

public struct SeriesMetadataSnapshot: Equatable, Sendable {
    public var title: String?
    public var coverImageURL: URL?

    public init(title: String?, coverImageURL: URL?) {
        self.title = title
        self.coverImageURL = coverImageURL
    }
}

public protocol SeriesMetadataFetching: Sendable {
    func metadata(for seriesURL: URL) async throws -> SeriesMetadataSnapshot?
}

public struct HTMLSeriesMetadataFetcher: SeriesMetadataFetching {
    private let httpClient: any HTTPDataLoading

    public init(httpClient: any HTTPDataLoading = URLSessionHTTPDataLoader()) {
        self.httpClient = httpClient
    }

    public func metadata(for seriesURL: URL) async throws -> SeriesMetadataSnapshot? {
        guard ["http", "https"].contains(seriesURL.scheme?.lowercased()) else {
            return nil
        }

        let response = try await httpClient.data(from: seriesURL)
        guard (200..<300).contains(response.statusCode) else {
            return nil
        }

        return HTMLSeriesMetadataParser.parse(
            html: String(decoding: response.data, as: UTF8.self),
            baseURL: seriesURL
        )
    }
}

public enum HTMLSeriesMetadataParser {
    public static func parse(html: String, baseURL: URL) -> SeriesMetadataSnapshot? {
        let title = metaContent(in: html, key: "og:title")
            ?? metaContent(in: html, key: "twitter:title")
        let image = structuredPortraitCover(in: html)
            ?? visibleSeriesCoverImage(in: html, title: title)
            ?? metaContent(in: html, key: "og:image")
            ?? metaContent(in: html, key: "twitter:image")
        let coverURL = image.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }

        guard title != nil || coverURL != nil else {
            return nil
        }

        return SeriesMetadataSnapshot(title: title, coverImageURL: coverURL)
    }

    private static func metaContent(in html: String, key: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let patterns = [
            #"<meta\b[^>]*(?:property|name)\s*=\s*["']\#(escapedKey)["'][^>]*content\s*=\s*["']([^"']+)["'][^>]*>"#,
            #"<meta\b[^>]*content\s*=\s*["']([^"']+)["'][^>]*(?:property|name)\s*=\s*["']\#(escapedKey)["'][^>]*>"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(
                    in: html,
                    range: NSRange(html.startIndex..<html.endIndex, in: html)
                  ),
                  let range = Range(match.range(at: 1), in: html) else {
                continue
            }
            return String(html[range])
        }

        return nil
    }

    private static func visibleSeriesCoverImage(in html: String, title: String?) -> String? {
        imageCandidates(in: html, title: title)
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.area > rhs.area
                }
                return lhs.score > rhs.score
            }
            .first?
            .url
    }

    private static func imageCandidates(in html: String, title: String?) -> [VisibleImageCandidate] {
        let pattern = #"<img\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        return regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)).compactMap { match in
            guard let range = Range(match.range, in: html) else {
                return nil
            }

            return VisibleImageCandidate(tag: String(html[range]), title: title)
        }
    }

    private static func structuredPortraitCover(in html: String) -> String? {
        let pattern = #"<script\b[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        let imageObjects = matches.flatMap { match -> [StructuredImageObject] in
            guard let range = Range(match.range(at: 1), in: html),
                  let data = String(html[range]).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                return []
            }
            return structuredImageObjects(in: json)
        }

        return imageObjects
            .filter(\.isPortrait)
            .sorted { lhs, rhs in
                if lhs.area == rhs.area {
                    return lhs.url < rhs.url
                }
                return lhs.area > rhs.area
            }
            .first?
            .url
    }

    private static func structuredImageObjects(in value: Any) -> [StructuredImageObject] {
        switch value {
        case let object as [String: Any]:
            let ownImage = StructuredImageObject(jsonObject: object).map { [$0] } ?? []
            return ownImage + object.values.flatMap(structuredImageObjects(in:))
        case let array as [Any]:
            return array.flatMap(structuredImageObjects(in:))
        default:
            return []
        }
    }

    private struct StructuredImageObject {
        let url: String
        let width: Double
        let height: Double

        init?(jsonObject: [String: Any]) {
            guard jsonObject["@type"] as? String == "ImageObject",
                  let url = jsonObject["url"] as? String,
                  let width = Self.numericValue(from: jsonObject["width"]),
                  let height = Self.numericValue(from: jsonObject["height"]) else {
                return nil
            }

            self.url = url
            self.width = width
            self.height = height
        }

        var isPortrait: Bool {
            height > width
        }

        var area: Double {
            width * height
        }

        private static func numericValue(from value: Any?) -> Double? {
            switch value {
            case let number as NSNumber:
                return number.doubleValue
            case let string as String:
                return Double(string)
            default:
                return nil
            }
        }
    }

    private struct VisibleImageCandidate {
        let url: String
        let score: Int
        let area: Double

        init?(tag: String, title: String?) {
            let attributes = Self.attributes(in: tag)
            guard let url = Self.firstURL(in: attributes) else {
                return nil
            }

            self.url = url
            let width = Self.numericValue(from: attributes["width"])
            let height = Self.numericValue(from: attributes["height"])
            self.area = (width ?? 0) * (height ?? 0)

            let haystack = [
                attributes["alt"],
                attributes["class"],
                attributes["id"],
                url
            ]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()

            let blockedHints = ["logo", "avatar", "banner", "ad-", "/ad/", "/ads/", "ads-", "advert", "icon", "comment", "reaction"]
            if blockedHints.contains(where: { haystack.contains($0) }) {
                return nil
            }

            var score = 0
            if let title, Self.matchesTitle(text: attributes["alt"], title: title) {
                score += 12
            }

            let positiveHints = ["cover", "poster", "thumbnail", "series", "comic", "upload"]
            score += positiveHints.filter { haystack.contains($0) }.count * 3

            if let width, let height, height > width {
                score += 8
            }

            if url.hasPrefix("data:") {
                return nil
            }

            self.score = score
        }

        private static func firstURL(in attributes: [String: String]) -> String? {
            if let src = nonEmpty(attributes["src"]) {
                return src
            }
            if let dataSrc = nonEmpty(attributes["data-src"]) ?? nonEmpty(attributes["data-lazy-src"]) {
                return dataSrc
            }
            if let srcset = nonEmpty(attributes["srcset"]) ?? nonEmpty(attributes["data-srcset"]) {
                return srcset
                    .split(separator: ",")
                    .compactMap { $0.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) }
                    .first
            }
            return nil
        }

        private static func nonEmpty(_ value: String?) -> String? {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }

        private static func attributes(in tag: String) -> [String: String] {
            let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*["']([^"']*)["']"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return [:]
            }

            return regex.matches(in: tag, range: NSRange(tag.startIndex..<tag.endIndex, in: tag)).reduce(into: [:]) { result, match in
                guard let keyRange = Range(match.range(at: 1), in: tag),
                      let valueRange = Range(match.range(at: 2), in: tag) else {
                    return
                }
                result[String(tag[keyRange]).lowercased()] = String(tag[valueRange])
            }
        }

        private static func matchesTitle(text: String?, title: String) -> Bool {
            guard let text else { return false }
            let textTokens = Set(tokens(in: text))
            let titleTokens = tokens(in: title).filter { $0 != "asura" && $0 != "scans" }
            guard !titleTokens.isEmpty else { return false }
            let overlap = titleTokens.filter(textTokens.contains).count
            return overlap >= min(3, titleTokens.count)
        }

        private static func tokens(in text: String) -> [String] {
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
        }

        private static func numericValue(from value: String?) -> Double? {
            guard let value else { return nil }
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
