import Foundation

/// Ranks only an already-loaded saved-library projection. No repository work occurs here.
public struct LibrarySuggestionRanker: Sendable {
    public init() {}

    public func rank(query: String, items: [LibrarySearchItem], limit: Int) -> [LibrarySearchItem] {
        guard limit > 0 else { return [] }
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return [] }
        let queryTokens = needle.split(separator: " ").map(String.init)

        let candidates = items.compactMap { item -> Candidate? in
            let title = Self.normalize(item.title)
            guard !title.isEmpty else { return nil }
            let titleTokens = title.split(separator: " ").map(String.init)
            let score: Int
            if title == needle {
                score = 0
            } else if title.hasPrefix(needle) {
                score = 1
            } else if Self.orderedTokenPrefix(queryTokens, in: titleTokens) {
                score = 2
            } else if queryTokens.allSatisfy({ title.contains($0) }) {
                score = 3
            } else {
                return nil
            }
            return Candidate(score: score, normalizedTitle: title, item: item)
        }
        .sorted(by: Self.precedes)

        var seen = Set<UUID>()
        var results: [LibrarySearchItem] = []
        for candidate in candidates where seen.insert(candidate.item.id).inserted {
            results.append(candidate.item)
            if results.count == limit { break }
        }
        return results
    }

    private struct Candidate {
        let score: Int
        let normalizedTitle: String
        let item: LibrarySearchItem
    }

    private static let stableLocale = Locale(identifier: "en_US_POSIX")

    private static func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: stableLocale)
            .lowercased(with: stableLocale)
        let words = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }
        return words.joined().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func orderedTokenPrefix(_ queryTokens: [String], in titleTokens: [String]) -> Bool {
        var nextTitleIndex = titleTokens.startIndex
        for queryToken in queryTokens {
            guard let matchIndex = titleTokens[nextTitleIndex...].firstIndex(where: { $0.hasPrefix(queryToken) }) else {
                return false
            }
            nextTitleIndex = titleTokens.index(after: matchIndex)
        }
        return true
    }

    private static func precedes(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        if lhs.normalizedTitle != rhs.normalizedTitle { return lhs.normalizedTitle < rhs.normalizedTitle }
        if lhs.item.id != rhs.item.id { return lhs.item.id.uuidString < rhs.item.id.uuidString }

        // A projection should have one row per ID. If it does not, choose a stable
        // representative regardless of the provider's input order.
        let left = lhs.item
        let right = rhs.item
        if left.title != right.title { return left.title < right.title }
        if left.sourceDomain != right.sourceDomain { return left.sourceDomain < right.sourceDomain }
        if left.libraryState != right.libraryState { return left.libraryState.rawValue < right.libraryState.rawValue }
        if left.currentChapterLabel != right.currentChapterLabel {
            switch (left.currentChapterLabel, right.currentChapterLabel) {
            case (nil, .some): return true
            case (.some, nil): return false
            case let (.some(leftLabel), .some(rightLabel)): return leftLabel < rightLabel
            case (nil, nil): break
            }
        }
        return (left.coverImageURL?.absoluteString ?? "") < (right.coverImageURL?.absoluteString ?? "")
    }
}
