import Foundation

public enum LibrarySortKey: String, CaseIterable, Equatable, Sendable {
    case activity
    case title
    case unreadUpdates
}

public enum LibrarySortDirection: String, CaseIterable, Equatable, Sendable {
    case ascending
    case descending
}

/// Sorts an existing snapshot projection without changing its membership or storage.
public struct LibraryCollectionQuery: Equatable, Sendable {
    public var segment: LibrarySegment
    public var sortKey: LibrarySortKey
    public var sortDirection: LibrarySortDirection

    public init(segment: LibrarySegment, sortKey: LibrarySortKey, sortDirection: LibrarySortDirection) {
        self.segment = segment
        self.sortKey = sortKey
        self.sortDirection = sortDirection
    }

    public static let `default` = LibraryCollectionQuery(
        segment: .recent,
        sortKey: .activity,
        sortDirection: .descending
    )

    public func apply(to snapshot: LibrarySnapshot) -> [LibrarySeriesSummary] {
        snapshot.series(for: segment).map(Candidate.init).sorted { lhs, rhs in
            switch sortKey {
            case .activity:
                return Self.activityPrecedes(lhs, rhs, direction: sortDirection)
            case .title:
                if lhs.title != rhs.title {
                    return sortDirection == .ascending ? lhs.title < rhs.title : lhs.title > rhs.title
                }
                return lhs.id < rhs.id
            case .unreadUpdates:
                if lhs.summary.hasUnreadUpdates != rhs.summary.hasUnreadUpdates {
                    return lhs.summary.hasUnreadUpdates
                }
                return Self.activityPrecedes(lhs, rhs, direction: .descending)
            }
        }.map(\.summary)
    }

    private struct Candidate {
        let summary: LibrarySeriesSummary
        let title: String
        let id: String

        init(_ summary: LibrarySeriesSummary) {
            self.summary = summary
            let locale = Locale(identifier: "en_US_POSIX")
            title = summary.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
                .lowercased(with: locale)
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            id = summary.id.uuidString.lowercased()
        }
    }

    private static func activityPrecedes(
        _ lhs: Candidate, _ rhs: Candidate, direction: LibrarySortDirection
    ) -> Bool {
        switch (lhs.summary.lastReadAt, rhs.summary.lastReadAt) {
        case let (left?, right?) where left != right:
            return direction == .ascending ? left < right : left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id < rhs.id
        }
    }
}
