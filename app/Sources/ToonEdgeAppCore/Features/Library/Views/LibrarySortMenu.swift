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

struct LibrarySortMenuLayout: Equatable, Sendable {
    let selectedChoice: LibrarySortChoice
    let accessibilityIdentifier = "library.sort"
    let accessibilityLabel = "Sort library"
    let resetTitle = "Reset Library organization"
    let resetIsAvailable = true

    var accessibilityValue: String { selectedChoice.title }

    init(query: LibraryCollectionQuery) {
        selectedChoice = LibrarySortChoice(query: query)
    }

    func isSelected(_ choice: LibrarySortChoice) -> Bool {
        choice == selectedChoice
    }
}

struct LibrarySortMenu: View {
    let layout: LibrarySortMenuLayout
    let select: (LibrarySortChoice) -> Void
    let reset: () -> Void

    var body: some View {
        Menu {
            ForEach(LibrarySortChoice.allCases) { choice in
                Button {
                    select(choice)
                } label: {
                    if layout.isSelected(choice) {
                        Label(choice.title, systemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
                .accessibilityAddTraits(layout.isSelected(choice) ? .isSelected : [])
                .accessibilityIdentifier("library.sort.\(choice.rawValue)")
            }
            if layout.resetIsAvailable {
                Divider()
                Button(layout.resetTitle, action: reset)
                    .accessibilityIdentifier("library.sort.reset")
            }
        } label: {
            HStack(spacing: ToonEdgeSpacing.small) {
                Text(layout.accessibilityValue)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "arrow.up.arrow.down")
            }
            .font(ToonEdgeTypography.caption)
            .foregroundStyle(ToonEdgeColor.textPrimary)
            .padding(.vertical, ToonEdgeSpacing.small)
        }
        .accessibilityIdentifier(layout.accessibilityIdentifier)
        .accessibilityLabel(layout.accessibilityLabel)
        .accessibilityValue(layout.accessibilityValue)
    }
}
