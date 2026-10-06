import SwiftUI

enum LibrarySortChoice: String, CaseIterable, Identifiable, Sendable {
    case recentNewest
    case recentOldest
    case titleAscending
    case titleDescending
    case unreadUpdates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentNewest: "Recent activity · Newest"
        case .recentOldest: "Recent activity · Oldest"
        case .titleAscending: "Title · A–Z"
        case .titleDescending: "Title · Z–A"
        case .unreadUpdates: "Unread updates first"
        }
    }

    init(query: LibraryCollectionQuery) {
        switch query.sortKey {
        case .activity:
            self = query.sortDirection == .descending ? .recentNewest : .recentOldest
        case .title:
            self = query.sortDirection == .ascending ? .titleAscending : .titleDescending
        case .unreadUpdates:
            self = .unreadUpdates
        }
    }

    func applying(to query: LibraryCollectionQuery) -> LibraryCollectionQuery {
        var result = query
        switch self {
        case .recentNewest:
            result.sortKey = .activity
            result.sortDirection = .descending
        case .recentOldest:
            result.sortKey = .activity
            result.sortDirection = .ascending
        case .titleAscending:
            result.sortKey = .title
            result.sortDirection = .ascending
        case .titleDescending:
            result.sortKey = .title
            result.sortDirection = .descending
        case .unreadUpdates:
            result.sortKey = .unreadUpdates
            result.sortDirection = .descending
        }
        return result
    }
}

struct LibraryOrganizationLayout: Equatable, Sendable {
    let sortChoice: LibrarySortChoice
    let sourceSummary: String
    let accessibilityIdentifier = "library.sort"
    let accessibilityLabel = "Sort and filter library"
    let resetTitle = "Reset Library organization"
    let isActive: Bool

    var accessibilityValue: String { "\(sortChoice.title), \(sourceSummary)" }

    init(query: LibraryCollectionQuery) {
        sortChoice = LibrarySortChoice(query: query)
        let sources = query.selectedSourceDomains
        if sources.isEmpty {
            sourceSummary = "All Sources"
        } else if sources.count == 1, let domain = sources.first {
            sourceSummary = domain
        } else {
            sourceSummary = "\(sources.count) sources selected"
        }
        isActive = sortChoice != .recentNewest || !sources.isEmpty
    }
}

struct LibraryOrganizationButton: View {
    let layout: LibraryOrganizationLayout
    let show: () -> Void

    var body: some View {
        Button(action: show) {
            Image(systemName: "slider.horizontal.3")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .foregroundStyle(layout.isActive ? ToonEdgeColor.accent : ToonEdgeColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(layout.accessibilityIdentifier)
        .accessibilityLabel(layout.accessibilityLabel)
        .accessibilityValue(layout.accessibilityValue)
    }
}
