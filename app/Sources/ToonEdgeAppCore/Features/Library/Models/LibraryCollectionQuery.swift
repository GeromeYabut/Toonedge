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

public struct LibrarySourceOption: Identifiable, Equatable, Sendable {
    public let domain: String
    public let titleCount: Int
    public var id: String { domain }

    public init(domain: String, titleCount: Int) {
        self.domain = domain
        self.titleCount = titleCount
    }
}

/// Filters and sorts an existing snapshot projection without changing its storage.
public struct LibraryCollectionQuery: Equatable, Sendable {
    public var segment: LibrarySegment
    public var sortKey: LibrarySortKey
    public var sortDirection: LibrarySortDirection

    private var sourceDomains: Set<String>
    public var selectedSourceDomains: Set<String> {
        get { sourceDomains }
        set { sourceDomains = Self.normalizedSources(newValue) }
    }

    public init(segment: LibrarySegment, sortKey: LibrarySortKey, sortDirection: LibrarySortDirection,
                selectedSourceDomains: Set<String> = []) {
        self.segment = segment
        self.sortKey = sortKey
        self.sortDirection = sortDirection
        self.sourceDomains = Self.normalizedSources(selectedSourceDomains)
    }

    public static let `default` = LibraryCollectionQuery(
        segment: .recent,
        sortKey: .activity,
        sortDirection: .descending
    )

    public func apply(to snapshot: LibrarySnapshot) -> [LibrarySeriesSummary] {
        let eligible = snapshot.series(for: segment).filter {
            selectedSourceDomains.isEmpty || selectedSourceDomains.contains(
                LibraryIdentityNormalizer.normalizedSourceDomain($0.sourceDomain))
        }
        return eligible.map(Candidate.init).sorted { lhs, rhs in
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

    public static func sourceOptions(in snapshot: LibrarySnapshot) -> [LibrarySourceOption] {
        var counts: [String: Int] = [:]
        for summary in snapshot.series {
            let domain = LibraryIdentityNormalizer.normalizedSourceDomain(summary.sourceDomain)
            if !domain.isEmpty { counts[domain, default: 0] += 1 }
        }
        return counts.keys.sorted().map { LibrarySourceOption(domain: $0, titleCount: counts[$0]!) }
    }

    public func repairingSources(in snapshot: LibrarySnapshot) -> LibraryCollectionQuery {
        var result = self
        result.selectedSourceDomains.formIntersection(Self.sourceOptions(in: snapshot).map(\.domain))
        return result
    }

    private static func normalizedSources(_ sources: Set<String>) -> Set<String> {
        Set(sources.map(LibraryIdentityNormalizer.normalizedSourceDomain).filter { !$0.isEmpty })
    }

    private struct Candidate {
        let summary: LibrarySeriesSummary
        let title: String
        let id: String

        init(_ summary: LibrarySeriesSummary) {
            self.summary = summary
            let locale = Locale(identifier: "en_US_POSIX")
            title = summary.title.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: locale)
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
