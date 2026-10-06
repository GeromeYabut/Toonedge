import SwiftUI

public enum SearchOverlayControlPlacement: Equatable, Sendable {
    case navigationToolbar
    case contentHeader
}

public struct SearchOverlayFirstOpenLayout: Equatable, Sendable {
    public var searchFieldPlacement: SearchOverlayControlPlacement
    public var cancelPlacement: SearchOverlayControlPlacement
    public var activatesFocusAfterFirstLayoutPass: Bool

    public init(
        searchFieldPlacement: SearchOverlayControlPlacement,
        cancelPlacement: SearchOverlayControlPlacement,
        activatesFocusAfterFirstLayoutPass: Bool
    ) {
        self.searchFieldPlacement = searchFieldPlacement
        self.cancelPlacement = cancelPlacement
        self.activatesFocusAfterFirstLayoutPass = activatesFocusAfterFirstLayoutPass
    }

    public static let `default` = SearchOverlayFirstOpenLayout(
        searchFieldPlacement: .contentHeader,
        cancelPlacement: .contentHeader,
        activatesFocusAfterFirstLayoutPass: true
    )
}

public struct SearchOverlayView: View {
    private let firstOpenLayout: SearchOverlayFirstOpenLayout
    @Binding private var router: AppRouter
    @StateObject private var viewModel: SearchOverlayViewModel
    @FocusState private var isSearchFocused: Bool

    public init(
        suggestionsProvider: any SearchSuggestionProviding = MockSearchSuggestionProvider(),
        libraryProvider: (any LibrarySearchProviding)? = nil,
        searchHistoryManager: (any SearchHistoryManaging)? = nil,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil,
        firstOpenLayout: SearchOverlayFirstOpenLayout = .default,
        router: Binding<AppRouter>
    ) {
        self._viewModel = StateObject(wrappedValue: SearchOverlayViewModel(
            suggestionsProvider: suggestionsProvider,
            libraryProvider: libraryProvider,
            searchHistoryManager: searchHistoryManager,
            interactionFeedback: interactionFeedback
        ))
        self.firstOpenLayout = firstOpenLayout
        self._router = router
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            searchHeader

            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.failure)
                    .accessibilityIdentifier("search.validation")
            }

            if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Suggestions")
                    .font(ToonEdgeTypography.sectionTitle)
            } else {
                Text("Open or search")
                    .font(ToonEdgeTypography.sectionTitle)
            }

            ScrollView {
                suggestionsList
                    .padding(.bottom, ToonEdgeSpacing.xlarge)
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer(minLength: 0)

        }
        .padding(ToonEdgeSpacing.large)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: ToonEdgeSpacing.small)
        }
        .task {
            if firstOpenLayout.activatesFocusAfterFirstLayoutPass {
                await Task.yield()
            }
            isSearchFocused = true
        }
        .task {
            await viewModel.load()
        }
        .toonEdgeScreen()
    }

    private var searchHeader: some View {
        HStack(alignment: .center, spacing: ToonEdgeSpacing.medium) {
            switch firstOpenLayout.searchFieldPlacement {
            case .contentHeader:
                searchField
            case .navigationToolbar:
                searchField
            }

            switch firstOpenLayout.cancelPlacement {
            case .contentHeader:
                cancelButton
            case .navigationToolbar:
                cancelButton
            }
        }
    }

    private var cancelButton: some View {
        Button("Cancel") {
            router.dismissSheet()
        }
        .font(ToonEdgeTypography.body.weight(.semibold))
        .buttonStyle(TEActionStyle())
        .foregroundStyle(ToonEdgeColor.textPrimary)
        .accessibilityIdentifier("search.cancel")
    }

    private var searchField: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isSearchFocused ? ToonEdgeColor.accent : ToonEdgeColor.textSecondary)
                .accessibilityHidden(true)

            ZStack(alignment: .leading) {
                if viewModel.query.isEmpty {
                    Text("Search the web or paste a chapter link")
                        .font(ToonEdgeTypography.body)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                        .lineLimit(1)
                }

                TextField("", text: $viewModel.query)
                    .foregroundStyle(ToonEdgeColor.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.go)
                    .onSubmit(openCurrentQuery)
                    .accessibilityLabel("Search the web or paste a chapter link")
                    .accessibilityIdentifier("search.input")
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                }
                .buttonStyle(TEActionStyle())
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("search.clear")
            }
        }
        .padding(ToonEdgeSpacing.large)
        .background(ToonEdgeColor.panel, in: RoundedRectangle(cornerRadius: ToonEdgeRadius.medium))
        .frame(maxWidth: .infinity)
    }

    private var suggestionsList: some View {
        VStack(spacing: ToonEdgeSpacing.small) {
            if let feedback = viewModel.historyFeedback {
                VStack(alignment: .leading, spacing: ToonEdgeSpacing.small) {
                    Text(feedback.message)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                    HStack {
                        if feedback.canRetry {
                            Button("Try again") { Task { await viewModel.retryHistoryOperation() } }
                                .accessibilityIdentifier("search.history.retry")
                        }
                        Button("Dismiss") { viewModel.dismissHistoryFeedback() }
                            .accessibilityIdentifier("search.history.dismiss")
                    }
                }
                .accessibilityIdentifier("search.history.feedback")
            }
            if viewModel.suggestions.isEmpty {
                TEBanner(
                    title: "No local suggestions",
                    message: "Type a web search or paste a chapter link to continue.",
                    systemImage: "magnifyingglass"
                )
            } else {
                TEEditorialGroup(viewModel.suggestions, spacing: 0, separatorInset: SearchSuggestionRowLayout().separatorInset) { suggestion in
                    Button {
                        open(suggestion)
                    } label: {
                        SearchSuggestionRow(suggestion: suggestion)
                    }
                    .buttonStyle(TEActionStyle())
                    .accessibilityIdentifier(accessibilityIdentifier(for: suggestion))
                }
            }
        }
    }

    private func open(_ suggestion: SearchSuggestion) {
        viewModel.select(suggestion, router: &router)
        if viewModel.validationMessage != nil { isSearchFocused = true }
    }

    private func accessibilityIdentifier(for suggestion: SearchSuggestion) -> String {
        if case .librarySeries(let item) = suggestion.destination {
            return "search.savedSeries.\(item.id.uuidString)"
        }
        return suggestion.kind == .searchAction ? "search.submitSuggestion" : "search.suggestion"
    }

    private func openCurrentQuery() {
        viewModel.submit(router: &router)
        if viewModel.validationMessage != nil { isSearchFocused = true }
    }
}

struct SearchSuggestionRowLayout: Equatable, Sendable {
    let minimumHeight: CGFloat = TEActionMetrics.minimumHitSize
    let iconWidth: CGFloat = 28
    var separatorInset: CGFloat { iconWidth + ToonEdgeSpacing.medium * 2 }

    func subtitleLineLimit(isSaved: Bool, accessibilityText: Bool) -> Int? {
        isSaved || accessibilityText ? nil : 1
    }
}

private struct SearchSuggestionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let suggestion: SearchSuggestion
    private let layout = SearchSuggestionRowLayout()

    var body: some View {
        HStack(spacing: ToonEdgeSpacing.medium) {
            Image(systemName: suggestion.systemImage)
                .frame(width: layout.iconWidth, height: layout.iconWidth)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ToonEdgeSpacing.xsmall) {
                Text(suggestion.title)
                    .font(ToonEdgeTypography.body)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                Text(suggestion.subtitle)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.textSecondary)
                    .lineLimit(layout.subtitleLineLimit(isSaved: suggestion.kind == .librarySeries, accessibilityText: dynamicTypeSize.isAccessibilitySize))
            }

            Spacer()

            Text(kindLabel)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: dynamicTypeSize.isAccessibilitySize)
        }
        .frame(maxWidth: .infinity, minHeight: layout.minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconColor: Color {
        switch suggestion.kind {
        case .clipboardLink:
            ToonEdgeColor.success
        case .recentLink, .commonSite, .librarySeries:
            ToonEdgeColor.accent
        case .recentSearch, .searchAction:
            ToonEdgeColor.textSecondary
        }
    }

    private var kindLabel: String {
        if suggestion.sourceSupportTier == .enabledPublic {
            return "Supported"
        }

        switch suggestion.kind {
        case .clipboardLink:
            return "Paste"
        case .recentLink:
            return "Link"
        case .librarySeries:
            return "Saved in Library"
        case .recentSearch:
            return "Search"
        case .commonSite:
            return "Site"
        case .searchAction:
            return "Go"
        }
    }
}
