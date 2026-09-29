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
    private let suggestionsProvider: any SearchSuggestionProviding
    private let searchHistoryRecorder: (any SearchHistoryRecording)?
    private let interactionFeedback: (any InteractionFeedbackProviding)?
    private let firstOpenLayout: SearchOverlayFirstOpenLayout
    @Binding private var router: AppRouter
    @State private var query = ""
    @State private var validationMessage: String?
    @State private var recentHistory: [SearchHistoryEntry] = []
    @FocusState private var isSearchFocused: Bool

    public init(
        suggestionsProvider: any SearchSuggestionProviding = MockSearchSuggestionProvider(),
        searchHistoryRecorder: (any SearchHistoryRecording)? = nil,
        interactionFeedback: (any InteractionFeedbackProviding)? = nil,
        firstOpenLayout: SearchOverlayFirstOpenLayout = .default,
        router: Binding<AppRouter>
    ) {
        self.suggestionsProvider = suggestionsProvider
        self.searchHistoryRecorder = searchHistoryRecorder
        self.interactionFeedback = interactionFeedback
        self.firstOpenLayout = firstOpenLayout
        self._router = router
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
            searchHeader

            if let validationMessage {
                Text(validationMessage)
                    .font(ToonEdgeTypography.caption)
                    .foregroundStyle(ToonEdgeColor.failure)
                    .accessibilityIdentifier("search.validation")
            }

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            recentHistory = await searchHistoryRecorder?.recentSearchHistory(limit: 12) ?? []
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
                if query.isEmpty {
                    Text("Search the web or paste a chapter link")
                        .font(ToonEdgeTypography.body)
                        .foregroundStyle(ToonEdgeColor.textSecondary)
                        .lineLimit(1)
                }

                TextField("", text: $query)
                    .foregroundStyle(ToonEdgeColor.textPrimary)
                    .focused($isSearchFocused)
                    .submitLabel(.go)
                    .onSubmit(openCurrentQuery)
                    .onChange(of: query) { _, _ in validationMessage = nil }
                    .accessibilityLabel("Search the web or paste a chapter link")
                    .accessibilityIdentifier("search.input")
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }

            if !query.isEmpty {
                Button {
                    query = ""
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
            if currentSuggestions.isEmpty {
                TEBanner(
                    title: "No local suggestions",
                    message: "Type a web search or paste a chapter link to continue.",
                    systemImage: "magnifyingglass"
                )
            } else {
                TEEditorialGroup(currentSuggestions, spacing: 0, separatorInset: SearchSuggestionRowLayout().separatorInset) { suggestion in
                    Button {
                        open(suggestion)
                    } label: {
                        SearchSuggestionRow(suggestion: suggestion)
                    }
                    .buttonStyle(TEActionStyle())
                    .accessibilityIdentifier(suggestion.kind == .searchAction ? "search.submitSuggestion" : "search.suggestion")
                }
            }
        }
    }

    private var currentSuggestions: [SearchSuggestion] {
        SearchHistoryBackedSuggestionProvider(
            baseProvider: suggestionsProvider,
            history: recentHistory
        )
        .suggestions(matching: query)
    }

    private func open(_ suggestion: SearchSuggestion) {
        openValue(suggestion.value, title: suggestion.title)
    }

    private func openCurrentQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        openValue(trimmed, title: trimmed)
    }

    private func openValue(_ value: String, title: String) {
        let input: SearchInput
        switch SearchInputClassifier.validate(value) {
        case .empty:
            return
        case .invalidURL:
            validationMessage = "Enter a complete web address or search phrase."
            if let interactionFeedback {
                InteractionFeedbackOutcomeReporter(feedback: interactionFeedback)
                    .reportInvalidInput(validationIsVisible: validationMessage != nil)
            }
            isSearchFocused = true
            return
        case .valid(let validatedInput):
            input = validatedInput
        }
        if let searchHistoryRecorder {
            Task {
                try? await searchHistoryRecorder.recordSearchHistory(
                    SearchHistoryInput(
                        kind: input.kind == .url ? .link : .searchQuery,
                        value: input.normalizedValue,
                        displayTitle: title
                    )
                )
                recentHistory = await searchHistoryRecorder.recentSearchHistory(limit: 12)
            }
        }
        router.presentBrowser(input.browserStartPoint)
    }
}

struct SearchSuggestionRowLayout: Equatable, Sendable {
    let minimumHeight: CGFloat = TEActionMetrics.minimumHitSize
    let iconWidth: CGFloat = 28
    var separatorInset: CGFloat { iconWidth + ToonEdgeSpacing.medium * 2 }
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }

            Spacer()

            Text(kindLabel)
                .font(ToonEdgeTypography.caption)
                .foregroundStyle(ToonEdgeColor.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, minHeight: layout.minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconColor: Color {
        switch suggestion.kind {
        case .clipboardLink:
            ToonEdgeColor.success
        case .recentLink, .commonSite:
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
        case .recentSearch:
            return "Search"
        case .commonSite:
            return "Site"
        case .searchAction:
            return "Go"
        }
    }
}
